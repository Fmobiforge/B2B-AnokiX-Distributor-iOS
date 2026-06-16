import UIKit

/// Products tab — matches fragment_products.xml: logo header, title, search + filter, list, FAB.
final class ProductsTabViewController: BaseMainViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    @IBOutlet private weak var logoImageView: UIImageView!
    @IBOutlet private weak var logoSubtitleLabel: UILabel!
    @IBOutlet private weak var pageTitleLabel: UILabel!

    private let productsCollectionView = UICollectionView(
        frame: .zero, collectionViewLayout: AdaptiveGridLayout.make(estimatedHeight: 88))
    private let addProductButton = UIButton(type: .system)

    private var items: [ProductItem] = []
    private var filtered: [ProductItem] = []
    private var search = ""

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
        let searchRow = SearchFilterRowView(placeholder: "Search products…", height: 42)
        searchRow.searchBar.onChange = { [weak self] text in
            self?.search = text
            self?.applyFilter()
        }
        searchRow.bindFilterToast(from: self)

        let chrome = ListScreenLayout.surfaceSection(
            [searchRow],
            insets: UIEdgeInsets(top: 0, left: 16, bottom: 12, right: 16)
        )

        productsCollectionView.dataSource = self
        productsCollectionView.delegate = self
        productsCollectionView.backgroundColor = AppColors.background
        productsCollectionView.alwaysBounceVertical = true
        productsCollectionView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 80, right: 0)
        productsCollectionView.registerNib(ProductCell.self)

        StyleKit.stylePrimaryButton(addProductButton)
        addProductButton.setTitle("  Add Product", for: .normal)
        addProductButton.setImage(UIImage(systemName: "plus"), for: .normal)
        addProductButton.addTarget(self, action: #selector(addProductTapped), for: .touchUpInside)

        let divider = ListScreenLayout.hairline()
        chrome.forAutoLayout()
        divider.forAutoLayout()
        productsCollectionView.forAutoLayout()
        addProductButton.forAutoLayout()
        container.addSubviews(chrome, divider, productsCollectionView, addProductButton)

        NSLayoutConstraint.activate([
            chrome.topAnchor.constraint(equalTo: container.topAnchor),
            chrome.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.topAnchor.constraint(equalTo: chrome.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            productsCollectionView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            productsCollectionView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            productsCollectionView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            productsCollectionView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
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
        filtered = search.isEmpty ? items : items.filter { $0.name.localizedCaseInsensitiveContains(search) }
        productsCollectionView.reloadData()
    }

    override func loadData() {
        loadProducts()
    }

    /// Port of ProductsFragment.loadProducts(): fetch from the API, populate the list on
    /// success, and surface the server message on failure.
    private func loadProducts() {
        ApiClient.shared.getProducts { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                self.items = ApiMapper.toProductItems(data)
                self.applyFilter()
            case .failure(let error):
                self.toast(error.message)
            }
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
