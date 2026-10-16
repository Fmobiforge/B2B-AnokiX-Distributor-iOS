import UIKit

enum BrandAssets {
    static let logoWhite = UIImage(named: "LogoWhite")
    static let logoBlack = UIImage(named: "LogoBlack")
}

extension UIImageView {
    private static var brandLogoSizingKey: UInt8 = 0

    /// Sizes a wide brand wordmark to a fixed header height with the correct aspect ratio.
    /// Without an explicit width, `scaleAspectFit` centers the logo inside a ~1200pt-wide
    /// intrinsic frame and it renders off the leading edge of the screen.
    func applyBrandLogoSizing(height: CGFloat = 28) {
        contentMode = .scaleAspectFit
        clipsToBounds = true
        setContentHuggingPriority(.required, for: .horizontal)
        // Allow Auto Layout to shrink below the image's huge intrinsic width (~1200pt).
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultHigh, for: .vertical)

        if objc_getAssociatedObject(self, &UIImageView.brandLogoSizingKey) as? Bool == true {
            return
        }
        objc_setAssociatedObject(self, &UIImageView.brandLogoSizingKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        constraints.filter { constraint in
            (constraint.firstItem as? UIView) === self || (constraint.secondItem as? UIView) === self
        }.filter { constraint in
            constraint.firstAttribute == .height || constraint.firstAttribute == .width
                || constraint.secondAttribute == .height || constraint.secondAttribute == .width
        }.forEach { $0.isActive = false }

        let resolvedHeight = heightAnchor.constraint(equalToConstant: height)
        resolvedHeight.priority = .required
        resolvedHeight.isActive = true

        guard let img = image ?? BrandAssets.logoBlack, img.size.height > 0 else { return }
        let aspect = img.size.width / img.size.height
        let resolvedWidth = widthAnchor.constraint(equalToConstant: height * aspect)
        resolvedWidth.priority = .required
        resolvedWidth.isActive = true
    }
}

/// Loads a view from a same-named XIB in the main bundle.
protocol NibLoadable: UIView {
    static var nibName: String { get }
}

extension NibLoadable {
    static var nibName: String { String(describing: self) }

    static func loadFromNib() -> Self {
        guard let view = Bundle.main.loadNibNamed(nibName, owner: nil, options: nil)?.first as? Self else {
            fatalError("Missing XIB: \(nibName).xib")
        }
        return view
    }
}

/// Login / splash gradient — bg_login_gradient.xml (#0A1030 → #000920).
@IBDesignable
final class BrandGradientView: UIView {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }
    private func setupGradient() {
        gradient.colors = [UIColor(hex: 0x0A1030).cgColor, AppColors.loginBg.cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(gradient, at: 0)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}

/// DashboardHeaderView.xib
final class DashboardHeaderView: UIView, NibLoadable {

    var onMenu: (() -> Void)?
    var onNotifications: (() -> Void)?

    @IBOutlet private weak var menuButton: UIButton!
    @IBOutlet private weak var welcomeLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var notificationsButton: UIButton!
    @IBOutlet private weak var avatarLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = AppColors.surface
        subtitleLabel.text = S.dashboardSubtitle
        subtitleLabel.font = AppFonts.regular(AppMetrics.textBodySM)
        subtitleLabel.textColor = AppColors.textSecondary
        welcomeLabel.font = AppFonts.semibold(AppMetrics.textTitle)
        welcomeLabel.textColor = AppColors.topTitle
        // Portal avatar: 135° indigo → violet gradient, white semibold initials (36pt circle).
        avatarLabel.layer.cornerRadius = 18
        avatarLabel.layer.masksToBounds = true
        StyleKit.applyAvatarGradient(to: avatarLabel, size: CGSize(width: 36, height: 36))
        avatarLabel.textColor = .white
        avatarLabel.font = AppFonts.semibold(AppMetrics.textTitle)
        menuButton.tintColor = AppColors.textPrimary
        notificationsButton.tintColor = AppColors.textPrimary
    }

    func configure(welcome: String, initials: String) {
        welcomeLabel.text = welcome
        avatarLabel.text = initials
    }

    @IBAction private func menuTapped(_ sender: UIButton) { onMenu?() }
    @IBAction private func notificationsTapped(_ sender: UIButton) { onNotifications?() }
}

/// LogoHeaderView.xib
final class LogoHeaderView: UIView, NibLoadable {

    var onNotifications: (() -> Void)?

    @IBOutlet private weak var logoImageView: UIImageView!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var notificationsButton: UIButton!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = AppColors.surface
        logoImageView.image = BrandAssets.logoBlack
        logoImageView.applyBrandLogoSizing()
        subtitleLabel.text = S.loginSubtitle
        subtitleLabel.font = AppFonts.regular(AppMetrics.textLabel)
        subtitleLabel.textColor = AppColors.textSecondary
        notificationsButton.tintColor = AppColors.textPrimary
    }

    @IBAction private func notificationsTapped(_ sender: UIButton) { onNotifications?() }
}

/// Page title row — built in Interface Builder via PageTitleSectionView.xib
final class PageTitleSectionView: UIView, NibLoadable {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = AppColors.surface
        titleLabel.font = AppFonts.semibold(AppMetrics.textHeadline)
        titleLabel.textColor = AppColors.topTitle
        subtitleLabel.font = AppFonts.regular(AppMetrics.textBodySM)
        subtitleLabel.textColor = AppColors.textSecondary
    }

    func configure(title: String, subtitle: String?) {
        titleLabel.text = title
        if let subtitle = subtitle, !subtitle.isEmpty {
            subtitleLabel.text = subtitle
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.isHidden = true
        }
    }
}

enum TabBarStyling {
    static func apply(to tabBar: UITabBar) {
        tabBar.isTranslucent = false
        tabBar.tintColor = AppColors.purplePrimary
        tabBar.unselectedItemTintColor = AppColors.textTertiary

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColors.surface
        appearance.shadowColor = AppColors.borderLight

        let normal = appearance.stackedLayoutAppearance.normal
        normal.titleTextAttributes = [
            .font: AppFonts.medium(AppMetrics.bottomNavTextSize),
            .foregroundColor: AppColors.textTertiary
        ]
        normal.iconColor = AppColors.textTertiary

        let selected = appearance.stackedLayoutAppearance.selected
        selected.titleTextAttributes = [
            .font: AppFonts.semibold(AppMetrics.bottomNavTextSize),
            .foregroundColor: AppColors.purplePrimary
        ]
        selected.iconColor = AppColors.purplePrimary

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }
}
