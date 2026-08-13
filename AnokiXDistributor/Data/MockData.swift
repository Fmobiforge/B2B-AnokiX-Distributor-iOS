import UIKit

/// Port of data/MockData.java — static sample content for the screens that aren't
/// (yet) wired to a live endpoint.
enum MockData {

    static func orders() -> [OrderItem] {
        [
            OrderItem(orderId: "ORD-10548", traderName: "Spaza Sunrise Umlazi", initials: "SS",
                      location: "Umlazi, Durban, 4031", amount: "R8,560.00", payment: "Wallet",
                      time: "10 Jun 2026, 14:32", status: "new",
                      relativeTime: "2 mins ago",
                      productSummary: "Airtime x10  ·  Data 10GB x5  ·  Electricity x3  ·  +3", isPaid: true),
            OrderItem(orderId: "ORD-10547", traderName: "Township Store", initials: "TS",
                      location: "Soweto, Johannesburg", amount: "R4,320.00", payment: "Card",
                      time: "10 Jun 2026, 13:15", status: "new",
                      relativeTime: "15 mins ago",
                      productSummary: "Airtime x5  ·  Data 5GB x2  ·  +1", isPaid: true),
            OrderItem(orderId: "ORD-10546", traderName: "Zulu Corner", initials: "ZC",
                      location: "Pinetown, Durban", amount: "R12,450.00", payment: "Cash",
                      time: "9 Jun 2026, 11:48", status: "new",
                      relativeTime: "1 hour ago",
                      productSummary: "Electricity x8  ·  Airtime x20", isPaid: false),
            OrderItem(orderId: "ORD-10545", traderName: "Sipho Spaza Store", initials: "SS",
                      location: "Durban Central", amount: "R2,890.00", payment: "Credit",
                      time: "9 Jun 2026, 10:20", status: "processing"),
            OrderItem(orderId: "ORD-10542", traderName: "Spaza Sunrise", initials: "SS",
                      location: "Umlazi, Durban", amount: "R9,240.00", payment: "Cash",
                      time: "5 Jun 2026, 09:45", status: "delivered")
        ]
    }

    static func inventory() -> [ListItem] {
        [
            ListItem(title: "anokiX Maize Meal 10kg", sku: "AX-MM-10KG", stockCount: 186, stockPercent: 85, badge: "In Stock"),
            ListItem(title: "anokiX Cooking Oil 5L", sku: "AX-CO-5L", stockCount: 42, stockPercent: 35, badge: "Low Stock"),
            ListItem(title: "anokiX Sugar 2kg", sku: "AX-SG-2KG", stockCount: 12, stockPercent: 15, badge: "Low Stock"),
            ListItem(title: "anokiX Rice 10kg", sku: "AX-RC-10KG", stockCount: 0, stockPercent: 0, badge: "Out of Stock"),
            ListItem(title: "anokiX Flour 5kg", sku: "AX-FL-5KG", stockCount: 88, stockPercent: 70, badge: "In Stock"),
            ListItem(title: "Sunlight 2kg", sku: "AX-SL-2KG", stockCount: 5, stockPercent: 8, badge: "Low Stock"),
            ListItem(title: "Coca-Cola 2L", sku: "AX-CC-2L", stockCount: 0, stockPercent: 0, badge: "Out of Stock"),
            ListItem(title: "anokiX Spring Water 5L", sku: "AX-SW-5L", stockCount: 134, stockPercent: 90, badge: "In Stock"),
            ListItem(title: "anokiX Milk Powder 400g", sku: "AX-MP-400G", stockCount: 3, stockPercent: 5, badge: "Expired"),
            ListItem(title: "anokiX Tomato Paste 410g", sku: "AX-TP-410G", stockCount: 0, stockPercent: 0, badge: "Expired")
        ]
    }

