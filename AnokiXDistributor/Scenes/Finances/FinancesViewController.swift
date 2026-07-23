import UIKit

/// Finances ledger — the distributor's anokiX wallet (GET api/distributor/finances). A KPI strip
/// sits above a search box, the Status / Type / Payment-Method dropdowns and a date-range pill;
/// the endpoint returns the full ledger, so all of these filter the loaded list locally. Each row
/// opens a detail bottom sheet (View / tap) or the ⋯ menu. UI modelled on the Trader Finances screen.
final class FinancesViewController: BaseSecondaryViewController {

    override var screenTitle: String { S.finances }
    override var screenSubtitle: String? { S.financesSubtitle }

    // Filter labels mirror the web dropdowns; index 0 is the "All" reset in each.
    private static let statusLabels = [S.allStatuses, "Paid", "Pending", "Overdue", "Partial"]
    private static let statusKeys = ["", "paid", "pending", "overdue", "partial"]
    private static let typeLabels = [S.allTypes, "Invoice", "Payment", "Payout", "Credit Note"]
    private static let typeKeys = ["", FinanceFormat.typeInvoice, FinanceFormat.typePayment,
                                   FinanceFormat.typePayout, FinanceFormat.typeCreditNote]
    private static let methodLabels = [S.allMethods, "EFT", "Card", "Cash", "Credit"]

    // Data + filter state
    private var allItems: [FinanceTransactionDTO] = []
    private var selectedStatus = ""      // "" = All Statuses
    private var selectedType = ""        // "" = All Types
    private var selectedMethod = ""      // "" = All Methods
    private var search = ""
    private var dateFrom = ""             // "yyyy-MM-dd" local filter, "" = no range
    private var dateTo = ""

    // UI
    private let mainScroll = UIScrollView()
    private let summaryScroll = UIScrollView()
    private let summaryRow = UIStackView.horizontal(spacing: 10, alignment: .fill)
    private let statusPill = FilterPillButton(title: S.financeStatusLabel)
    private let typePill = FilterPillButton(title: S.financeTypeLabel)
    private let methodPill = FilterPillButton(title: S.financeMethodLabel)
    private let datePill = DateRangePillView(text: S.financeDateRange)
    private let dateClearButton = UIButton(type: .system)
    private let resultCountLabel = UILabel.make("", font: AppFonts.regular(11), color: AppColors.textSecondary)
    private let listStack = UIStackView.vertical(spacing: 12, alignment: .fill)
    private let emptyLabel = UILabel.make(S.noFinances, font: AppFonts.regular(14),
                                          color: AppColors.textSecondary, align: .center)
    private let spinner = UIActivityIndicatorView(style: .medium)

    // MARK: - Setup

