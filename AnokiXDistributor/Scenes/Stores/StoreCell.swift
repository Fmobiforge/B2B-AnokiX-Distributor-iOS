import UIKit

/// item_store.xml — store icon tile, name, address, Followers / Reviews stats, status, chevron.
/// Layout lives in `StoreCell.xib`; theme styling is applied in `awakeFromNib`.
final class StoreCell: UICollectionViewCell {

    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var iconTile: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var addressLabel: UILabel!
    @IBOutlet private weak var infoStack: UIStackView!
    @IBOutlet private weak var followerCountLabel: UILabel!
    @IBOutlet private weak var reviewCountLabel: UILabel!
    @IBOutlet private weak var statusBadge: PaddingLabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear

        StyleKit.styleCard(cardView)

        iconTile.backgroundColor = AppColors.purpleLight
        iconTile.layer.cornerRadius = AppMetrics.radiusMD
        iconImageView.image = AppIcons.symbol("ic_stores")
        iconImageView.tintColor = AppColors.purplePrimary

        nameLabel.font = AppFonts.bold(13)
        nameLabel.textColor = AppColors.textPrimary
        addressLabel.font = AppFonts.regular(11)
        addressLabel.textColor = AppColors.textSecondary
        addressLabel.numberOfLines = 1
        followerCountLabel.font = AppFonts.bold(11)
        followerCountLabel.textColor = AppColors.textPrimary
        reviewCountLabel.font = AppFonts.bold(11)
        reviewCountLabel.textColor = AppColors.textPrimary

        infoStack.setCustomSpacing(6, after: addressLabel)

        StyleKit.styleBadge(statusBadge)
    }

    func configure(_ item: StoreItem) {
        nameLabel.text = item.name
        addressLabel.text = item.address
        followerCountLabel.text = "\(item.followerCount)"
        reviewCountLabel.text = "\(item.reviewCount)"
        StyleKit.applyStatusBadge(statusBadge, status: item.status)
    }
}
