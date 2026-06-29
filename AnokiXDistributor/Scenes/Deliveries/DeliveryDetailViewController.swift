import UIKit

/// Delivery detail screen (port of DeliveryDetailActivity / the *-Details mocks): delivery
/// & order numbers + status, trader contact, area + delivery time, the line items, the order
/// total, and a single action button (Dispatch Delivery / Mark as Delivered) decided by the
/// raw `status`. Fetched by id from `api/distributor/deliveries/get-by-id`.
final class DeliveryDetailViewController: BaseSecondaryViewController {

    override var screenTitle: String { S.deliveryDetails }

    /// Notifies the list to refresh after a successful dispatch / deliver.
    var onUpdated: (() -> Void)?

    private let deliveryId: String
    private let currency = "R"
    private var traderPhone: String?

    private var contentStack: UIStackView!
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(deliveryId: String) {
        self.deliveryId = deliveryId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func setupContent(in container: UIView) {
        contentStack = makeScrollStack(in: container, spacing: 16)
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
        ApiClient.shared.getDeliveryById(id: deliveryId) { [weak self] result in
            guard let self = self else { return }
            self.spinner.stopAnimating()
            switch result {
            case .success(let data):
                guard let delivery = data.delivery else {
                    self.toast(S.deliveryLoadFailed)
                    self.navigationController?.popViewController(animated: true)
                    return
                }
                self.bind(delivery)
            case .failure(let error):
                self.toast(error.message.isEmpty ? S.deliveryLoadFailed : error.message)
                self.navigationController?.popViewController(animated: true)
            }
        }
    }

    // MARK: - Bind

    private func bind(_ d: DeliveryDetailDTO) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        contentStack.addArrangedSubview(headerBlock(d))
        contentStack.addArrangedSubview(ListScreenLayout.hairline())
        contentStack.addArrangedSubview(traderBlock(d))
        contentStack.addArrangedSubview(ListScreenLayout.hairline())
        contentStack.addArrangedSubview(itemsCard(d))
        contentStack.addArrangedSubview(totalRow(d))
        if let action = DeliveriesViewController.actionFor(d.status) {
            contentStack.addArrangedSubview(actionButton(action, deliveryId: d.id))
        }
    }

    private func headerBlock(_ d: DeliveryDetailDTO) -> UIView {
        let number = UILabel.make(d.deliveryNumber ?? "", font: AppFonts.bold(20), color: AppColors.purplePrimary)
        let orderNumber = UILabel.make(d.orderNumber ?? "", font: AppFonts.regular(13), color: AppColors.textSecondary)
        let leftCol = UIStackView.vertical(spacing: 2, alignment: .leading)
        leftCol.addArrangedSubview(number)
        leftCol.addArrangedSubview(orderNumber)

        let badgeStatus = (d.deliveryStatus?.isEmpty == false) ? d.deliveryStatus : d.statusKey
        let badge = StyleKit.badgeLabel()
        let (fg, bg) = DeliveryFormat.colors(badgeStatus)
        badge.text = DeliveryFormat.label(badgeStatus)
        badge.textColor = fg
        badge.backgroundColor = bg
        badge.font = AppFonts.regular(12)
        badge.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.addArrangedSubview(leftCol)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(badge)
        return row
    }

