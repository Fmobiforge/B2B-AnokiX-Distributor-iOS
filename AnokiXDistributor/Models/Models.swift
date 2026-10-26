import UIKit

// Direct ports of the Android `model/*.java` value types. Android resource ids
// (iconRes / colorRes) become SF Symbol name strings and UIColor here.

struct StoreItem {
    let id: String
    let name: String
    let address: String
    let followerCount: Int
    let reviewCount: Int
    let status: String
    let area: String
    var tags: [String] = []
}

struct ProductItem {
    let id: String
    let name: String
    let sku: String
    let category: String
    let price: String
    let stockStatus: String
    var imageUrl: String?

    // Extra list metadata — powers the category / brand / status filters and the card.
    var brand: String = ""
    var brandId: String = ""
    var categoryId: String = ""
    var parentCategoryId: String = ""
    var parentCategory: String = ""
    /// Product record status from the API ("Active" / "Inactive").
    var status: String = ""
    var barcode: String = ""
    var stockQty: Int = 0
    var reorderLevel: Int = 0

    /// Status groups the portal styles differently (green / amber / grey).
    enum StatusKind { case active, pending, inactive, other }

    static let labelActive = "Active"
    static let labelPending = "Pending Review"
    static let labelInactive = "InActive"

    /// The portal's status normalisation: "Pending", "pending_review", "Under Review" … are all
    /// a pending review; "approved" / "enabled" count as active; "disabled" / "rejected" as
    /// inactive. A blank status is active (the list mapper's default).
    var statusKind: StatusKind {
        let s = status.trimmingCharacters(in: .whitespaces).lowercased()
            .replacingOccurrences(of: "[\\s-]+", with: "_", options: .regularExpression)
        switch s {
        case "": return .active
        case "pending", "pending_review", "pending_approval", "awaiting_approval", "under_review": return .pending
        case "active", "approved", "enabled": return .active
        case "inactive", "in_active", "disabled", "rejected": return .inactive
        default: return .other
        }
    }

    /// Badge text, as on the portal: "Active", "Pending Review", "InActive", or the raw status.
    var statusLabel: String {
        switch statusKind {
        case .active: return Self.labelActive
        case .pending: return Self.labelPending
        case .inactive: return Self.labelInactive
        case .other:
            return status.replacingOccurrences(of: "_", with: " ")
                .split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
    }

    var isActive: Bool { statusKind == .active }
    var isOutOfStock: Bool { stockQty <= 0 }
    /// In stock but at or below the reorder level the distributor configured.
    var isLowStock: Bool { stockQty > 0 && reorderLevel > 0 && stockQty <= reorderLevel }
}

struct OrderItem {
    let orderId: String
    let traderName: String
    let initials: String
    let location: String
    let amount: String
    let payment: String
    let time: String
    let status: String
    let relativeTime: String
    let productSummary: String
    let isPaid: Bool

    init(orderId: String, traderName: String, initials: String, location: String,
         amount: String, payment: String, time: String, status: String,
         relativeTime: String? = nil, productSummary: String = "", isPaid: Bool = false) {
        self.orderId = orderId
        self.traderName = traderName
        self.initials = initials
        self.location = location
        self.amount = amount
        self.payment = payment
        self.time = time
        self.status = status
        self.relativeTime = relativeTime ?? time
        self.productSummary = productSummary
        self.isPaid = isPaid
    }
}

/// Generic list row used by the simpler secondary screens (BaseListActivity).
struct ListItem {
    let title: String
    let subtitle: String
    let badge: String
    let sku: String
    let stockCount: Int
    let stockPercent: Int

    init(title: String, subtitle: String, badge: String) {
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.sku = ""
        self.stockCount = 0
        self.stockPercent = 50
    }

    init(title: String, sku: String, stockCount: Int, stockPercent: Int, badge: String) {
        self.title = title
        self.sku = sku
        self.stockCount = stockCount
        self.stockPercent = stockPercent
        self.badge = badge
        self.subtitle = "\(sku) · \(stockCount) units"
    }
}

struct MenuItem {
    let key: String
    let title: String
    let icon: String   // SF Symbol name
    /// Optional second line under the title ("Powered by IMB"); nil hides it.
    let subtitle: String?

    init(key: String, title: String, icon: String, subtitle: String? = nil) {
        self.key = key
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
    }
}

struct DeliveryItem {
    let id: String
    let traderName: String
    let driverName: String
    let eta: String
    let status: String
}

struct FinanceSummary {
    let title: String
    let amount: String
    let trend: String
    let trendUp: Bool
    let valueColor: UIColor
    let trendColor: UIColor
}

struct FinanceTransaction {
    let id: String
    let title: String
    let invoiceId: String
    let date: String
    let amount: String
    let isIncome: Bool
    let status: String
    let icon: String
}

struct NotificationItem {
    let id: String
    let title: String
    let message: String
    let relativeTime: String
    let type: String
    let icon: String
    let iconBg: UIColor
    let iconTint: UIColor
    let actionLabel: String
    let unread: Bool
}

struct NotificationPreference {
    let key: String
    let title: String
    let subtitle: String
    var enabled: Bool
}

/// UI model for a single campaign row on the Promotions screen. Port of model/PromotionItem.java.
struct PromotionItem {
    let id: String
    let name: String
    let campaignType: String   // raw, e.g. "best_deal" (used by the local filter)
    let typeLabel: String      // e.g. "Best Deal"
    let status: String         // raw, e.g. "pending_approval" (used by the local filter)
    let statusLabel: String    // e.g. "Pending Approval"
    let dateRange: String      // e.g. "15 Jun – 30 Jun 2026"
    let budget: String         // e.g. "R3,000"
    let reach: String
    let clicks: String
    let ctr: String            // e.g. "0.0%"
}

struct ReturnItem {
    let id: String
    let traderName: String
    let reason: String
    let amount: String
    let timestamp: String
    let status: String
}

struct SettingsMenuEntry {
    let key: String
    let title: String
    let subtitle: String
    let icon: String
}

struct SettingsProfile {
    let name: String
    let email: String
    let initials: String
    let verified: Bool
}

struct ProfileSettings {
    let firstName: String
    let lastName: String
    let email: String
    let phone: String
    let companyName: String
}

struct BusinessSettings {
    let businessName: String
    let registrationNumber: String
    let vatNumber: String
    let address: String
    let city: String
    let latitude: Double?
    let longitude: Double?
}

struct AppPreferences {
    let language: String
    let currency: String
    let timezone: String
    let dateFormat: String
}
