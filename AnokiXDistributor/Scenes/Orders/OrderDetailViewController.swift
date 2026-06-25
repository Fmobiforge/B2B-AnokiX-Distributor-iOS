import UIKit

/// Order detail / tracking screen (port of OrderDetailActivity): an order header, a vertical
/// status timeline (Order Placed → Accepted → … → Delivered, or a cancelled/failed note),
/// the trader details, and the ordered items with a subtotal/total. Fetched by id from
/// `api/distributor/orders/get-by-id`.
final class OrderDetailViewController: BaseSecondaryViewController {

    private static let stageKeys = [
        "pending", "accepted", "picking", "packing", "ready_for_delivery",
        "out_for_delivery", "delivered"
    ]
    private static let stageLabels = [
        "Order Placed", "Accepted", "Picking", "Packing", "Ready for Delivery",
        "Out for Delivery", "Delivered"
    ]

    override var screenTitle: String { S.orderDetails }

    private let orderId: String
    private let currency = "R"
    private var traderPhone: String?

    private var contentStack: UIStackView!
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var imageTasks: [URLSessionDataTask] = []

    init(orderId: String) {
        self.orderId = orderId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func setupContent(in container: UIView) {
        contentStack = makeScrollStack(in: container, spacing: 14)
        spinner.hidesWhenStopped = true
        spinner.forAutoLayout()
        container.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
    }

    override func loadData() {
        spinner.startAnimating()
        ApiClient.shared.getOrderById(id: orderId) { [weak self] result in
            guard let self = self else { return }
            self.spinner.stopAnimating()
            switch result {
            case .success(let data):
                guard let order = data.order else {
                    self.toast(S.orderLoadFailed)
                    self.navigationController?.popViewController(animated: true)
                    return
                }
                self.bind(order)
            case .failure(let error):
                self.toast(error.message.isEmpty ? S.orderLoadFailed : error.message)
                self.navigationController?.popViewController(animated: true)
            }
        }
    }

    private func bind(_ order: OrderDTO) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        contentStack.addArrangedSubview(buildHeaderCard(order))
        contentStack.addArrangedSubview(buildTrackingCard(order))
        contentStack.addArrangedSubview(buildTraderCard(order))
        contentStack.addArrangedSubview(buildItemsCard(order))
        if let notes = order.notes, !notes.trimmingCharacters(in: .whitespaces).isEmpty {
            let note = UILabel.make("Note: \(notes)", font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 0)
            contentStack.addArrangedSubview(note)
        }
    }

    // MARK: - Header

    private func buildHeaderCard(_ order: OrderDTO) -> UIView {
        let card = StyleKit.cardView()
        let name = order.traderName

        let avatar = UILabel()
        avatar.text = name.isEmpty ? "?" : String(name.prefix(1)).uppercased()
        avatar.font = AppFonts.bold(16)
        avatar.textColor = .white
        avatar.textAlignment = .center
        avatar.backgroundColor = OrderFormat.logoColor(order.traderId ?? 0)
        avatar.layer.cornerRadius = AppMetrics.radiusMD
        avatar.layer.masksToBounds = true
        avatar.constrainSize(44)

        let orderNumber = UILabel.make(order.orderNumber, font: AppFonts.bold(16), color: AppColors.textPrimary)
        let status = StyleKit.badgeLabel()
        let color = OrderFormat.statusColor(order.resolvedStatusKey)
        status.text = OrderFormat.humanize(order.resolvedStatusKey)
        status.textColor = color
        status.backgroundColor = color.withAlphaComponent(0.11)
        status.setContentHuggingPriority(.required, for: .horizontal)

        let titleRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        titleRow.addArrangedSubview(orderNumber)
        titleRow.addArrangedSubview(status)
        let traderLabel = UILabel.make(name, font: AppFonts.regular(13), color: AppColors.textSecondary, lines: 1)
        let infoCol = UIStackView.vertical(spacing: 4, alignment: .leading)
        infoCol.addArrangedSubview(titleRow)
        infoCol.addArrangedSubview(traderLabel)

        let amount = UILabel.make(OrderFormat.money(order.amount, currency: currency),
                                  font: AppFonts.bold(18), color: AppColors.purplePrimary, align: .right)
        let itemsCount = UILabel.make(S.ordersItemsCount(order.itemCount ?? 0),
                                      font: AppFonts.regular(12), color: AppColors.textSecondary, align: .right)
        let rightCol = UIStackView.vertical(spacing: 2, alignment: .trailing)
        rightCol.addArrangedSubview(amount)
        rightCol.addArrangedSubview(itemsCount)
        rightCol.setContentHuggingPriority(.required, for: .horizontal)
        rightCol.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.addArrangedSubview(avatar)
        row.addArrangedSubview(infoCol)
        row.addArrangedSubview(rightCol)
        row.forAutoLayout()
        card.addSubview(row)
        row.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return card
    }

