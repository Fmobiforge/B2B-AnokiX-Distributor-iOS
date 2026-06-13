import UIKit

/// drawer_content.xml row — pill background with icon + title, purple when selected.
/// Layout lives in `DrawerMenuCell.xib`; selected/unselected styling is applied in configure.
final class DrawerMenuCell: UITableViewCell {

    @IBOutlet private weak var pillView: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        selectionStyle = .none
        pillView.layer.cornerRadius = AppMetrics.radiusMD
        iconImageView.contentMode = .scaleAspectFit
    }

    func configure(_ item: MenuItem, selected: Bool) {
        titleLabel.text = item.title
        iconImageView.image = AppIcons.symbol(item.icon)
        if selected {
            pillView.backgroundColor = AppColors.drawerItemSelected
            titleLabel.textColor = AppColors.drawerText
            titleLabel.font = AppFonts.bold(14)
            iconImageView.tintColor = AppColors.drawerText
        } else {
            pillView.backgroundColor = .clear
            titleLabel.textColor = AppColors.drawerTextMuted
            titleLabel.font = AppFonts.medium(14)
            iconImageView.tintColor = AppColors.drawerTextMuted
        }
    }
}
