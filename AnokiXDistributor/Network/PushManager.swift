import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

/// The id fields a notification payload can carry. FCM `data` values are always strings,
/// while the in-app feed sends them as numbers — `PushIds` normalises both to `String?`.
struct PushIds: Equatable {
    var orderId: String?
    var grnId: String?
    var grvId: String?
    var deliveryId: String?
    var invoiceId: String?
    var productId: String?
    var promotionId: String?
    var traderId: String?
    var transactionId: String?
    var notificationId: String?

    /// Reads the ids out of a push payload's `userInfo`.
    static func from(userInfo: [AnyHashable: Any]) -> PushIds {
        PushIds(orderId: id(userInfo["order_id"]),
                grnId: id(userInfo["grn_id"]),
                grvId: id(userInfo["grv_id"]),
                deliveryId: id(userInfo["delivery_id"]),
                invoiceId: id(userInfo["invoice_id"]),
                productId: id(userInfo["product_id"]),
                promotionId: id(userInfo["promotion_id"]),
                traderId: id(userInfo["trader_id"]),
                transactionId: id(userInfo["transaction_id"]),
                notificationId: id(userInfo["notification_id"]))
    }

    /// Normalises an id payload value (String or Int) to a non-empty String, or nil for a
    /// missing id / the backend's "no id" placeholder of 0.
    static func id(_ value: Any?) -> String? {
        if let s = value as? String, !s.isEmpty, s != "0" { return s }
        if let i = value as? Int, i > 0 { return String(i) }
        return nil
    }
}

/// Where a push (or an in-app notification row) navigates when tapped — the iOS
/// counterpart of the Android `messaging.PushManager.navigate`.
enum PushRoute: Equatable {
    case order(String?)
    case delivery(String?)
    case returnDetail(String?)
    case finance
    case wallet
    case products
    case vas
    case promotion(String?)
    case report
    case traders
    case settings
    /// The feed itself — also the fallback for a payload we can't place.
    case notifications

    /// Resolves the destination for a payload. An explicit, recognised `route` wins;
    /// otherwise the `type` prefix decides. Kept in lockstep with the Android
    /// `PushManager.routeKey` — see `FCM-settings/3-Event-Catalogue.md`.
    ///
    /// Goods Received lives only on the trader side, so a `grv.*` event reaching a
    /// distributor is about one of its orders and resolves to `.order`.
    ///
    /// The ids break a tie when `route` and `type` disagree. The server groups events into
    /// broad screen families, so a payload can name a route it cannot actually be placed
    /// on: `grv.confirmed` arrives as `route=delivery` carrying only a `grv_id`. When the
    /// named route needs an id the payload does not carry and the `type` resolves to
    /// somewhere we *can* open, the type wins.
    static func resolve(type: String?, route: String?, ids: PushIds) -> PushRoute {
        let derived = fromType(type, ids: ids)
        guard let explicit = fromRoute(route, ids: ids) else { return derived ?? .notifications }
        if let derived, explicit != derived, !explicit.canOpen, derived.canOpen { return derived }
        return explicit
    }

    /// True when this payload can actually land somewhere. Only the destinations that
    /// dead-end at the notifications feed without an id are "can't open" — the rest fall
    /// back to their own list screen, which is a real answer and must not be overridden.
    private var canOpen: Bool {
        switch self {
        case .order(let id): return id != nil
        default:             return true
        }
    }

    /// The destination named outright by `route`, or nil when it names none we know.
    private static func fromRoute(_ route: String?, ids: PushIds) -> PushRoute? {
        switch (route ?? "").trimmingCharacters(in: .whitespaces).lowercased() {
        case "order", "grv":  return .order(ids.orderId)
        case "delivery":      return .delivery(ids.deliveryId ?? ids.orderId)
        case "return":        return .returnDetail(ids.grnId)
        case "invoice", "finance": return .finance
        case "wallet":        return .wallet
        case "inventory", "product", "marketplace": return .products
        case "vas":           return .vas
        case "promotion":     return .promotion(ids.promotionId)
        case "report":        return .report
        case "trader":        return .traders
        case "settings":      return .settings
        case "notifications": return .notifications
        default:              return nil
        }
    }