    // MARK: - Tracking timeline

    private func buildTrackingCard(_ order: OrderDTO) -> UIView {
        let card = StyleKit.cardView()

        let title = UILabel.make(S.orderTracking, font: AppFonts.bold(14), color: AppColors.textPrimary)
        let live = UILabel.make("● \(S.liveUpdates)", font: AppFonts.medium(12), color: AppColors.success)
        live.setContentHuggingPriority(.required, for: .horizontal)
        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        let spacer = UIView()
        header.addArrangedSubview(title)
        header.addArrangedSubview(spacer)
        header.addArrangedSubview(live)

        let timeline = UIStackView.vertical(spacing: 0, alignment: .fill)
        buildTimeline(into: timeline, order: order)

        let stack = UIStackView.vertical(spacing: 14, alignment: .fill)
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(timeline)
        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return card
    }

    private func buildTimeline(into timeline: UIStackView, order: OrderDTO) {
        let statusKey = order.resolvedStatusKey
        let cancelled = statusKey == "cancelled" || statusKey == "failed"
        let currentIndex = indexOf(statusKey)

        if cancelled {
            timeline.addArrangedSubview(stageRow(label: Self.stageLabels[0], subtitle: stageSubtitle(0, order),
                                                 caption: nil, done: true, current: false, hasLine: true, lineDone: true))
            let failed = statusKey == "failed"
            timeline.addArrangedSubview(terminalRow(
                label: failed ? S.orderFailedStage : S.orderCancelledStage,
                note: failed ? S.orderFailedNote : S.orderCancelledNote))
            return
        }

        for i in 0..<Self.stageLabels.count {
            let done = i < currentIndex
            let current = i == currentIndex
            let terminalDone = current && statusKey == "delivered"
            let last = i == Self.stageLabels.count - 1
            // The active (non-terminal) stage gets a purple descriptive caption, matching the mocks.
            let caption = (current && !terminalDone) ? stageCaption(i) : nil
            timeline.addArrangedSubview(stageRow(
                label: Self.stageLabels[i], subtitle: stageSubtitle(i, order), caption: caption,
                done: done || terminalDone, current: current && !terminalDone,
                hasLine: !last, lineDone: done))
        }
    }

    /// Purple status description shown under the current stage (nil where the mocks show none).
    private func stageCaption(_ index: Int) -> String? {
        switch index {
        case 1: return S.orderStageCaptionAccepted
        case 2: return S.orderStageCaptionPicking
        case 3: return S.orderStageCaptionPacking
        case 4: return S.orderStageCaptionReady
        case 5: return S.orderStageCaptionOutForDelivery
        default: return nil   // Order Placed shows only the date; Delivered shows only the date.
        }
    }

    private func stageRow(label: String, subtitle: String?, caption: String?, done: Bool, current: Bool,
                          hasLine: Bool, lineDone: Bool) -> UIView {
        // `.top` (not `.fill`): the indicator column keeps its natural height instead of being
        // stretched to the row. With `.fill`, a row whose left column is a lone fixed-size circle
        // (the last stage / terminal node, no connector line) conflicts with the row height when the
        // text column is taller — AutoLayout then under-measures the card and clips the bottom row.
        let row = UIStackView.horizontal(spacing: 14, alignment: .top)

        let left = UIStackView.vertical(spacing: 0, alignment: .center)
        left.addArrangedSubview(buildCircle(done: done, current: current))
        if hasLine {
            let line = UIView()
            line.backgroundColor = lineDone ? AppColors.success : AppColors.border
            line.translatesAutoresizingMaskIntoConstraints = false
            line.widthAnchor.constraint(equalToConstant: 2).isActive = true
            line.heightAnchor.constraint(equalToConstant: 30).isActive = true
            left.addArrangedSubview(line)
        }
        left.widthAnchor.constraint(equalToConstant: 24).isActive = true

        let reached = done || current
        let titleLabel = UILabel.make(label, font: current ? AppFonts.bold(14) : AppFonts.regular(14),
                                      color: reached ? AppColors.textPrimary : AppColors.textTertiary)
        let right = UIStackView.vertical(spacing: 2, alignment: .leading)
        right.isLayoutMarginsRelativeArrangement = true
        right.layoutMargins = UIEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
        right.addArrangedSubview(titleLabel)
        if let subtitle = subtitle {
            right.addArrangedSubview(UILabel.make(subtitle, font: AppFonts.regular(12), color: AppColors.textSecondary))
        }
        if let caption = caption {
            right.addArrangedSubview(UILabel.make(caption, font: AppFonts.regular(12), color: AppColors.purplePrimary, lines: 0))
        }

        row.addArrangedSubview(left)
        row.addArrangedSubview(right)
        return row
    }

