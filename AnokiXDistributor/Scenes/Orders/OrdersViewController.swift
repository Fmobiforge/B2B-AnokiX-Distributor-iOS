import UIKit

/// Distributor Orders list — wired to GET `api/distributor/orders` (port of the Android
/// OrdersFragment). Supports a keyword search, a trader filter discovered from the loaded
/// orders, a date range, status tabs with live counts, pagination, and the per-status
/// fulfilment actions (Accept / Reject / Pick / Pack / Mark Ready / Dispatch / Delivered).
final class OrdersViewController: BaseMainViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet private weak var pageTitleLabel: UILabel!
    @IBOutlet private weak var pageSubtitleLabel: UILabel!

    private static let statusLabels = [
        "Order Queue", "Accept", "Picking", "Packing", "Ready For Delivery",
        "Out For Delivery", "Delivered", "Cancelled", "Failed"
    ]
    private static let statusKeys = [
        "pending", "accepted", "picking", "packing", "ready_for_delivery",
        "out_for_delivery", "delivered", "cancelled", "failed"
    ]
    private static let perPage = 10
    private let currency = "R"

    // UI
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let emptyLabel = UILabel.bodySecondary(S.noOrdersFound)
    private let traderPill = FilterPillButton(title: S.allTraders)
    private let datePill = DateRangePillView(text: "")
    private lazy var statusTabs = OrderStatusTabsView(titles: Self.statusLabels, selectedIndex: 0)
    private let paginationBar = UIView()
    private let paginationLabel = UILabel.caption()
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)

    // Data + filter state
    private var orders: [OrderDTO] = []
    private var search = ""
    private var traderId: String?            // nil = All Traders
    private var dateFrom = ""
    private var dateTo = ""
    private var status = "pending"           // Order Queue is the default tab
    private var page = 1
    private var totalPages = 1
    private var total = 0
    /// Trader options discovered from loaded orders (id → display name), insertion-ordered.
    private var knownTraderIds: [String] = []
    private var knownTraders: [String: String] = [:]

    private var searchWorkItem: DispatchWorkItem?
    private var hasAppeared = false

    // MARK: - Chrome

    override func configureStoryboardChrome() {
        pageTitleLabel.text = S.ordersQueue
        pageTitleLabel.font = AppFonts.semibold(AppMetrics.textHeadline)
        pageTitleLabel.textColor = AppColors.topTitle
        pageSubtitleLabel.text = S.ordersSubtitle
        pageSubtitleLabel.font = AppFonts.regular(AppMetrics.textBodySM)
        pageSubtitleLabel.textColor = AppColors.textSecondary
    }

    // MARK: - Content

    override func setupContent(in container: UIView) {
        // Default range: last 30 days (matches the web portal's first call).
        let now = Date()
        dateTo = Self.apiDate(now)
        dateFrom = Self.apiDate(Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now)

        let chrome = buildChrome()
        let listArea = buildListArea()
        buildPaginationBar()

        chrome.forAutoLayout()
        listArea.forAutoLayout()
        paginationBar.forAutoLayout()
        container.addSubviews(chrome, listArea, paginationBar)
        NSLayoutConstraint.activate([
            chrome.topAnchor.constraint(equalTo: container.topAnchor),
            chrome.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            listArea.topAnchor.constraint(equalTo: chrome.bottomAnchor),
            listArea.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            listArea.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            listArea.bottomAnchor.constraint(equalTo: paginationBar.topAnchor),

            paginationBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            paginationBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            paginationBar.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    private func buildChrome() -> UIView {
        // Search + trader filter row.
        let searchBar = SearchBarView(placeholder: S.ordersSearchHint)
        searchBar.onChange = { [weak self] text in self?.onSearchChanged(text) }
        searchBar.setContentHuggingPriority(.defaultLow, for: .horizontal)
        traderPill.addTarget(self, action: #selector(showTraderMenu), for: .touchUpInside)
        traderPill.setContentHuggingPriority(.required, for: .horizontal)
        traderPill.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true

        let topRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        topRow.addArrangedSubview(searchBar)
        topRow.addArrangedSubview(traderPill)

        // Date range pill (full width).
        updateDateLabel()
        datePill.addTarget(self, action: #selector(showDateRangePicker), for: .touchUpInside)

        statusTabs.onSelect = { [weak self] index in self?.onStatusSelected(index) }
        statusTabs.constrainHeight(46)

        let filters = UIStackView.vertical(spacing: 10, alignment: .fill)
        filters.addArrangedSubview(topRow)
        filters.addArrangedSubview(datePill)

        let block = UIStackView.vertical(spacing: 0, alignment: .fill)
        let padded = UIView()
        padded.backgroundColor = AppColors.surface
        filters.forAutoLayout()
        padded.addSubview(filters)
        filters.pinEdges(to: padded, insets: UIEdgeInsets(top: 12, left: 12, bottom: 10, right: 12))

        block.addArrangedSubview(padded)
        block.addArrangedSubview(statusTabs)
        block.addArrangedSubview(ListScreenLayout.hairline())
        let wrapper = UIView()
        wrapper.backgroundColor = AppColors.surface
        block.forAutoLayout()
        wrapper.addSubview(block)
        block.pinEdges(to: wrapper)
        return wrapper
    }

    private func buildListArea() -> UIView {
        let area = UIView()

        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = AppColors.background
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 240
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 12, right: 0)
        tableView.register(OrderListCell.self, forCellReuseIdentifier: OrderListCell.reuseId)
        tableView.forAutoLayout()

        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        emptyLabel.forAutoLayout()
        spinner.hidesWhenStopped = true
        spinner.color = AppColors.purplePrimary
        spinner.forAutoLayout()

        area.addSubviews(tableView, emptyLabel, spinner)
        tableView.pinEdges(to: area)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: area.centerXAnchor),
            emptyLabel.topAnchor.constraint(equalTo: area.topAnchor, constant: 40),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: area.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: area.trailingAnchor, constant: -24),
            spinner.centerXAnchor.constraint(equalTo: area.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: area.centerYAnchor)
        ])
        return area
    }

    private func buildPaginationBar() {
        paginationBar.backgroundColor = AppColors.surface
        paginationBar.isHidden = true

        let topLine = ListScreenLayout.hairline()
        paginationLabel.textColor = AppColors.textSecondary

        styleNavButton(prevButton, system: "chevron.left")
        styleNavButton(nextButton, system: "chevron.right")
        prevButton.addTarget(self, action: #selector(prevPage), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextPage), for: .touchUpInside)

        let row = UIStackView.horizontal(spacing: 10, alignment: .center)
        let spacer = UIView()
        row.addArrangedSubview(paginationLabel)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(prevButton)
        row.addArrangedSubview(nextButton)
        row.forAutoLayout()
        topLine.forAutoLayout()
        paginationBar.addSubviews(topLine, row)
        NSLayoutConstraint.activate([
            topLine.topAnchor.constraint(equalTo: paginationBar.topAnchor),
            topLine.leadingAnchor.constraint(equalTo: paginationBar.leadingAnchor),
            topLine.trailingAnchor.constraint(equalTo: paginationBar.trailingAnchor),
            row.topAnchor.constraint(equalTo: paginationBar.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: paginationBar.bottomAnchor, constant: -8),
            row.leadingAnchor.constraint(equalTo: paginationBar.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: paginationBar.trailingAnchor, constant: -16)
        ])
    }

    private func styleNavButton(_ button: UIButton, system: String) {
        button.setImage(UIImage(systemName: system), for: .normal)
        button.tintColor = AppColors.textPrimary
        button.backgroundColor = AppColors.surface
        button.layer.cornerRadius = AppMetrics.radiusSM
        button.layer.borderWidth = 1
        button.layer.borderColor = AppColors.border.cgColor
        button.widthAnchor.constraint(equalToConstant: 36).isActive = true
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true
    }

    override func loadData() {
        load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh after returning from the detail screen (a status may have changed).
        if hasAppeared { load() }
        hasAppeared = true
    }

    // MARK: - Filters

    private func onSearchChanged(_ text: String) {
        searchWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.search = text.trimmingCharacters(in: .whitespacesAndNewlines)
            self.page = 1
            self.load()
        }
        searchWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func onStatusSelected(_ index: Int) {
        let key = Self.statusKeys[index]
        guard key != status else { return }
        status = key
        page = 1
        load()
    }

    @objc private func showTraderMenu() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: S.allTraders, style: .default) { [weak self] _ in
            self?.traderId = nil
            self?.traderPill.setTitle(S.allTraders)
            self?.page = 1
            self?.load()
        })
        for id in knownTraderIds {
            let name = knownTraders[id] ?? id
            sheet.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                self?.traderId = id
                self?.traderPill.setTitle(name)
                self?.page = 1
                self?.load()
            })
        }
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = traderPill
            popover.sourceRect = traderPill.bounds
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
            self.page = 1
            self.load()
        }
        present(sheet, animated: true)
    }

    private func updateDateLabel() {
        datePill.rangeLabel.text = "\(Self.displayDate(dateFrom))  →  \(Self.displayDate(dateTo))"
    }

    // MARK: - Networking

    private func load() {
        spinner.startAnimating()
        emptyLabel.isHidden = true
        ApiClient.shared.getOrders(traderId: traderId, search: search, dateFrom: dateFrom,
                                   dateTo: dateTo, status: status, page: page, perPage: Self.perPage) { [weak self] result in
            guard let self = self else { return }
            self.spinner.stopAnimating()
            switch result {
            case .success(let data):
                self.bind(data)
            case .failure(let error):
                self.orders = []
                self.tableView.reloadData()
                self.emptyLabel.isHidden = false
                self.paginationBar.isHidden = true
                self.toast(error.message.isEmpty ? S.ordersLoadFailed : error.message)
            }
        }
    }

    private func bind(_ data: OrdersData) {
        orders = data.orders ?? []
        mergeTraders(orders)
        tableView.reloadData()

        emptyLabel.isHidden = !orders.isEmpty
        updateStatusCounts(data.statusCounts)
        updatePagination(data.pagination)
        if !orders.isEmpty {
            tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
        }
    }

    private func mergeTraders(_ list: [OrderDTO]) {
        for order in list {
            guard let trader = order.trader, let id = trader.id, id != 0 else { continue }
            let key = String(id)
            if knownTraders[key] == nil { knownTraderIds.append(key) }
            knownTraders[key] = order.traderName
        }
    }

    private func updateStatusCounts(_ counts: OrderStatusCounts?) {
        let values = Self.statusKeys.map { counts?.count(for: $0) ?? 0 }
        statusTabs.updateCounts(values)
    }

    private func updatePagination(_ pagination: OrderPagination?) {
        guard let pagination = pagination, (pagination.total ?? 0) > 0 else {
            paginationBar.isHidden = true
            return
        }
        page = pagination.page ?? page
        totalPages = max(1, pagination.totalPages ?? 1)
        total = pagination.total ?? 0

        let from = (page - 1) * Self.perPage + 1
        let to = min(page * Self.perPage, total)
        paginationLabel.text = S.ordersPagination(from, to, total)

        paginationBar.isHidden = false
        let multi = totalPages > 1
        prevButton.isEnabled = page > 1
        prevButton.alpha = page > 1 ? 1 : 0.4
        nextButton.isEnabled = page < totalPages
        nextButton.alpha = page < totalPages ? 1 : 0.4
        prevButton.isHidden = !multi
        nextButton.isHidden = !multi
    }

    @objc private func prevPage() {
        guard page > 1 else { return }
        page -= 1
        load()
    }

    @objc private func nextPage() {
        guard page < totalPages else { return }
        page += 1
        load()
    }

    // MARK: - Actions

    private func openDetail(_ order: OrderDTO) {
        let vc = OrderDetailViewController(orderId: String(order.id))
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }

    private func performAction(_ order: OrderDTO, action: String) {
        spinner.startAnimating()
        ApiClient.shared.orderAction(action, orderId: order.id) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.toast(self.actionDoneMessage(action))
                self.load()
            case .failure(let error):
                self.spinner.stopAnimating()
                self.toast(error.message.isEmpty ? S.orderActionFailed : error.message)
            }
        }
    }

    private func actionDoneMessage(_ action: String) -> String {
        switch action {
        case "accept":   return "Order accepted"
        case "reject":   return "Order rejected"
        case "pick":     return "Order moved to picking"
        case "pack":     return "Order moved to packing"
        case "ready":    return "Order marked ready"
        case "dispatch": return "Order dispatched"
        case "deliver":  return "Order delivered"
        default:         return "Order updated"
        }
    }

    // MARK: - Table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { orders.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: OrderListCell.reuseId,
                                                       for: indexPath) as? OrderListCell else {
            return UITableViewCell()
        }
        let order = orders[indexPath.row]
        cell.configure(order, currency: currency)
        cell.onView = { [weak self] in self?.openDetail(order) }
        cell.onPrimary = { [weak self, weak cell] in
            guard let action = cell?.primaryAction else { return }
            self?.performAction(order, action: action)
        }
        cell.onReject = { [weak self] in self?.performAction(order, action: "reject") }
        return cell
    }

    // MARK: - Helpers

    private func toast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { alert.dismiss(animated: true) }
    }

    private static let apiFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func apiDate(_ date: Date) -> String { apiFormatter.string(from: date) }
    private static func parseApiDate(_ raw: String) -> Date? { apiFormatter.date(from: raw) }

    /// "yyyy-MM-dd" → "26 May 2026".
    private static func displayDate(_ raw: String) -> String {
        guard let date = parseApiDate(raw) else { return raw }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.timeZone = TimeZone(identifier: "UTC")
        out.dateFormat = "dd MMM yyyy"
        return out.string(from: date)
    }
}