    private func traderBlock(_ d: DeliveryDetailDTO) -> UIView {
        let stack = UIStackView.vertical(spacing: 8, alignment: .fill)
        stack.addArrangedSubview(UILabel.make(d.resolvedTraderName, font: AppFonts.bold(16), color: AppColors.purplePrimary, lines: 0))

        if let phone = d.trader?.phone, !phone.isEmpty {
            traderPhone = phone
            let phoneIcon = UIImageView(image: UIImage(systemName: "phone.fill"))
            phoneIcon.tintColor = AppColors.textSecondary
            phoneIcon.contentMode = .scaleAspectFit
            phoneIcon.forAutoLayout()
            phoneIcon.constrainSize(16)
            phoneIcon.setContentHuggingPriority(.required, for: .horizontal)
            let phoneLabel = UILabel.make(phone, font: AppFonts.regular(13), color: AppColors.textSecondary)
            let phoneRow = UIStackView.horizontal(spacing: 8, alignment: .center)
            phoneRow.addArrangedSubview(phoneIcon)
            phoneRow.addArrangedSubview(phoneLabel)
            phoneRow.addArrangedSubview(UIView())
            phoneRow.isUserInteractionEnabled = true
            phoneRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(callTrader)))
            stack.addArrangedSubview(phoneRow)
        }

        let areaText = (d.area?.isEmpty == false) ? d.area : d.trader?.location
        if let areaText = areaText, !areaText.isEmpty {
            stack.addArrangedSubview(iconRow("mappin.circle", areaText))
        }
        let at = DeliveryFormat.deliveryAt(d.deliveryAt)
        if !at.isEmpty {
            stack.addArrangedSubview(iconRow("clock", at))
        }
        return stack
    }

    private func iconRow(_ symbol: String, _ text: String) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = AppColors.textSecondary
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        icon.constrainSize(16)
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let label = UILabel.make(text, font: AppFonts.regular(13), color: AppColors.textSecondary, lines: 0)
        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.addArrangedSubview(icon)
        row.addArrangedSubview(label)
        return row
    }

    private func itemsCard(_ d: DeliveryDetailDTO) -> UIView {
        let card = StyleKit.cardView()
        let stack = UIStackView.vertical(spacing: 0, alignment: .fill)
        stack.forAutoLayout()

        // Header row
        let itemTitle = UILabel.make(S.itemColTitle, font: AppFonts.bold(11), color: AppColors.textSecondary)
        let qtyTitle = UILabel.make(S.qtyColTitle, font: AppFonts.bold(11), color: AppColors.textSecondary, align: .right)
        qtyTitle.setContentHuggingPriority(.required, for: .horizontal)
        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        header.isLayoutMarginsRelativeArrangement = true
        header.layoutMargins = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        header.addArrangedSubview(itemTitle)
        header.addArrangedSubview(qtyTitle)
        let headerWrap = UIView()
        headerWrap.backgroundColor = AppColors.surfaceVariant
        header.forAutoLayout()
        headerWrap.addSubview(header)
        header.pinEdges(to: headerWrap)
        stack.addArrangedSubview(headerWrap)

        let items = d.items ?? []
        for (index, item) in items.enumerated() {
            if index > 0 { stack.addArrangedSubview(ListScreenLayout.hairline()) }
            stack.addArrangedSubview(itemRow(item))
        }

        card.addSubview(stack)
        stack.pinEdges(to: card)
        return card
    }

    private func itemRow(_ item: DeliveryItemDTO) -> UIView {
        let name = UILabel.make(item.name ?? "", font: AppFonts.regular(13), color: AppColors.textPrimary, lines: 0)
        let qty = UILabel.make("\(item.quantity ?? 0)", font: AppFonts.regular(13), color: AppColors.textPrimary, align: .right)
        qty.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        row.addArrangedSubview(name)
        row.addArrangedSubview(qty)
        return row
    }

    private func totalRow(_ d: DeliveryDetailDTO) -> UIView {
        let title = UILabel.make(S.orderTotalLabel, font: AppFonts.regular(14), color: AppColors.textSecondary)
        let amount = UILabel.make(OrderFormat.money(d.totalAmount ?? 0, currency: currency),
                                  font: AppFonts.bold(18), color: AppColors.purplePrimary, align: .right)
        amount.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.addArrangedSubview(title)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(amount)
        return row
    }

    private func actionButton(_ action: String, deliveryId: Int) -> UIView {
        let button = UIButton(type: .system)
        StyleKit.stylePrimaryButton(button)
        button.setTitle(action == "dispatch" ? S.dispatchDelivery : S.markAsDelivered, for: .normal)
        button.setImage(UIImage(systemName: action == "dispatch" ? "paperplane" : "checkmark"), for: .normal)
        button.tintColor = .white
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.addAction(UIAction { [weak self] _ in self?.performAction(action, deliveryId: deliveryId) }, for: .touchUpInside)
        return button
    }

    private func performAction(_ action: String, deliveryId: Int) {
        spinner.startAnimating()
        ApiClient.shared.deliveryAction(action, deliveryId: deliveryId) { [weak self] result in
            guard let self = self else { return }
            self.spinner.stopAnimating()
            switch result {
            case .success(let data):
                self.onUpdated?()
                self.successBanner(action == "dispatch" ? S.deliveryDispatchedMsg : S.deliveryDeliveredMsg)
                if let delivery = data.delivery { self.bind(delivery) }
            case .failure(let error):
                self.toast(error.message.isEmpty ? S.deliveryActionFailed : error.message)
            }
        }
    }

    @objc private func callTrader() {
        let digits = (traderPhone ?? "").filter { !$0.isWhitespace }
        guard !digits.isEmpty, let url = URL(string: "tel://\(digits)"),
              UIApplication.shared.canOpenURL(url) else {
            toast(S.orderCallFailed)
            return
        }
        UIApplication.shared.open(url)
    }
}
