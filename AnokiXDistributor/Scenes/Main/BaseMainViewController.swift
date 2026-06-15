import UIKit

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
    func constrainLogoHeaderImage(_ imageView: UIImageView) {
        imageView.applyBrandLogoSizing()
    }

    func addNotificationBadge(to button: UIButton) {
        refreshNotificationBadge(on: button)
    }

    func refreshNotificationBadge(on button: UIButton) {
        let count = repository.getUnreadNotificationCount()
        let text = count > 99 ? "99+" : "\(count)"
        if let badge = button.viewWithTag(9001) as? UILabel {
            badge.text = text
            badge.isHidden = count == 0
            return
        }
        guard count > 0 else { return }
        let badge = UILabel()
        badge.tag = 9001
        badge.text = text
        badge.font = AppFonts.bold(9)
        badge.textColor = .white
        badge.textAlignment = .center
        badge.backgroundColor = AppColors.purplePrimary
        badge.layer.cornerRadius = 8
        badge.layer.masksToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 16),
            badge.heightAnchor.constraint(equalToConstant: 16),
            badge.topAnchor.constraint(equalTo: button.topAnchor, constant: 2),
            badge.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -2)
        ])
    }

    /// Called when header chrome is already placed in Main.storyboard.
    func configureStoryboardChrome() {}

    /// Override to add header XIBs when the storyboard chrome stack is empty.
    func setupChromeHeader() {}

    func setupContent(in container: UIView) {}
    func loadData() {}

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshNotificationBadgesInChrome()
    }

    func refreshNotificationBadgesInChrome() {
        guard let panel = chromeStackView?.arrangedSubviews.first else { return }
        panel.subviews.compactMap { $0 as? UIButton }.forEach { refreshNotificationBadge(on: $0) }
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
        guard let vc = Router.secondaryViewController(for: key) else { return }
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
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
