import UIKit

/// drawer_content.xml row — pill background with icon + title, purple when selected.
/// Layout lives in `DrawerMenuCell.xib`; selected/unselected styling is applied in configure.
/// Branded entries ("anokiX wallet", "Airtime & VAS") carry a second line, rendered as a
/// two-line attributed title so the XIB's single label covers both cases.
final class DrawerMenuCell: UITableViewCell {

    /// Row height when the item has a "Powered by …" second line.
    static let subtitleRowHeight: CGFloat = 54

    @IBOutlet private weak var pillView: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        selectionStyle = .none
        pillView.layer.cornerRadius = AppMetrics.radiusMD
        iconImageView.contentMode = .scaleAspectFit
        titleLabel.numberOfLines = 2
    }

    func configure(_ item: MenuItem, selected: Bool) {
        let textColor = selected ? AppColors.drawerText : AppColors.drawerTextMuted
        let titleFont = selected ? AppFonts.bold(14) : AppFonts.medium(14)

        if let subtitle = item.subtitle, !subtitle.isEmpty {
            let text = NSMutableAttributedString(
                string: item.title,
                attributes: [.font: titleFont, .foregroundColor: textColor])
            text.append(NSAttributedString(
                string: "\n" + subtitle,
                attributes: [.font: AppFonts.regular(11),
                             .foregroundColor: textColor.withAlphaComponent(selected ? 0.85 : 0.75)]))
            titleLabel.attributedText = text
        } else {
            titleLabel.attributedText = nil
            titleLabel.text = item.title
            titleLabel.font = titleFont
            titleLabel.textColor = textColor
        }

        iconImageView.image = AppIcons.symbol(item.icon)
        iconImageView.tintColor = textColor
        pillView.backgroundColor = selected ? AppColors.drawerItemSelected : .clear
    }
}
