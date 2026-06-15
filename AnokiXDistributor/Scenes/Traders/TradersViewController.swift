import UIKit

/// Port of TradersActivity + activity_traders.xml. Search, area/segment filters, trader cards.
final class TradersViewController: BaseSecondaryViewController, UICollectionViewDataSource {

    override var screenTitle: String { S.traders }

    private let collectionView = UICollectionView(
        frame: .zero, collectionViewLayout: AdaptiveGridLayout.make(estimatedHeight: 84))
    private var allItems: [TraderItem] = []
    private var filtered: [TraderItem] = []
    private var search = ""
    private var selectedArea = S.allAreas
    private var selectedSegment = S.allSegments
    private var areaPill: FilterPillButton!
    private var segmentPill: FilterPillButton!

    override func setupContent(in container: UIView) {
        let titleLabel = UILabel.make(S.traders, font: AppFonts.bold(AppMetrics.textHeadline), color: AppColors.textPrimary)
        let searchBar = SearchBarView(placeholder: S.searchTraders, height: 42)
        searchBar.onChange = { [weak self] text in self?.search = text; self?.applyFilters() }

        areaPill = FilterPillButton(title: selectedArea)
        areaPill.addTarget(self, action: #selector(pickArea), for: .touchUpInside)
        segmentPill = FilterPillButton(title: selectedSegment)
        segmentPill.addTarget(self, action: #selector(pickSegment), for: .touchUpInside)
        let filterButton = FilterIconButton.make()

        let filterRow = UIStackView.horizontal(spacing: 6, alignment: .center)
        filterRow.distribution = .fill
        filterRow.addArrangedSubview(areaPill)
        filterRow.addArrangedSubview(segmentPill)
        filterRow.addArrangedSubview(filterButton)

        let chrome = ListScreenLayout.surfaceSection(
            [titleLabel, searchBar, filterRow],
            spacing: 10,
            insets: UIEdgeInsets(top: 16, left: 16, bottom: 12, right: 16)
        )

        collectionView.dataSource = self
        collectionView.backgroundColor = AppColors.surface
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 16, right: 0)
        collectionView.registerNib(TraderCell.self)

        _ = embedSecondaryListChrome(in: container, chrome: chrome, listView: collectionView)
    }

    override func loadData() {
        ApiClient.shared.getTraders(search: "") { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                self.allItems = ApiMapper.toTraderItems(data)
                self.applyFilters()
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    @objc private func pickArea() {
        pick(from: MockData.filterAreas, current: selectedArea) { [weak self] value in
            self?.selectedArea = value
            self?.areaPill.setTitle(value)
            self?.applyFilters()
        }
    }

    @objc private func pickSegment() {
        pick(from: MockData.filterSegments, current: selectedSegment) { [weak self] value in
            self?.selectedSegment = value
            self?.segmentPill.setTitle(value)
            self?.applyFilters()
        }
    }

    private func pick(from options: [String], current: String, onPick: @escaping (String) -> Void) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for option in options {
            sheet.addAction(UIAlertAction(title: option, style: .default) { _ in onPick(option) })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }

    private func applyFilters() {
        filtered = allItems.filter { item in
            let matchesArea = selectedArea == S.allAreas || selectedArea == item.area
            let matchesSegment = selectedSegment == S.allSegments
                || item.segment.caseInsensitiveCompare(selectedSegment) == .orderedSame
            let matchesSearch = search.isEmpty || item.name.localizedCaseInsensitiveContains(search)
                || item.location.localizedCaseInsensitiveContains(search)
                || item.phone.localizedCaseInsensitiveContains(search)
            return matchesArea && matchesSegment && matchesSearch
        }
        collectionView.reloadData()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { filtered.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeue(TraderCell.self, for: indexPath)
        cell.configure(filtered[indexPath.row])
        return cell
    }
}
