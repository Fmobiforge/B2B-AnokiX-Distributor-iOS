import Foundation

// Codable ports of network/dto/*.java. The shared decoder uses
// `.convertFromSnakeCase`, so Swift camelCase properties map to the JSON snake_case keys.

// MARK: - Envelope

struct ApiResponse<T: Decodable>: Decodable {
    let status: Bool
    let message: String?
    let data: T?
}

// MARK: - Login

struct LoginData: Decodable {
    let token: String?
    let user: User?
    let portalType: String?

    struct User: Decodable {
        let id: String?
        let firstName: String?
        let lastName: String?
        let email: String?
        let phoneNumber: String?
        let roleType: String?
        let roleLabel: String?
    }
}

// MARK: - Dashboard

struct DashboardData: Decodable {
    let dashboard: Dashboard?

    struct Dashboard: Decodable {
        let meta: Meta?
        let overview: [OverviewItem]?
        let revenueOverview: RevenueOverview?
        let topSellingCategories: TopCategories?
        let recentOrders: RecentOrders?
    }
    struct Meta: Decodable {
        let dateRangeLabel: String?
        let comparePeriodLabel: String?
    }
    struct OverviewItem: Decodable {
        let key: String?
        let label: String?
        let value: Int64?
    }
    struct RevenueOverview: Decodable {
        let formattedTotal: String?
        let trend: Trend?
        let chart: Chart?
    }
    struct Trend: Decodable {
        let direction: String?
        let percentage: Double?
        let label: String?
    }
    struct Chart: Decodable {
        let labels: [String]?
        let values: [Double]?
    }
    struct TopCategories: Decodable {
        let title: String?
        let items: [CategoryItem]?
    }
    struct CategoryItem: Decodable {
        let name: String?
        let formattedAmount: String?
        let percentage: Double?
        let color: String?
    }
    struct RecentOrders: Decodable {
        let title: String?
        let items: [RecentOrder]?
    }
    struct RecentOrder: Decodable {
        let orderId: String?
        let trader: String?
        let formattedAmount: String?
        let statusLabel: String?
        let statusColor: String?
        let formattedDate: String?
    }
}

// MARK: - Inventory summary

struct InventorySummaryData: Decodable {
    let summary: Summary?

    struct Summary: Decodable {
        let totalStockValue: Double?
        let totalUnits: Int64?
        let lowStockCount: Int?
        let outOfStockCount: Int?
        let movementsThisWeek: Int?
    }
}

// MARK: - Products

struct ProductsData: Decodable {
    let products: [Product]?
    let totalProducts: Int?
    let activeProducts: Int?
    let outOfStock: Int?
    let lowStock: Int?

    struct Product: Decodable {
        let id: String?
        let name: String?
        let sku: String?
        let barcode: String?
        let sellingPrice: String?
        let unitCost: String?
        let stock: String?
        let status: String?
        let tagList: String?
        let imageUrl: String?
        let category: Category?
        let brand: Brand?
    }
    struct Category: Decodable {
        let id: Int64?
        let title: String?
    }
    struct Brand: Decodable {
        let id: Int64?
        let name: String?
    }
}

// MARK: - Traders

struct TradersData: Decodable {
    let traders: [Trader]?
    let total: Int?
    let summary: Summary?

    struct Trader: Decodable {
        let id: String?
        let name: String?
        let businessName: String?
        let tradingName: String?
        let ownerFullName: String?
        let phoneNumber: String?
        let countryCode: String?
        let email: String?
        let address: String?
        let storeType: String?
        let traderCode: String?
        let status: String?
        let registrationStatus: String?
        let creditStatus: String?
    }
    struct Summary: Decodable {
        let totalTraders: Int?
        let totalTradersMonthChangeLabel: String?
        let activeTraders: Int?
        let activeTradersPercentLabel: String?
        let newThisMonth: Int?
        let newThisMonthChangeLabel: String?
        let highValueTraders: Int?
        let highValueTradersPercentLabel: String?
    }
}

// MARK: - Stores

struct StoresData: Decodable {
    let totalCount: Int?
    let keyword: String?
    let stores: [Store]?

    struct Store: Decodable {
        let id: Int64
        let name: String?
        let address: String?
        let tagList: String?
        let isClickCollect: Bool?
        let isClickDeliver: Bool?
        let followerCount: Int?
        let reviewCount: Int?
    }
}

struct StoreDetailData: Decodable {
    let store: Store?

    struct Store: Decodable {
        let id: Int64?
        let name: String?
        let address: String?
        let street: String?
        let tagList: String?
        let contactNumber: String?
        let description: String?
        let buildingNumber: String?
        let vatNumber: String?
        let addressStreet1: String?
        let addressStreet2: String?
        let addressSuburb: String?
        let addressCity: String?
        let addressState: String?
        let addressCountry: String?
        let addressPostalCode: String?
        let latitude: Double?
        let longitude: Double?
        let isClickCollect: Bool?
        let isClickDeliver: Bool?
        let workingDays: String?
        let tradingTime: String?
        let timeZone: String?
        let timeOffset: Int64?
        let currencyId: String?
        let followerCount: Int?
        let reviewCount: Int?
    }
}

// MARK: - Base info (currencies + timezones)

struct BaseInfoData: Decodable {
    let currencies: [Currency]?
    let timezones: [Timezone]?

    struct Currency: Decodable {
        let id: String?
        let code: String?
        let name: String?
        let symbol: String?
    }
    struct Timezone: Decodable {
        let name: String?
        let region: String?
        let label: String?
        let timeZone: String?
        let timeOffset: Int64?
    }
}