    override func setupContent(in container: UIView) {
        mainScroll.alwaysBounceVertical = true
        mainScroll.showsVerticalScrollIndicator = false
        mainScroll.backgroundColor = AppColors.background
        mainScroll.forAutoLayout()
        container.addSubview(mainScroll)

        let refresh = UIRefreshControl()
        refresh.tintColor = AppColors.purplePrimary
        refresh.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        mainScroll.refreshControl = refresh

        let stack = UIStackView.vertical(spacing: 14, alignment: .fill)
        stack.forAutoLayout()
        mainScroll.addSubview(stack)

        // Summary stat cards (horizontally scrollable).
        summaryScroll.showsHorizontalScrollIndicator = false
        summaryRow.forAutoLayout()
        summaryScroll.addSubview(summaryRow)
        NSLayoutConstraint.activate([
            summaryRow.topAnchor.constraint(equalTo: summaryScroll.contentLayoutGuide.topAnchor),
            summaryRow.bottomAnchor.constraint(equalTo: summaryScroll.contentLayoutGuide.bottomAnchor),
            summaryRow.leadingAnchor.constraint(equalTo: summaryScroll.contentLayoutGuide.leadingAnchor),
            summaryRow.trailingAnchor.constraint(equalTo: summaryScroll.contentLayoutGuide.trailingAnchor),
            summaryRow.heightAnchor.constraint(equalTo: summaryScroll.frameLayoutGuide.heightAnchor)
        ])
        let summaryHeight = summaryScroll.heightAnchor.constraint(equalToConstant: 120)
        summaryHeight.priority = .defaultHigh
        summaryHeight.isActive = true
        stack.addArrangedSubview(summaryScroll)
        renderSummary(nil)   // zeroed placeholder cards until the API responds

        // Search.
        let searchBar = SearchBarView(placeholder: S.searchFinances)
        searchBar.onChange = { [weak self] text in self?.search = text; self?.applyFilter() }
        stack.addArrangedSubview(searchBar)

        // Status / Type / Method filter pills.
        statusPill.addTarget(self, action: #selector(showStatusMenu), for: .touchUpInside)
        typePill.addTarget(self, action: #selector(showTypeMenu), for: .touchUpInside)
        methodPill.addTarget(self, action: #selector(showMethodMenu), for: .touchUpInside)
        let filterRow = UIStackView.horizontal(spacing: 8, alignment: .fill)
        filterRow.distribution = .fillEqually
        filterRow.addArrangedSubview(statusPill)
        filterRow.addArrangedSubview(typePill)
        filterRow.addArrangedSubview(methodPill)
        stack.addArrangedSubview(filterRow)

        // Date range + clear.
        datePill.addTarget(self, action: #selector(showDateRangePicker), for: .touchUpInside)
        datePill.setContentHuggingPriority(.defaultLow, for: .horizontal)
        dateClearButton.setTitle("Clear", for: .normal)
        dateClearButton.setTitleColor(AppColors.purplePrimary, for: .normal)
        dateClearButton.titleLabel?.font = AppFonts.bold(12)
        dateClearButton.isHidden = true
        dateClearButton.setContentHuggingPriority(.required, for: .horizontal)
        dateClearButton.addTarget(self, action: #selector(clearDateRange), for: .touchUpInside)
        let dateRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        dateRow.addArrangedSubview(datePill)
        dateRow.addArrangedSubview(dateClearButton)
        stack.addArrangedSubview(dateRow)

        // Result count.
        let countRow = UIStackView.horizontal(spacing: 0, alignment: .center)
        countRow.addArrangedSubview(resultCountLabel)
        countRow.addArrangedSubview(UIView())
        stack.addArrangedSubview(countRow)

        emptyLabel.isHidden = true
        stack.addArrangedSubview(emptyLabel)
        stack.addArrangedSubview(listStack)

        spinner.hidesWhenStopped = true
        spinner.forAutoLayout()
        container.addSubview(spinner)

        NSLayoutConstraint.activate([
            mainScroll.topAnchor.constraint(equalTo: container.topAnchor),
            mainScroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            mainScroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            mainScroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stack.topAnchor.constraint(equalTo: mainScroll.contentLayoutGuide.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: mainScroll.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: mainScroll.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: mainScroll.frameLayoutGuide.trailingAnchor, constant: -16),

            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: container.topAnchor, constant: 160)
        ])
    }

    override func loadData() {
        spinner.startAnimating()
        emptyLabel.isHidden = true
        // The endpoint returns the full ledger — filters (incl. date range) are applied locally.
        ApiClient.shared.getFinances(dateFrom: "", dateTo: "") { [weak self] result in
            guard let self = self else { return }
            self.spinner.stopAnimating()
            self.mainScroll.refreshControl?.endRefreshing()
            switch result {
            case .success(let data):
                self.renderSummary(data.summary)
                self.allItems = data.transactions ?? []
                self.applyFilter()
            case .failure(let error):
                self.allItems = []
                self.renderSummary(nil)
                self.applyFilter()
                self.toast(error.message.isEmpty ? S.financesLoadFailed : error.message)
            }
        }
    }

    @objc private func handleRefresh() { loadData() }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if hasAppeared { loadData() }
        hasAppeared = true
    }
    private var hasAppeared = false

    // MARK: - Summary cards

    private func renderSummary(_ s: FinanceSummaryDTO?) {
        summaryRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let received = s?.received ?? 0
        let receivedMonth = s?.receivedMonth ?? 0
        let pending = s?.pending ?? 0
        let commission = s?.commissionMonth ?? 0
        let overdue = s?.overdue ?? 0
        let count = s?.count ?? 0
        let cur = "R"

        summaryRow.addArrangedSubview(statCard(
            S.financeRevenueMonth, OrderFormat.money(receivedMonth, currency: cur), S.financeRevenueMonthSub,
            AppColors.textSecondary, icon: "dollarsign.circle.fill", tint: AppColors.purplePrimary, tile: AppColors.purpleLight))
        summaryRow.addArrangedSubview(statCard(
            S.financeCommissionMonth, OrderFormat.money(commission, currency: cur), S.financeCommissionMonthSub,
            AppColors.textSecondary, icon: "doc.text.fill", tint: AppColors.warning, tile: AppColors.warningBg))
        summaryRow.addArrangedSubview(statCard(
            S.financeReceivedPayments, OrderFormat.money(received, currency: cur), S.financeTransactionsCount(count),
            AppColors.textSecondary, icon: "creditcard.fill", tint: AppColors.success, tile: AppColors.successBg))
        summaryRow.addArrangedSubview(statCard(
            S.financePending, OrderFormat.money(pending, currency: cur), S.financePendingSub,
            AppColors.textSecondary, icon: "clock.fill", tint: AppColors.info, tile: AppColors.infoBg))
        summaryRow.addArrangedSubview(statCard(
            S.financeOverdue, OrderFormat.money(overdue, currency: cur),
            overdue <= 0 ? S.financeOverdueSub : "Awaiting payment",
            AppColors.danger, icon: "exclamationmark.circle.fill", tint: AppColors.danger, tile: AppColors.dangerBg))
    }

    private func statCard(_ title: String, _ value: String, _ sub: String, _ subColor: UIColor,
                          icon: String, tint: UIColor, tile tileColor: UIColor) -> UIView {
        let card = StyleKit.cardView()

        let tile = StyleKit.iconTile(color: tileColor)
        tile.constrainSize(30)
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = tint
        iconView.contentMode = .scaleAspectFit
        iconView.forAutoLayout()
        tile.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16)
        ])

        let iconRow = UIStackView.horizontal(spacing: 10, alignment: .center)
        let label = UILabel.make(title, font: AppFonts.regular(11), color: AppColors.textPrimary, lines: 2)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        iconRow.addArrangedSubview(tile)
        iconRow.addArrangedSubview(label)

        let valueLabel = UILabel.make(value, font: AppFonts.bold(20), color: AppColors.textPrimary, lines: 1)
        let subLabel = UILabel.make(sub, font: AppFonts.regular(10), color: subColor, lines: 1)
        let stack = UIStackView.vertical(spacing: 4, alignment: .fill)
        stack.forAutoLayout()
        stack.addArrangedSubview(iconRow)
        stack.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(subLabel)
        stack.setCustomSpacing(10, after: iconRow)
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14))
        card.widthAnchor.constraint(equalToConstant: 190).isActive = true
        return card
    }

    // MARK: - Filter menus / date

    @objc private func showStatusMenu() {
        presentMenu(Self.statusLabels, from: statusPill) { [weak self] index in
            guard let self = self else { return }
            self.selectedStatus = Self.statusKeys[index]
            self.statusPill.setTitle(index == 0 ? S.financeStatusLabel : Self.statusLabels[index])
            self.setPillActive(self.statusPill, index != 0)
            self.applyFilter()
        }
    }

    @objc private func showTypeMenu() {
        presentMenu(Self.typeLabels, from: typePill) { [weak self] index in
            guard let self = self else { return }
            self.selectedType = Self.typeKeys[index]
            self.typePill.setTitle(index == 0 ? S.financeTypeLabel : Self.typeLabels[index])
            self.setPillActive(self.typePill, index != 0)
            self.applyFilter()
        }
    }

    @objc private func showMethodMenu() {
        presentMenu(Self.methodLabels, from: methodPill) { [weak self] index in
            guard let self = self else { return }
            // No payment_method field yet — filter is lenient until the API supplies it.
            self.selectedMethod = index == 0 ? "" : Self.methodLabels[index]
            self.methodPill.setTitle(index == 0 ? S.financeMethodLabel : Self.methodLabels[index])
            self.setPillActive(self.methodPill, index != 0)
            self.applyFilter()
        }
    }

    /// Toggle a filter pill between the neutral and active (purple) look.
    private func setPillActive(_ pill: FilterPillButton, _ active: Bool) {
        pill.backgroundColor = active ? AppColors.purpleLight : AppColors.surfaceVariant
        pill.layer.borderColor = (active ? AppColors.purplePrimary : AppColors.border).cgColor
        pill.titleLabel.textColor = active ? AppColors.purplePrimary : AppColors.textPrimary
    }

    private func presentMenu(_ options: [String], from source: UIView, _ onPick: @escaping (Int) -> Void) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for (index, option) in options.enumerated() {
            sheet.addAction(UIAlertAction(title: option, style: .default) { _ in onPick(index) })
        }
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = source
            pop.sourceRect = source.bounds
        }
        present(sheet, animated: true)
    }

    @objc private func showDateRangePicker() {
        let from = Self.parseApiDate(dateFrom) ?? Date()
        let to = Self.parseApiDate(dateTo) ?? Date()
        let sheet = OrderDateRangeSheet(from: from, to: to)
        sheet.onApply = { [weak self] start, end in
            guard let self = self else { return }
            self.dateFrom = Self.apiDate(start)
            self.dateTo = Self.apiDate(end)
            self.updateDateLabel()
            self.applyFilter()
        }
        present(sheet, animated: true)
    }

    @objc private func clearDateRange() {
        dateFrom = ""
        dateTo = ""
        updateDateLabel()
        applyFilter()
    }

    private func updateDateLabel() {
        let active = !dateFrom.isEmpty || !dateTo.isEmpty
        datePill.rangeLabel.text = active
            ? "\(Self.displayDate(dateFrom))  →  \(Self.displayDate(dateTo))"
            : S.financeDateRange
        datePill.rangeLabel.textColor = active ? AppColors.textPrimary : AppColors.textSecondary
        dateClearButton.isHidden = !active
    }

    // MARK: - Filtering + list

    private func applyFilter() {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = allItems.filter { t in
            if !selectedStatus.isEmpty && selectedStatus.caseInsensitiveCompare(t.status ?? "") != .orderedSame { return false }
            if !selectedType.isEmpty && selectedType != FinanceFormat.typeCategory(t.type) { return false }
            if !selectedMethod.isEmpty, let m = t.paymentMethod, !m.isEmpty,
               selectedMethod.caseInsensitiveCompare(m) != .orderedSame { return false }
            if !withinDateRange(t) { return false }
            if !q.isEmpty {
                let hay = [t.reference, t.orderNumber, t.traderName, t.traderPhone, t.description]
                    .compactMap { $0?.lowercased() }
                if !hay.contains(where: { $0.contains(q) }) { return false }
            }
            return true
        }
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        cardTargets.removeAll()
        emptyLabel.isHidden = !filtered.isEmpty
        resultCountLabel.text = "Showing \(filtered.count) \(filtered.count == 1 ? "transaction" : "transactions")"
        for t in filtered {
            listStack.addArrangedSubview(makeCard(t))
        }
    }

    private func withinDateRange(_ t: FinanceTransactionDTO) -> Bool {
        if dateFrom.isEmpty && dateTo.isEmpty { return true }
        guard let day = Self.dayString(t.createdAt) else { return false }
        if !dateFrom.isEmpty && day < dateFrom { return false }
        if !dateTo.isEmpty && day > dateTo { return false }
        return true
    }

    // MARK: - Transaction card

    private func makeCard(_ t: FinanceTransactionDTO) -> UIView {
        let card = StyleKit.cardView()

        // Header: type badge (left) + status badge (right)
        let typeBadge = StyleKit.badgeLabel()
        let (tfg, tbg) = FinanceFormat.typeColors(t.type)
        typeBadge.text = FinanceFormat.typeLabel(t.type)
        typeBadge.textColor = tfg
        typeBadge.backgroundColor = tbg
        typeBadge.setContentHuggingPriority(.required, for: .horizontal)
        let statusBadge = StyleKit.badgeLabel()
        let (sfg, sbg) = FinanceFormat.statusColors(t.status)
        statusBadge.text = FinanceFormat.statusLabel(t.status)
        statusBadge.textColor = sfg
        statusBadge.backgroundColor = sbg
        statusBadge.setContentHuggingPriority(.required, for: .horizontal)
        let headerRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        headerRow.addArrangedSubview(typeBadge)
        headerRow.addArrangedSubview(UIView())
        headerRow.addArrangedSubview(statusBadge)

        // Trader + amount
        let avatar = UILabel()
        let name = t.resolvedTraderName
        avatar.text = OrderFormat.initials(name)
        avatar.font = AppFonts.bold(14)
        avatar.textColor = .white
        avatar.textAlignment = .center
        avatar.backgroundColor = OrderFormat.logoColor(t.id)
        avatar.layer.cornerRadius = 19
        avatar.layer.masksToBounds = true
        avatar.constrainSize(38)
        let nameLabel = UILabel.make(name, font: AppFonts.bold(14), color: AppColors.textPrimary, lines: 1)
        let traderCol = UIStackView.vertical(spacing: 2, alignment: .leading)
        traderCol.addArrangedSubview(nameLabel)
        if let phone = t.traderPhone, !phone.isEmpty {
            traderCol.addArrangedSubview(UILabel.make(phone, font: AppFonts.regular(11), color: AppColors.textSecondary, lines: 1))
        }
        let amount = t.amount ?? 0
        let amountLabel = UILabel.make(signedMoney(amount, t.currency),
                                       font: AppFonts.bold(16),
                                       color: amount < 0 ? AppColors.danger : AppColors.success, lines: 1)
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)
        let traderRow = UIStackView.horizontal(spacing: 10, alignment: .center)
        traderRow.addArrangedSubview(avatar)
        traderRow.addArrangedSubview(traderCol)
        traderRow.addArrangedSubview(UIView())
        traderRow.addArrangedSubview(amountLabel)

        // Description + meta
        let descLabel = UILabel.make(t.description ?? "—", font: AppFonts.regular(12),
                                     color: AppColors.textPrimary, lines: 2)
        let metaLabel = UILabel.make("\(Self.shortReference(t.reference)) · \(FinanceFormat.date(t.createdAt))",
                                     font: AppFonts.regular(10), color: AppColors.textTertiary, lines: 1)

        // Footer: method + View + overflow
        let walletIcon = UIImageView(image: UIImage(systemName: "wallet.pass"))
        walletIcon.tintColor = AppColors.textSecondary
        walletIcon.contentMode = .scaleAspectFit
        walletIcon.forAutoLayout()
        walletIcon.constrainSize(13)
        walletIcon.setContentHuggingPriority(.required, for: .horizontal)
        let methodLabel = UILabel.make(methodDisplay(t), font: AppFonts.regular(11), color: AppColors.textSecondary, lines: 1)
        let viewButton = OrderListCell.actionButton(title: S.viewBtn, icon: "eye", color: AppColors.purplePrimary)
        viewButton.setContentHuggingPriority(.required, for: .horizontal)
        viewButton.addAction(UIAction { [weak self] _ in self?.presentDetail(t) }, for: .touchUpInside)
        let menuButton = overflowButton()
        menuButton.addAction(UIAction { [weak self] _ in self?.showRowMenu(t, from: menuButton) }, for: .touchUpInside)
        let footerRow = UIStackView.horizontal(spacing: 6, alignment: .center)
        footerRow.addArrangedSubview(walletIcon)
        footerRow.addArrangedSubview(methodLabel)
        footerRow.addArrangedSubview(UIView())
        footerRow.addArrangedSubview(viewButton)
        footerRow.addArrangedSubview(menuButton)

        let stack = UIStackView.vertical(spacing: 10, alignment: .fill)
        stack.addArrangedSubview(headerRow)
        stack.addArrangedSubview(traderRow)
        stack.addArrangedSubview(descLabel)
        stack.addArrangedSubview(metaLabel)
        stack.addArrangedSubview(ListScreenLayout.hairline())
        stack.addArrangedSubview(footerRow)
        stack.setCustomSpacing(4, after: descLabel)
        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))

        let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:)))
        tap.cancelsTouchesInView = false   // let the View / ⋯ buttons still receive their taps
        card.addGestureRecognizer(tap)
        cardTargets[ObjectIdentifier(card)] = t
        return card
    }

    /// Map of card view → transaction, so a whole-card tap can open the detail sheet.
    private var cardTargets: [ObjectIdentifier: FinanceTransactionDTO] = [:]

    @objc private func cardTapped(_ gr: UITapGestureRecognizer) {
        guard let view = gr.view, let t = cardTargets[ObjectIdentifier(view)] else { return }
        presentDetail(t)
    }

    private func overflowButton() -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "ellipsis")
        config.baseForegroundColor = AppColors.textSecondary
        config.background.strokeColor = AppColors.border
        config.background.strokeWidth = 1
        config.background.cornerRadius = AppMetrics.radiusSM
        config.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 14, bottom: 9, trailing: 14)
        let button = UIButton(configuration: config)
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    // MARK: - Row menu + detail sheet

    private func showRowMenu(_ t: FinanceTransactionDTO, from source: UIView) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: S.financeViewDetails, style: .default) { [weak self] _ in
            self?.presentDetail(t)
        })
        sheet.addAction(UIAlertAction(title: S.downloadPdf, style: .default) { [weak self] _ in
            self?.toast(S.comingSoon)
        })
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = source
            pop.sourceRect = source.bounds
        }
        present(sheet, animated: true)
    }

    private func presentDetail(_ t: FinanceTransactionDTO) {
        let vc = FinanceDetailSheetViewController(transaction: t)
        vc.onDownload = { [weak self] in self?.toast(S.comingSoon) }
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(vc, animated: true)
    }

    private func methodDisplay(_ t: FinanceTransactionDTO) -> String {
        if let m = t.paymentMethod, !m.isEmpty { return m }
        return S.financeWalletMethod
    }

    private func signedMoney(_ value: Double, _ currency: String?) -> String {
        (value < 0 ? "-" : "") + OrderFormat.money(abs(value), currency: FinanceFormat.currencySymbol(currency))
    }

    // MARK: - Helpers

    /// Shorten the long UUID reference to keep the row tidy.
    private static func shortReference(_ ref: String?) -> String {
        guard let r = ref?.trimmingCharacters(in: .whitespaces), !r.isEmpty else { return "—" }
        return r.count > 10 ? String(r.prefix(8)) + "…" : r
    }

    // MARK: - Date helpers

    private static let apiFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let createdFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private static func apiDate(_ date: Date) -> String { apiFormatter.string(from: date) }
    private static func parseApiDate(_ raw: String) -> Date? { raw.isEmpty ? nil : apiFormatter.date(from: raw) }

    /// created_at "yyyy-MM-dd HH:mm:ss" → "yyyy-MM-dd" for range comparison.
    private static func dayString(_ raw: String?) -> String? {
        guard let raw = raw, let d = createdFormatter.date(from: raw) else { return nil }
        return apiFormatter.string(from: d)
    }

    private static func displayDate(_ raw: String) -> String {
        guard let date = parseApiDate(raw) else { return raw }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.timeZone = TimeZone(identifier: "UTC")
        out.dateFormat = "dd MMM yyyy"
        return out.string(from: date)
    }
}

