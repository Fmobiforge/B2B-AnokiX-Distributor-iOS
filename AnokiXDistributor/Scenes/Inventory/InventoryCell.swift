import UIKit

/// item_inventory.xml — name, SKU · units, stock bar, status pill.
/// Layout lives in `InventoryCell.xib`; the stock-bar fill width is constraint-driven here.
final class InventoryCell: UICollectionViewCell {

    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var skuLabel: UILabel!
    @IBOutlet private weak var statusBadge: PaddingLabel!
    @IBOutlet private weak var trackView: UIView!
    @IBOutlet private weak var fillView: UIView!

    private var fillWidth: NSLayoutConstraint!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear

        StyleKit.styleCard(cardView)

        nameLabel.font = AppFonts.bold(13)
        nameLabel.textColor = AppColors.textPrimary
        skuLabel.font = AppFonts.regular(11)
        skuLabel.textColor = AppColors.textSecondary

        StyleKit.styleBadge(statusBadge)

        trackView.backgroundColor = AppColors.borderLight
        trackView.layer.cornerRadius = 3
        fillView.layer.cornerRadius = 3
        fillWidth = fillView.widthAnchor.constraint(equalTo: trackView.widthAnchor, multiplier: 0.5)
        fillWidth.isActive = true
    }

    func configure(_ item: ListItem) {
        nameLabel.text = item.title
        skuLabel.text = item.subtitle
        StyleKit.applyStatusBadge(statusBadge, status: item.badge)
        let percent = max(0.02, min(1, CGFloat(item.stockPercent) / 100))
        fillView.backgroundColor = StyleKit.statusColors(for: item.badge).fg
        fillWidth.isActive = false
        fillWidth = fillView.widthAnchor.constraint(equalTo: trackView.widthAnchor, multiplier: percent)
        fillWidth.isActive = true
    }
}
