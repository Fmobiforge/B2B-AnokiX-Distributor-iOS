import UIKit

/// Inventory item drawer: a stock summary with the adjust / transfer actions, the product's
/// facts (Details) and its ledger (History) — the mobile take on the web side panel
/// (New-Design/Inventory 2 & 3).
final class InventoryDetailViewController: BaseSecondaryViewController {

    override var screenTitle: String { "Stock item" }

    /// Fired when an adjust / transfer changed the numbers, so the list can reload.
    var onStockChanged: (() -> Void)?

    private var row: InventoryPageData.Row
    private var warehouses: [InventoryPageData.Warehouse]
    private let startOnHistory: Bool

    private static let breakdown: [(key: String, color: UIColor)] = [
        ("Available", AppColors.success),
        ("Reserved", AppColors.info),
        ("Packed", AppColors.purplePrimary),
        ("Damaged", AppColors.warning),
        ("Expired", AppColors.danger)
    ]

    private let heroSwatch = UIView()
    private let heroName = UILabel()
    private let heroMeta = UILabel()
    private let heroBadge = PaddingLabel(insets: UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
    private let heroUnits = UILabel()
    private let heroValue = UILabel()
    private let factsStack = UIStackView.vertical(spacing: 0, alignment: .fill)
    private let breakdownStack = UIStackView.horizontal(spacing: 8, alignment: .fill)
    private let detailsPane = UIStackView.vertical(spacing: 16, alignment: .fill)
    private let historyPane = UIStackView.vertical(spacing: 10, alignment: .fill)
    private let historyEmpty = UILabel.make("No stock movements recorded yet.",
                                            font: AppFonts.regular(AppMetrics.textBody),
                                            color: AppColors.textSecondary, align: .center, lines: 0)
    private var historyLoaded = false

    init(row: InventoryPageData.Row, warehouses: [InventoryPageData.Warehouse], startOnHistory: Bool) {
        self.row = row
        self.warehouses = warehouses
        self.startOnHistory = startOnHistory
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func setupContent(in container: UIView) {
        let tabs = UnderlineTabBar(titles: ["Details", "History"],
                                   selectedIndex: startOnHistory ? 1 : 0) { [weak self] index in
            self?.showTab(history: index == 1)
        }
        tabs.constrainHeight(44)
        let chrome = ListScreenLayout.surfaceSection([tabs], spacing: 0,
                                                     insets: UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0))

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.backgroundColor = AppColors.background
        scroll.forAutoLayout()

        let content = UIStackView.vertical(spacing: 14, alignment: .fill)
        content.addArrangedSubview(buildHero())
        content.addArrangedSubview(detailsPane)
        content.addArrangedSubview(historyPane)
        content.addArrangedSubview(historyEmpty)
        content.forAutoLayout()
        scroll.addSubview(content)

        historyEmpty.isHidden = true
        buildDetails()
        render()

        _ = embedSecondaryListChrome(in: container, chrome: chrome, listView: scroll)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
            content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24)
        ])

        showTab(history: startOnHistory)
    }

    // MARK: Hero

    private func buildHero() -> UIView {
        let card = StyleKit.cardView()

        heroSwatch.layer.cornerRadius = AppMetrics.radiusMD
        heroSwatch.forAutoLayout()
        let swatchIcon = UIImageView(image: AppIcons.symbol("ic_package"))
        swatchIcon.tintColor = .white
        swatchIcon.contentMode = .scaleAspectFit
        swatchIcon.forAutoLayout()
        heroSwatch.addSubview(swatchIcon)

        heroName.font = AppFonts.bold(AppMetrics.textTitle)
        heroName.textColor = AppColors.topTitle
        heroName.numberOfLines = 2
        heroMeta.font = AppFonts.regular(AppMetrics.textCaption)
        heroMeta.textColor = AppColors.textSecondary

        StyleKit.styleBadge(heroBadge)
        heroBadge.font = AppFonts.bold(AppMetrics.textMicro)
        heroBadge.setContentHuggingPriority(.required, for: .horizontal)

        let titleStack = UIStackView.vertical(spacing: 2, alignment: .leading)
        titleStack.addArrangedSubview(heroName)
        titleStack.addArrangedSubview(heroMeta)

        let headerRow = UIStackView.horizontal(spacing: 12, alignment: .center)
        headerRow.addArrangedSubview(heroSwatch)
        headerRow.addArrangedSubview(titleStack)
        headerRow.addArrangedSubview(heroBadge)

        heroUnits.font = AppFonts.bold(AppMetrics.textHeadline)
        heroUnits.textColor = AppColors.textPrimary
        heroValue.font = AppFonts.bold(AppMetrics.textHeadline)
        heroValue.textColor = AppColors.purplePrimary

        let statsRow = UIStackView.horizontal(spacing: 12, alignment: .fill)
        statsRow.distribution = .fillEqually
        statsRow.addArrangedSubview(statColumn("On hand", value: heroUnits))
        statsRow.addArrangedSubview(statColumn("Stock value", value: heroValue))

        let adjust = UIButton(type: .system)
        adjust.setTitle("Adjust Stock", for: .normal)
        StyleKit.styleOutlinedButton(adjust, fontSize: AppMetrics.textBodySM)
        adjust.constrainHeight(42)
        adjust.addTarget(self, action: #selector(adjustTapped), for: .touchUpInside)

        let transfer = UIButton(type: .system)
        transfer.setTitle("Transfer", for: .normal)
        StyleKit.stylePrimaryButton(transfer, fontSize: AppMetrics.textBodySM)
        transfer.constrainHeight(42)
        transfer.addTarget(self, action: #selector(transferTapped), for: .touchUpInside)

        let buttons = UIStackView.horizontal(spacing: 10, alignment: .fill)
        buttons.distribution = .fillEqually
        buttons.addArrangedSubview(adjust)
        buttons.addArrangedSubview(transfer)

        let stack = UIStackView.vertical(spacing: 14, alignment: .fill)
        stack.addArrangedSubview(headerRow)
        stack.addArrangedSubview(ListScreenLayout.hairline())
        stack.addArrangedSubview(statsRow)
        stack.addArrangedSubview(buttons)
        stack.setCustomSpacing(12, after: statsRow)
        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))

        NSLayoutConstraint.activate([
            heroSwatch.widthAnchor.constraint(equalToConstant: 44),
            heroSwatch.heightAnchor.constraint(equalToConstant: 44),
            swatchIcon.centerXAnchor.constraint(equalTo: heroSwatch.centerXAnchor),
            swatchIcon.centerYAnchor.constraint(equalTo: heroSwatch.centerYAnchor),
            swatchIcon.widthAnchor.constraint(equalToConstant: 20),
            swatchIcon.heightAnchor.constraint(equalToConstant: 20)
        ])
        return card
    }

    private func statColumn(_ title: String, value: UILabel) -> UIView {
        let label = UILabel()
        label.attributedText = NSAttributedString(string: title.uppercased(), attributes: [
            .font: AppFonts.regular(AppMetrics.textMicro),
            .foregroundColor: AppColors.textTertiary,
            .kern: 0.6
        ])
        let column = UIStackView.vertical(spacing: 2, alignment: .leading)
        column.addArrangedSubview(label)
        column.addArrangedSubview(value)
        return column
    }

    private func render() {
        heroSwatch.backgroundColor = UIColor.fromHexString(row.imageColor, fallback: AppColors.purplePrimary)
        heroName.text = row.name
        heroMeta.text = join(row.sku, row.brand)
        heroUnits.text = format(row.unitsOnHand)
        heroValue.text = "R" + format(Int64(row.stockValue ?? 0))

        heroBadge.text = row.statusLabel
        if row.isOutOfStock {
            heroBadge.textColor = AppColors.danger; heroBadge.backgroundColor = AppColors.dangerBg
        } else if row.isLowStock {
            heroBadge.textColor = AppColors.warning; heroBadge.backgroundColor = AppColors.warningBg
        } else {
            heroBadge.textColor = AppColors.success; heroBadge.backgroundColor = AppColors.successBg
        }

        buildFacts()
        buildBreakdown()
    }

    // MARK: Details

    private func buildDetails() {
        detailsPane.addArrangedSubview(sectionTitle("Product facts"))
        let card = StyleKit.cardView()
        factsStack.forAutoLayout()
        card.addSubview(factsStack)
        factsStack.pinEdges(to: card, insets: UIEdgeInsets(top: 2, left: 14, bottom: 2, right: 14))
        detailsPane.addArrangedSubview(card)
        detailsPane.setCustomSpacing(8, after: detailsPane.arrangedSubviews[0])

        detailsPane.addArrangedSubview(sectionTitle("Where those units sit"))
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        breakdownStack.forAutoLayout()
        scroll.addSubview(breakdownStack)
        scroll.forAutoLayout()
        NSLayoutConstraint.activate([
            breakdownStack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            breakdownStack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            breakdownStack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            breakdownStack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            breakdownStack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
        detailsPane.addArrangedSubview(scroll)
        detailsPane.setCustomSpacing(8, after: detailsPane.arrangedSubviews[2])
    }

    private func sectionTitle(_ text: String) -> UILabel {
        UILabel.make(text, font: AppFonts.bold(AppMetrics.textTitle), color: AppColors.textPrimary)
    }

    private func buildFacts() {
        factsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let entries: [(String, String?)] = [
            ("SKU", row.sku),
            ("Barcode", row.barcode),
            ("Category", row.category),
            ("Brand", row.brand),
            ("Warehouse", row.warehouse),
            ("Batch", row.batchNumber),
            ("Expires", row.expiryDate),
            ("Last updated", row.updatedAt)
        ]
        for (index, entry) in entries.enumerated() {
            if index > 0 { factsStack.addArrangedSubview(ListScreenLayout.hairline()) }
            factsStack.addArrangedSubview(factRow(entry.0, entry.1))
        }
    }

    private func factRow(_ label: String, _ value: String?) -> UIView {
        let title = UILabel.make(label, font: AppFonts.regular(AppMetrics.textBody),
                                 color: AppColors.textSecondary)
        let display = (value?.isEmpty == false && value != "null") ? value! : "—"
        let detail = UILabel.make(display, font: AppFonts.bold(AppMetrics.textBody),
                                  color: AppColors.textPrimary, align: .right, lines: 0)
        detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 13, left: 0, bottom: 13, right: 0)
        row.addArrangedSubview(title)
        row.addArrangedSubview(detail)
        return row
    }

    /// "Where those units sit" — one colour-coded chip per inventory bucket.
    private func buildBreakdown() {
        breakdownStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for bucket in Self.breakdown {
            let value = row.breakdownValue(bucket.key)
            let card = StyleKit.cardView()

            let dot = UIView()
            dot.backgroundColor = bucket.color
            dot.layer.cornerRadius = 4
            dot.constrainSize(8)
            let name = UILabel.make(bucket.key, font: AppFonts.light(AppMetrics.textLabel),
                                    color: AppColors.textSecondary)
            let header = UIStackView.horizontal(spacing: 6, alignment: .center)
            header.addArrangedSubview(dot)
            header.addArrangedSubview(name)

            let count = UILabel.make(format(Int64(value)), font: AppFonts.bold(18),
                                     color: value > 0 ? AppColors.textPrimary : AppColors.textTertiary)

            let stack = UIStackView.vertical(spacing: 4, alignment: .leading)
            stack.addArrangedSubview(header)
            stack.addArrangedSubview(count)
            stack.forAutoLayout()
            card.addSubview(stack)
            stack.pinEdges(to: card, insets: UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
            card.widthAnchor.constraint(equalToConstant: 104).isActive = true
            breakdownStack.addArrangedSubview(card)
        }
    }

    // MARK: Stock actions

    @objc private func adjustTapped() {
        StockActionSheets.showAdjustStock(from: self, row: row) { [weak self] message in
            self?.stockChanged(message)
        }
    }

    @objc private func transferTapped() {
        StockActionSheets.showTransfer(from: self, row: row, warehouses: warehouses) { [weak self] message in
            self?.stockChanged(message)
        }
    }

    /// Reloads the row from the page API so the drawer shows the post-change numbers.
    private func stockChanged(_ message: String) {
        if !message.isEmpty { toast(message) }
        onStockChanged?()
        ApiClient.shared.getInventoryPage { [weak self] result in
            guard let self = self, case .success(let data) = result else { return }
            if let updated = (data.rows ?? []).first(where: { $0.productId == self.row.productId }) {
                self.row = updated
            }
            self.warehouses = data.warehouses ?? self.warehouses
            self.render()
            self.historyLoaded = false
            if !self.historyPane.isHidden { self.loadHistory() }
        }
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
        let color = movementColor(movement)

        let dot = UIView()
        dot.backgroundColor = color
        dot.layer.cornerRadius = 4
        dot.constrainSize(8)
        let dotHolder = UIView()
        dot.forAutoLayout()
        dotHolder.addSubview(dot)
        NSLayoutConstraint.activate([
            dotHolder.widthAnchor.constraint(equalToConstant: 8),
            dot.topAnchor.constraint(equalTo: dotHolder.topAnchor, constant: 5),
            dot.leadingAnchor.constraint(equalTo: dotHolder.leadingAnchor),
            dot.trailingAnchor.constraint(equalTo: dotHolder.trailingAnchor)
        ])

        let type = UILabel.make(movement.movementLabel, font: AppFonts.bold(AppMetrics.textBody),
                                color: AppColors.textPrimary)
        let units = UILabel.make(signedQuantity(movement), font: AppFonts.bold(AppMetrics.textTitle),
                                 color: color, align: .right)
        units.setContentHuggingPriority(.required, for: .horizontal)

        let top = UIStackView.horizontal(spacing: 8, alignment: .center)
        top.addArrangedSubview(type)
        top.addArrangedSubview(UIView())
        top.addArrangedSubview(units)

        let body = UIStackView.vertical(spacing: 4, alignment: .fill)
        body.addArrangedSubview(top)
        body.addArrangedSubview(UILabel.make(join(movement.createdAt, movement.warehouseName),
                                             font: AppFonts.regular(AppMetrics.textCaption),
                                             color: AppColors.textSecondary, lines: 0))
        let note = join(movement.notes, movement.userEmail)
        if !note.isEmpty {
            body.addArrangedSubview(UILabel.make(note, font: AppFonts.light(AppMetrics.textCaption),
                                                 color: AppColors.textTertiary, lines: 0))
        }

        let row = UIStackView.horizontal(spacing: 10, alignment: .fill)
        row.addArrangedSubview(dotHolder)
        row.addArrangedSubview(body)
        row.forAutoLayout()
        card.addSubview(row)
        row.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14))
        return card
    }

    private func movementColor(_ movement: StockMovement) -> UIColor {
        let type = (movement.movementType ?? "").lowercased()
        if type.contains("receive") || type.contains("in") { return AppColors.success }
        if type.contains("transfer") { return AppColors.purplePrimary }
        if type.contains("damage") || type.contains("expire") || type.contains("out") { return AppColors.danger }
        return AppColors.info
    }

    /// Receipts read as "+10", write-offs as "-10", everything else plain.
    private func signedQuantity(_ movement: StockMovement) -> String {
        let quantity = (movement.quantity ?? "0").trimmingCharacters(in: .whitespaces)
        let type = (movement.movementType ?? "").lowercased()
        if quantity.hasPrefix("-") || quantity.hasPrefix("+") { return quantity }
        if type.contains("receive") || type.hasSuffix("_in") { return "+" + quantity }
        if type.hasSuffix("_out") || type.contains("damage") || type.contains("expire") { return "-" + quantity }
        return quantity
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
