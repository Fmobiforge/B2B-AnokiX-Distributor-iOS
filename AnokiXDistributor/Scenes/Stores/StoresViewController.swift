import UIKit

/// Port of StoresActivity + activity_stores.xml. Search over name / address / tags,
/// a store-count pill and the store cards.
final class StoresViewController: BaseSecondaryViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    override var screenTitle: String { S.stores }
    override var trailingTitle: String? { S.addStore }
    override var trailingIcon: String? { "ic_add" }

    private let collectionView = UICollectionView(
        frame: .zero, collectionViewLayout: AdaptiveGridLayout.make(estimatedHeight: 128))
    private var allItems: [StoreItem] = []
    private var filtered: [StoreItem] = []
    private var search = ""
    private let countPill = PaddingLabel(insets: UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12))
    private let emptyLabel = UILabel.make(S.noStoresYet, font: AppFonts.regular(AppMetrics.textBody),
                                          color: AppColors.textSecondary, align: .center, lines: 0)

    override func setupContent(in container: UIView) {
        let searchBar = SearchBarView(placeholder: S.searchStores, height: 42)
        searchBar.onChange = { [weak self] text in self?.search = text; self?.applyFilters() }

        countPill.font = AppFonts.bold(AppMetrics.textBodySM)
        countPill.textColor = AppColors.purplePrimary
        countPill.backgroundColor = AppColors.purpleLight
        countPill.layer.cornerRadius = AppMetrics.radiusSM
        countPill.layer.masksToBounds = true
        countPill.setContentHuggingPriority(.required, for: .horizontal)
        countPill.setContentCompressionResistancePriority(.required, for: .horizontal)

        let searchRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        searchRow.addArrangedSubview(searchBar)
        searchRow.addArrangedSubview(countPill)

        let chrome = ListScreenLayout.surfaceSection(
            [searchRow],
            spacing: 0,
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

        emptyLabel.isHidden = true
        emptyLabel.forAutoLayout()
        container.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.topAnchor.constraint(equalTo: collectionView.topAnchor, constant: 48),
            emptyLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32)
        ])

        applyFilters()
    }

    override func loadData() {
        ApiClient.shared.getStores(keyword: "") { [weak self] result in
            guard let self = self, case .success(let data) = result else { return }
            self.allItems = ApiMapper.toStoreItems(data)
            self.applyFilters()
        }
    }

    override func trailingTapped() { openEditor(storeId: nil, storeName: nil) }

    private func openEditor(storeId: String?, storeName: String?, listItem: StoreItem? = nil) {
        let editor = AddEditStoreViewController(storeId: storeId, storeName: storeName, listItem: listItem)
        editor.onSaved = { [weak self] in self?.loadData() }
        navigationController?.pushViewController(editor, animated: true)
    }

    /// Local search over name, address and tags — mirrors the web store list search.
    private func applyFilters() {
        let needle = search.trimmingCharacters(in: .whitespaces)
        filtered = needle.isEmpty ? allItems : allItems.filter { item in
            item.name.localizedCaseInsensitiveContains(needle)
                || item.address.localizedCaseInsensitiveContains(needle)
                || item.tags.contains { $0.localizedCaseInsensitiveContains(needle) }
        }
        countPill.text = S.storesCount(filtered.count)
        emptyLabel.text = allItems.isEmpty ? S.noStoresYet : S.noStoresFound
        emptyLabel.isHidden = !filtered.isEmpty
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
