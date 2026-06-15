import UIKit

/// Port of InventoryFragment + fragment_inventory.xml — scroll layout with stat cards,
/// underline tabs, search, table-in-card, and donut summary.
final class InventoryViewController: BaseMainViewController {

    @IBOutlet private weak var logoImageView: UIImageView!
    @IBOutlet private weak var logoSubtitleLabel: UILabel!
    @IBOutlet private weak var pageTitleLabel: UILabel!
    @IBOutlet private weak var pageSubtitleLabel: UILabel!

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView.vertical(spacing: 0, alignment: .fill)
    private let summaryRow = UIStackView.horizontal(spacing: 8, alignment: .fill)
    private let tableRowsStack = UIStackView.vertical(spacing: 0, alignment: .fill)
    private let donutTotalLabel = UILabel()
    private let donutChart = DonutChartView()

    private var items: [ListItem] = []
    private var filtered: [ListItem] = []
    private var inventoryTab = 0
    private var searchText = ""

    override func configureStoryboardChrome() {
        logoImageView.image = BrandAssets.logoBlack
        configureLogoHeaderImage(logoImageView, in: chromeStackView.arrangedSubviews.first)
        logoSubtitleLabel.text = S.loginSubtitle
        logoSubtitleLabel.font = AppFonts.light(AppMetrics.textLabel)
        logoSubtitleLabel.textColor = AppColors.textSecondary
        pageTitleLabel.text = S.inventoryOverview
        pageTitleLabel.font = AppFonts.bold(AppMetrics.textHeadline)
        pageTitleLabel.textColor = AppColors.textPrimary
        pageSubtitleLabel.isHidden = true
        pageSubtitleLabel.removeFromSuperview()
        addLogoHeaderDivider()
        styleNotificationBell(in: chromeStackView.arrangedSubviews.first)
    }

    private func styleNotificationBell(in panel: UIView?) {
        guard let panel = panel,
              let bell = panel.subviews.compactMap({ $0 as? UIButton }).first else { return }
        bell.tintColor = AppColors.textPrimary
        addNotificationBadge(to: bell)
    }

    private func addLogoHeaderDivider() {
        guard chromeStackView.arrangedSubviews.count >= 1,
              let logoPanel = chromeStackView.arrangedSubviews.first else { return }
        guard logoPanel.subviews.first(where: { $0.tag == 8801 }) == nil else { return }
        let divider = UIView()
        divider.tag = 8801
        divider.backgroundColor = AppColors.border
        divider.translatesAutoresizingMaskIntoConstraints = false
        logoPanel.addSubview(divider)
        NSLayoutConstraint.activate([
            divider.leadingAnchor.constraint(equalTo: logoPanel.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: logoPanel.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: logoPanel.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    @IBAction private func notificationsTapped(_ sender: UIButton) { openNotifications() }

    override func setupContent(in container: UIView) {
        summaryRow.distribution = .fillEqually

        let tabs = UnderlineTabBar(titles: [S.tabAll, S.lowStock, S.expired], selectedIndex: 0) { [weak self] index in
            self?.inventoryTab = index
            self?.applyFilters()
        }
        tabs.constrainHeight(44)

        let searchRow = SearchFilterRowView(placeholder: "Search products…", height: AppMetrics.searchBarHeight)
        searchRow.searchBar.onChange = { [weak self] text in
            self?.searchText = text
            self?.applyFilters()
        }
        searchRow.bindFilterToast(from: self)

        let headerBlock = ListScreenLayout.surfaceSection(
            [summaryRow, tabs, searchRow],
            spacing: 12,
            insets: UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        )

        let tableCard = buildTableCard()
        let summaryCard = buildDonutSummaryCard()

        contentStack.addArrangedSubview(headerBlock)
        contentStack.addArrangedSubview(tableCard)
        contentStack.addArrangedSubview(summaryCard)

        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = AppColors.background
        scrollView.forAutoLayout()
        contentStack.forAutoLayout()
        scrollView.addSubview(contentStack)
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func buildTableCard() -> UIView {
        let card = StyleKit.cardView()
        let inner = UIStackView.vertical(spacing: 0, alignment: .fill)
        inner.forAutoLayout()
        inner.addArrangedSubview(tableHeaderRow())
        inner.addArrangedSubview(ListScreenLayout.hairline())
        inner.addArrangedSubview(tableRowsStack)
        card.addSubview(inner)
        inner.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        let wrapper = UIView()
        wrapper.backgroundColor = AppColors.background
        wrapper.addSubview(card)
        card.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 12),
            card.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
        ])
        return wrapper
    }

    private func tableHeaderRow() -> UIView {
        let row = UIView()
        row.constrainHeight(32)
        let product = columnHeader(S.productColumn, alignRight: false)
        let sku = columnHeader(S.skuColumn, alignRight: false)
        let stock = columnHeader(S.stockColumn, alignRight: false)
        let status = columnHeader(S.statusColumn, alignRight: true)
        row.addSubviews(product, sku, stock, status)
        pinTableColumns(product: product, sku: sku, stock: stock, status: status, in: row)
        return row
    }

    private func columnHeader(_ text: String, alignRight: Bool) -> UILabel {
        UILabel.make(text, font: AppFonts.bold(AppMetrics.textLabel), color: AppColors.textSecondary,
                     align: alignRight ? .right : .left)
    }

    private func pinTableColumns(product: UIView, sku: UIView, stock: UIView, status: UIView, in row: UIView) {
        [product, sku, stock, status].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            product.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            product.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            product.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 2.0 / 5.2),

            sku.leadingAnchor.constraint(equalTo: product.trailingAnchor, constant: 4),
            sku.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            sku.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 1.0 / 5.2),

            stock.leadingAnchor.constraint(equalTo: sku.trailingAnchor, constant: 4),
            stock.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            stock.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 1.0 / 5.2),

