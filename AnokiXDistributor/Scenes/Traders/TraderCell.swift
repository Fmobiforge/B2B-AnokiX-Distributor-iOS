import UIKit

/// item_trader.xml — colored initials avatar, name, location, phone, segment + New badge.
/// Layout lives in `TraderCell.xib`; theme styling is applied here so Swift stays the
/// single source of truth for fonts/colors (mirrors the DashboardHeaderView pattern).
final class TraderCell: UICollectionViewCell {

    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var avatarLabel: UILabel!
    @IBOutlet private weak var nameLabel: UILabel!
    // Second line = trader code (Android item_trader: traderCode, bold).
    @IBOutlet private weak var codeLabel: UILabel!
    // Third line = address, up to 2 lines (Android item_trader: traderLocation maxLines=2).
    @IBOutlet private weak var addressLabel: UILabel!
    @IBOutlet private weak var badgeLabel: PaddingLabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear

        StyleKit.styleCard(cardView)

        avatarLabel.font = AppFonts.bold(14)
        avatarLabel.textColor = .white
        avatarLabel.textAlignment = .center
        avatarLabel.layer.cornerRadius = 22
        avatarLabel.layer.masksToBounds = true

        nameLabel.font = AppFonts.bold(13)
        nameLabel.textColor = AppColors.textPrimary
        codeLabel.font = AppFonts.bold(11)
        codeLabel.textColor = AppColors.textPrimary
        addressLabel.font = AppFonts.regular(11)
        addressLabel.textColor = AppColors.textSecondary
        addressLabel.numberOfLines = 2

        StyleKit.styleBadge(badgeLabel)
    }

    func configure(_ item: TraderItem) {
        avatarLabel.text = item.initials
        avatarLabel.backgroundColor = item.avatarColor
        nameLabel.text = item.name
        codeLabel.text = item.traderCode
        codeLabel.isHidden = item.traderCode.isEmpty
        addressLabel.text = item.location.isEmpty ? item.segment : item.location
        if item.isNew {
            badgeLabel.isHidden = false
            StyleKit.applyStatusBadge(badgeLabel, status: "New")
        } else {
            badgeLabel.isHidden = true
        }
    }
}
