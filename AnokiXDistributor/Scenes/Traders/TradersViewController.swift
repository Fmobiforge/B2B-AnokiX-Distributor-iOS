import UIKit

/// Port of TradersActivity + activity_traders.xml. Search, status / registration-status
/// filters (driven by the API), a trader card list, and an "+ Add New Trader" action
/// that opens the 8-step Create Trader wizard.
final class TradersViewController: BaseSecondaryViewController, UICollectionViewDataSource {

    override var screenTitle: String { S.traders }
    override var trailingTitle: String? { S.addNewTraderButton }

    private let collectionView = UICollectionView(
        frame: .zero, collectionViewLayout: AdaptiveGridLayout.make(estimatedHeight: 84))
    private var allItems: [TraderItem] = []
    private var filtered: [TraderItem] = []
    private var search = ""

    // Server-side filters: empty string means "no filter" (All Status).
    private var selectedStatus = ""
    private var selectedRegistrationStatus = ""
    private var statusPill: FilterPillButton!
    private var registrationPill: FilterPillButton!

    override func setupContent(in container: UIView) {
        let titleLabel = UILabel.make(S.traders, font: AppFonts.bold(AppMetrics.textHeadline), color: AppColors.textPrimary)
        let searchBar = SearchBarView(placeholder: S.searchTraders, height: 42)
        searchBar.onChange = { [weak self] text in self?.search = text; self?.applyFilters() }

        statusPill = FilterPillButton(title: S.allStatus)
        statusPill.addTarget(self, action: #selector(pickStatus), for: .touchUpInside)
        registrationPill = FilterPillButton(title: S.allStatus)
        registrationPill.addTarget(self, action: #selector(pickRegistration), for: .touchUpInside)
        let filterButton = FilterIconButton.make()

        let filterRow = UIStackView.horizontal(spacing: 6, alignment: .center)
        filterRow.distribution = .fill
        filterRow.addArrangedSubview(statusPill)
        filterRow.addArrangedSubview(registrationPill)
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
        ApiClient.shared.getTraders(search: "", status: selectedStatus,
                                    registrationStatus: selectedRegistrationStatus) { [weak self] result in
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

    /// "+ Add New Trader" in the header → open the wizard, refresh on success.
    override func trailingTapped() {
        let wizard = CreateTraderViewController()
        wizard.onSaved = { [weak self] in self?.loadData() }
        navigationController?.pushViewController(wizard, animated: true)
    }

    @objc private func pickStatus() {
        pick(from: MockData.filterStatus, current: pillText(statusPill)) { [weak self] value in
            self?.selectedStatus = (value == S.allStatus) ? "" : value
            self?.statusPill.setTitle(value)
            self?.loadData()
        }
    }

    @objc private func pickRegistration() {
        pick(from: MockData.filterRegistrationStatus, current: pillText(registrationPill)) { [weak self] value in
            self?.selectedRegistrationStatus = (value == S.allStatus) ? "" : value
            self?.registrationPill.setTitle(value)
            self?.loadData()
        }
    }

    private func pillText(_ pill: FilterPillButton) -> String { pill.titleLabel.text ?? "" }

    private func pick(from options: [String], current: String, onPick: @escaping (String) -> Void) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for option in options {
            sheet.addAction(UIAlertAction(title: option, style: .default) { _ in onPick(option) })
        }
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        present(sheet, animated: true)
    }

    private func applyFilters() {
        filtered = allItems.filter { item in
            search.isEmpty
                || item.name.localizedCaseInsensitiveContains(search)
                || item.location.localizedCaseInsensitiveContains(search)
                || item.phone.localizedCaseInsensitiveContains(search)
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