            status.leadingAnchor.constraint(equalTo: stock.trailingAnchor, constant: 4),
            status.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            status.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            status.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 1.2 / 5.2)
        ])
    }

    private func buildDonutSummaryCard() -> UIView {
        let card = StyleKit.cardView()
        let title = UILabel.make(S.inventorySummary, font: AppFonts.bold(AppMetrics.textTitle), color: AppColors.textPrimary)

        donutChart.setData(values: [1047, 86, 12], colors: [AppColors.success, AppColors.warning, AppColors.danger])
        donutChart.forAutoLayout()
        NSLayoutConstraint.activate([
            donutChart.widthAnchor.constraint(equalToConstant: 120),
            donutChart.heightAnchor.constraint(equalToConstant: 120)
        ])

        donutTotalLabel.text = "1,245"
        donutTotalLabel.font = AppFonts.bold(AppMetrics.textTitle)
        donutTotalLabel.textColor = AppColors.textPrimary
        donutTotalLabel.textAlignment = .center
        let donutSubtitle = UILabel.make(S.totalSkus, font: AppFonts.light(AppMetrics.textMicro), color: AppColors.textSecondary, align: .center)
        let centerStack = UIStackView.vertical(spacing: 2, alignment: .center)
        centerStack.addArrangedSubview(donutTotalLabel)
        centerStack.addArrangedSubview(donutSubtitle)

        let donutContainer = UIView()
        donutContainer.addSubviews(donutChart, centerStack)
        centerStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            donutChart.centerXAnchor.constraint(equalTo: donutContainer.centerXAnchor),
            donutChart.centerYAnchor.constraint(equalTo: donutContainer.centerYAnchor),
            centerStack.centerXAnchor.constraint(equalTo: donutContainer.centerXAnchor),
            centerStack.centerYAnchor.constraint(equalTo: donutContainer.centerYAnchor),
            donutContainer.widthAnchor.constraint(equalToConstant: 120),
            donutContainer.heightAnchor.constraint(equalToConstant: 120)
        ])

        let legend = UIStackView.vertical(spacing: 4, alignment: .fill)
        legend.addArrangedSubview(legendRow(color: AppColors.success, title: S.inStock, value: "1,047 (84%)"))
        legend.addArrangedSubview(legendRow(color: AppColors.warning, title: S.lowStock, value: "86 (7%)"))
        legend.addArrangedSubview(legendRow(color: AppColors.danger, title: S.outOfStock, value: "12 (1%)"))

        let chartRow = UIStackView.horizontal(spacing: 16, alignment: .center)
        chartRow.addArrangedSubview(donutContainer)
        chartRow.addArrangedSubview(legend)

        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.forAutoLayout()
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(chartRow)
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))

        let wrapper = UIView()
        wrapper.addSubview(card)
        card.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 12),
            card.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
        ])
        return wrapper
    }

    private func legendRow(color: UIColor, title: String, value: String) -> UIStackView {
        let dot = UIView()
        dot.backgroundColor = color
        dot.layer.cornerRadius = 4
        dot.constrainSize(8)
        let titleLabel = UILabel.make(title, font: AppFonts.regular(AppMetrics.textBodySM), color: AppColors.textSecondary)
        let valueLabel = UILabel.make(value, font: AppFonts.bold(AppMetrics.textBodySM), color: AppColors.textPrimary)
        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.addArrangedSubview(dot)
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(valueLabel)
        return row
    }

    override func loadData() {
        items = MockData.inventory()
        applyFilters()
        renderSummary(total: 1245, low: 86, out: 12)

        ApiClient.shared.getInventorySummary { [weak self] result in
            guard let self = self, case .success(let data) = result, let s = data.summary else { return }
            let total = Int(s.totalUnits ?? 1245)
            let low = s.lowStockCount ?? 86
            let out = s.outOfStockCount ?? 12
            self.renderSummary(total: total, low: low, out: out)
            self.donutTotalLabel.text = self.formatCount(total)
        }
    }

    private func renderSummary(total: Int, low: Int, out: Int) {
        summaryRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        summaryRow.addArrangedSubview(summaryChip(S.totalSkus, formatCount(total), AppColors.purplePrimary, "shippingbox.fill"))
        summaryRow.addArrangedSubview(summaryChip(S.lowStock, formatCount(low), AppColors.warning, "exclamationmark.triangle.fill"))
        summaryRow.addArrangedSubview(summaryChip(S.outOfStock, formatCount(out), AppColors.danger, "xmark.circle.fill"))
        donutTotalLabel.text = formatCount(total)
    }

    private func formatCount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func summaryChip(_ title: String, _ value: String, _ color: UIColor, _ icon: String) -> UIView {
        let card = StyleKit.cardView()
        let titleLabel = UILabel.make(title, font: AppFonts.regular(AppMetrics.textLabel), color: AppColors.textSecondary)
        titleLabel.lineBreakMode = .byTruncatingTail
        let valueLabel = UILabel.make(value, font: AppFonts.bold(AppMetrics.textStatValue), color: color)
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.forAutoLayout()
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20)
        ])
        let valueRow = UIStackView.horizontal(spacing: 4, alignment: .center)
        valueRow.addArrangedSubview(valueLabel)
        valueRow.addArrangedSubview(UIView())
        valueRow.addArrangedSubview(iconView)
        let stack = UIStackView.vertical(spacing: 8, alignment: .leading)
        stack.forAutoLayout()
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(valueRow)
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        return card
    }

    private func applyFilters() {
        var result = items
        switch inventoryTab {
        case 1: result = result.filter { $0.badge == S.lowStock }
        case 2: result = result.filter { $0.badge == S.expired }
        default: break
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                    || $0.sku.localizedCaseInsensitiveContains(searchText)
            }
        }
        filtered = result
        reloadTableRows()
    }

    private func reloadTableRows() {
        tableRowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, item) in filtered.enumerated() {
            tableRowsStack.addArrangedSubview(inventoryTableRow(item, showDivider: index < filtered.count - 1))
        }
    }

    private func inventoryTableRow(_ item: ListItem, showDivider: Bool) -> UIView {
        let container = UIStackView.vertical(spacing: 0, alignment: .fill)
        let row = UIView()
        row.constrainHeight(44)

        let title = UILabel.make(item.title, font: AppFonts.regular(AppMetrics.textMicro), color: AppColors.textPrimary)
        title.lineBreakMode = .byTruncatingTail
        let sku = UILabel.make(item.sku, font: AppFonts.regular(AppMetrics.textMicro), color: AppColors.textSecondary)
        sku.lineBreakMode = .byTruncatingTail
        let stock = UILabel.make("\(item.stockCount)", font: AppFonts.regular(AppMetrics.textMicro), color: AppColors.textPrimary)

        let statusColumn = UIView()
        let outLabel = UILabel.make(
            item.badge == S.expired ? S.expired : S.outLabel,
            font: AppFonts.bold(AppMetrics.textMicro),
            color: AppColors.textSecondary,
            align: .right
        )
        let track = UIView()
        track.backgroundColor = AppColors.borderLight
        track.layer.cornerRadius = 3
        let fill = UIView()
        fill.layer.cornerRadius = 3
        fill.backgroundColor = stockBarColor(for: item.badge)
        track.addSubviews(fill)

        let outOfStock = item.badge == S.outOfStock
        let expired = item.badge == S.expired
        let showBar = !outOfStock && !expired

        statusColumn.addSubviews(track, outLabel)
        track.translatesAutoresizingMaskIntoConstraints = false
        fill.translatesAutoresizingMaskIntoConstraints = false
        outLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            track.leadingAnchor.constraint(equalTo: statusColumn.leadingAnchor),
            track.centerYAnchor.constraint(equalTo: statusColumn.centerYAnchor),
            track.trailingAnchor.constraint(equalTo: outLabel.leadingAnchor, constant: -4),
            track.heightAnchor.constraint(equalToConstant: 6),
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            fill.widthAnchor.constraint(equalTo: track.widthAnchor,
                                        multiplier: CGFloat(max(0.02, min(1, Double(item.stockPercent) / 100)))),
            outLabel.trailingAnchor.constraint(equalTo: statusColumn.trailingAnchor),
            outLabel.centerYAnchor.constraint(equalTo: statusColumn.centerYAnchor)
        ])
        track.isHidden = !showBar
        outLabel.isHidden = showBar

        row.addSubviews(title, sku, stock, statusColumn)
        pinTableColumns(product: title, sku: sku, stock: stock, status: statusColumn, in: row)

        container.addArrangedSubview(row)
        if showDivider { container.addArrangedSubview(ListScreenLayout.hairline()) }
        return container
    }

    private func stockBarColor(for badge: String) -> UIColor {
        switch badge {
        case S.inStock: return AppColors.success
        case S.lowStock: return AppColors.warning
        case S.expired: return AppColors.textSecondary
        default: return AppColors.danger
        }
    }
}
