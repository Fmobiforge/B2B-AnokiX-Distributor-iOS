import UIKit

/// Main shell matching Android BottomNavigationView — 4 tabSpecs defined in Main.storyboard.
/// Tabs and their bar items are wired defensively so the bottom navigation always appears,
/// whether the controller is loaded as the storyboard initial VC or instantiated by ID
/// (e.g. after login via SceneDelegate.setRoot).
final class MainTabBarController: UITabBarController, UITabBarControllerDelegate {

    private struct TabSpec {
        let key: String
        let storyboardId: String
        let title: String
        let icon: String   // SF Symbol
    }

    private let tabSpecs: [TabSpec] = [
        TabSpec(key: "home",      storyboardId: "DashboardNavigationController", title: "Home",      icon: "square.grid.2x2.fill"),
        TabSpec(key: "orders",    storyboardId: "OrdersNavigationController",    title: "Orders",    icon: "doc.text.fill"),
        TabSpec(key: "inventory", storyboardId: "InventoryNavigationController", title: "Inventory", icon: "shippingbox.fill"),
        TabSpec(key: "products",  storyboardId: "ProductsNavigationController",  title: "Products",  icon: "bag.fill")
    ]

    var currentTabKey: String {
        tabSpecs[safe: selectedIndex]?.key ?? "home"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        wireTabsIfNeeded()
        applyTabBarItems()
        configureTabBarVisibility()
        TabBarStyling.apply(to: tabBar)
        // FCM: covers the auto-login path (returning users who skip LoginViewController) —
        // ask for push permission and register this device's token. Both calls are idempotent.
        PushManager.shared.requestAuthorization()
        PushManager.shared.registerCurrentToken()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configureTabBarVisibility()
        // Apply any navigation a notification tap requested while the app was launching.
        PushManager.shared.applyPendingRoute()
    }

    /// Keep the classic Android-style bottom bar always visible (iOS 26 minimizes on scroll by default).
    private func configureTabBarVisibility() {
        tabBar.isHidden = false
        // `tabBarMinimizeBehavior` only exists in the iOS 26 SDK (Xcode 26 / Swift 6.2+).
        // #available is a *runtime* check, so it can't prevent a *compile* error on older
        // Xcode — gate the symbol behind a compiler-version check too.
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior = .never
        }
        #endif
        // `mode` / `setTabBarHidden(_:animated:)` are iOS 18 SDK symbols (Xcode 16 / Swift 6.0+).
        #if compiler(>=6.0)
        if #available(iOS 18.0, *) {
            mode = .tabBar
            setTabBarHidden(false, animated: false)
        }
        #endif
    }

    /// Relationship segues are not always applied when instantiating by storyboard ID,
    /// so build the tab children explicitly when they are missing or incomplete.
    private func wireTabsIfNeeded() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let expectedCount = tabSpecs.count
        if viewControllers?.count != expectedCount {
            viewControllers = tabSpecs.map { storyboard.instantiateViewController(withIdentifier: $0.storyboardId) }
            selectedIndex = min(selectedIndex, expectedCount - 1)
        }
    }

    /// Guarantee every tab shows the correct label + icon even if the storyboard item was lost.
    private func applyTabBarItems() {
        guard let vcs = viewControllers else { return }
        for (index, vc) in vcs.enumerated() where index < tabSpecs.count {
            let spec = tabSpecs[index]
            vc.tabBarItem = UITabBarItem(title: spec.title,
                                         image: UIImage(systemName: spec.icon),
                                         selectedImage: UIImage(systemName: spec.icon))
        }
    }

    @discardableResult
    func selectTab(forKey key: String) -> Bool {
        guard let index = tabSpecs.firstIndex(where: { $0.key == key }) else { return false }
        selectedIndex = index
        (selectedViewController as? UINavigationController)?.popToRootViewController(animated: false)
        return true
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        (viewController as? UINavigationController)?.popToRootViewController(animated: false)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
