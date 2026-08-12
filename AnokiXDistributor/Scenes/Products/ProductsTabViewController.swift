import UIKit

/// Products tab — matches fragment_products.xml: logo header, title, KPI cards, stock
/// tabs, search + category / brand / status filters, product list and the Add FAB.
final class ProductsTabViewController: BaseMainViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    @IBOutlet private weak var logoImageView: UIImageView!
    @IBOutlet private weak var logoSubtitleLabel: UILabel!
    @IBOutlet private weak var pageTitleLabel: UILabel!

    private let productsCollectionView = UICollectionView(
        frame: .zero, collectionViewLayout: AdaptiveGridLayout.make(estimatedHeight: 118))
    private let addProductButton = UIButton(type: .system)
    private let chrome = ProductsChromeView()
    private let countLabel = UILabel.make(font: AppFonts.regular(AppMetrics.textCaption),
                                          color: AppColors.textSecondary)
    private let emptyLabel = UILabel.make(S.noProductsYet, font: AppFonts.regular(AppMetrics.textBody),
                                          color: AppColors.textSecondary, align: .center, lines: 0)

    private var items: [ProductItem] = []
    private var filtered: [ProductItem] = []

    override func configureStoryboardChrome() {
        logoImageView.image = BrandAssets.logoBlack
        configureLogoHeaderImage(logoImageView, in: chromeStackView.arrangedSubviews.first)
        logoSubtitleLabel.text = S.loginSubtitle
        logoSubtitleLabel.font = AppFonts.light(AppMetrics.textLabel)
        logoSubtitleLabel.textColor = AppColors.textSecondary
        pageTitleLabel.text = S.productsTitle
        pageTitleLabel.font = AppFonts.bold(AppMetrics.textHeadline)
        pageTitleLabel.textColor = AppColors.textPrimary
        styleNotificationBell(in: chromeStackView.arrangedSubviews.first)
    }

    override func setupContent(in container: UIView) {
        chrome.presenter = self
        chrome.onFilterChanged = { [weak self] in self?.applyFilter() }

        let countRow = UIView()
        countRow.backgroundColor = AppColors.background
        countLabel.forAutoLayout()
        countRow.addSubview(countLabel)
        countLabel.pinEdges(to: countRow, insets: UIEdgeInsets(top: 10, left: 16, bottom: 0, right: 16))

        productsCollectionView.dataSource = self
        productsCollectionView.delegate = self
        productsCollectionView.backgroundColor = AppColors.background
        productsCollectionView.alwaysBounceVertical = true
        productsCollectionView.keyboardDismissMode = .onDrag
        productsCollectionView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 80, right: 0)
        productsCollectionView.registerNib(ProductCell.self)

        StyleKit.stylePrimaryButton(addProductButton, fontSize: 13)
        addProductButton.setTitle("  Add Product", for: .normal)
        addProductButton.setImage(UIImage(systemName: "plus"), for: .normal)
        addProductButton.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        addProductButton.addTarget(self, action: #selector(addProductTapped), for: .touchUpInside)

        let divider = ListScreenLayout.hairline()
        chrome.forAutoLayout()
        countRow.forAutoLayout()
        divider.forAutoLayout()
        productsCollectionView.forAutoLayout()
        addProductButton.forAutoLayout()
        emptyLabel.forAutoLayout()
        emptyLabel.isHidden = true
        container.addSubviews(chrome, divider, countRow, productsCollectionView, emptyLabel, addProductButton)

        NSLayoutConstraint.activate([
            chrome.topAnchor.constraint(equalTo: container.topAnchor),
            chrome.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.topAnchor.constraint(equalTo: chrome.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            countRow.topAnchor.constraint(equalTo: divider.bottomAnchor),
            countRow.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            countRow.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            productsCollectionView.topAnchor.constraint(equalTo: countRow.bottomAnchor),
            productsCollectionView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            productsCollectionView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            productsCollectionView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            emptyLabel.topAnchor.constraint(equalTo: productsCollectionView.topAnchor, constant: 40),
            emptyLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
            addProductButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            addProductButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            addProductButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func styleNotificationBell(in panel: UIView?) {
        guard let panel = panel,
              let bell = panel.subviews.compactMap({ $0 as? UIButton }).first else { return }
        bell.tintColor = AppColors.textPrimary
        addNotificationBadge(to: bell)
    }

    @IBAction private func notificationsTapped(_ sender: UIButton) { openNotifications() }

    @objc private func addProductTapped() {
        let options = AddProductOptionsViewController()
        options.onSaved = { [weak self] in self?.loadProducts() }
        options.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(options, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard indexPath.row < filtered.count else { return }
        let wizard = CreateProductViewController()
        wizard.productId = filtered[indexPath.row].id
        wizard.onSaved = { [weak self] in self?.loadProducts() }
        wizard.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(wizard, animated: true)
    }

    private func applyFilter() {
        filtered = chrome.filteredItems
        countLabel.text = "\(filtered.count) of \(items.count) products"
        emptyLabel.text = items.isEmpty ? S.noProductsYet : S.noProductsMatch
        emptyLabel.isHidden = !filtered.isEmpty
        productsCollectionView.reloadData()
    }

    override func loadData() {
        loadProducts()
        loadFilterOptions()
    }

    /// Port of ProductsFragment.loadProducts(): fetch from the API, populate the list on
    /// success, and surface the server message on failure.
    private func loadProducts() {
        ApiClient.shared.getProducts { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                self.items = ApiMapper.toProductItems(data)
                self.chrome.setProducts(self.items, summary: data.summary)
                self.applyFilter()
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    /// Categories + brands for the filter pickers; failures leave the product-derived lists.
    private func loadFilterOptions() {
        ApiClient.shared.getBaseInfo { [weak self] result in
            guard let self = self, case .success(let data) = result else { return }
            self.chrome.setBaseInfo(data)
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { filtered.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeue(ProductCell.self, for: indexPath)
        cell.configure(filtered[indexPath.row])
        return cell
    }

    private func toast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { alert.dismiss(animated: true) }
    }
}