    static func storeItems() -> [StoreItem] {
        [
            StoreItem(id: "s1", name: "Mabopane Super Store", address: "1239 Block VV, Mabopane, Pretoria", followerCount: 48, reviewCount: 12, status: "Active", area: "Gauteng"),
            StoreItem(id: "s2", name: "Emthombeni Super Store", address: "456 Block C, Emthombeni, Durban", followerCount: 36, reviewCount: 8, status: "Active", area: "KZN"),
            StoreItem(id: "s3", name: "Rockingham Super Store", address: "981 Block 6, Rockingham, Durban", followerCount: 52, reviewCount: 21, status: "Active", area: "KZN"),
            StoreItem(id: "s4", name: "Zandile's Value Store", address: "78 Main Road, Pinetown, Durban", followerCount: 29, reviewCount: 5, status: "Active", area: "KZN"),
            StoreItem(id: "s5", name: "Township Store", address: "12 Vilakazi St, Soweto, Johannesburg", followerCount: 41, reviewCount: 17, status: "Active", area: "Gauteng"),
            StoreItem(id: "s6", name: "Zwelisha Community Store", address: "5 Church Street, Verulam, KZN", followerCount: 22, reviewCount: 3, status: "Inactive", area: "KZN")
        ]
    }

    static func productItems() -> [ProductItem] {
        [
            ProductItem(id: "p1", name: "anokiX Maize Meal 10kg", sku: "AX-MM-10KG", category: "Staples", price: "R 112.50", stockStatus: "In Stock"),
            ProductItem(id: "p2", name: "anokiX Cooking Oil 5L", sku: "AX-CO-5L", category: "Staples", price: "R 89.99", stockStatus: "In Stock"),
            ProductItem(id: "p3", name: "anokiX Sugar 2kg", sku: "AX-SG-2KG", category: "Staples", price: "R 34.50", stockStatus: "Low Stock"),
            ProductItem(id: "p4", name: "anokiX Rice 10kg", sku: "AX-RC-10KG", category: "Staples", price: "R 145.00", stockStatus: "Out of Stock"),
            ProductItem(id: "p5", name: "anokiX Spring Water 5L", sku: "AX-SW-5L", category: "Beverages", price: "R 28.00", stockStatus: "In Stock"),
            ProductItem(id: "p6", name: "Simba Chips 125g", sku: "AX-SC-125G", category: "Snacks", price: "R 12.99", stockStatus: "In Stock")
        ]
    }

    static let filterAreas = ["All Areas", "Gauteng", "KZN", "Limpopo", "Mpumalanga", "Eastern Cape"]
    static let filterSegments = ["All Segments", "Spaza", "Reseller", "Trader"]
    static let filterDrivers = ["All Drivers", "Thabo M.", "Sipho N.", "John K.", "Peter S."]

    // Traders list filters → API ?status= and ?credit_status= (Android parity).
    static let filterStatus = ["All Status", "New", "Active", "Inactive", "Suspended"]
    static let filterCreditStatus = ["All Credit Status", "Good Standing", "Warning", "Overdue", "Suspended"]
    static let filterRegistrationStatus = ["All Status", "Draft", "Pending Approval", "Approved", "Rejected", "Needs Information"]

    static func moreMenuItems() -> [MenuItem] {
        [
            MenuItem(key: "stores", title: "Stores", icon: "ic_stores"),
            MenuItem(key: "traders", title: "Traders", icon: "ic_traders"),
            MenuItem(key: "products", title: "Products", icon: "ic_products"),
            MenuItem(key: "promotions", title: "Ads & Promotions", icon: "ic_promotions"),
            MenuItem(key: "finances", title: "Finances", icon: "ic_finances"),
            MenuItem(key: "wallet", title: "anokiX wallet", icon: "ic_wallet", subtitle: "Powered by IMB"),
            MenuItem(key: "airtime", title: "Airtime & VAS", icon: "ic_vas", subtitle: "Powered by Limes"),
            MenuItem(key: "reports", title: "Reports", icon: "ic_reports"),
            MenuItem(key: "deliveries", title: "Deliveries", icon: "ic_deliveries"),
            MenuItem(key: "returns", title: "Returns", icon: "ic_returns"),
            MenuItem(key: "notifications", title: "Notifications", icon: "ic_notifications"),
            MenuItem(key: "settings", title: "Settings", icon: "ic_settings")
        ]
    }

