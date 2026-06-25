import UIKit

/// Order card for the distributor Orders list (port of OrderAdapter + item_order.xml):
/// trader logo/name, order number + placed time, status badge, amount, delivery window,
/// product chips, and the per-status fulfilment actions.
final class OrderListCell: UITableViewCell {

    static let reuseId = "OrderListCell"

    var onView: (() -> Void)?
    var onPrimary: (() -> Void)?
    var onReject: (() -> Void)?

    /// Action key for the primary button (accept/pick/pack/ready/dispatch/deliver), nil when hidden.
    private(set) var primaryAction: String?

    private let card = UIView()
    private let avatar = UILabel()
    private let traderNameLabel = UILabel.make(font: AppFonts.bold(14), color: AppColors.purplePrimary, lines: 1)
    private let orderNumberLabel = UILabel.make(font: AppFonts.regular(12), color: AppColors.textSecondary)
    private let timeLabel = UILabel.make(font: AppFonts.regular(11), color: AppColors.textTertiary)
    private let addressLabel = UILabel.make(font: AppFonts.regular(11), color: AppColors.textSecondary, lines: 2)
    private let amountLabel = UILabel.make(font: AppFonts.bold(16), color: AppColors.textPrimary, align: .right)
    private let statusBadge = StyleKit.badgeLabel()
    private let deliveryLabel = UILabel.make(font: AppFonts.regular(11), color: AppColors.textSecondary, align: .right, lines: 1)
    private let productsLabel = UILabel.make(font: AppFonts.bold(10), color: AppColors.textTertiary)
    private let chipsView = OrderChipsView()

    private let viewButton = OrderListCell.actionButton(title: S.orderActionViewOrder, icon: "eye", color: AppColors.info)
    private let primaryButton = OrderListCell.actionButton(title: S.orderActionAccept, icon: "checkmark", color: AppColors.success)
    private let rejectButton = OrderListCell.actionButton(title: S.orderActionReject, icon: "xmark", color: AppColors.danger)
    private let actionsRow = UIStackView.horizontal(spacing: 8, alignment: .center)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        setupLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupLayout() {
        StyleKit.styleCard(card)
        card.forAutoLayout()
        contentView.addSubview(card)
        card.pinEdges(to: contentView, insets: UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16))

        avatar.font = AppFonts.bold(15)
        avatar.textColor = .white
        avatar.textAlignment = .center
        avatar.layer.cornerRadius = AppMetrics.radiusMD
        avatar.layer.masksToBounds = true
        avatar.constrainSize(44)

        let infoCol = UIStackView.vertical(spacing: 2, alignment: .leading)
        infoCol.addArrangedSubview(traderNameLabel)
        infoCol.addArrangedSubview(orderNumberLabel)
        infoCol.addArrangedSubview(timeLabel)
        infoCol.addArrangedSubview(addressLabel)

        statusBadge.setContentHuggingPriority(.required, for: .horizontal)
        let rightCol = UIStackView.vertical(spacing: 4, alignment: .trailing)
        rightCol.addArrangedSubview(amountLabel)
        rightCol.addArrangedSubview(statusBadge)
        rightCol.addArrangedSubview(deliveryLabel)
        rightCol.setContentHuggingPriority(.required, for: .horizontal)
        rightCol.setContentCompressionResistancePriority(.required, for: .horizontal)

        let headerRow = UIStackView.horizontal(spacing: 10, alignment: .top)
        headerRow.addArrangedSubview(avatar)
        headerRow.addArrangedSubview(infoCol)
        headerRow.addArrangedSubview(rightCol)

        viewButton.addTarget(self, action: #selector(viewTapped), for: .touchUpInside)
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)
        rejectButton.addTarget(self, action: #selector(rejectTapped), for: .touchUpInside)
        actionsRow.distribution = .fillEqually
        actionsRow.addArrangedSubview(viewButton)
        actionsRow.addArrangedSubview(primaryButton)
        actionsRow.addArrangedSubview(rejectButton)

        let divider = ListScreenLayout.hairline()

        let stack = UIStackView.vertical(spacing: 10, alignment: .fill)
        stack.addArrangedSubview(headerRow)
        stack.addArrangedSubview(productsLabel)
        stack.addArrangedSubview(chipsView)
        stack.addArrangedSubview(divider)
        stack.addArrangedSubview(actionsRow)
        stack.setCustomSpacing(4, after: productsLabel)
        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
    }

    func configure(_ order: OrderDTO, currency: String) {
        let name = order.traderName
        traderNameLabel.text = name
        orderNumberLabel.text = order.orderNumber
        timeLabel.text = OrderFormat.createdAt(order.createdAt)
        amountLabel.text = OrderFormat.money(order.amount, currency: currency)

        avatar.text = OrderFormat.initials(name)
        avatar.backgroundColor = OrderFormat.logoColor(order.traderId ?? 0)

        let key = order.resolvedStatusKey
        let color = OrderFormat.statusColor(key)
        statusBadge.text = OrderFormat.humanize(key)
        statusBadge.textColor = color
        statusBadge.backgroundColor = color.withAlphaComponent(0.11)

        let location = order.trader?.location ?? ""
        addressLabel.text = location
        addressLabel.isHidden = location.isEmpty

        deliveryLabel.text = deliveryInfo(order)
        deliveryLabel.isHidden = (deliveryLabel.text ?? "").isEmpty

        let products = order.products ?? []
        productsLabel.text = S.ordersProductsLabel(products.count)
        chipsView.setChips(products)
        chipsView.isHidden = products.isEmpty

        bindActions(key, order: order)
    }