// MARK: - Detail bottom sheet

private final class FinanceDetailSheetViewController: UIViewController {

    private let t: FinanceTransactionDTO
    var onDownload: (() -> Void)?

    init(transaction: FinanceTransactionDTO) {
        self.t = transaction
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.background

        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = false
        scroll.forAutoLayout()
        view.addSubview(scroll)

        let stack = UIStackView.vertical(spacing: 0, alignment: .fill)
        stack.forAutoLayout()
        scroll.addSubview(stack)

        // Header badges
        let typeBadge = StyleKit.badgeLabel()
        let (tfg, tbg) = FinanceFormat.typeColors(t.type)
        typeBadge.text = FinanceFormat.typeLabel(t.type)
        typeBadge.textColor = tfg
        typeBadge.backgroundColor = tbg
        typeBadge.setContentHuggingPriority(.required, for: .horizontal)
        let statusBadge = StyleKit.badgeLabel()
        let (sfg, sbg) = FinanceFormat.statusColors(t.status)
        statusBadge.text = FinanceFormat.statusLabel(t.status)
        statusBadge.textColor = sfg
        statusBadge.backgroundColor = sbg
        statusBadge.setContentHuggingPriority(.required, for: .horizontal)
        let headerRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        headerRow.addArrangedSubview(typeBadge)
        headerRow.addArrangedSubview(UIView())
        headerRow.addArrangedSubview(statusBadge)

        let amount = t.amount ?? 0
        let amountLabel = UILabel.make((amount < 0 ? "-" : "") + OrderFormat.money(abs(amount), currency: FinanceFormat.currencySymbol(t.currency)),
                                       font: AppFonts.bold(26),
                                       color: amount < 0 ? AppColors.danger : AppColors.success, lines: 1)
        let descLabel = UILabel.make(t.description ?? "—", font: AppFonts.regular(13), color: AppColors.textSecondary, lines: 0)

        let rowsStack = UIStackView.vertical(spacing: 14, alignment: .fill)
        addRow(rowsStack, "Reference", t.reference ?? "—")
        addRow(rowsStack, "Order", t.orderNumber ?? "—")
        addRow(rowsStack, "Trader", t.resolvedTraderName)
        if let phone = t.traderPhone, !phone.isEmpty { addRow(rowsStack, "Phone", phone) }
        addRow(rowsStack, "Method", (t.paymentMethod?.isEmpty == false) ? t.paymentMethod! : S.financeWalletMethod)
        addRow(rowsStack, "Date", FinanceFormat.dateTime(t.createdAt))

        stack.addArrangedSubview(headerRow)
        stack.addArrangedSubview(amountLabel)
        stack.addArrangedSubview(descLabel)
        stack.addArrangedSubview(ListScreenLayout.hairline())
        stack.addArrangedSubview(rowsStack)
        stack.setCustomSpacing(14, after: headerRow)
        stack.setCustomSpacing(4, after: amountLabel)
        stack.setCustomSpacing(14, after: descLabel)
        stack.setCustomSpacing(14, after: stack.arrangedSubviews[3])   // after the hairline

        // Download button
        var config = UIButton.Configuration.plain()
        config.title = S.downloadPdf
        config.image = UIImage(systemName: "doc.text")
        config.imagePadding = 8
        config.baseForegroundColor = AppColors.purplePrimary
        config.background.strokeColor = AppColors.purplePrimary
        config.background.strokeWidth = 1
        config.background.cornerRadius = AppMetrics.radiusMD
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        let download = UIButton(configuration: config)
        download.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true) { self?.onDownload?() }
        }, for: .touchUpInside)
        download.forAutoLayout()
        download.heightAnchor.constraint(equalToConstant: 46).isActive = true
        stack.setCustomSpacing(18, after: rowsStack)
        stack.addArrangedSubview(download)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20)
        ])
    }

    private func addRow(_ parent: UIStackView, _ label: String, _ value: String) {
        let l = UILabel.make(label, font: AppFonts.regular(12), color: AppColors.textSecondary)
        l.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let v = UILabel.make(value, font: AppFonts.bold(12), color: AppColors.textPrimary, align: .right, lines: 0)
        v.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        v.setContentCompressionResistancePriority(.required, for: .horizontal)
        let row = UIStackView.horizontal(spacing: 12, alignment: .top)
        row.addArrangedSubview(l)
        row.addArrangedSubview(v)
        parent.addArrangedSubview(row)
    }
}

