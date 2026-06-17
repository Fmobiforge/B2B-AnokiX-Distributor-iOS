import UIKit

/// Reusable visual building blocks that mirror the Android drawables/styles
/// (bg_stat_card, bg_badge_success, bg_login_input, bg_kpi_icon_*, etc.).
enum StyleKit {

    /// White card with 1px border and rounded corners — bg_stat_card / Widget.AnokiX.Card.Flat.
    static func cardView() -> UIView {
        let v = UIView()
        styleCard(v)
        return v
    }

    /// Applies the card look to an existing view (e.g. a `cardView` outlet inside a XIB cell).
    static func styleCard(_ v: UIView, radius: CGFloat = AppMetrics.radiusLG) {
        v.backgroundColor = AppColors.surface
        v.layer.cornerRadius = radius
        v.layer.borderWidth = 1
        v.layer.borderColor = AppColors.border.cgColor
    }

    /// Rounded tinted square that holds an icon — bg_kpi_icon_* / bg_stat_icon_*.
    static func iconTile(color: UIColor, radius: CGFloat = AppMetrics.radiusMD) -> UIView {
        let v = UIView()
        v.backgroundColor = color
        v.layer.cornerRadius = radius
        return v
    }

    /// Pill badge (status chips) — bg_badge_success and friends.
    static func badgeLabel() -> PaddingLabel {
        let l = PaddingLabel(insets: UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
        styleBadge(l)
        return l
    }

    /// Applies the pill-badge look to an existing `PaddingLabel` outlet inside a XIB cell.
    static func styleBadge(_ l: PaddingLabel) {
        l.insets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        l.font = AppFonts.regular(AppMetrics.textLabel)
        l.layer.cornerRadius = AppMetrics.radiusSM
        l.layer.masksToBounds = true
        l.textAlignment = .center
    }

    /// Applies status colours (Active/Inactive/In Stock/Low Stock/etc.) to a badge.
    static func applyStatusBadge(_ label: PaddingLabel, status: String) {
        let (fg, bg) = statusColors(for: status)
        label.text = status
        label.textColor = fg
        label.backgroundColor = bg
    }

    static func statusColors(for status: String) -> (fg: UIColor, bg: UIColor) {
        switch status.lowercased() {
        case "active", "in stock", "delivered", "approved", "paid":
            return (AppColors.success, AppColors.successBg)
        case "low stock", "processing", "pending", "in transit", "delayed", "expiring", "paused":
            return (AppColors.warning, AppColors.warningBg)
        case "out of stock", "inactive", "rejected", "returned", "expired", "new":
            return (status.lowercased() == "new")
                ? (AppColors.info, AppColors.infoBg)
                : (AppColors.danger, AppColors.dangerBg)
        default:
            return (AppColors.textSecondary, AppColors.borderLight)
        }
    }

    /// Bordered input container — bg_login_input.
    static func styleInput(_ field: UITextField) {
        field.backgroundColor = AppColors.surface
        field.layer.cornerRadius = AppMetrics.radiusMD
        field.layer.borderWidth = 1
        field.layer.borderColor = AppColors.border.cgColor
        field.font = AppFonts.regular(AppMetrics.textBody)
        field.textColor = AppColors.textPrimary
        field.heightAnchor.constraint(equalToConstant: 48).isActive = true
        let pad = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        field.leftView = pad
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        field.rightViewMode = .always
    }

    /// Primary filled purple button — bg_login_button_primary.
    static func stylePrimaryButton(_ button: UIButton, fontSize: CGFloat = 15) {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = AppColors.purplePrimary
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.bold(fontSize); return out
        }
        button.configuration = config
    }

    /// Outlined purple button — bg_login_button_outlined.
    static func styleOutlinedButton(_ button: UIButton, fontSize: CGFloat = 15) {
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = AppColors.purplePrimary
        config.background.strokeColor = AppColors.purplePrimary
        config.background.strokeWidth = 1
        config.background.cornerRadius = AppMetrics.radiusMD
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.bold(fontSize); return out
        }
        button.configuration = config
    }
}

/// UILabel with content insets — used for pill badges and chips.
final class PaddingLabel: UILabel {
    var insets: UIEdgeInsets

    init(insets: UIEdgeInsets) {
        self.insets = insets
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) {
        self.insets = .zero
        super.init(coder: coder)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + insets.left + insets.right,
                      height: s.height + insets.top + insets.bottom)
    }
}