    private func bindActions(_ key: String, order: OrderDTO) {
        var action: String?
        var primaryTitle = ""
        var primaryIcon = "checkmark"
        var showReject = false

        switch key {
        case "pending":
            action = "accept"; primaryTitle = S.orderActionAccept; primaryIcon = "checkmark"; showReject = true
        case "accepted":
            action = "pick"; primaryTitle = S.orderActionPick; primaryIcon = "hand.tap"
        case "picking":
            action = "pack"; primaryTitle = S.orderActionPack; primaryIcon = "shippingbox"
        case "packing":
            action = "ready"; primaryTitle = S.orderActionMarkReady; primaryIcon = "checkmark.seal"
        case "ready_for_delivery":
            action = "dispatch"; primaryTitle = S.orderActionDispatch; primaryIcon = "paperplane"
        case "out_for_delivery":
            action = "deliver"; primaryTitle = S.orderActionDelivered; primaryIcon = "checkmark.circle"
        default:
            action = nil
        }

        primaryAction = action
        if action != nil {
            primaryButton.isHidden = false
            primaryButton.configuration?.title = primaryTitle
            primaryButton.configuration?.image = UIImage(systemName: primaryIcon)
        } else {
            primaryButton.isHidden = true
        }
        rejectButton.isHidden = !showReject
    }

    /// "25 Jun 2026, 08:00–22:00" — delivery date + time window, when present.
    private func deliveryInfo(_ order: OrderDTO) -> String {
        let date = OrderFormat.deliveryDate(order.deliveryDate)
        let start = OrderFormat.trimSeconds(order.deliveryStartTime)
        let end = OrderFormat.trimSeconds(order.deliveryEndTime)
        let window = (!start.isEmpty || !end.isEmpty) ? "\(start)–\(end)" : ""
        if date.isEmpty { return window }
        return window.isEmpty ? date : "\(date), \(window)"
    }

    @objc private func viewTapped() { onView?() }
    @objc private func primaryTapped() { onPrimary?() }
    @objc private func rejectTapped() { onReject?() }

    static func actionButton(title: String, icon: String, color: UIColor) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.image = UIImage(systemName: icon)
        config.imagePadding = 6
        config.baseForegroundColor = color
        config.background.strokeColor = color.withAlphaComponent(0.5)
        config.background.strokeWidth = 1
        config.background.cornerRadius = AppMetrics.radiusSM
        config.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 8, bottom: 9, trailing: 8)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.bold(12); return out
        }
        let button = UIButton(configuration: config)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.8
        return button
    }
}

// MARK: - Wrapping chips container (product pills)

final class OrderChipsView: UIView {

    private var chipViews: [PaddingLabel] = []
    private let hSpacing: CGFloat = 6
    private let vSpacing: CGFloat = 6
    private var lastLayoutWidth: CGFloat = 0

    func setChips(_ titles: [String]) {
        chipViews.forEach { $0.removeFromSuperview() }
        chipViews = titles.map { makeChip($0) }
        chipViews.forEach { addSubview($0) }
        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    private func makeChip(_ text: String) -> PaddingLabel {
        let label = PaddingLabel(insets: UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10))
        label.text = text
        label.font = AppFonts.regular(11)
        label.textColor = AppColors.textPrimary
        label.backgroundColor = AppColors.surfaceVariant
        label.layer.cornerRadius = 12
        label.layer.borderWidth = 1
        label.layer.borderColor = AppColors.border.cgColor
        label.layer.masksToBounds = true
        return label
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.width != lastLayoutWidth {
            lastLayoutWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
        layoutChips(maxWidth: bounds.width, apply: true)
    }

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : (UIScreen.main.bounds.width - 60)
        let height = layoutChips(maxWidth: width, apply: false)
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    @discardableResult
    private func layoutChips(maxWidth: CGFloat, apply: Bool) -> CGFloat {
        guard maxWidth > 0, !chipViews.isEmpty else { return 0 }
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for chip in chipViews {
            let size = chip.intrinsicContentSize
            if x > 0, x + size.width > maxWidth {
                x = 0; y += lineHeight + vSpacing; lineHeight = 0
            }
            if apply { chip.frame = CGRect(x: x, y: y, width: size.width, height: size.height) }
            x += size.width + hSpacing
            lineHeight = max(lineHeight, size.height)
        }
        return y + lineHeight
    }
}

// MARK: - Status tabs with live counts (Order Queue / Accept / …)

final class OrderStatusTabsView: UIView {

    var onSelect: ((Int) -> Void)?

