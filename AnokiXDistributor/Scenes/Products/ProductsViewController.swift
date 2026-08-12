import UIKit

/// Standalone Products list from the drawer — KPI cards, stock tabs, keyword search
/// and the category / brand / status filters (activity_products.xml).
final class ProductsViewController: BaseSecondaryViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    override var screenTitle: String { S.products }
    override var screenSubtitle: String? { S.productsSubtitle }

    private let collectionView = UICollectionView(
        frame: .zero, collectionViewLayout: AdaptiveGridLayout.make(estimatedHeight: 118))
    private let chrome = ProductsChromeView()
    private let countLabel = UILabel.make(font: AppFonts.regular(AppMetrics.textCaption),
                                          color: AppColors.textSecondary)
    private let emptyLabel = UILabel.make(S.noProductsYet, font: AppFonts.regular(AppMetrics.textBody),
                                          color: AppColors.textSecondary, align: .center, lines: 0)
    private var items: [ProductItem] = []
    private var filtered: [ProductItem] = []

    override func setupContent(in container: UIView) {
        chrome.presenter = self
        chrome.onFilterChanged = { [weak self] in self?.applyFilter() }

        let countRow = UIView()
        countRow.backgroundColor = AppColors.background
        countLabel.forAutoLayout()
        countRow.addSubview(countLabel)
        countLabel.pinEdges(to: countRow, insets: UIEdgeInsets(top: 10, left: 16, bottom: 0, right: 16))

        let chromeBlock = UIStackView.vertical(spacing: 0, alignment: .fill)
        chromeBlock.addArrangedSubview(chrome)
        chromeBlock.addArrangedSubview(countRow)

        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = AppColors.background
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .onDrag
        collectionView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 16, right: 0)
        collectionView.registerNib(ProductCell.self)

        _ = embedSecondaryListChrome(in: container, chrome: chromeBlock, listView: collectionView)

        emptyLabel.isHidden = true
        emptyLabel.forAutoLayout()
        container.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.topAnchor.constraint(equalTo: collectionView.topAnchor, constant: 40),
            emptyLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32)
        ])
    }

    override func loadData() {
        loadProducts()
        loadFilterOptions()
    }

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

    private func applyFilter() {
        filtered = chrome.filteredItems
        countLabel.text = "\(filtered.count) of \(items.count) products"
        emptyLabel.text = items.isEmpty ? S.noProductsYet : S.noProductsMatch
        emptyLabel.isHidden = !filtered.isEmpty
        collectionView.reloadData()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { filtered.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeue(ProductCell.self, for: indexPath)
        cell.configure(filtered[indexPath.row])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard indexPath.row < filtered.count else { return }
        let wizard = CreateProductViewController()
        wizard.productId = filtered[indexPath.row].id
        wizard.onSaved = { [weak self] in self?.loadProducts() }
        navigationController?.pushViewController(wizard, animated: true)
    }
}