    private func terminalRow(label: String, note: String) -> UIView {
        let row = UIStackView.horizontal(spacing: 14, alignment: .top)

        let circle = UIView()
        circle.backgroundColor = AppColors.danger
        circle.layer.cornerRadius = 12
        circle.constrainSize(24)
        let left = UIStackView.vertical(spacing: 0, alignment: .center)
        left.addArrangedSubview(circle)
        left.widthAnchor.constraint(equalToConstant: 24).isActive = true

        let right = UIStackView.vertical(spacing: 2, alignment: .leading)
        right.isLayoutMarginsRelativeArrangement = true
        right.layoutMargins = UIEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
        right.addArrangedSubview(UILabel.make(label, font: AppFonts.bold(14), color: AppColors.textPrimary))
        right.addArrangedSubview(UILabel.make(note, font: AppFonts.regular(12), color: AppColors.danger))

        row.addArrangedSubview(left)
        row.addArrangedSubview(right)
        return row
    }

    private func buildCircle(done: Bool, current: Bool) -> UIView {
        if done {
            let container = UIView()
            container.backgroundColor = AppColors.success
            container.layer.cornerRadius = 12
            container.constrainSize(24)
            let check = UIImageView(image: UIImage(systemName: "checkmark"))
            check.tintColor = .white
            check.contentMode = .scaleAspectFit
            check.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
            check.forAutoLayout()
            container.addSubview(check)
            NSLayoutConstraint.activate([
                check.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                check.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
            return container
        }
        let ring = UIView()
        ring.backgroundColor = AppColors.surface
        ring.layer.cornerRadius = 12
        ring.layer.borderWidth = current ? 3 : 2
        ring.layer.borderColor = (current ? AppColors.purplePrimary : AppColors.textTertiary).cgColor
        ring.constrainSize(24)
        return ring
    }

    private func stageSubtitle(_ index: Int, _ order: OrderDTO) -> String? {
        switch index {
        case 0:
            return OrderFormat.createdAt(order.createdAt)
        case 5, 6:
            let date = OrderFormat.deliveryDate(order.deliveryDate)
            if date.isEmpty { return nil }
            let window = timeWindow(order)
            return window.isEmpty ? date : "\(date), \(window)"
        default:
            return nil
        }
    }

    private func timeWindow(_ order: OrderDTO) -> String {
        let start = OrderFormat.trimSeconds(order.deliveryStartTime)
        let end = OrderFormat.trimSeconds(order.deliveryEndTime)
        if start.isEmpty && end.isEmpty { return "" }
        return "\(start)–\(end)"
    }

    private func indexOf(_ status: String) -> Int {
        Self.stageKeys.firstIndex(of: status) ?? 0
    }

    // MARK: - Trader

    private func buildTraderCard(_ order: OrderDTO) -> UIView {
        let card = StyleKit.cardView()

        let icon = UIImageView(image: UIImage(systemName: "mappin.circle"))
        icon.tintColor = AppColors.purplePrimary
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        icon.constrainSize(18)
        let title = UILabel.make(S.orderTraderSection, font: AppFonts.bold(14), color: AppColors.textPrimary)
        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        header.addArrangedSubview(icon)
        header.addArrangedSubview(title)

        let name = UILabel.make(order.traderName, font: AppFonts.bold(14), color: AppColors.textPrimary, lines: 0)
        let stack = UIStackView.vertical(spacing: 6, alignment: .fill)
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(name)
        if let location = order.trader?.location, !location.isEmpty {
            stack.addArrangedSubview(UILabel.make(location, font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 0))
        }
        if let phone = order.trader?.phone, !phone.isEmpty {
            traderPhone = phone
            let phoneIcon = UIImageView(image: UIImage(systemName: "phone.fill"))
            phoneIcon.tintColor = AppColors.purplePrimary
            phoneIcon.contentMode = .scaleAspectFit
            phoneIcon.forAutoLayout()
            phoneIcon.constrainSize(13)
            phoneIcon.setContentHuggingPriority(.required, for: .horizontal)
            let phoneLabel = UILabel.make(phone, font: AppFonts.regular(12), color: AppColors.purplePrimary)
            // Tap the row to place the call (tel:).
            let phoneRow = UIStackView.horizontal(spacing: 6, alignment: .center)
            phoneRow.addArrangedSubview(phoneIcon)
            phoneRow.addArrangedSubview(phoneLabel)
            let spacer = UIView()
            phoneRow.addArrangedSubview(spacer)   // keep the tap target left-aligned, not full bleed
            phoneRow.isUserInteractionEnabled = true
            phoneRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(callTrader)))
            stack.addArrangedSubview(phoneRow)
        }
        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return card
    }

