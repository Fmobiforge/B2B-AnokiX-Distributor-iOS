import UIKit

/// Port of OrdersFragment + fragment_orders.xml — title row, status tabs, search/filter, chips, order list.
final class OrdersViewController: BaseMainViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet private weak var pageTitleLabel: UILabel!
    @IBOutlet private weak var pageSubtitleLabel: UILabel!

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var selectedChip = 0
    private var allOrders: [OrderItem] = []
    private var filtered: [OrderItem] = []
    private var search = ""

    override func configureStoryboardChrome() {
        pageTitleLabel.text = S.ordersQueue
        pageTitleLabel.font = AppFonts.bold(AppMetrics.textHeadline)
        pageTitleLabel.textColor = AppColors.textPrimary
        pageSubtitleLabel.text = S.ordersSubtitle
        pageSubtitleLabel.font = AppFonts.light(AppMetrics.textBodySM)
        pageSubtitleLabel.textColor = AppColors.textSecondary
        addDateRangePill()
    }

    private func addDateRangePill() {
        guard let panel = chromeStackView.arrangedSubviews.first else { return }
        let range = FilterUiHelper.defaultWeekRange()
        let pill = DateRangePillView(text: FilterUiHelper.formatDateRange(start: range.start, end: range.end))
        pill.forAutoLayout()
        panel.addSubview(pill)
        NSLayoutConstraint.activate([
            pill.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            pill.centerYAnchor.constraint(equalTo: pageTitleLabel.centerYAnchor),
            pill.leadingAnchor.constraint(greaterThanOrEqualTo: pageSubtitleLabel.trailingAnchor, constant: 8)
        ])
        FilterUiHelper.bindDateRangePicker(
            on: pill,
            label: pill.rangeLabel,
            from: self,
            start: range.start,
            end: range.end
        ) { _, _, _ in }
    }

    override func setupContent(in container: UIView) {
        let statusTabs = ScrollStatusTabBar(
            titles: ["New Orders (12)", "Processing (18)", "Delivered (245)"],
            selectedIndex: 0
        ) { _ in /* visual state only — matches Android OrdersFragment */ }
        statusTabs.constrainHeight(44)

        let searchRow = SearchFilterRowView(placeholder: "Search by trader name, order ID…")
        searchRow.searchBar.onChange = { [weak self] text in
            self?.search = text
            self?.applyFilters()
        }
        searchRow.bindFilterToast(from: self)

        let chipBar = ChipBarView(
            titles: [S.tabAll, "High Value", "Wallet", "COD", "More ▾"],
            selectedIndex: 0
        ) { [weak self] index in
            self?.selectedChip = index
            self?.applyFilters()
        }
        chipBar.constrainHeight(42)

        let chromeBlock = ListScreenLayout.surfaceSection(
            [statusTabs, ListScreenLayout.hairline(), searchRow, chipBar],
            insets: UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        )

        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = AppColors.background
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 260
        tableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        tableView.registerNib(OrderCell.self)

        chromeBlock.forAutoLayout()
        tableView.forAutoLayout()
        container.addSubviews(chromeBlock, tableView)
        NSLayoutConstraint.activate([
            chromeBlock.topAnchor.constraint(equalTo: container.topAnchor),
            chromeBlock.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            chromeBlock.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: chromeBlock.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    override func loadData() {
        allOrders = MockData.orders()
        applyFilters()
    }

    private func applyFilters() {
        filtered = allOrders.filter { order in
            let matchesSearch = search.isEmpty
                || order.traderName.localizedCaseInsensitiveContains(search)
                || order.orderId.localizedCaseInsensitiveContains(search)
            let matchesChip: Bool
            switch selectedChip {
            case 1: matchesChip = order.amount.contains("8") || order.amount.contains("9")
            case 2: matchesChip = order.payment.lowercased().contains("wallet")
            case 3: matchesChip = order.payment.lowercased().contains("cod")
            default: matchesChip = true
            }
            return matchesSearch && matchesChip
        }
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { filtered.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(OrderCell.self, for: indexPath)
        let order = filtered[indexPath.row]
        cell.configure(order, showActions: true)
        cell.onAccept = { [weak self] in self?.toast("Order accepted") }
        cell.onReject = { [weak self] in self?.toast("Order rejected") }
        cell.onView = { [weak self] in self?.toast("View order \(order.orderId)") }
        cell.onCopy = { [weak self] in
            UIPasteboard.general.string = order.orderId
            self?.toast("Copied \(order.orderId)")
        }
        return cell
    }

    private func toast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { alert.dismiss(animated: true) }
    }
}
