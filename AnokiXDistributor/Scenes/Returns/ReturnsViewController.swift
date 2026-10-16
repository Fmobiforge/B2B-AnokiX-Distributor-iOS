import UIKit

/// Returns list — wired to GET `api/distributor/grns` (port of ReturnsActivity). KPI summary,
/// status tabs with live counts, a date range that drives the API call, plus local search +
/// reason filtering. Each card opens the detail screen and, when pending, shows inline
/// Approve / Reject buttons.
final class ReturnsViewController: BaseSecondaryViewController {

    override var screenTitle: String { S.returns }
    override var screenSubtitle: String? { S.returnsSubtitle }

    private static let tabKeys = ["all", "pending", "approved", "rejected"]
    private static let tabTitles = [S.allReturns, S.pending, S.approved, S.rejected]
    /// Reason filter labels mirror the web dropdown; "" = All Reasons.
    private static let reasonLabels = ["Damaged Items", "Expired Items", "Incorrect Item",
                                       "Overstock", "Supplier Recall", "Other"]
    private let currency = "R"

    // Data + filter state
    private var allItems: [ReturnDTO] = []
    private var currentTab = "all"
    private var selectedReason = ""        // "" = All Reasons
    private var search = ""
    private var dateFrom = ""
    private var dateTo = ""

    // UI
    private let summaryScroll = UIScrollView()
    private let summaryRow = UIStackView.horizontal(spacing: 10, alignment: .fill)
    private let reasonPill = FilterPillButton(title: S.allReasons)
    private let datePill = DateRangePillView(text: "")
    private lazy var statusTabs = OrderStatusTabsView(titles: Self.tabTitles, selectedIndex: 0)
    private let listStack = UIStackView.vertical(spacing: 12, alignment: .fill)
    private let emptyLabel = UILabel.make(S.noReturns, font: AppFonts.regular(14),
                                          color: AppColors.textSecondary, align: .center)
    private let spinner = UIActivityIndicatorView(style: .medium)

    // MARK: - Setup

