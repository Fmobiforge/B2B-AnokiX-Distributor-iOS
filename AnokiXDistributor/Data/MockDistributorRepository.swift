import UIKit

/// Port of data/MockDistributorRepository.java — in-memory sample data for the
/// secondary screens, including the mutable notification read-state + preferences.
final class MockDistributorRepository: DistributorRepository {

    private let returns: [ReturnItem] = [
        ReturnItem(id: "RET-10032", traderName: "Zim Wholesale", reason: "Damaged Goods", amount: "R4,560.00", timestamp: "21 May 2025 • 10:30 AM", status: "pending"),
        ReturnItem(id: "RET-10028", traderName: "Township Store", reason: "Expired Products", amount: "R560.00", timestamp: "20 May 2025 • 14:15 PM", status: "pending"),
        ReturnItem(id: "RET-10025", traderName: "Banim Wholesale", reason: "Wrong Items", amount: "R3,780.00", timestamp: "19 May 2025 • 09:00 AM", status: "approved"),
        ReturnItem(id: "RET-10020", traderName: "Spaza Sunrise", reason: "Damaged Packaging", amount: "R1,980.00", timestamp: "18 May 2025 • 16:45 PM", status: "rejected")
    ]

    private var notifications: [NotificationItem] = [
        NotificationItem(id: "n1", title: "New order received", message: "Order #ORD-10456 has been placed by Sunrise Traders.", relativeTime: "2m ago", type: "orders", icon: "ic_orders", iconBg: AppColors.purpleLight, iconTint: AppColors.purplePrimary, actionLabel: "View order", unread: true),
        NotificationItem(id: "n2", title: "Low stock alert", message: "5 products are low on stock. Please restock soon.", relativeTime: "1h ago", type: "inventory", icon: "ic_warning_box", iconBg: AppColors.warningBg, iconTint: AppColors.warning, actionLabel: "View items", unread: true),
        NotificationItem(id: "n3", title: "Delivery delayed", message: "Delivery for order #ORD-10432 has been delayed.", relativeTime: "3h ago", type: "deliveries", icon: "ic_deliveries", iconBg: AppColors.dangerBg, iconTint: AppColors.danger, actionLabel: "View order", unread: true),
        NotificationItem(id: "n4", title: "Order delivered", message: "Order #ORD-10428 has been delivered successfully.", relativeTime: "Yesterday, 6:20 PM", type: "orders", icon: "ic_check_green", iconBg: AppColors.successBg, iconTint: AppColors.success, actionLabel: "", unread: false)
    ]

    private var preferences: [NotificationPreference] = [
        NotificationPreference(key: "order_alerts", title: "Order Alerts", subtitle: "Get notified when new orders are placed.", enabled: true),
        NotificationPreference(key: "low_stock", title: "Low Stock Alerts", subtitle: "Receive alerts when products fall below minimum stock.", enabled: true),
        NotificationPreference(key: "delivery_updates", title: "Delivery Updates", subtitle: "Track delivery status changes and delays.", enabled: true),
        NotificationPreference(key: "finance_reminders", title: "Finance Reminders", subtitle: "Reminders for overdue invoices and payments.", enabled: true),
        NotificationPreference(key: "report_ready", title: "Report Ready", subtitle: "Notify when scheduled reports are generated.", enabled: false)
    ]

    private var profileSettings = ProfileSettings(
        firstName: "Chang", lastName: "CongCong", email: "test@gmail.com", phone: "", companyName: "comp1")
    private var businessSettings = BusinessSettings(
        businessName: "comp1", registrationNumber: "", vatNumber: "ca",
        address: "Beştepe, AŞTİ, Yenimahalle/Ankara, Türkiye", city: "",
        latitude: 39.9306, longitude: 32.7439)
    private var appPreferences = AppPreferences(
        language: "English", currency: "South African Rand (ZAR)",
        timezone: "Africa/Johannesburg", dateFormat: "19 May 2024")

    func getReturns(statusFilter: String) -> [ReturnItem] {
        if statusFilter == "all" { return returns }
        return returns.filter { $0.status.caseInsensitiveCompare(statusFilter) == .orderedSame }
    }

