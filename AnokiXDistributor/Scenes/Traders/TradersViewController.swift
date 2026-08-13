import UIKit

/// Trader Management (New-Design/Traders/1.Traders-Dashboard.png).
///
/// Keyword search plus the Status and Credit Status dropdowns all go to the server, so
/// the list, the KPI cards and the result count always describe the same query. The web
/// layout's tab strip is intentionally not ported — the two dropdowns already cover it,
/// and a second scrolling row would cost a thumb-height of phone screen for nothing.
///
/// Each card's overflow button opens Edit / Delete (2.Trader-Item-Menu.png); deleting
/// asks for confirmation first (3.Confirm-Deletion.png).
final class TradersViewController: BaseSecondaryViewController, UICollectionViewDataSource {

    override var screenTitle: String { S.traders }
    override var screenSubtitle: String? { S.tradersSubtitle }
    override var trailingTitle: String? { S.addNewTraderButton }

    /// Wait for a pause in typing before spending a request on the keyword.
    private static let searchDebounce: TimeInterval = 0.35

    // The KPI cards ride in the list header so the trader cards always own the
    // remaining height — a fixed summary left nothing to scroll on short screens.
    private let collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: AdaptiveGridLayout.make(estimatedHeight: 150, headerEstimatedHeight: 130))

    private var traders: [TradersData.Trader] = []
    private var summary: TradersData.Summary?
    private var total = 0

    // Server-side filters: empty string means "no filter".
    private var search = ""
    private var selectedStatus = ""
    private var selectedCreditStatus = ""
    private var searchWorkItem: DispatchWorkItem?

    private var statusPill: FilterPillButton!
    private var creditPill: FilterPillButton!
    private let countLabel = UILabel.make(font: AppFonts.regular(AppMetrics.textCaption),
                                          color: AppColors.textSecondary)

    /// Set by the wizard on success; shown as a banner once we reappear.
    private var pendingSuccessBanner: String?

    override func setupContent(in container: UIView) {
        let searchBar = SearchBarView(placeholder: S.searchTradersHint, height: 42)
        searchBar.onChange = { [weak self] text in self?.searchChanged(text) }

        statusPill = FilterPillButton(title: S.allStatus)
        statusPill.addTarget(self, action: #selector(pickStatus), for: .touchUpInside)
        creditPill = FilterPillButton(title: S.allCreditStatus)
        creditPill.addTarget(self, action: #selector(pickCreditStatus), for: .touchUpInside)

        let filterRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        filterRow.distribution = .fillEqually
        filterRow.addArrangedSubview(statusPill)
        filterRow.addArrangedSubview(creditPill)

        let chrome = ListScreenLayout.surfaceSection(
            [searchBar, filterRow, countLabel],
            spacing: 10,
            insets: UIEdgeInsets(top: 12, left: 16, bottom: 10, right: 16))

        collectionView.dataSource = self
        collectionView.backgroundColor = AppColors.background
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .onDrag
        collectionView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 16, right: 0)
        collectionView.register(TraderCell.self, forCellWithReuseIdentifier: TraderCell.reuseIdentifier)
        collectionView.register(TradersSummaryHeaderView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: TradersSummaryHeaderView.reuseIdentifier)

        _ = embedSecondaryListChrome(in: container, chrome: chrome, listView: collectionView)
    }

    override func loadData() {
        ApiClient.shared.getTraders(search: search, status: selectedStatus,
                                    creditStatus: selectedCreditStatus) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                self.traders = data.traders ?? []
                self.summary = data.summary
                self.total = data.total ?? self.traders.count
                self.render()
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    private func render() {
        countLabel.text = "Showing \(traders.count) of \(max(total, traders.count)) traders"
        collectionView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let message = pendingSuccessBanner {
            pendingSuccessBanner = nil
            successBanner(message)
        }
    }

    // MARK: Search + filters

    private func searchChanged(_ text: String) {
        let keyword = text.trimmingCharacters(in: .whitespaces)
        guard keyword != search else { return }
        searchWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.search = keyword
            self?.loadData()
        }
        searchWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.searchDebounce, execute: work)
    }

    @objc private func pickStatus() {
        pick(title: S.filterStatusTitle, options: MockData.filterStatus, from: statusPill) { [weak self] value in
            self?.selectedStatus = (value == S.allStatus) ? "" : value
            self?.statusPill.setTitle(value)
            self?.loadData()
        }
    }

    @objc private func pickCreditStatus() {
        pick(title: S.filterCreditStatusTitle, options: MockData.filterCreditStatus, from: creditPill) { [weak self] value in
            self?.selectedCreditStatus = (value == S.allCreditStatus) ? "" : value
            self?.creditPill.setTitle(value)
            self?.loadData()
        }
    }

    private func pick(title: String, options: [String], from anchor: UIView,
                      onPick: @escaping (String) -> Void) {
        let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for option in options {
            sheet.addAction(UIAlertAction(title: option, style: .default) { _ in onPick(option) })
        }
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        sheet.popoverPresentationController?.sourceView = anchor   // iPad anchor
        sheet.popoverPresentationController?.sourceRect = anchor.bounds
        present(sheet, animated: true)
    }

    // MARK: Add / edit / delete

    /// "+ Add New Trader" in the header → open the wizard, refresh on success.
    override func trailingTapped() {
        openWizard(editing: nil)
    }

    private func openWizard(editing trader: TradersData.Trader?) {
        let wizard = CreateTraderViewController(editing: trader)
        wizard.onSaved = { [weak self] in
            self?.loadData()
            self?.pendingSuccessBanner = trader == nil
                ? S.traderCreatedMessage : S.traderUpdatedMessage
        }
        navigationController?.pushViewController(wizard, animated: true)
    }

    private func showRowMenu(_ trader: TradersData.Trader, anchor: UIView) {
        let sheet = UIAlertController(title: trader.displayName, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: S.traderEdit, style: .default) { [weak self] _ in
            self?.openWizard(editing: trader)
        })
        sheet.addAction(UIAlertAction(title: S.traderDelete, style: .destructive) { [weak self] _ in
            self?.confirmDelete(trader)
        })
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        sheet.popoverPresentationController?.sourceView = anchor   // iPad anchor
        sheet.popoverPresentationController?.sourceRect = anchor.bounds
        present(sheet, animated: true)
    }

    private func confirmDelete(_ trader: TradersData.Trader) {
        let alert = UIAlertController(title: S.traderDeleteTitle,
                                      message: S.traderDeleteMessage(trader.displayName),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: S.traderDelete, style: .destructive) { [weak self] _ in
            self?.delete(trader)
        })
        present(alert, animated: true)
    }

    private func delete(_ trader: TradersData.Trader) {
        ApiClient.shared.deleteTrader(id: trader.id ?? "") { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                self.toast(message.isEmpty ? S.traderDeletedMessage : message)
                self.loadData()
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    // MARK: Collection view

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        traders.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: TraderCell.reuseIdentifier, for: indexPath) as? TraderCell else {
            return UICollectionViewCell()
        }
        let trader = traders[indexPath.row]
        cell.configure(trader, index: indexPath.row)
        cell.onMore = { [weak self] anchor in self?.showRowMenu(trader, anchor: anchor) }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind, withReuseIdentifier: TradersSummaryHeaderView.reuseIdentifier,
                for: indexPath) as? TradersSummaryHeaderView else {
            return UICollectionReusableView()
        }
        let filtering = !search.isEmpty || !selectedStatus.isEmpty || !selectedCreditStatus.isEmpty
        header.configure(summary: summary,
                         emptyMessage: traders.isEmpty
                            ? (filtering ? S.tradersEmptyFiltered : S.tradersEmpty) : nil)
        return header
    }
}

