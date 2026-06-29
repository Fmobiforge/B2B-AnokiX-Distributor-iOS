import UIKit

/// Deliveries list — wired to GET `api/distributor/deliveries` (port of DeliveriesActivity).
/// KPI summary, status tabs with live counts, a date range that drives the API call, plus
/// local search + area filtering. Each card opens the detail screen and, when actionable,
/// shows an inline Dispatch / Mark Delivered button.
final class DeliveriesViewController: BaseSecondaryViewController {

    override var screenTitle: String { S.deliveries }
    override var screenSubtitle: String? { S.deliveriesSubtitle }

    private static let tabKeys = ["all", "in_transit", "delivered", "delayed", "failed", "returned"]
    private static let tabTitles = [S.tabAll, S.inTransit, S.delivered, S.delayed, S.failedStatus, S.returnedStatus]
    private let currency = "R"

    // Data + filter state
    private var allItems: [DeliveryDTO] = []
    private var areaOptions: [String] = []
    private var currentTab = "all"
    private var selectedArea = ""          // "" = All Areas
    private var search = ""
    private var dateFrom = ""
    private var dateTo = ""

    // UI
    private let summaryScroll = UIScrollView()
    private let summaryRow = UIStackView.horizontal(spacing: 10, alignment: .fill)
    private let areaPill = FilterPillButton(title: S.allAreas)
    private let datePill = DateRangePillView(text: "")
    private lazy var statusTabs = OrderStatusTabsView(titles: Self.tabTitles, selectedIndex: 0)
    private let listStack = UIStackView.vertical(spacing: 12, alignment: .fill)
    private let emptyLabel = UILabel.make(S.noDeliveries, font: AppFonts.regular(14),
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
        let searchBar = SearchBarView(placeholder: S.searchDeliveries)
        searchBar.onChange = { [weak self] text in self?.search = text; self?.applyFilter() }
        stack.addArrangedSubview(searchBar)

        // Area + date range filters.
        areaPill.addTarget(self, action: #selector(showAreaMenu), for: .touchUpInside)
        areaPill.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        updateDateLabel()
        datePill.addTarget(self, action: #selector(showDateRangePicker), for: .touchUpInside)
        datePill.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let filterRow = UIStackView.horizontal(spacing: 10, alignment: .fill)
        filterRow.addArrangedSubview(areaPill)
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
        ApiClient.shared.getDeliveries(dateFrom: dateFrom, dateTo: dateTo, search: "",
                                       page: 1, perPage: 100) { [weak self] result in
            guard let self = self else { return }
            self.spinner.stopAnimating()
            switch result {
            case .success(let data):
                self.renderSummary(data.summary)
                self.statusTabs.updateCounts(Self.tabKeys.map { data.statusCounts?.count(for: $0) ?? 0 })
                self.bindAreas(data.areas ?? [])
                self.allItems = data.deliveries ?? []
                self.applyFilter()
            case .failure(let error):
                self.allItems = []
                self.applyFilter()
                self.toast(error.message.isEmpty ? S.deliveriesLoadFailed : error.message)
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

    private func renderSummary(_ s: DeliverySummary?) {
        summaryRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let s = s else { summaryScroll.isHidden = true; return }
        summaryScroll.isHidden = false
        summaryRow.addArrangedSubview(statCard(S.totalDeliveries, "\(s.totalDeliveries ?? 0)", S.inSelectedRange, AppColors.textSecondary,
                                               icon: "bag.fill", tint: AppColors.purplePrimary, tile: AppColors.purpleLight))
        summaryRow.addArrangedSubview(statCard(S.onTime, "\(s.onTime ?? 0)", pct(s.onTimePct), AppColors.success,
                                               icon: "checkmark.circle.fill", tint: AppColors.success, tile: AppColors.successBg))
        summaryRow.addArrangedSubview(statCard(S.inTransit, "\(s.inTransit ?? 0)", pct(s.inTransitPct), AppColors.info,
                                               icon: "shippingbox.fill", tint: AppColors.info, tile: AppColors.infoBg))
        summaryRow.addArrangedSubview(statCard(S.delayed, "\(s.delayed ?? 0)", pct(s.delayedPct), AppColors.warning,
                                               icon: "clock.fill", tint: AppColors.warning, tile: AppColors.warningBg))
        summaryRow.addArrangedSubview(statCard(S.failedStatus, "\(s.failed ?? 0)", pct(s.failedPct), AppColors.danger,
                                               icon: "xmark.circle.fill", tint: AppColors.danger, tile: AppColors.dangerBg))
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
        let valueLabel = UILabel.make(value, font: AppFonts.bold(22), color: AppColors.textPrimary)
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
        card.widthAnchor.constraint(equalToConstant: 140).isActive = true
        return card
    }

    private func pct(_ value: Double?) -> String {
        let v = value ?? 0
        return v == v.rounded() ? "\(Int(v))%" : String(format: "%.1f%%", v)
    }

    // MARK: - Tabs / Area / Date

    private func onTabSelected(_ index: Int) {
        currentTab = Self.tabKeys[index]
        applyFilter()
    }

    private func bindAreas(_ areas: [String]) {
        areaOptions = areas.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if !selectedArea.isEmpty && !areaOptions.contains(selectedArea) {
            selectedArea = ""
            areaPill.setTitle(S.allAreas)
        }
    }

    @objc private func showAreaMenu() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: S.allAreas, style: .default) { [weak self] _ in
            self?.selectedArea = ""
            self?.areaPill.setTitle(S.allAreas)
            self?.applyFilter()
        })
        for area in areaOptions {
            sheet.addAction(UIAlertAction(title: area, style: .default) { [weak self] _ in
                self?.selectedArea = area
                self?.areaPill.setTitle(area)
                self?.applyFilter()
            })
        }
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = areaPill
            pop.sourceRect = areaPill.bounds
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
        let filtered = allItems.filter { d in
            if currentTab != "all" && currentTab.caseInsensitiveCompare(d.status ?? "") != .orderedSame { return false }
            if !selectedArea.isEmpty && selectedArea.caseInsensitiveCompare(d.area ?? "") != .orderedSame { return false }
            if !q.isEmpty {
                let hay = [d.deliveryNumber, d.orderNumber, d.traderName].compactMap { $0?.lowercased() }
                if !hay.contains(where: { $0.contains(q) }) { return false }
            }
            return true
        }
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        emptyLabel.isHidden = !filtered.isEmpty
        for d in filtered {
            listStack.addArrangedSubview(makeCard(d))
        }
    }

    // MARK: - Delivery card

    private func makeCard(_ d: DeliveryDTO) -> UIView {
        let card = StyleKit.cardView()

        // Delivery no. + status badge
        let number = UILabel.make(d.deliveryNumber ?? "", font: AppFonts.bold(14), color: AppColors.purplePrimary, lines: 1)
        let badge = StyleKit.badgeLabel()
        let (fg, bg) = DeliveryFormat.colors(d.status)
        badge.text = DeliveryFormat.label(d.status)
        badge.textColor = fg
        badge.backgroundColor = bg
        badge.setContentHuggingPriority(.required, for: .horizontal)
        let titleRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        titleRow.addArrangedSubview(number)
        titleRow.addArrangedSubview(UIView())
        titleRow.addArrangedSubview(badge)

        let orderNumber = UILabel.make(d.orderNumber ?? "", font: AppFonts.regular(11), color: AppColors.textSecondary)

        // Trader
        let avatar = UILabel()
        let name = d.resolvedTraderName
        avatar.text = OrderFormat.initials(name)
        avatar.font = AppFonts.bold(13)
        avatar.textColor = .white
        avatar.textAlignment = .center
        avatar.backgroundColor = OrderFormat.logoColor(d.traderId ?? 0)
        avatar.layer.cornerRadius = 18
        avatar.layer.masksToBounds = true
        avatar.constrainSize(36)
        let nameLabel = UILabel.make(name, font: AppFonts.bold(12), color: AppColors.textPrimary, lines: 1)
        let traderCol = UIStackView.vertical(spacing: 2, alignment: .leading)
        traderCol.addArrangedSubview(nameLabel)
        if let phone = d.traderPhone, !phone.isEmpty {
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
        let grid1 = infoRow(S.areaLabel, d.area ?? "—", S.deliveryDateLabel, DeliveryFormat.deliveryAt(d.deliveryAt))
        let grid2 = infoRow(S.itemsLabel, "\(d.itemCount ?? 0)", S.amountLabel,
                            OrderFormat.money(d.totalAmount ?? 0, currency: currency))

        // Actions
        let viewButton = OrderListCell.actionButton(title: S.viewBtn, icon: "eye", color: AppColors.purplePrimary)
        viewButton.addAction(UIAction { [weak self] _ in self?.openDetail(d) }, for: .touchUpInside)
        let actionsRow = UIStackView.horizontal(spacing: 8, alignment: .fill)
        actionsRow.distribution = .fillEqually
        actionsRow.addArrangedSubview(viewButton)
        if let action = Self.actionFor(d.rawStatus) {
            let title = action == "dispatch" ? S.dispatch : S.markDelivered
            let icon = action == "dispatch" ? "paperplane" : "checkmark.circle"
            let actionButton = OrderListCell.actionButton(title: title, icon: icon, color: AppColors.success)
            actionButton.addAction(UIAction { [weak self] _ in self?.performAction(d, action: action) }, for: .touchUpInside)
            actionsRow.addArrangedSubview(actionButton)
        }

        let stack = UIStackView.vertical(spacing: 10, alignment: .fill)
        stack.addArrangedSubview(titleRow)
        stack.addArrangedSubview(orderNumber)
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

    private func openDetail(_ d: DeliveryDTO) {
        let vc = DeliveryDetailViewController(deliveryId: String(d.id))
        vc.onUpdated = { [weak self] in self?.loadData() }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func performAction(_ d: DeliveryDTO, action: String) {
        spinner.startAnimating()
        ApiClient.shared.deliveryAction(action, deliveryId: d.id) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.toast(action == "dispatch" ? S.deliveryDispatchedMsg : S.deliveryDeliveredMsg)
                self.loadData()
            case .failure(let error):
                self.spinner.stopAnimating()
                self.toast(error.message.isEmpty ? S.deliveryActionFailed : error.message)
            }
        }
    }

    /// Raw status → action: ReadyForDelivery=dispatch, OutForDelivery=deliver, else none.
    static func actionFor(_ rawStatus: String?) -> String? {
        switch rawStatus {
        case "ReadyForDelivery": return "dispatch"
        case "OutForDelivery":   return "deliver"
        default:                 return nil
        }
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

// MARK: - Delivery formatting helpers (port of DeliveryFormat.java)

enum DeliveryFormat {

    static func label(_ status: String?) -> String {
        switch key(status) {
        case "delivered":  return "Delivered"
        case "in_transit": return "In Transit"
        case "delayed":    return "Delayed"
        case "failed":     return "Failed"
        case "returned":   return "Returned"
        default:           return (status ?? "").capitalized
        }
    }

    static func colors(_ status: String?) -> (fg: UIColor, bg: UIColor) {
        switch key(status) {
        case "delivered":  return (AppColors.success, AppColors.successBg)
        case "in_transit": return (AppColors.info, AppColors.infoBg)
        case "delayed":    return (AppColors.warning, AppColors.warningBg)
        case "failed":     return (AppColors.danger, AppColors.dangerBg)
        case "returned":   return (AppColors.purplePrimary, AppColors.purpleLight)
        default:           return (AppColors.info, AppColors.infoBg)
        }
    }

    /// "2026-06-25 22:00" → "25 Jun 2026, 10:00 PM".
    static func deliveryAt(_ raw: String?) -> String {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return "" }
        let date = parse(raw, "yyyy-MM-dd HH:mm") ?? parse(raw, "yyyy-MM-dd HH:mm:ss")
        guard let date = date else { return raw }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "dd MMM yyyy, hh:mm a"
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