    func getReturnSummaryCounts() -> [String: Int] {
        ["pending": 12, "approved": 18, "rejected": 4]
    }

    func getNotifications(filter: String) -> [NotificationItem] {
        switch filter {
        case "unread": return notifications.filter { $0.unread }
        case "orders": return notifications.filter { $0.type == "orders" }
        default: return notifications
        }
    }

    func getUnreadNotificationCount() -> Int {
        notifications.filter { $0.unread }.count
    }

    func markAllNotificationsRead() {
        notifications = notifications.map {
            NotificationItem(id: $0.id, title: $0.title, message: $0.message, relativeTime: $0.relativeTime,
                             type: $0.type, icon: $0.icon, iconBg: $0.iconBg, iconTint: $0.iconTint,
                             actionLabel: $0.actionLabel, unread: false)
        }
    }

    func getPromotions() -> [PromotionItem] {
        [
            PromotionItem(id: "p1", name: "Boost Sales Campaign", campaignType: "best_deal", typeLabel: "Best Deal", status: "active", statusLabel: "Active", dateRange: "15 Jun – 30 Jun 2026", budget: "R3,000", reach: "245,678", clicks: "8,472", ctr: "3.45%"),
            PromotionItem(id: "p2", name: "Max Power Launch", campaignType: "promotion", typeLabel: "Promotion", status: "active", statusLabel: "Active", dateRange: "10 Jun – 24 Jun 2026", budget: "R5,000", reach: "182,450", clicks: "5,237", ctr: "2.87%"),
            PromotionItem(id: "p3", name: "Summer Mega Deals", campaignType: "exclusive_deal", typeLabel: "Exclusive Deal", status: "paused", statusLabel: "Paused", dateRange: "01 Jun – 14 Jun 2026", budget: "R2,200", reach: "81,203", clicks: "1,234", ctr: "1.52%")
        ]
    }

    func getFinanceSummaries() -> [FinanceSummary] {
        [
            FinanceSummary(title: "Revenue This Month", amount: "R2.4M", trend: "↑ 12.5% vs last month", trendUp: true, valueColor: AppColors.textPrimary, trendColor: AppColors.purplePrimary),
            FinanceSummary(title: "Invoices Paid", amount: "R1.8M", trend: "↑ 8.3% vs last month", trendUp: true, valueColor: AppColors.textPrimary, trendColor: AppColors.success),
            FinanceSummary(title: "Pending Payments", amount: "R620K", trend: "↓ 4.6% vs last month", trendUp: false, valueColor: AppColors.textPrimary, trendColor: AppColors.warning)
        ]
    }

    func getFinanceTransactions(typeFilter: String) -> [FinanceTransaction] {
        let all = [
            FinanceTransaction(id: "f1", title: "Payment from Mega Traders", invoiceId: "INV-10023", date: "24 May 2025", amount: "+R250,000", isIncome: true, status: "Paid", icon: "ic_document"),
            FinanceTransaction(id: "f2", title: "Stock Purchase - May", invoiceId: "EXP-20015", date: "24 May 2025", amount: "-R75,000", isIncome: false, status: "Paid", icon: "ic_package"),
            FinanceTransaction(id: "f3", title: "Payment from Quick Retail", invoiceId: "INV-10020", date: "23 May 2025", amount: "+R180,000", isIncome: true, status: "Paid", icon: "ic_document"),
            FinanceTransaction(id: "f4", title: "Transport Fuel", invoiceId: "EXP-20012", date: "22 May 2025", amount: "-R12,500", isIncome: false, status: "Paid", icon: "ic_deliveries"),
            FinanceTransaction(id: "f5", title: "Payment from Queenland Store", invoiceId: "INV-10018", date: "21 May 2025", amount: "+R95,000", isIncome: true, status: "Paid", icon: "ic_document")
        ]
        switch typeFilter {
        case "income": return all.filter { $0.isIncome }
        case "expenses": return all.filter { !$0.isIncome }
        default: return all
        }
    }

