import UIKit

/// Port of StoresActivity + activity_stores.xml. Search, area filter, filter icon, store cards.
final class StoresViewController: BaseSecondaryViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    override var screenTitle: String { S.stores }
    override var trailingTitle: String? { S.addStore }
    override var trailingIcon: String? { "ic_add" }

    private let collectionView = UICollectionView(
        frame: .zero, collectionViewLayout: AdaptiveGridLayout.make(estimatedHeight: 100))
    private var allItems: [StoreItem] = []
    private var filtered: [StoreItem] = []
    private var selectedArea = S.allAreas
    private var search = ""
    private var areaPill: FilterPillButton!

    override func setupContent(in container: UIView) {
        let searchBar = SearchBarView(placeholder: "Search stores…", height: 42)
        searchBar.onChange = { [weak self] text in self?.search = text; self?.applyFilters() }

        areaPill = FilterPillButton(title: selectedArea)
        areaPill.addTarget(self, action: #selector(pickArea), for: .touchUpInside)
        let filterButton = FilterIconButton.make()

        let filterRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        filterRow.addArrangedSubview(areaPill)
        filterRow.addArrangedSubview(filterButton)

        let chrome = ListScreenLayout.surfaceSection(
            [searchBar, filterRow],
            spacing: 10,
            insets: UIEdgeInsets(top: AppMetrics.screenPaddingVertical, left: 16, bottom: 12, right: 16)
        )

        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = AppColors.surface
        collectionView.alwaysBounceVertical = true
        // Horizontal margins come from AdaptiveGridLayout.section.contentInsets only.
        collectionView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 16, right: 0)
        collectionView.registerNib(StoreCell.self)

        _ = embedSecondaryListChrome(in: container, chrome: chrome, listView: collectionView)
    }

    override func loadData() {
        allItems = MockData.storeItems()
        applyFilters()
        ApiClient.shared.getStores(keyword: "") { [weak self] result in
            guard let self = self, case .success(let data) = result else { return }
            let mapped = ApiMapper.toStoreItems(data)
            if !mapped.isEmpty { self.allItems = mapped; self.applyFilters() }
        }
    }

    override func trailingTapped() { openEditor(storeId: nil, storeName: nil) }

    private func openEditor(storeId: String?, storeName: String?, listItem: StoreItem? = nil) {
        let editor = AddEditStoreViewController(storeId: storeId, storeName: storeName, listItem: listItem)
        editor.onSaved = { [weak self] in self?.loadData() }
        navigationController?.pushViewController(editor, animated: true)
    }

    @objc private func pickArea() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for area in MockData.filterAreas {
            sheet.addAction(UIAlertAction(title: area, style: .default) { [weak self] _ in
                self?.selectedArea = area
                self?.areaPill.setTitle(area)
                self?.applyFilters()
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }

    private func applyFilters() {
        filtered = allItems.filter { item in
            let matchesArea = selectedArea == S.allAreas || item.area == selectedArea
            let matchesSearch = search.isEmpty || item.name.localizedCaseInsensitiveContains(search)
            return matchesArea && matchesSearch
        }
        collectionView.reloadData()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { filtered.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeue(StoreCell.self, for: indexPath)
        cell.configure(filtered[indexPath.row])
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let item = filtered[indexPath.row]
        openEditor(storeId: item.id, storeName: item.name, listItem: item)
    }
}
