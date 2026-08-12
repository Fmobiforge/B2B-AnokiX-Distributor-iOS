import UIKit

/// Inventory item drawer: the product's stock facts (Details) and its ledger (History),
/// ported from the web side panel (New-Design/Inventory 2 & 3).
final class InventoryDetailViewController: BaseSecondaryViewController {

    override var screenTitle: String { row.name ?? S.inventoryOverview }

    private let row: InventoryPageData.Row
    private let startOnHistory: Bool
    private static let breakdownKeys = ["Available", "Reserved", "Packed", "Damaged", "Expired"]

    private let detailsPane = UIStackView.vertical(spacing: 16, alignment: .fill)
    private let historyPane = UIStackView.vertical(spacing: 10, alignment: .fill)
    private let historyEmpty = UILabel.make("No stock movements recorded yet.",
                                            font: AppFonts.regular(AppMetrics.textBody),
                                            color: AppColors.textSecondary, align: .center, lines: 0)
    private var tabBar: UnderlineTabBar!
    private var historyLoaded = false

    init(row: InventoryPageData.Row, startOnHistory: Bool) {
        self.row = row
        self.startOnHistory = startOnHistory
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func setupContent(in container: UIView) {
        tabBar = UnderlineTabBar(titles: ["Details", "History"],
                                 selectedIndex: startOnHistory ? 1 : 0) { [weak self] index in
            self?.showTab(history: index == 1)
        }
        tabBar.constrainHeight(44)

        let chrome = ListScreenLayout.surfaceSection([tabBar], spacing: 0,
                                                     insets: UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0))

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.backgroundColor = AppColors.background
        scroll.forAutoLayout()

        let content = UIStackView.vertical(spacing: 0, alignment: .fill)
        content.addArrangedSubview(detailsPane)
        content.addArrangedSubview(historyPane)
        content.addArrangedSubview(historyEmpty)
        content.forAutoLayout()
        scroll.addSubview(content)

        historyEmpty.isHidden = true
        buildDetails()

        _ = embedSecondaryListChrome(in: container, chrome: chrome, listView: scroll)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
            content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24)
        ])

        showTab(history: startOnHistory)
    }

    // MARK: Details

    private func buildDetails() {
        let card = StyleKit.cardView()
        let rows = UIStackView.vertical(spacing: 0, alignment: .fill)
        rows.forAutoLayout()

        let entries: [(String, String?)] = [
            ("SKU", row.sku),
            ("Barcode", row.barcode),
            ("Category", row.category),
            ("Brand", row.brand),
            ("Warehouse", row.warehouse),
            ("Units on hand", format(row.unitsOnHand)),
            ("Stock value", "R" + format(Int64(row.stockValue ?? 0))),
            ("Batch", row.batchNumber),
            ("Expires", row.expiryDate),
            ("Last updated", row.updatedAt)
        ]
        for (index, entry) in entries.enumerated() {
            if index > 0 { rows.addArrangedSubview(ListScreenLayout.hairline()) }
            rows.addArrangedSubview(detailRow(entry.0, entry.1))
        }
        card.addSubview(rows)
        rows.pinEdges(to: card, insets: UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12))
        detailsPane.addArrangedSubview(card)

        detailsPane.addArrangedSubview(UILabel.make("Where those units sit",
                                                    font: AppFonts.bold(AppMetrics.textTitle),
                                                    color: AppColors.textPrimary))

        let chips = UIStackView.horizontal(spacing: 8, alignment: .fill)
        for key in Self.breakdownKeys {
            chips.addArrangedSubview(breakdownChip(key, row.breakdownValue(key)))
        }
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        chips.forAutoLayout()
        scroll.addSubview(chips)
        scroll.forAutoLayout()
        NSLayoutConstraint.activate([
            chips.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            chips.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            chips.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            chips.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            chips.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
        detailsPane.addArrangedSubview(scroll)
    }

    private func detailRow(_ label: String, _ value: String?) -> UIView {
        let title = UILabel.make(label, font: AppFonts.regular(AppMetrics.textBody),
                                 color: AppColors.textSecondary)
        let display = (value?.isEmpty == false && value != "null") ? value! : "—"
        let detail = UILabel.make(display, font: AppFonts.bold(AppMetrics.textBody),
                                  color: AppColors.textPrimary, align: .right, lines: 0)
        detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        row.addArrangedSubview(title)
        row.addArrangedSubview(detail)
        return row
    }

    private func breakdownChip(_ title: String, _ value: Int) -> UIView {
        let card = StyleKit.cardView()
        let valueLabel = UILabel.make(format(Int64(value)), font: AppFonts.bold(18),
                                      color: AppColors.textPrimary)
        let titleLabel = UILabel.make(title, font: AppFonts.light(AppMetrics.textCaption),
                                      color: AppColors.textSecondary)
        let stack = UIStackView.vertical(spacing: 2, alignment: .leading)
        stack.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(titleLabel)
        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14))
        card.widthAnchor.constraint(equalToConstant: 96).isActive = true
        return card
    }

    // MARK: History

    private func showTab(history: Bool) {
        detailsPane.isHidden = history
        historyPane.isHidden = !history
        historyEmpty.isHidden = !history || !historyPane.arrangedSubviews.isEmpty
        if history && !historyLoaded { loadHistory() }
    }

    private func loadHistory() {
        historyLoaded = true
        ApiClient.shared.getStockHistory(productId: String(row.productId ?? 0)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                self.renderHistory(data.movements ?? [])
            case .failure(let error):
                self.historyLoaded = false
                self.toast(error.message)
            }
        }
    }

    private func renderHistory(_ movements: [StockMovement]) {
        historyPane.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for movement in movements {
            historyPane.addArrangedSubview(historyCard(movement))
        }
        // Only surfaces on the History tab, and only when the ledger came back empty.
        historyEmpty.isHidden = !movements.isEmpty || historyPane.isHidden
    }

    private func historyCard(_ movement: StockMovement) -> UIView {
        let card = StyleKit.cardView()

        let type = PaddingLabel(insets: UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
        StyleKit.styleBadge(type)
        type.text = movement.movementLabel
        type.font = AppFonts.regular(AppMetrics.textMicro)
        type.textColor = AppColors.success
        type.backgroundColor = AppColors.successBg
        type.setContentHuggingPriority(.required, for: .horizontal)

        let units = UILabel.make(movement.quantity ?? "—", font: AppFonts.bold(AppMetrics.textTitle),
                                 color: AppColors.textPrimary, align: .right)

        let top = UIStackView.horizontal(spacing: 8, alignment: .center)
        top.addArrangedSubview(type)
        top.addArrangedSubview(UIView())
        top.addArrangedSubview(units)

        let when = UILabel.make(join(movement.createdAt, movement.warehouseName),
                                font: AppFonts.regular(AppMetrics.textCaption),
                                color: AppColors.textSecondary, lines: 0)

        let stack = UIStackView.vertical(spacing: 6, alignment: .fill)
        stack.addArrangedSubview(top)
        stack.addArrangedSubview(when)

        let note = join(movement.notes, movement.userEmail)
        if !note.isEmpty {
            stack.addArrangedSubview(UILabel.make(note, font: AppFonts.light(AppMetrics.textCaption),
                                                  color: AppColors.textTertiary, lines: 0))
        }
        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        return card
    }

    private func join(_ first: String?, _ second: String?) -> String {
        [first, second]
            .compactMap { ($0?.isEmpty == false && $0 != "null") ? $0 : nil }
            .joined(separator: "  ·  ")
    }

    private func format(_ value: Int64) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }
}
