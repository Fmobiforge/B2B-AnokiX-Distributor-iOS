import UIKit

/// Products tab — matches fragment_products.xml: logo header, title, search + filter, list, FAB.
final class ProductsTabViewController: BaseMainViewController, UICollectionViewDataSource {

    @IBOutlet private weak var logoImageView: UIImageView!
    @IBOutlet private weak var logoSubtitleLabel: UILabel!
    @IBOutlet private weak var pageTitleLabel: UILabel!
    @IBOutlet private weak var searchField: UITextField!
    @IBOutlet private weak var productsCollectionView: UICollectionView!
    @IBOutlet private weak var addProductButton: UIButton!

    private var searchRow: SearchFilterRowView?
    private var items: [ProductItem] = []
    private var filtered: [ProductItem] = []

    override func configureStoryboardChrome() {
        constrainLogoHeaderImage(logoImageView)
        logoImageView.image = BrandAssets.logoBlack
        logoSubtitleLabel.text = S.loginSubtitle
        logoSubtitleLabel.font = AppFonts.light(AppMetrics.textLabel)
        logoSubtitleLabel.textColor = AppColors.textSecondary
        pageTitleLabel.text = S.productsTitle
        pageTitleLabel.font = AppFonts.bold(AppMetrics.textHeadline)
        pageTitleLabel.textColor = AppColors.textPrimary
        addLogoHeaderDivider()
        styleNotificationBell(in: chromeStackView.arrangedSubviews.first)
        wireSearchFilterRow()
        wireProductsList()
        wireAddProductFab()
    }

    private func addLogoHeaderDivider() {
        guard let logoPanel = chromeStackView.arrangedSubviews.first else { return }
        guard logoPanel.viewWithTag(8801) == nil else { return }
        let divider = UIView()
        divider.tag = 8801
        divider.backgroundColor = AppColors.border
        divider.translatesAutoresizingMaskIntoConstraints = false
        logoPanel.addSubview(divider)
        NSLayoutConstraint.activate([
            divider.leadingAnchor.constraint(equalTo: logoPanel.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: logoPanel.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: logoPanel.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func wireSearchFilterRow() {
        guard searchRow == nil, let container = searchField.superview else { return }
        let placeholder = searchField.placeholder ?? "Search products…"
        container.constraints.filter {
            ($0.firstItem as? UITextField == searchField) || ($0.secondItem as? UITextField == searchField)
        }.forEach { $0.isActive = false }
        searchField.removeFromSuperview()

        let row = SearchFilterRowView(placeholder: placeholder, height: 42)
        row.searchBar.onChange = { [weak self] text in self?.applySearch(text) }
        row.forAutoLayout()
        container.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            row.heightAnchor.constraint(equalToConstant: 42)
        ])
        searchRow = row

        if let collection = productsCollectionView {
            container.constraints.filter {
                ($0.firstItem as? UICollectionView == collection && $0.firstAttribute == .top)
                || ($0.secondItem as? UICollectionView == collection && $0.secondAttribute == .top)
            }.forEach { $0.isActive = false }
            NSLayoutConstraint.activate([
                collection.topAnchor.constraint(equalTo: row.bottomAnchor, constant: 12)
            ])
        }
    }

    private func wireProductsList() {
        productsCollectionView.dataSource = self
        productsCollectionView.backgroundColor = AppColors.background
        productsCollectionView.alwaysBounceVertical = true
        productsCollectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)
        productsCollectionView.collectionViewLayout = AdaptiveGridLayout.make(estimatedHeight: 88)
        productsCollectionView.registerNib(ProductCell.self)
    }

    private func wireAddProductFab() {
        StyleKit.stylePrimaryButton(addProductButton)
        addProductButton.setTitle("  Add Product", for: .normal)
        addProductButton.setImage(UIImage(systemName: "plus"), for: .normal)
    }

    private func styleNotificationBell(in panel: UIView?) {
        guard let panel = panel,
              let bell = panel.subviews.compactMap({ $0 as? UIButton }).first else { return }
        bell.tintColor = AppColors.textPrimary
        addNotificationBadge(to: bell)
    }

    @IBAction private func notificationsTapped(_ sender: UIButton) { openNotifications() }

    @IBAction private func addProductTapped(_ sender: UIButton) {
        toast("Add product coming soon")
    }

    private func applySearch(_ text: String) {
        filtered = text.isEmpty ? items : items.filter { $0.name.localizedCaseInsensitiveContains(text) }
        productsCollectionView.reloadData()
    }

    override func loadData() {
        items = MockData.productItems()
        filtered = items
        productsCollectionView.reloadData()

        ApiClient.shared.getProducts { [weak self] result in
            guard let self = self, case .success(let data) = result else { return }
            let mapped = ApiMapper.toProductItems(data)
            if !mapped.isEmpty {
                self.items = mapped
                self.filtered = mapped
                self.productsCollectionView.reloadData()
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