// MARK: - KPI summary header

/// Scrolling header of the Traders list: the four KPI cards from the web dashboard.
///
/// The fourth web card is "High Value Traders", but /traders only returns
/// pending_approval_* in its summary, so the card shows what the API actually knows —
/// how many traders are still waiting on approval.
final class TradersSummaryHeaderView: UICollectionReusableView {

    static let reuseIdentifier = "TradersSummaryHeaderView"

    private let totalCard = InventoryKpiCard(
        title: S.kpiTotalTraders, icon: "ic_traders", tint: AppColors.purplePrimary,
        tile: AppColors.purpleLight, caption: "")
    private let activeCard = InventoryKpiCard(
        title: S.kpiActiveTraders, icon: "ic_check_circle", tint: AppColors.success,
        tile: AppColors.successBg, caption: "")
    private let newCard = InventoryKpiCard(
        title: S.kpiNewThisMonth, icon: "ic_person_add", tint: AppColors.info,
        tile: AppColors.infoBg, caption: "")
    private let pendingCard = InventoryKpiCard(
        title: S.kpiPendingApproval, icon: "ic_clock", tint: AppColors.warning,
        tile: AppColors.warningBg, caption: "")

    private let emptyLabel = UILabel.make(font: AppFonts.regular(AppMetrics.textBody),
                                          color: AppColors.textSecondary, align: .center, lines: 0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        build()
    }

    private func build() {
        backgroundColor = .clear

        let row = UIStackView.horizontal(spacing: 8, alignment: .fill)
        [totalCard, activeCard, newCard, pendingCard].forEach { row.addArrangedSubview($0) }
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.clipsToBounds = false
        row.forAutoLayout()
        scroll.addSubview(row)
        scroll.forAutoLayout()
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])

        emptyLabel.isHidden = true

        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(scroll)
        stack.addArrangedSubview(emptyLabel)
        stack.forAutoLayout()
        addSubview(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0))
    }

    func configure(summary: TradersData.Summary?, emptyMessage: String?) {
        totalCard.set("\(summary?.totalTraders ?? 0)",
                      caption: summary?.totalTradersMonthChangeLabel)
        activeCard.set("\(summary?.activeTraders ?? 0)",
                       caption: summary?.activeTradersPercentLabel)
        newCard.set("\(summary?.newThisMonth ?? 0)",
                    caption: summary?.newThisMonthChangeLabel)
        pendingCard.set("\(summary?.pendingApprovalTraders ?? 0)",
                        caption: summary?.pendingApprovalTradersPercentLabel)

        emptyLabel.text = emptyMessage
        emptyLabel.isHidden = emptyMessage?.isEmpty != false
    }
}