    private let scrollView = UIScrollView()
    private let stack = UIStackView.horizontal(spacing: 20, alignment: .fill)
    private var tabs: [(container: UIControl, label: UILabel, count: PaddingLabel, indicator: UIView)] = []
    private var selectedIndex = 0

    init(titles: [String], selectedIndex: Int) {
        super.init(frame: .zero)
        self.selectedIndex = selectedIndex
        backgroundColor = AppColors.surface
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.forAutoLayout()
        stack.forAutoLayout()
        addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        for (index, title) in titles.enumerated() {
            let tab = makeTab(title, index: index)
            stack.addArrangedSubview(tab.container)
            tabs.append(tab)
        }
        applySelection()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updateCounts(_ counts: [Int]) {
        for (index, value) in counts.enumerated() where index < tabs.count {
            tabs[index].count.text = "\(value)"
        }
    }

    private func makeTab(_ title: String, index: Int) -> (UIControl, UILabel, PaddingLabel, UIView) {
        let container = TabControl()
        container.tag = index
        container.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)

        let label = UILabel.make(title, font: AppFonts.regular(13), color: AppColors.textSecondary, lines: 1)

        let count = PaddingLabel(insets: UIEdgeInsets(top: 1, left: 6, bottom: 1, right: 6))
        count.text = "0"
        count.font = AppFonts.bold(10)
        count.textAlignment = .center
        count.layer.cornerRadius = 9
        count.layer.masksToBounds = true

        let row = UIStackView.horizontal(spacing: 6, alignment: .center)
        row.isUserInteractionEnabled = false
        row.addArrangedSubview(label)
        row.addArrangedSubview(count)
        row.forAutoLayout()

        let indicator = UIView()
        indicator.backgroundColor = OrderFormat.statusColor(nil)
        indicator.layer.cornerRadius = 1.5
        indicator.forAutoLayout()

        container.addSubviews(row, indicator)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            row.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            indicator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            indicator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            indicator.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            indicator.heightAnchor.constraint(equalToConstant: 3)
        ])
        return (container, label, count, indicator)
    }

    @objc private func tabTapped(_ sender: UIControl) {
        guard sender.tag != selectedIndex else {
            onSelect?(sender.tag)
            return
        }
        selectedIndex = sender.tag
        applySelection()
        onSelect?(sender.tag)
    }

    private func applySelection() {
        for (index, tab) in tabs.enumerated() {
            let selected = index == selectedIndex
            tab.label.font = selected ? AppFonts.bold(13) : AppFonts.regular(13)
            tab.label.textColor = selected ? AppColors.purplePrimary : AppColors.textSecondary
            tab.indicator.isHidden = !selected
            tab.indicator.backgroundColor = selected ? AppColors.purplePrimary : .clear
            tab.count.textColor = selected ? AppColors.purplePrimary : AppColors.textSecondary
            tab.count.backgroundColor = selected ? AppColors.purpleLight : AppColors.surfaceVariant
        }
    }
}

/// A UIControl that lets its child stack ignore touches so the whole tab is tappable.
private final class TabControl: UIControl {
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Date range picker sheet (start / end)

final class OrderDateRangeSheet: UIViewController {

    var onApply: ((Date, Date) -> Void)?

    private let fromPicker = UIDatePicker()
    private let toPicker = UIDatePicker()

    init(from: Date, to: Date) {
        super.init(nibName: nil, bundle: nil)
        fromPicker.date = from
        toPicker.date = to
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.surface

        let title = UILabel.make(S.ordersDateRange, font: AppFonts.bold(16), color: AppColors.textPrimary)

        configurePicker(fromPicker)
        configurePicker(toPicker)

        let fromRow = labeledRow("From", picker: fromPicker)
        let toRow = labeledRow("To", picker: toPicker)

        let apply = UIButton(type: .system)
        StyleKit.stylePrimaryButton(apply)
        apply.setTitle("Apply", for: .normal)
        apply.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)

        let cancel = UIButton(type: .system)
        StyleKit.styleOutlinedButton(cancel)
        cancel.setTitle(S.cancel, for: .normal)
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let buttons = UIStackView.horizontal(spacing: 12, alignment: .fill)
        buttons.distribution = .fillEqually
        buttons.addArrangedSubview(cancel)
        buttons.addArrangedSubview(apply)

        let stack = UIStackView.vertical(spacing: 16, alignment: .fill)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(fromRow)
        stack.addArrangedSubview(toRow)
        stack.addArrangedSubview(buttons)
        stack.forAutoLayout()
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func configurePicker(_ picker: UIDatePicker) {
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .compact
        picker.timeZone = TimeZone(identifier: "UTC")
    }

    private func labeledRow(_ text: String, picker: UIDatePicker) -> UIView {
        let label = UILabel.make(text, font: AppFonts.medium(14), color: AppColors.textSecondary)
        label.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        let spacer = UIView()
        row.addArrangedSubview(label)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(picker)
        return row
    }

    @objc private func applyTapped() {
        var start = fromPicker.date
        var end = toPicker.date
        if start > end { swap(&start, &end) }
        onApply?(start, end)
        dismiss(animated: true)
    }

    @objc private func cancelTapped() { dismiss(animated: true) }
}
