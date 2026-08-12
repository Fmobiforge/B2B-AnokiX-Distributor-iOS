import UIKit

/// Scrolling header of the Inventory list: page title, KPI cards, the stock-mix donut and
/// the empty-state line (item_inventory_summary.xml on Android).
///
/// It rides inside the collection view so the stock cards always own the remaining
/// height — a fixed summary left nothing to scroll on short screens.
final class InventorySummaryHeaderView: UICollectionReusableView {

    static let reuseIdentifier = "InventorySummaryHeaderView"

    private let stockValueCard = InventoryKpiCard(
        title: "Total Stock Value", icon: "ic_package", tint: AppColors.purplePrimary,
        tile: AppColors.purpleLight, caption: "On-hand cost value")
    private let unitsCard = InventoryKpiCard(
        title: "Total Units in Stock", icon: "ic_inventory", tint: AppColors.success,
        tile: AppColors.successBg, caption: "Sellable units")
    private let lowCard = InventoryKpiCard(
        title: "Low Stock Items", icon: "ic_warning_box", tint: AppColors.warning,
        tile: AppColors.warningBg, caption: "At or below reorder level")
    private let outCard = InventoryKpiCard(
        title: "Out of Stock Items", icon: "ic_cancel_circle", tint: AppColors.danger,
        tile: AppColors.dangerBg, caption: "Nothing on hand")
    private let movementsCard = InventoryKpiCard(
        title: "Stock Movement", icon: "ic_finance_report", tint: AppColors.info,
        tile: AppColors.infoBg, caption: "Last 7 days")

    private let donutChart = DonutChartView()
    private let donutLegend = UIStackView.vertical(spacing: 3, alignment: .fill)
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

        let title = UILabel.make(S.inventoryOverview, font: AppFonts.bold(AppMetrics.textHeadline),
                                 color: AppColors.textPrimary)
        let subtitle = UILabel.make(S.inventorySubtitle, font: AppFonts.light(AppMetrics.textCaption),
                                    color: AppColors.textSecondary, lines: 0)

        let kpiRow = UIStackView.horizontal(spacing: 8, alignment: .fill)
        [stockValueCard, unitsCard, lowCard, outCard, movementsCard].forEach { kpiRow.addArrangedSubview($0) }
        let kpiScroll = UIScrollView()
        kpiScroll.showsHorizontalScrollIndicator = false
        kpiScroll.clipsToBounds = false
        kpiRow.forAutoLayout()
        kpiScroll.addSubview(kpiRow)
        kpiScroll.forAutoLayout()
        NSLayoutConstraint.activate([
            kpiRow.topAnchor.constraint(equalTo: kpiScroll.contentLayoutGuide.topAnchor),
            kpiRow.leadingAnchor.constraint(equalTo: kpiScroll.contentLayoutGuide.leadingAnchor),
            kpiRow.trailingAnchor.constraint(equalTo: kpiScroll.contentLayoutGuide.trailingAnchor),
            kpiRow.bottomAnchor.constraint(equalTo: kpiScroll.contentLayoutGuide.bottomAnchor),
            kpiRow.heightAnchor.constraint(equalTo: kpiScroll.frameLayoutGuide.heightAnchor)
        ])

        donutChart.forAutoLayout()
        donutChart.strokeWidth = 11
        NSLayoutConstraint.activate([
            donutChart.widthAnchor.constraint(equalToConstant: 104),
            donutChart.heightAnchor.constraint(equalToConstant: 104)
        ])
        let donutRow = UIStackView.horizontal(spacing: 16, alignment: .center)
        donutRow.addArrangedSubview(donutChart)
        donutRow.addArrangedSubview(donutLegend)

        let donutCard = StyleKit.cardView()
        let donutStack = UIStackView.vertical(spacing: 12, alignment: .fill)
        donutStack.addArrangedSubview(UILabel.make("Inventory Summary",
                                                   font: AppFonts.bold(AppMetrics.textTitle),
                                                   color: AppColors.topTitle))
        donutStack.addArrangedSubview(donutRow)
        donutStack.forAutoLayout()
        donutCard.addSubview(donutStack)
        donutStack.pinEdges(to: donutCard, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))

        emptyLabel.isHidden = true

        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(kpiScroll)
        stack.addArrangedSubview(donutCard)
        stack.addArrangedSubview(emptyLabel)
        stack.setCustomSpacing(2, after: title)
        stack.setCustomSpacing(24, after: donutCard)
        stack.forAutoLayout()
        addSubview(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0))
    }

    func configure(summary: InventorySummaryData.Summary?,
                   chart: [InventoryPageData.ChartSlice],
                   emptyMessage: String?) {
        let units = summary?.totalUnits ?? 0
        stockValueCard.set("R" + format(Int64(summary?.totalStockValue ?? 0)))
        unitsCard.set(format(units))
        lowCard.set("\(summary?.lowStockCount ?? 0)")
        outCard.set("\(summary?.outOfStockCount ?? 0)")
        movementsCard.set("\(summary?.movementsThisWeek ?? 0)")

        // The donut hole carries the headline number the cards break down.
        donutChart.setCenterText(main: format(units), sub: "units")
        bindDonut(chart)

        emptyLabel.text = emptyMessage
        emptyLabel.isHidden = emptyMessage?.isEmpty != false
    }

    /// Donut + legend from the chart slices the API returns (In Stock / Low / Out / Damaged).
    private func bindDonut(_ chart: [InventoryPageData.ChartSlice]) {
        donutLegend.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let total = chart.reduce(0) { $0 + max(0, $1.value ?? 0) }
        guard !chart.isEmpty, total > 0 else {
            donutChart.setData(values: [1], colors: [AppColors.border])
            return
        }
        donutChart.setData(values: chart.map { CGFloat(max(0, $0.value ?? 0)) },
                           colors: chart.map { UIColor.fromHexString($0.color, fallback: AppColors.purplePrimary) })
        for slice in chart {
            let percent = Int(((slice.value ?? 0) / total * 100).rounded())
            donutLegend.addArrangedSubview(legendRow(
                color: UIColor.fromHexString(slice.color, fallback: AppColors.purplePrimary),
                title: slice.type ?? "", value: "\(percent)%"))
        }
    }

    private func legendRow(color: UIColor, title: String, value: String) -> UIView {
        let dot = UIView()
        dot.backgroundColor = color
        dot.layer.cornerRadius = 4
        dot.constrainSize(8)
        let titleLabel = UILabel.make(title, font: AppFonts.regular(AppMetrics.textBodySM),
                                      color: AppColors.textSecondary)
        let valueLabel = UILabel.make(value, font: AppFonts.bold(AppMetrics.textBodySM),
                                      color: AppColors.textPrimary)
        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.addArrangedSubview(dot)
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(valueLabel)
        return row
    }

    private func format(_ value: Int64) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }
}
