import UIKit
import UserNotifications

/// Base for bottom-tab screens. Chrome + content containers are in Main.storyboard.
/// Subclasses override `setupChromeHeader()` only when chrome is not already in the storyboard.
class BaseMainViewController: UIViewController {

    let repository = RepositoryProvider.get()

    @IBOutlet private(set) weak var chromeStackView: UIStackView!
    @IBOutlet private(set) weak var contentView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.background
        navigationController?.setNavigationBarHidden(true, animated: false)
        pinChromeBelowStatusBar()

        if chromeStackView.arrangedSubviews.isEmpty {
            setupChromeHeader()
        }
        configureStoryboardChrome()
        setupContent(in: contentView)
        loadData()
    }

    /// Pin chrome below the status bar / notch (storyboard may already use safe area).
    private func pinChromeBelowStatusBar() {
        guard let chrome = chromeStackView else { return }
        let safeGuide = view.safeAreaLayoutGuide
        let alreadyPinnedToSafeArea = view.constraints.contains { constraint in
            (constraint.firstItem as? UIView == chrome && constraint.firstAttribute == .top
                && constraint.secondItem === safeGuide)
            || (constraint.secondItem as? UIView == chrome && constraint.secondAttribute == .top
                && constraint.firstItem === safeGuide)
        }
        if alreadyPinnedToSafeArea { return }

        view.constraints.filter { constraint in
            (constraint.firstItem as? UIView == chrome && constraint.firstAttribute == .top
                && constraint.secondItem as? UIView == view)
            || (constraint.secondItem as? UIView == chrome && constraint.secondAttribute == .top
                && constraint.firstItem as? UIView == view)
        }.forEach { view.removeConstraint($0) }
        chrome.topAnchor.constraint(equalTo: safeGuide.topAnchor).isActive = true
    }

    /// Sizes the wordmark to the 28pt header height with the correct aspect ratio so it
    /// renders at the leading edge instead of off-screen (matches the Android header).
    func configureLogoHeaderImage(_ imageView: UIImageView, in panel: UIView? = nil) {
        if imageView.image == nil {
            imageView.image = BrandAssets.logoBlack
        }
        imageView.applyBrandLogoSizing()
        guard let panel else { return }
        if let bell = panel.subviews.compactMap({ $0 as? UIButton }).first {
            let trailing = imageView.trailingAnchor.constraint(lessThanOrEqualTo: bell.leadingAnchor, constant: -8)
            trailing.priority = .required
            trailing.isActive = true
        }
    }

    /// Backward-compatible alias used by tab screens.
    func constrainLogoHeaderImage(_ imageView: UIImageView) {
        let panel = chromeStackView?.arrangedSubviews.first
        configureLogoHeaderImage(imageView, in: panel)
    }

    private static let notificationButtonId = "notificationButton"
    private static let notificationBadgeTag = 9001

    func addNotificationBadge(to button: UIButton) {
        button.accessibilityIdentifier = Self.notificationButtonId
        _ = ensureBadge(on: button)
        refreshNotificationBadge(on: button)
    }

    /// Creates the (initially hidden) badge label once so the live count can be filled in async.
    @discardableResult
    private func ensureBadge(on button: UIButton) -> UILabel {
        if let badge = button.viewWithTag(Self.notificationBadgeTag) as? UILabel { return badge }
        let badge = UILabel()
        badge.tag = Self.notificationBadgeTag
        badge.font = AppFonts.bold(9)
        badge.textColor = .white
        badge.textAlignment = .center
        badge.backgroundColor = AppColors.purplePrimary
        badge.layer.cornerRadius = 8
        badge.layer.masksToBounds = true
        badge.isHidden = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 16),
            badge.heightAnchor.constraint(equalToConstant: 16),
            badge.topAnchor.constraint(equalTo: button.topAnchor, constant: 2),
            badge.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -2)
        ])
        return badge
    }

    /// Fills the bell badge from the live unread count (GET notifications/unread-count).
    /// Hides at zero, shows "99+" beyond 99.
    func refreshNotificationBadge(on button: UIButton) {
        guard button.accessibilityIdentifier == Self.notificationButtonId else { return }
        let badge = ensureBadge(on: button)
        ApiClient.shared.getUnreadCount { result in
            let count: Int
            switch result {
            case .success(let data): count = data.unreadCount ?? 0
            case .failure: count = 0
            }
            badge.text = count > 99 ? "99+" : "\(count)"
            badge.isHidden = count == 0
            Self.applyAppIconBadge(count)
        }
    }

    /// Keeps the springboard badge in step with the bell.
    ///
    /// The server sends `aps.badge` as the unread total at send time, so iOS is only
    /// correct until the user reads something in-app — without this the icon keeps
    /// showing the old count until the next push arrives.
    private static func applyAppIconBadge(_ count: Int) {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }

    /// Called when header chrome is already placed in Main.storyboard.
    func configureStoryboardChrome() {}

    /// Override to add header XIBs when the storyboard chrome stack is empty.
    func setupChromeHeader() {}

    func setupContent(in container: UIView) {}
    func loadData() {}

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
        refreshNotificationBadgesInChrome()
    }

    func refreshNotificationBadgesInChrome() {
        guard let panel = chromeStackView?.arrangedSubviews.first else { return }
        panel.subviews.compactMap { $0 as? UIButton }.forEach { button in
            if button.accessibilityIdentifier == Self.notificationButtonId {
                refreshNotificationBadge(on: button)
            } else {
                button.viewWithTag(Self.notificationBadgeTag)?.removeFromSuperview()
            }
        }
    }

    func openDrawer() {
        let tab = tabBarController as? MainTabBarController
        let drawer = DrawerMenuViewController(selectedKey: tab?.currentTabKey ?? "home")
        drawer.modalPresentationStyle = .overFullScreen
        drawer.onSelect = { [weak self] key in self?.handleDrawer(key) }
        present(drawer, animated: false)
    }

    func openNotifications() {
        guard let vc = Router.secondaryViewController(for: "notifications") else { return }
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }

    private func handleDrawer(_ key: String) {
        if let tab = tabBarController as? MainTabBarController, tab.selectTab(forKey: key) {
            return
        }
        guard let vc = Router.secondaryViewController(for: key) else {
            // Card Machine / Warehouse Staff / Support Centre: menu entries are in place,
            // their screens are still to come.
            if let title = MockData.drawerMenuItems().first(where: { $0.key == key })?.title {
                showComingSoon(title)
            }
            return
        }
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showComingSoon(_ feature: String) {
        let alert = UIAlertController(title: nil, message: S.featureComingSoon(feature),
                                      preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { alert.dismiss(animated: true) }
    }

    func embedHeader(_ header: UIView) {
        chromeStackView.addArrangedSubview(header)
    }

    func embedLogoHeader(onNotifications: @escaping () -> Void) -> LogoHeaderView {
        let header = LogoHeaderView.loadFromNib()
        header.onNotifications = onNotifications
        embedHeader(header)
        return header
    }

    func embedPageTitle(title: String, subtitle: String?) {
        let section = PageTitleSectionView.loadFromNib()
        section.configure(title: title, subtitle: subtitle)
        embedHeader(section)
    }
}
