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
    /// Portal status pill: 12% tint fill, status-colour semibold text, fully rounded.
    static func styleBadge(_ l: PaddingLabel) {
        l.insets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        l.font = AppFonts.semibold(AppMetrics.textLabel)
        l.layer.cornerRadius = AppMetrics.radiusSM
        l.layer.masksToBounds = true
        l.isPill = true
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
        field.layer.cornerRadius = AppMetrics.radiusSM
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

    /// Primary filled brand-blue button — portal primary: solid #0D47A1, radius 8, semibold white.
    static func stylePrimaryButton(_ button: UIButton, fontSize: CGFloat = 15) {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = AppColors.purplePrimary
        config.baseForegroundColor = .white
        config.cornerStyle = .fixed
        config.background.cornerRadius = AppMetrics.radiusSM
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.semibold(fontSize); return out
        }
        button.configuration = config
    }

    /// Outlined button. Default = the portal's neutral secondary button (white fill, 1pt #DCE1E8
    /// border, navy text, radius 8). Pass `color` for a coloured outline (e.g. success / danger).
    static func styleOutlinedButton(_ button: UIButton, fontSize: CGFloat = 15, color: UIColor? = nil) {
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = color ?? AppColors.textPrimary
        config.background.backgroundColor = AppColors.surface
        config.background.strokeColor = color ?? AppColors.border
        config.background.strokeWidth = 1
        config.background.cornerRadius = AppMetrics.radiusSM
        config.cornerStyle = .fixed
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.semibold(fontSize); return out
        }
        button.configuration = config
    }

    // MARK: Gradients (portal accent: nav active item, initials avatars)

    /// Renders a linear gradient into an image. `diagonal` = CSS 135° (top-left → bottom-right),
    /// otherwise left → right.
    static func gradientImage(size: CGSize, colors: [UIColor], diagonal: Bool = true) -> UIImage? {
        guard size.width > 0, size.height > 0, colors.count >= 2 else { return nil }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cgColors = colors.map { $0.cgColor } as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: cgColors, locations: nil) else { return }
            let end = diagonal ? CGPoint(x: size.width, y: size.height) : CGPoint(x: size.width, y: 0)
            ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: end,
                                             options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
    }

    /// Fills an initials avatar (a fixed-size label or view) with the portal's 135° indigo → violet
    /// gradient. Uses a pattern colour so it also works on UILabels, whose sublayers would
    /// otherwise cover the text. `size` must be the view's final size.
    static func applyAvatarGradient(to view: UIView, size: CGSize) {
        if let image = gradientImage(size: size, colors: [AppColors.gradientStart, AppColors.gradientEnd]) {
            view.backgroundColor = UIColor(patternImage: image)
        } else {
            view.backgroundColor = AppColors.gradientStart
        }
    }

    /// Storyboard / XIB views are authored with the system font; this walks a view tree and
    /// swaps any system-font label, button title or text field to the Inter face of the same
    /// size and weight (AppFonts). Custom fonts that were already applied are left alone.
    static func applyInterFonts(in root: UIView) {
        func convert(_ font: UIFont) -> UIFont {
            let isSystem = font.fontName.hasPrefix(".") || font.familyName.hasPrefix(".")
            guard isSystem else { return font }
            let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
            let weight = (traits?[.weight] as? CGFloat) ?? 0
            let size = font.pointSize
            if weight >= UIFont.Weight.semibold.rawValue - 0.01 { return AppFonts.semibold(size) }
            if weight >= UIFont.Weight.medium.rawValue - 0.01 { return AppFonts.medium(size) }
            if weight <= UIFont.Weight.light.rawValue + 0.01 { return AppFonts.light(size) }
            return AppFonts.regular(size)
        }
        for view in root.subviews {
            if let label = view as? UILabel {
                label.font = convert(label.font)
            } else if let button = view as? UIButton {
                if button.configuration == nil, let titleLabel = button.titleLabel {
                    titleLabel.font = convert(titleLabel.font)
                }
                continue
            } else if let field = view as? UITextField, let font = field.font {
                field.font = convert(font)
            }
            applyInterFonts(in: view)
        }
    }

    /// Global UIKit appearance defaults (portal: switches / spinners / refresh / pickers /
    /// segmented controls and system navigation bars in brand blue + Inter). Values set
    /// explicitly on a view still win over these proxies.
    static func applyGlobalAppearance() {
        UIActivityIndicatorView.appearance().color = AppColors.purplePrimary
        UISwitch.appearance().onTintColor = AppColors.purplePrimary
        UIRefreshControl.appearance().tintColor = AppColors.purplePrimary
        UIDatePicker.appearance().tintColor = AppColors.purplePrimary
        UISlider.appearance().minimumTrackTintColor = AppColors.purplePrimary
        UIProgressView.appearance().progressTintColor = AppColors.purplePrimary
        UIPageControl.appearance().currentPageIndicatorTintColor = AppColors.purplePrimary

        let segmented = UISegmentedControl.appearance()
        segmented.selectedSegmentTintColor = AppColors.purplePrimary
        segmented.setTitleTextAttributes([.font: AppFonts.semibold(13), .foregroundColor: UIColor.white],
                                         for: .selected)
        segmented.setTitleTextAttributes([.font: AppFonts.medium(13), .foregroundColor: AppColors.textSecondary],
                                         for: .normal)

        // System navigation bars (modal pickers such as the country / multi-select lists).
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = AppColors.surface
        nav.shadowColor = AppColors.border
        nav.titleTextAttributes = [.font: AppFonts.semibold(17), .foregroundColor: AppColors.topTitle]
        nav.largeTitleTextAttributes = [.font: AppFonts.semibold(30), .foregroundColor: AppColors.topTitle]
        let barProxy = UINavigationBar.appearance()
        barProxy.standardAppearance = nav
        barProxy.scrollEdgeAppearance = nav
        barProxy.compactAppearance = nav
        barProxy.tintColor = AppColors.purplePrimary
    }

    /// Spinner / refresh-control / switch tint used across the app.
    static func tintControls(_ views: UIView...) {
        for v in views {
            if let s = v as? UISwitch { s.onTintColor = AppColors.purplePrimary }
            else { v.tintColor = AppColors.purplePrimary }
        }
    }
}

/// A view whose backing layer is a `CAGradientLayer`, so the gradient always tracks the
/// view's bounds (used for the gradient avatars that are laid out with Auto Layout).
final class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
    var gradientLayer: CAGradientLayer {
        // layerClass guarantees the type.
        return layer as! CAGradientLayer
    }

    init(colors: [UIColor] = [AppColors.gradientStart, AppColors.gradientEnd], diagonal: Bool = true) {
        super.init(frame: .zero)
        setColors(colors, diagonal: diagonal)
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setColors([AppColors.gradientStart, AppColors.gradientEnd], diagonal: true)
    }

    func setColors(_ colors: [UIColor], diagonal: Bool = true) {
        gradientLayer.colors = colors.map { $0.cgColor }
        gradientLayer.startPoint = .zero
        gradientLayer.endPoint = diagonal ? CGPoint(x: 1, y: 1) : CGPoint(x: 1, y: 0)
    }
}

/// UILabel with content insets — used for pill badges and chips.
final class PaddingLabel: UILabel {
    var insets: UIEdgeInsets
    /// When true the corner radius tracks half the height (fully rounded pill).
    var isPill: Bool = false {
        didSet { setNeedsLayout() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if isPill { layer.cornerRadius = bounds.height / 2 }
    }

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
