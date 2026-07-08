import UIKit

/// Central place that maps a menu key to the matching secondary screen, mirroring the
/// switch in MainActivity.onDrawerItemClicked / MoreFragment.
enum Router {
    static func secondaryViewController(for key: String) -> UIViewController? {
        switch key {
        case "stores": return StoresViewController()
        case "traders": return TradersViewController()
        // Drawer "products" selects the Products tab (MainActivity parity) — not a pushed screen.
        case "airtime": return AirtimeViewController()
        case "promotions": return PromotionsViewController()
        case "finances": return FinancesViewController()
        case "reports": return ReportsViewController()
        case "deliveries": return DeliveriesViewController()
        case "returns": return ReturnsViewController()
        case "notifications": return NotificationsViewController()
        case "settings": return SettingsViewController()
        default: return nil
        }
    }
}
