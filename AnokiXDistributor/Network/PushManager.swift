import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

/// Where a push should navigate when tapped — mirrors `NotificationsViewController.openDetail`
/// and the Android `messaging.PushManager.handleRouting`.
enum PushRoute: Equatable {
    case order(String?)
    case returnDetail(String?)
    case deliveries
    case products
    case notifications
}

/// Central Firebase Cloud Messaging handler for the iOS app (parity with the Android
/// `messaging.PushManager` + `AxFirebaseMessagingService`, and the Trader iOS `PushManager`).
///
/// Responsibilities:
///  - `configure()` boots Firebase and wires the messaging / notification-center delegates,
///  - `requestAuthorization()` asks for the alert/badge/sound permission and registers with APNs,
///  - the messaging delegate registers the rotated FCM token with the backend (when signed in),
///  - notification taps are decoded into a `PushRoute` and pushed onto the active tab's
///    navigation stack (or stashed until the main shell appears if the app was cold-launched).
///
/// Backend recommendation: send the routing fields (`type`, `route`, `order_id`, `grn_id`)
/// inside the push payload so `routeFromUserInfo` can resolve the destination.
final class PushManager: NSObject {

    static let shared = PushManager()

    private let lastRegisteredKey = "fcm_last_registered_token"
    private var currentToken: String?
    /// Set when a cold-launch tap can't route yet; applied by `applyPendingRoute()`.
    private var pendingRoute: PushRoute?

    private override init() { super.init() }

    // MARK: Setup

    /// Boots Firebase and registers the delegates. Call once from the app delegate.
    func configure() {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }

    /// Requests notification authorization, then registers with APNs on the main thread.
    /// Safe to call after login / when the main UI first appears.
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // MARK: Token registration

    /// Registers the cached token with the backend if the user is signed in and the token
    /// is new. Called after login and whenever a fresh token arrives.
    func registerCurrentToken() {
        guard let token = currentToken, !token.isEmpty else { return }
        guard SessionManager.shared.isLoggedIn else { return }        // signed in?
        if UserDefaults.standard.string(forKey: lastRegisteredKey) == token { return }

        ApiClient.shared.registerDeviceToken(token) { result in
            if case .success = result {
                UserDefaults.standard.set(token, forKey: self.lastRegisteredKey)
            }
            // On failure (e.g. endpoint not live yet) leave it unregistered so a later call retries.
        }
    }

    /// Removes this device's token from the backend (call on logout, before clearing auth).
    func unregister() {
        let token = currentToken ?? Messaging.messaging().fcmToken
        UserDefaults.standard.removeObject(forKey: lastRegisteredKey)
        guard let token, !token.isEmpty else { return }
        ApiClient.shared.unregisterDeviceToken(token) { _ in }
    }

    // MARK: Routing

    /// Decodes a push payload's routing fields into a `PushRoute`. Mirrors
    /// `NotificationsViewController.openDetail`: order → order detail, return → GRN detail,
    /// delivery → deliveries, stock → products, else → notifications list.
    func routeFromUserInfo(_ userInfo: [AnyHashable: Any]) -> PushRoute {
        let type = (userInfo["type"] as? String) ?? ""
        let route = (userInfo["route"] as? String) ?? ""
        if type.hasPrefix("order") || route == "order" { return .order(stringId(userInfo["order_id"])) }
        if type.hasPrefix("return") || route == "return" { return .returnDetail(stringId(userInfo["grn_id"])) }
        if type.hasPrefix("delivery") || route == "delivery" { return .deliveries }
        if type.hasPrefix("stock") || route == "inventory" { return .products }
        return .notifications
    }

    /// Navigate now if the main shell is up; otherwise stash for `applyPendingRoute()`.
    func handleTap(_ route: PushRoute) {
        if !navigate(route) { pendingRoute = route }
    }

    /// Applies a route stashed by a cold-launch tap. Called from `MainTabBarController`.
    func applyPendingRoute() {
        guard let route = pendingRoute else { return }
        pendingRoute = nil
        navigate(route)
    }

    @discardableResult
    private func navigate(_ route: PushRoute) -> Bool {
        guard SessionManager.shared.isLoggedIn, let nav = topNavigationController() else { return false }
        let destination: UIViewController
        switch route {
        case .order(let id):
            destination = id != nil ? OrderDetailViewController(orderId: id!) : NotificationsViewController()
        case .returnDetail(let id):
            destination = id != nil ? ReturnDetailViewController(returnId: id!) : ReturnsViewController()
        case .deliveries:
            destination = DeliveriesViewController()
        case .products:
            destination = ProductsViewController()
        case .notifications:
            destination = NotificationsViewController()
        }
        nav.pushViewController(destination, animated: true)
        return true
    }

    /// Normalises an id payload value (String or Int) to a non-empty String, or nil.
    private func stringId(_ value: Any?) -> String? {
        if let s = value as? String, !s.isEmpty, s != "0" { return s }
        if let i = value as? Int, i > 0 { return String(i) }
        return nil
    }

    /// The navigation controller of the currently-visible tab, drilling through any
    /// presented (modal) view controllers first.
    private func topNavigationController() -> UINavigationController? {
        guard var top = activeKeyWindow()?.rootViewController else { return nil }
        while let presented = top.presentedViewController { top = presented }
        if let tab = top as? UITabBarController,
           let nav = tab.selectedViewController as? UINavigationController { return nav }
        if let nav = top as? UINavigationController { return nav }
        return top.navigationController
    }

    private func activeKeyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

// MARK: - MessagingDelegate

extension PushManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        currentToken = fcmToken
        registerCurrentToken()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushManager: UNUserNotificationCenterDelegate {
    /// Foreground: still show the banner + play sound (matches Android building the
    /// notification in `onMessageReceived`).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    /// Tap: decode the destination and navigate.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let route = routeFromUserInfo(response.notification.request.content.userInfo)
        DispatchQueue.main.async { self.handleTap(route) }
        completionHandler()
    }
}