// MARK: - Order formatting helpers (port of OrderFormat.java)

enum OrderFormat {

    private static let logoColors = [0xEC4899, 0x8B5CF6, 0x1565C0, 0x0891B2, 0x2E7D32, 0xE65100, 0xF57F17]

    static func statusColor(_ key: String?) -> UIColor {
        switch key {
        case "pending":            return AppColors.statExpiring
        case "accepted":           return AppColors.purplePrimary
        case "picking":            return AppColors.info
        case "packing":            return UIColor(hex: 0x0891B2)
        case "ready_for_delivery": return UIColor(hex: 0x0D9488)
        case "out_for_delivery":   return AppColors.warning
        case "delivered":          return AppColors.success
        case "cancelled":          return AppColors.danger
        case "failed":             return UIColor(hex: 0xB91C1C)
        default:                   return AppColors.textSecondary
        }
    }

    /// "out_for_delivery" → "Out For Delivery".
    static func humanize(_ key: String?) -> String {
        guard let key = key, !key.isEmpty else { return "" }
        return key.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static let moneyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.decimalSeparator = "."
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    static func money(_ value: Double, currency: String = "R") -> String {
        let symbol = currency.isEmpty ? "R" : currency
        let number = moneyFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return symbol + number
    }

    /// "24/06/2026 21:13:56" → "24 Jun 2026, 21:13".
    static func createdAt(_ raw: String?) -> String {
        guard let date = parse(raw, "dd/MM/yyyy HH:mm:ss") else { return raw ?? "" }
        return format(date, "dd MMM yyyy, HH:mm")
    }

    /// "2026-06-26" → "26 Jun 2026".
    static func deliveryDate(_ raw: String?) -> String {
        guard let date = parse(raw, "yyyy-MM-dd") else { return raw ?? "" }
        return format(date, "dd MMM yyyy")
    }

    /// "08:00:00" → "08:00".
    static func trimSeconds(_ time: String?) -> String {
        guard let time = time else { return "" }
        return time.count >= 5 ? String(time.prefix(5)) : time
    }

    static func logoColor(_ id: Int) -> UIColor {
        UIColor(hex: logoColors[abs(id) % logoColors.count])
    }

    static func initials(_ name: String?) -> String {
        guard let name = name?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return "?" }
        var result = ""
        for part in name.split(separator: " ") {
            if result.count >= 2 { break }
            if let first = part.first { result.append(Character(first.uppercased())) }
        }
        return result.isEmpty ? "?" : result
    }

    private static func parse(_ raw: String?, _ pattern: String) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = pattern
        return f.date(from: raw)
    }

    private static func format(_ date: Date, _ pattern: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = pattern
        return f.string(from: date)
    }
}