    /// The destination implied by the event type, e.g. "order.status" → `.order`;
    /// nil when the type says nothing, so it never overrides an explicit route.
    private static func fromType(_ type: String?, ids: PushIds) -> PushRoute? {
        let t = (type ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        if t.hasPrefix("order") || t.hasPrefix("grv") { return .order(ids.orderId) }
        if t.hasPrefix("delivery")  { return .delivery(ids.deliveryId ?? ids.orderId) }
        if t.hasPrefix("return")    { return .returnDetail(ids.grnId) }
        if t.hasPrefix("invoice") || t.hasPrefix("payment")
            || t.hasPrefix("payout") || t.hasPrefix("finance") { return .finance }
        if t.hasPrefix("wallet")    { return .wallet }
        if t.hasPrefix("stock") || t.hasPrefix("product") { return .products }
        if t.hasPrefix("vas")       { return .vas }
        if t.hasPrefix("promotion") { return .promotion(ids.promotionId) }
        if t.hasPrefix("report") || t.hasPrefix("pos") { return .report }
        if t.hasPrefix("trader")    { return .traders }
        if t.hasPrefix("security")  { return .settings }
        return nil
    }
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
/// Backend contract: iOS needs the alert in `apns.payload.aps`, with the routing fields
/// (`type`, `route`, `order_id`, `grn_id`, `delivery_id`, …) alongside it so they land in
/// `userInfo` for `routeFromUserInfo`. See `FCM-settings/3-Event-Catalogue.md`.
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

    /// Decodes a push payload's routing fields into a `PushRoute`, using the same resolver
    /// as the in-app feed (`NotificationsViewController`).
    func routeFromUserInfo(_ userInfo: [AnyHashable: Any]) -> PushRoute {
        PushRoute.resolve(type: userInfo["type"] as? String,
                          route: userInfo["route"] as? String,
                          ids: PushIds.from(userInfo: userInfo))
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

    /// Pushes the screen a route points at onto the active tab's stack.
    ///
    /// - Parameter fallbackToFeed: `true` for a push tap (an unroutable payload opens the
    ///   Notifications list); `false` for a tap inside that list, which stays put.
    @discardableResult
    func navigate(_ route: PushRoute, fallbackToFeed: Bool = true) -> Bool {
        guard SessionManager.shared.isLoggedIn, let nav = topNavigationController() else { return false }

        var destination: UIViewController? = nil
        switch route {
        case .order(let id):
            if let id { destination = OrderDetailViewController(orderId: id) }
            else if fallbackToFeed { destination = NotificationsViewController() }
        case .delivery(let id):
            if let id { destination = DeliveryDetailViewController(deliveryId: id) }
            else { destination = DeliveriesViewController() }
        case .returnDetail(let id):
            if let id { destination = ReturnDetailViewController(returnId: id) }
            else { destination = ReturnsViewController() }
        // The distributor has no standalone invoices screen — its ledger covers both.
        case .finance:
            destination = FinancesViewController()
        case .wallet:
            destination = WalletViewController()
        case .products:
            destination = ProductsViewController()
        case .vas:
            destination = AirtimeViewController()
        case .promotion(let id):
            if let id { destination = ViewPromotionViewController(promotionId: id) }
            else { destination = PromotionsViewController() }
        case .report:
            destination = ReportsViewController()
        case .traders:
            destination = TradersViewController()
        case .settings:
            destination = SettingsSecurityViewController()
        case .notifications:
            if fallbackToFeed { destination = NotificationsViewController() }
        }

        guard let destination else { return true }   // resolved, but nowhere to go
        nav.pushViewController(destination, animated: true)
        return true
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
        // No app-side dedupe needed here: the system draws the banner, and the server's
        // apns-collapse-id makes an at-least-once redelivery replace it rather than stack.
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