    /// Drawer navigation, in the order agreed for the new design (New-Design/Menu).
    /// "card_machine", "warehouse_staff" and "support" have no screens yet — the drawer
    /// handler answers those with a "coming soon" message.
    static func drawerMenuItems() -> [MenuItem] {
        [
            MenuItem(key: "home", title: "Dashboard", icon: "ic_dashboard"),
            MenuItem(key: "stores", title: "Stores", icon: "ic_stores"),
            MenuItem(key: "products", title: "Products", icon: "ic_shopping_bag"),
            MenuItem(key: "promotions", title: "Ads & Promotions", icon: "ic_promotions"),
            MenuItem(key: "orders", title: "Orders", icon: "ic_orders"),
            MenuItem(key: "deliveries", title: "Deliveries", icon: "ic_deliveries"),
            MenuItem(key: "returns", title: "Returns", icon: "ic_returns"),
            MenuItem(key: "inventory", title: "Inventory", icon: "ic_inventory"),
            MenuItem(key: "finances", title: "Finances", icon: "ic_finances"),
            MenuItem(key: "card_machine", title: "Card Machine", icon: "ic_card", subtitle: "Powered by PayCloud"),
            MenuItem(key: "wallet", title: "anokiX wallet", icon: "ic_wallet", subtitle: "Powered by IMB"),
            MenuItem(key: "airtime", title: "Airtime & VAS", icon: "ic_vas", subtitle: "Powered by Limes"),
            MenuItem(key: "reports", title: "Reports", icon: "ic_reports"),
            MenuItem(key: "traders", title: "Traders", icon: "ic_traders"),
            MenuItem(key: "warehouse_staff", title: "Warehouse Staff", icon: "ic_person_add",
                     subtitle: "Who can pick and pack"),
            MenuItem(key: "notifications", title: "Notifications", icon: "ic_notifications"),
            MenuItem(key: "settings", title: "Settings", icon: "ic_settings"),
            MenuItem(key: "support", title: "Support Centre", icon: "ic_headset")
        ]
    }

    // Dashboard KPI fallbacks
    static let kpiTitles = ["Pending Orders", "Out for Delivery", "Low Stock", "New Traders"]
    static let kpiValues = ["126", "342", "32", "154"]
    static let kpiIcons = ["ic_shopping_bag", "ic_deliveries", "ic_warning_box", "ic_traders"]
    static let kpiIconBackgrounds = [AppColors.warningBg, AppColors.purpleLight, AppColors.dangerBg, AppColors.successBg]
    static let kpiValueColors = [AppColors.warning, AppColors.purplePrimary, AppColors.danger, AppColors.success]
    static let kpiIconTints = [AppColors.warning, AppColors.purplePrimary, AppColors.danger, AppColors.success]

    /// Placeholder summary KPI cards shown before the dashboard API responds.
    static var fallbackSummaryCards: [DashboardData.SummaryCard] {
        func card(_ key: String, _ label: String, _ value: String, _ trend: String,
                  _ color: String, _ spark: [Double]) -> DashboardData.SummaryCard {
            DashboardData.SummaryCard(
                key: key, label: label, value: nil, formattedValue: value, isMoney: nil,
                trend: DashboardData.Trend(direction: "up", percentage: nil, label: trend),
                compareLabel: nil, sparkline: spark, color: color)
        }
        return [
            card("total_revenue", "Total Revenue", "R0.00", "↑ 0.0%", "purple",
                 [4.2, 3.8, 5.1, 4.7, 5.6, 4.9, 6.2]),
            card("total_orders", "Total Orders", "0", "↑ 0.0%", "blue",
                 [9.8, 10.2, 10.5, 11, 11.5, 12, 12.86]),
            card("active_traders", "Active Traders", "0", "↑ 0.0%", "green",
                 [21, 21.5, 22, 22.8, 23.2, 23.8, 24.53]),
            card("products_sold", "Products Sold", "0", "↑ 0.0%", "orange",
                 [20.1, 20.8, 21.4, 22, 22.9, 23.6, 24.56])
        ]
    }
}
