import UIKit

/// Data-access contract for the distributor screens. Port of data/DistributorRepository.java.
/// Swap `MockDistributorRepository` for an API-backed implementation when endpoints exist.
protocol DistributorRepository {
    func getReturns(statusFilter: String) -> [ReturnItem]
    func getReturnSummaryCounts() -> [String: Int]
    func getNotifications(filter: String) -> [NotificationItem]
    func getUnreadNotificationCount() -> Int
    func markAllNotificationsRead()
    func getPromotions() -> [PromotionItem]
    func getFinanceSummaries() -> [FinanceSummary]
    func getFinanceTransactions(typeFilter: String) -> [FinanceTransaction]
    func getReportTypes() -> [ReportTypeItem]
    func getRecentReports() -> [ReportHistoryItem]
    func getDeliveries(statusFilter: String) -> [DeliveryItem]
    func getSettingsProfile() -> SettingsProfile
    func getSettingsMenuEntries() -> [SettingsMenuEntry]
    func getNotificationPreferences() -> [NotificationPreference]
    func saveNotificationPreferences(_ preferences: [NotificationPreference])
}

/// Shared accessor — port of data/RepositoryProvider.java.
enum RepositoryProvider {
    private static var repository: DistributorRepository = MockDistributorRepository()
    static func get() -> DistributorRepository { repository }
    static func set(_ impl: DistributorRepository) { repository = impl }
}
