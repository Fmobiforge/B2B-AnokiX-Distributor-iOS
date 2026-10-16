import UIKit

/// item_order.xml — status ribbon + time, avatar/trader/order-id(+copy)/location,
/// product summary, Order Value + PAID/payment badges, and View/Accept/Reject buttons.
/// Layout lives in `OrderCell.xib`; theme + button styling is applied in `awakeFromNib`.
final class OrderCell: UITableViewCell {

    var onAccept: (() -> Void)?
    var onReject: (() -> Void)?
    var onView: (() -> Void)?
    var onCopy: (() -> Void)?

    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var ribbonBadge: PaddingLabel!
    @IBOutlet private weak var timeLabel: UILabel!
    @IBOutlet private weak var avatarLabel: UILabel!
    @IBOutlet private weak var traderNameLabel: UILabel!
    @IBOutlet private weak var orderIdLabel: UILabel!
    @IBOutlet private weak var copyButton: UIButton!
    @IBOutlet private weak var locationRow: UIStackView!
    @IBOutlet private weak var locationLabel: UILabel!
    @IBOutlet private weak var summaryLabel: UILabel!
    @IBOutlet private weak var amountLabel: UILabel!
    @IBOutlet private weak var paidBadge: PaddingLabel!
    @IBOutlet private weak var paymentBadge: PaddingLabel!
    @IBOutlet private weak var viewButton: UIButton!
    @IBOutlet private weak var acceptButton: UIButton!
    @IBOutlet private weak var rejectButton: UIButton!
    @IBOutlet private weak var actionsStack: UIStackView!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        selectionStyle = .none

        StyleKit.styleCard(cardView)

        // Ribbon
        StyleKit.styleBadge(ribbonBadge)
        ribbonBadge.font = AppFonts.semibold(10)
        ribbonBadge.textColor = AppColors.warning
        ribbonBadge.backgroundColor = AppColors.warningBg

        timeLabel.font = AppFonts.regular(11)
        timeLabel.textColor = AppColors.textSecondary

        // Avatar
        // Portal initials avatar: 135° indigo → violet gradient, white semibold initials.
        avatarLabel.font = AppFonts.semibold(14)
        avatarLabel.textColor = .white
        avatarLabel.textAlignment = .center
        StyleKit.applyAvatarGradient(to: avatarLabel, size: CGSize(width: 44, height: 44))
        avatarLabel.layer.cornerRadius = AppMetrics.radiusMD
        avatarLabel.layer.masksToBounds = true

        traderNameLabel.font = AppFonts.semibold(14)
        traderNameLabel.textColor = AppColors.topTitle
        orderIdLabel.font = AppFonts.regular(12)
        orderIdLabel.textColor = AppColors.textSecondary
        copyButton.tintColor = AppColors.textSecondary
        locationLabel.font = AppFonts.regular(12)
        locationLabel.textColor = AppColors.textSecondary
        summaryLabel.font = AppFonts.regular(12)
        summaryLabel.textColor = AppColors.textSecondary
        summaryLabel.numberOfLines = 2
        amountLabel.font = AppFonts.semibold(AppMetrics.textStatValue)
        amountLabel.textColor = AppColors.topTitle

        // Value badges
        StyleKit.styleBadge(paidBadge)
        paidBadge.font = AppFonts.semibold(10)
        paidBadge.textColor = AppColors.success
        paidBadge.backgroundColor = AppColors.successBg
        StyleKit.styleBadge(paymentBadge)
        paymentBadge.font = AppFonts.semibold(10)
        paymentBadge.textColor = AppColors.purplePrimary
        paymentBadge.backgroundColor = AppColors.purpleLight

        // Actions
        // Portal outlined actions: neutral View, success Accept, danger Reject (1pt, radius 8).
        styleActionButton(viewButton, fg: AppColors.textPrimary, bg: AppColors.surface, stroke: AppColors.border, title: "View Order", icon: "eye")
        styleActionButton(acceptButton, fg: AppColors.success, bg: AppColors.surface, stroke: AppColors.success, title: "Accept Order", icon: "checkmark.circle.fill")
        styleActionButton(rejectButton, fg: AppColors.danger, bg: AppColors.surface, stroke: AppColors.danger, title: "Reject Order", icon: "xmark.circle.fill")
    }

    func configure(_ order: OrderItem, showActions: Bool) {
        avatarLabel.text = order.initials.isEmpty ? String(order.traderName.prefix(2)).uppercased() : order.initials
        traderNameLabel.text = order.traderName
        orderIdLabel.text = order.orderId
        locationLabel.text = order.location
        locationRow.isHidden = order.location.isEmpty
        amountLabel.text = order.amount
        timeLabel.text = order.relativeTime
        summaryLabel.text = order.productSummary
        summaryLabel.isHidden = order.productSummary.isEmpty
        paidBadge.isHidden = !order.isPaid
        paymentBadge.text = "  \(order.payment)  "
        paymentBadge.isHidden = order.payment.isEmpty

        switch order.status {
        case "new": ribbonBadge.text = "NEW ORDER"; ribbonBadge.isHidden = false
        case "processing": ribbonBadge.text = "PROCESSING"; ribbonBadge.isHidden = false
        default: ribbonBadge.isHidden = true
        }
        actionsStack.isHidden = !showActions
    }

    // MARK: Actions

    @IBAction private func acceptTapped() { onAccept?() }
    @IBAction private func rejectTapped() { onReject?() }
    @IBAction private func viewTapped() { onView?() }
    @IBAction private func copyTapped() { onCopy?() }

    private func styleActionButton(_ button: UIButton, fg: UIColor, bg: UIColor, stroke: UIColor?, title: String, icon: String) {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = bg
        config.baseForegroundColor = fg
        config.cornerStyle = .fixed
        config.background.cornerRadius = AppMetrics.radiusSM
        config.title = title
        config.image = UIImage(systemName: icon)
        config.imagePadding = 8
        config.titleTextAttributesTransformer = .init { incoming in
            var out = incoming; out.font = AppFonts.semibold(13); return out
        }
        if let stroke = stroke {
            config.background.strokeColor = stroke
            config.background.strokeWidth = 1
        }
        button.configuration = config
    }
}
