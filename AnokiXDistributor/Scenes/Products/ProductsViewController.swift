import UIKit

/// Standalone Products list from the drawer — matches activity_products / fragment search row.
final class ProductsViewController: BaseSecondaryViewController, UICollectionViewDataSource {

    override var screenTitle: String { S.products }
    override var screenSubtitle: String? { nil }

    private let collectionView = UICollectionView(
        frame: .zero, collectionViewLayout: AdaptiveGridLayout.make(estimatedHeight: 88))
    private var items: [ProductItem] = []
    private var filtered: [ProductItem] = []

    override func setupContent(in container: UIView) {
        let searchRow = SearchFilterRowView(placeholder: "Search products…", height: 42)
        searchRow.searchBar.onChange = { [weak self] text in
            guard let self = self else { return }
            self.filtered = text.isEmpty ? self.items
                : self.items.filter { $0.name.localizedCaseInsensitiveContains(text) }
            self.collectionView.reloadData()
        }

        let chrome = ListScreenLayout.surfaceSection(
            [searchRow],
            insets: UIEdgeInsets(top: AppMetrics.screenPaddingVertical, left: 16, bottom: 12, right: 16)
        )

        collectionView.dataSource = self
        collectionView.backgroundColor = AppColors.background
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 16, right: 0)
        collectionView.registerNib(ProductCell.self)

        _ = embedSecondaryListChrome(in: container, chrome: chrome, listView: collectionView)
    }

    override func loadData() {
        items = MockData.productItems()
        filtered = items
        collectionView.reloadData()
        ApiClient.shared.getProducts { [weak self] result in
            guard let self = self, case .success(let data) = result else { return }
            let mapped = ApiMapper.toProductItems(data)
            if !mapped.isEmpty { self.items = mapped; self.filtered = mapped; self.collectionView.reloadData() }
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { filtered.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeue(ProductCell.self, for: indexPath)
        cell.configure(filtered[indexPath.row])
        return cell
    }
}