    override func setupContent(in container: UIView) {
        // Default range: the last 90 days drives the initial API call.
        let now = Date()
        dateTo = Self.apiDate(now)
        dateFrom = Self.apiDate(Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now)

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = false
        scroll.backgroundColor = AppColors.background
        scroll.forAutoLayout()
        container.addSubview(scroll)

        let stack = UIStackView.vertical(spacing: 14, alignment: .fill)
        stack.forAutoLayout()
        scroll.addSubview(stack)

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
        summaryScroll.isHidden = true
        let summaryHeight = summaryScroll.heightAnchor.constraint(equalToConstant: 120)
        summaryHeight.priority = .defaultHigh
        summaryHeight.isActive = true
        stack.addArrangedSubview(summaryScroll)

        // Search.
        let searchBar = SearchBarView(placeholder: S.searchReturns)
        searchBar.onChange = { [weak self] text in self?.search = text; self?.applyFilter() }
        stack.addArrangedSubview(searchBar)

        // Reason + date range filters.
        reasonPill.addTarget(self, action: #selector(showReasonMenu), for: .touchUpInside)
        reasonPill.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        updateDateLabel()
        datePill.addTarget(self, action: #selector(showDateRangePicker), for: .touchUpInside)
        datePill.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let filterRow = UIStackView.horizontal(spacing: 10, alignment: .fill)
        filterRow.addArrangedSubview(reasonPill)
        filterRow.addArrangedSubview(datePill)
        stack.addArrangedSubview(filterRow)

        // Status tabs with live counts.
        statusTabs.onSelect = { [weak self] index in self?.onTabSelected(index) }
        statusTabs.constrainHeight(46)
        stack.addArrangedSubview(statusTabs)

        emptyLabel.isHidden = true
        stack.addArrangedSubview(emptyLabel)
        stack.addArrangedSubview(listStack)

        spinner.hidesWhenStopped = true
        spinner.forAutoLayout()
        container.addSubview(spinner)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: container.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),

            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: container.topAnchor, constant: 140)
        ])
    }

    override func loadData() {
        spinner.startAnimating()
        emptyLabel.isHidden = true
        ApiClient.shared.getReturns(dateFrom: dateFrom, dateTo: dateTo, search: "",
                                    page: 1, perPage: 100) { [weak self] result in
            guard let self = self else { return }
            self.spinner.stopAnimating()
            switch result {
            case .success(let data):
                self.renderSummary(data.summary)
                self.statusTabs.updateCounts(Self.tabKeys.map { data.statusCounts?.count(for: $0) ?? 0 })
                self.allItems = data.returns ?? []
                self.applyFilter()
            case .failure(let error):
                self.allItems = []
                self.applyFilter()
                self.toast(error.message.isEmpty ? S.returnsLoadFailed : error.message)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if hasAppeared { loadData() }
        hasAppeared = true
    }
    private var hasAppeared = false

    // MARK: - Summary cards

    private func renderSummary(_ s: ReturnSummary?) {
        summaryRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let s = s else { summaryScroll.isHidden = true; return }
        summaryScroll.isHidden = false
        summaryRow.addArrangedSubview(statCard(S.totalReturns, "\(s.totalReturns ?? 0)", S.inSelectedRange, AppColors.textSecondary,
                                               icon: "bag.fill", tint: AppColors.purplePrimary, tile: AppColors.purpleLight))
        summaryRow.addArrangedSubview(statCard(S.approved, "\(s.approved ?? 0)", S.inSelectedRange, AppColors.textSecondary,
                                               icon: "person.fill", tint: AppColors.success, tile: AppColors.successBg))
        summaryRow.addArrangedSubview(statCard(S.pending, "\(s.pending ?? 0)", S.awaitingReview, AppColors.warning,
                                               icon: "clock.fill", tint: AppColors.warning, tile: AppColors.warningBg))
        summaryRow.addArrangedSubview(statCard(S.rejected, "\(s.rejected ?? 0)", S.inSelectedRange, AppColors.textSecondary,
                                               icon: "xmark.circle.fill", tint: AppColors.danger, tile: AppColors.dangerBg))
        summaryRow.addArrangedSubview(statCard(S.creditIssued, OrderFormat.money(s.totalValue ?? 0, currency: currency), S.inSelectedRange, AppColors.textSecondary,
                                               icon: "checkmark.shield.fill", tint: AppColors.info, tile: AppColors.infoBg))
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

        let label = UILabel.make(title, font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 1)
        let valueLabel = UILabel.make(value, font: AppFonts.semibold(22), color: AppColors.topTitle, lines: 1)
        let subLabel = UILabel.make(sub, font: AppFonts.regular(10), color: subColor, lines: 1)
        let stack = UIStackView.vertical(spacing: 4, alignment: .leading)
        stack.forAutoLayout()
        stack.addArrangedSubview(tile)
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(subLabel)
        stack.setCustomSpacing(8, after: tile)
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14))
        card.widthAnchor.constraint(equalToConstant: 150).isActive = true
        return card
    }

    // MARK: - Tabs / Reason / Date

    private func onTabSelected(_ index: Int) {
        currentTab = Self.tabKeys[index]
        applyFilter()
    }

    @objc private func showReasonMenu() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: S.allReasons, style: .default) { [weak self] _ in
            self?.selectedReason = ""
            self?.reasonPill.setTitle(S.allReasons)
            self?.applyFilter()
        })
        for reason in Self.reasonLabels {
            sheet.addAction(UIAlertAction(title: reason, style: .default) { [weak self] _ in
                self?.selectedReason = reason
                self?.reasonPill.setTitle(reason)
                self?.applyFilter()
            })
        }
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = reasonPill
            pop.sourceRect = reasonPill.bounds
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
            self.loadData()
        }
        present(sheet, animated: true)
    }

    private func updateDateLabel() {
        datePill.rangeLabel.text = "\(Self.displayDate(dateFrom))  →  \(Self.displayDate(dateTo))"
    }

    // MARK: - Filtering + list

    private func applyFilter() {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = allItems.filter { r in
            if currentTab != "all" && currentTab.caseInsensitiveCompare(r.status ?? "") != .orderedSame { return false }
            if !selectedReason.isEmpty && selectedReason.caseInsensitiveCompare(r.reasonLabel ?? "") != .orderedSame { return false }
            if !q.isEmpty {
                let hay = [r.grnNumber, r.traderName, r.traderPhone].compactMap { $0?.lowercased() }
                if !hay.contains(where: { $0.contains(q) }) { return false }
            }
            return true
        }
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        emptyLabel.isHidden = !filtered.isEmpty
        for r in filtered {
            listStack.addArrangedSubview(makeCard(r))
        }
    }

    // MARK: - Return card

    private func makeCard(_ r: ReturnDTO) -> UIView {
        let card = StyleKit.cardView()

        // GRN no. + status badge
        let number = UILabel.make(r.grnNumber ?? "", font: AppFonts.bold(14), color: AppColors.purplePrimary, lines: 1)
        let badge = StyleKit.badgeLabel()
        let (fg, bg) = ReturnFormat.colors(r.status)
        badge.text = ReturnFormat.label(r.status)
        badge.textColor = fg
        badge.backgroundColor = bg
        badge.setContentHuggingPriority(.required, for: .horizontal)
        let titleRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        titleRow.addArrangedSubview(number)
        titleRow.addArrangedSubview(UIView())
        titleRow.addArrangedSubview(badge)

        let reasonLabel = UILabel.make(r.reasonLabel ?? "—", font: AppFonts.regular(11), color: AppColors.textSecondary)

        // Trader
        let avatar = UILabel()
        let name = r.resolvedTraderName
        avatar.text = OrderFormat.initials(name)
        avatar.font = AppFonts.semibold(13)
        avatar.textColor = .white
        avatar.textAlignment = .center
        avatar.layer.cornerRadius = 18
        avatar.layer.masksToBounds = true
        avatar.constrainSize(36)
        StyleKit.applyAvatarGradient(to: avatar, size: CGSize(width: 36, height: 36))
        let nameLabel = UILabel.make(name, font: AppFonts.bold(12), color: AppColors.textPrimary, lines: 1)
        let traderCol = UIStackView.vertical(spacing: 2, alignment: .leading)
        traderCol.addArrangedSubview(nameLabel)
        if let phone = r.traderPhone, !phone.isEmpty {
            let phoneIcon = UIImageView(image: UIImage(systemName: "phone.fill"))
            phoneIcon.tintColor = AppColors.textSecondary
            phoneIcon.contentMode = .scaleAspectFit
            phoneIcon.forAutoLayout()
            phoneIcon.constrainSize(11)
            phoneIcon.setContentHuggingPriority(.required, for: .horizontal)
            let phoneLabel = UILabel.make(phone, font: AppFonts.regular(11), color: AppColors.textSecondary, lines: 1)
            let phoneRow = UIStackView.horizontal(spacing: 5, alignment: .center)
            phoneRow.addArrangedSubview(phoneIcon)
            phoneRow.addArrangedSubview(phoneLabel)
            traderCol.addArrangedSubview(phoneRow)
        }
        let traderRow = UIStackView.horizontal(spacing: 10, alignment: .center)
        traderRow.addArrangedSubview(avatar)
        traderRow.addArrangedSubview(traderCol)

        // Info grid
        let grid1 = infoRow(S.submittedLabel, ReturnFormat.date(r.createdAt), S.itemsLabel, "\(r.itemCount ?? 0)")
        let grid2 = infoRow(S.quantityLabel, "\(r.totalQuantity ?? 0)", S.creditNoteLabel, r.creditNoteNumber ?? "—")

        // Actions
        let viewButton = OrderListCell.actionButton(title: S.viewBtn, icon: "eye", color: AppColors.textPrimary,
                                                    stroke: AppColors.border)
        viewButton.addAction(UIAction { [weak self] _ in self?.openDetail(r) }, for: .touchUpInside)
        let actionsRow = UIStackView.horizontal(spacing: 8, alignment: .fill)
        actionsRow.distribution = .fillEqually
        actionsRow.addArrangedSubview(viewButton)
        if Self.isPending(r.status) {
            let approve = OrderListCell.actionButton(title: S.approve, icon: "checkmark.circle", color: AppColors.success)
            approve.addAction(UIAction { [weak self] _ in self?.promptAction(r, action: "approve") }, for: .touchUpInside)
            actionsRow.addArrangedSubview(approve)
            let reject = OrderListCell.actionButton(title: S.reject, icon: "xmark.circle", color: AppColors.danger)
            reject.addAction(UIAction { [weak self] _ in self?.promptAction(r, action: "reject") }, for: .touchUpInside)
            actionsRow.addArrangedSubview(reject)
        }

        let stack = UIStackView.vertical(spacing: 10, alignment: .fill)
        stack.addArrangedSubview(titleRow)
        stack.addArrangedSubview(reasonLabel)
        stack.addArrangedSubview(ListScreenLayout.hairline())
        stack.addArrangedSubview(traderRow)
        stack.addArrangedSubview(grid1)
        stack.addArrangedSubview(grid2)
        stack.addArrangedSubview(ListScreenLayout.hairline())
        stack.addArrangedSubview(actionsRow)
        stack.setCustomSpacing(2, after: titleRow)
        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return card
    }

    private func infoRow(_ l1: String, _ v1: String, _ l2: String, _ v2: String) -> UIStackView {
        let row = UIStackView.horizontal(spacing: 8, alignment: .top)
        row.distribution = .fillEqually
        row.addArrangedSubview(infoColumn(l1, v1))
        row.addArrangedSubview(infoColumn(l2, v2))
        return row
    }

    private func infoColumn(_ label: String, _ value: String) -> UIStackView {
        let stack = UIStackView.vertical(spacing: 2, alignment: .leading)
        stack.addArrangedSubview(UILabel.make(label, font: AppFonts.regular(10), color: AppColors.textSecondary))
        stack.addArrangedSubview(UILabel.make(value.isEmpty ? "—" : value, font: AppFonts.bold(12), color: AppColors.textPrimary, lines: 1))
        return stack
    }

    // MARK: - Detail + actions

    private func openDetail(_ r: ReturnDTO) {
        let vc = ReturnDetailViewController(returnId: String(r.id))
        vc.onUpdated = { [weak self] in self?.loadData() }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func promptAction(_ r: ReturnDTO, action: String) {
        let approve = action == "approve"
        let alert = UIAlertController(title: approve ? S.approveReturn : S.rejectReturn,
                                      message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = S.decisionNoteHint }
        alert.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: approve ? S.approve : S.reject,
                                      style: approve ? .default : .destructive) { [weak self, weak alert] _ in
            let note = alert?.textFields?.first?.text ?? ""
            self?.performAction(r, action: action, note: note)
        })
        present(alert, animated: true)
    }

    private func performAction(_ r: ReturnDTO, action: String, note: String) {
        spinner.startAnimating()
        ApiClient.shared.returnAction(action, grnId: r.id, note: note) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.toast(action == "approve" ? S.returnApprovedMsg : S.returnRejectedMsg)
                self.loadData()
            case .failure(let error):
                self.spinner.stopAnimating()
                self.toast(error.message.isEmpty ? S.returnActionFailed : error.message)
            }
        }
    }

    /// Pending returns can still be approved / rejected.
    static func isPending(_ status: String?) -> Bool {
        status?.lowercased() == "pending"
    }

    // MARK: - Date helpers (port of OrdersViewController)

    private static let apiFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func apiDate(_ date: Date) -> String { apiFormatter.string(from: date) }
    private static func parseApiDate(_ raw: String) -> Date? { apiFormatter.date(from: raw) }

    private static func displayDate(_ raw: String) -> String {
        guard let date = parseApiDate(raw) else { return raw }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.timeZone = TimeZone(identifier: "UTC")
        out.dateFormat = "dd MMM yyyy"
        return out.string(from: date)
    }
}

// MARK: - Return formatting helpers (port of ReturnFormat.java)

enum ReturnFormat {

    static func label(_ status: String?) -> String {
        switch key(status) {
        case "pending":  return "Pending"
        case "approved": return "Approved"
        case "rejected": return "Rejected"
        default:         return (status ?? "").capitalized
        }
    }

    static func colors(_ status: String?) -> (fg: UIColor, bg: UIColor) {
        switch key(status) {
        case "approved": return (AppColors.success, AppColors.successBg)
        case "rejected": return (AppColors.danger, AppColors.dangerBg)
        case "pending":  return (AppColors.warning, AppColors.warningBg)
        default:         return (AppColors.warning, AppColors.warningBg)
        }
    }

    /// "25/06/2026 18:51:50" or "2026-06-25 18:51:52" → "25 Jun 2026".
    static func date(_ raw: String?) -> String {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return "" }
        let date = parse(raw, "dd/MM/yyyy HH:mm:ss")
            ?? parse(raw, "yyyy-MM-dd HH:mm:ss")
            ?? parse(raw, "yyyy-MM-dd HH:mm")
            ?? parse(raw, "dd/MM/yyyy")
        guard let date = date else { return raw }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "dd MMM yyyy"
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