// MARK: - Finance formatting helpers (port of FinanceFormat.java)

enum FinanceFormat {

    static let typeInvoice = "invoice"
    static let typePayment = "payment"
    static let typePayout = "payout"
    static let typeCreditNote = "credit_note"

    /// Normalises the raw `type` to one of the four filter categories.
    static func typeCategory(_ type: String?) -> String {
        let k = key(type)
        if k.contains("invoice") { return typeInvoice }
        if k.contains("payout") { return typePayout }
        if k.contains("credit") { return typeCreditNote }
        return typePayment
    }

    static func typeLabel(_ type: String?) -> String {
        switch typeCategory(type) {
        case typeInvoice:    return "Invoice"
        case typePayout:     return "Payout"
        case typeCreditNote: return "Credit Note"
        default:             return "Payment"
        }
    }

    static func typeColors(_ type: String?) -> (fg: UIColor, bg: UIColor) {
        switch typeCategory(type) {
        case typeInvoice:    return (AppColors.info, AppColors.infoBg)
        case typePayout:     return (AppColors.purplePrimary, AppColors.purpleLight)
        case typeCreditNote: return (AppColors.warning, AppColors.warningBg)
        default:             return (AppColors.success, AppColors.successBg)
        }
    }

    static func statusLabel(_ status: String?) -> String {
        switch key(status) {
        case "paid":     return "Paid"
        case "pending":  return "Pending"
        case "overdue":  return "Overdue"
        case "partial":  return "Partial"
        case "failed":   return "Failed"
        case "reversed": return "Reversed"
        default:         return key(status).isEmpty ? "—" : (status ?? "").capitalized
        }
    }