    /// Open the dialer with the trader's number (tel:).
    @objc private func callTrader() {
        let digits = (traderPhone ?? "").filter { !$0.isWhitespace }
        guard !digits.isEmpty, let url = URL(string: "tel://\(digits)"),
              UIApplication.shared.canOpenURL(url) else {
            toast(S.orderCallFailed)
            return
        }
        UIApplication.shared.open(url)
    }

    // MARK: - Items

    private func buildItemsCard(_ order: OrderDTO) -> UIView {
        let card = StyleKit.cardView()
        let items = order.items ?? []

        let header = UILabel.make(S.ordersItemsHeader(items.count), font: AppFonts.bold(14), color: AppColors.textPrimary)
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(header)
        for item in items {
            stack.addArrangedSubview(itemRow(item))
        }

        stack.addArrangedSubview(ListScreenLayout.hairline())
        let subtotal = order.subtotal ?? 0
        stack.addArrangedSubview(totalsRow(S.orderSubtotal,
                                           OrderFormat.money(subtotal > 0 ? subtotal : order.amount, currency: currency),
                                           bold: false))
        stack.addArrangedSubview(totalsRow(S.orderTotal,
                                           OrderFormat.money(order.amount, currency: currency), bold: true))
        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return card
    }

    private func itemRow(_ item: OrderItemDTO) -> UIView {
        let row = UIStackView.horizontal(spacing: 12, alignment: .center)

        let imageContainer = UIView()
        imageContainer.backgroundColor = AppColors.surfaceVariant
        imageContainer.layer.cornerRadius = AppMetrics.radiusMD
        imageContainer.layer.masksToBounds = true
        imageContainer.constrainSize(48)

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.forAutoLayout()
        imageContainer.addSubview(imageView)
        imageView.pinEdges(to: imageContainer)

        let qty = PaddingLabel(insets: UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4))
        qty.text = "x\(item.quantity ?? 0)"
        qty.font = AppFonts.bold(10)
        qty.textColor = .white
        qty.backgroundColor = AppColors.purplePrimary
        qty.layer.cornerRadius = 8
        qty.layer.masksToBounds = true
        qty.forAutoLayout()
        imageContainer.addSubview(qty)
        NSLayoutConstraint.activate([
            qty.topAnchor.constraint(equalTo: imageContainer.topAnchor, constant: 2),
            qty.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor, constant: -2)
        ])

        if let urlString = item.imageUrl, let url = URL(string: urlString) {
            if let task = ImageLoader.load(url, completion: { [weak imageView] image in imageView?.image = image }) {
                imageTasks.append(task)
            }
        }

        let name = UILabel.make(item.name ?? "", font: AppFonts.medium(13), color: AppColors.textPrimary, lines: 2)
        let price = UILabel.make("\(item.quantity ?? 0) × \(OrderFormat.money(item.unitPrice ?? 0, currency: currency))",
                                 font: AppFonts.regular(12), color: AppColors.textSecondary)
        let infoCol = UIStackView.vertical(spacing: 2, alignment: .leading)
        infoCol.addArrangedSubview(name)
        infoCol.addArrangedSubview(price)

        let lineTotal = UILabel.make(OrderFormat.money(item.lineTotal ?? 0, currency: currency),
                                     font: AppFonts.bold(13), color: AppColors.textPrimary, align: .right)
        lineTotal.setContentHuggingPriority(.required, for: .horizontal)

        row.addArrangedSubview(imageContainer)
        row.addArrangedSubview(infoCol)
        row.addArrangedSubview(lineTotal)
        return row
    }

    private func totalsRow(_ label: String, _ value: String, bold: Bool) -> UIView {
        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        let title = UILabel.make(label, font: bold ? AppFonts.bold(14) : AppFonts.regular(13),
                                 color: bold ? AppColors.textPrimary : AppColors.textSecondary)
        let amount = UILabel.make(value, font: bold ? AppFonts.bold(15) : AppFonts.regular(13),
                                  color: bold ? AppColors.purplePrimary : AppColors.textPrimary, align: .right)
        let spacer = UIView()
        row.addArrangedSubview(title)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(amount)
        return row
    }

    deinit {
        imageTasks.forEach { $0.cancel() }
    }
}