    func getReportTypes() -> [ReportTypeItem] {
        [
            ReportTypeItem(id: "sales", title: "Sales Report", description: "View sales performance", icon: "ic_reports"),
            ReportTypeItem(id: "inventory", title: "Inventory Report", description: "Track stock levels", icon: "ic_package"),
            ReportTypeItem(id: "traders", title: "Traders Report", description: "Analyze trader activity", icon: "ic_traders"),
            ReportTypeItem(id: "finance", title: "Finance Report", description: "Financial summaries", icon: "ic_finance_report")
        ]
    }

    func getRecentReports() -> [ReportHistoryItem] {
        [
            ReportHistoryItem(id: "r1", name: "Sales Report - May 2025", generatedDate: "24 May 2025", format: "PDF"),
            ReportHistoryItem(id: "r2", name: "Inventory Report - May 2025", generatedDate: "24 May 2025", format: "PDF"),
            ReportHistoryItem(id: "r3", name: "Traders Report - May 2025", generatedDate: "23 May 2025", format: "PDF"),
            ReportHistoryItem(id: "r4", name: "Finance Report - May 2025", generatedDate: "23 May 2025", format: "PDF"),
            ReportHistoryItem(id: "r5", name: "Sales Report - April 2025", generatedDate: "30 Apr 2025", format: "PDF")
        ]
    }

    func getDeliveries(statusFilter: String) -> [DeliveryItem] {
        let all = [
            DeliveryItem(id: "DL-10045", traderName: "Mega Traders", driverName: "Thabo M.", eta: "Today, 15:30 – 16:00", status: "in_transit"),
            DeliveryItem(id: "DL-10044", traderName: "Quick Retail", driverName: "Sipho N.", eta: "24 May 2025, 11:20", status: "delivered"),
            DeliveryItem(id: "DL-10043", traderName: "Queenland Store", driverName: "John K.", eta: "Today, 17:00 – 17:30", status: "in_transit"),
            DeliveryItem(id: "DL-10042", traderName: "Rockingham Store", driverName: "Peter S.", eta: "ETA Tomorrow", status: "delayed")
        ]
        if statusFilter == "all" { return all }
        return all.filter { $0.status.caseInsensitiveCompare(statusFilter) == .orderedSame }
    }

    func getSettingsProfile() -> SettingsProfile {
        SettingsProfile(name: "Cong Distributor", email: "congdistributor@gmail.com", initials: "C", verified: true)
    }

    func getSettingsMenuEntries() -> [SettingsMenuEntry] {
        [
            SettingsMenuEntry(key: "profile", title: "Profile", subtitle: "", icon: "ic_person"),
            SettingsMenuEntry(key: "business", title: "Business", subtitle: "", icon: "ic_briefcase"),
            SettingsMenuEntry(key: "notifications", title: "Notifications", subtitle: "", icon: "ic_notifications"),
            SettingsMenuEntry(key: "security", title: "Security", subtitle: "", icon: "ic_shield"),
            SettingsMenuEntry(key: "preferences", title: "Preferences", subtitle: "", icon: "ic_tune")
        ]
    }

    func getProfileSettings() -> ProfileSettings { profileSettings }

    func saveProfileSettings(_ settings: ProfileSettings) { profileSettings = settings }

    func getBusinessSettings() -> BusinessSettings { businessSettings }

    func saveBusinessSettings(_ settings: BusinessSettings) { businessSettings = settings }

    func changePassword(current: String, newPassword: String, confirm: String) -> String? {
        if current.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Please enter your current password."
        }
        if newPassword.count < 8 {
            return "New password must be at least 8 characters."
        }
        if newPassword != confirm {
            return "New passwords do not match."
        }
        return nil
    }

    func getAppPreferences() -> AppPreferences { appPreferences }

    func saveAppPreferences(_ preferences: AppPreferences) { appPreferences = preferences }

    func getNotificationPreferences() -> [NotificationPreference] { preferences }

    func saveNotificationPreferences(_ updated: [NotificationPreference]) { preferences = updated }
}