    static func statusColors(_ status: String?) -> (fg: UIColor, bg: UIColor) {
        switch key(status) {
        case "paid":     return (AppColors.success, AppColors.successBg)
        case "overdue":  return (AppColors.danger, AppColors.dangerBg)
        case "failed":   return (AppColors.danger, AppColors.dangerBg)
        case "partial":  return (AppColors.info, AppColors.infoBg)
        case "pending":  return (AppColors.warning, AppColors.warningBg)
        case "reversed": return (AppColors.textSecondary, AppColors.surfaceVariant)
        default:         return (AppColors.textSecondary, AppColors.surfaceVariant)
        }
    }

    static func currencySymbol(_ currency: String?) -> String {
        switch (currency ?? "").uppercased() {
        case "ZAR": return "R"
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        default:    return "R"
        }
    }

    /// "2026-07-15 13:58:09" → "15 Jul 2026". Falls back to the raw value.
    static func date(_ raw: String?) -> String {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return "" }
        let date = parse(raw, "yyyy-MM-dd HH:mm:ss")
            ?? parse(raw, "yyyy-MM-dd HH:mm")
            ?? parse(raw, "dd/MM/yyyy HH:mm:ss")
            ?? parse(raw, "yyyy-MM-dd")
        guard let date = date else { return raw }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "dd MMM yyyy"
        return out.string(from: date)
    }

    /// "2026-07-15 13:58:09" → "15 Jul 2026, 13:58". Falls back to the raw value.
    static func dateTime(_ raw: String?) -> String {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return "—" }
        let date = parse(raw, "yyyy-MM-dd HH:mm:ss")
            ?? parse(raw, "yyyy-MM-dd HH:mm")
            ?? parse(raw, "dd/MM/yyyy HH:mm:ss")
        guard let date = date else { return raw }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "dd MMM yyyy, HH:mm"
        return out.string(from: date)
    }

    private static func key(_ s: String?) -> String { (s ?? "").lowercased() }

    private static func parse(_ raw: String, _ pattern: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = pattern
        return f.date(from: raw)
    }
}
