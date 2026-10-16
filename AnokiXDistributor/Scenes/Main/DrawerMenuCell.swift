import UIKit

/// drawer_content.xml row — pill background with icon + title; the active row carries the
/// portal's horizontal indigo → violet gradient.
/// Layout lives in `DrawerMenuCell.xib`; selected/unselected styling is applied in configure.
/// Branded entries ("anokiX wallet", "Airtime & VAS") carry a second line, rendered as a
/// two-line attributed title so the XIB's single label covers both cases.
final class DrawerMenuCell: UITableViewCell {

    /// Row height when the item has a "Powered by …" second line.
    static let subtitleRowHeight: CGFloat = 54

    @IBOutlet private weak var pillView: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!

    /// Active-item fill (portal: #F26366F1 → #E68B5CF6, left to right).
    private let selectedGradient = CAGradientLayer()

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        selectionStyle = .none
        pillView.layer.cornerRadius = AppMetrics.radiusMD
        pillView.layer.masksToBounds = true
        pillView.backgroundColor = .clear
        selectedGradient.colors = [AppColors.gradientStart.withAlphaComponent(0.95).cgColor,
                                   AppColors.gradientEnd.withAlphaComponent(0.9).cgColor]
        selectedGradient.startPoint = CGPoint(x: 0, y: 0.5)
        selectedGradient.endPoint = CGPoint(x: 1, y: 0.5)
        selectedGradient.cornerRadius = AppMetrics.radiusMD
        selectedGradient.isHidden = true
        pillView.layer.insertSublayer(selectedGradient, at: 0)
        iconImageView.contentMode = .scaleAspectFit
        titleLabel.numberOfLines = 2
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        selectedGradient.frame = pillView.bounds
        CATransaction.commit()
    }

    func configure(_ item: MenuItem, selected: Bool) {
        let textColor = selected ? AppColors.drawerText : AppColors.drawerTextMuted
        let titleFont = selected ? AppFonts.semibold(14) : AppFonts.medium(14)

        if let subtitle = item.subtitle, !subtitle.isEmpty {
            let text = NSMutableAttributedString(
                string: item.title,
                attributes: [.font: titleFont, .foregroundColor: textColor])
            text.append(NSAttributedString(
                string: "\n" + subtitle,
                attributes: [.font: AppFonts.regular(11),
                             // drawerTextMuted already carries alpha 0.65 — keep the
                             // second line a step quieter than the title.
                             .foregroundColor: selected ? textColor.withAlphaComponent(0.85)
                                                        : UIColor(white: 1, alpha: 0.5)]))
            titleLabel.attributedText = text
        } else {
            titleLabel.attributedText = nil
            titleLabel.text = item.title
            titleLabel.font = titleFont
            titleLabel.textColor = textColor
        }

        iconImageView.image = AppIcons.symbol(item.icon)
        iconImageView.tintColor = textColor
        pillView.backgroundColor = .clear
        selectedGradient.isHidden = !selected
        setNeedsLayout()
    }
}
