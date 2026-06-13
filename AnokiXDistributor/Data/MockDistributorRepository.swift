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
        NotificationPreference(key: "order_alerts", title: "Order Alerts", subtitle: "Get notified about new orders", enabled: true),
        NotificationPreference(key: "low_stock", title: "Low Stock", subtitle: "Get notified when stock is low", enabled: true),
        NotificationPreference(key: "delivery_updates", title: "Delivery Updates", subtitle: "Get notified about delivery status", enabled: true)
    ]

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
            PromotionItem(id: "p1", title: "Boost Sales Campaign", status: "Active", impressions: "245,678", ctr: "3.45%", bannerColor: AppColors.purpleDark, bannerLabel: "BOOST SALES\nEARN MORE"),
            PromotionItem(id: "p2", title: "Max Power Launch", status: "Active", impressions: "182,450", ctr: "2.87%", bannerColor: AppColors.purplePrimary, bannerLabel: "MAX POWER\nLAUNCH"),
            PromotionItem(id: "p3", title: "Summer Mega Deals", status: "Paused", impressions: "81,203", ctr: "1.52%", bannerColor: AppColors.warning, bannerLabel: "SUMMER\nMEGA DEALS")
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

    func getNotificationPreferences() -> [NotificationPreference] { preferences }

    func saveNotificationPreferences(_ updated: [NotificationPreference]) { preferences = updated }
}
