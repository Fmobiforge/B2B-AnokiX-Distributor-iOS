import Foundation

// Codable ports of network/dto/*.java. The shared decoder uses
// `.convertFromSnakeCase`, so Swift camelCase properties map to the JSON snake_case keys.

// MARK: - Flexible JSON helpers

enum JSONDecoding {
    static func flexString<K: CodingKey>(_ c: KeyedDecodingContainer<K>, key: K) -> String? {
        if let value = try? c.decode(String.self, forKey: key) { return value }
        if let value = try? c.decode(Int64.self, forKey: key) { return String(value) }
        if let value = try? c.decode(Int.self, forKey: key) { return String(value) }
        if let value = try? c.decode(Double.self, forKey: key) {
            return value.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(value)) : String(value)
        }
        return nil
    }
}

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

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = JSONDecoding.flexString(c, key: .id)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            businessName = try c.decodeIfPresent(String.self, forKey: .businessName)
            tradingName = try c.decodeIfPresent(String.self, forKey: .tradingName)
            ownerFullName = try c.decodeIfPresent(String.self, forKey: .ownerFullName)
            phoneNumber = JSONDecoding.flexString(c, key: .phoneNumber)
                ?? JSONDecoding.flexString(c, key: .businessPhoneNumber)
            countryCode = try c.decodeIfPresent(String.self, forKey: .countryCode)
            email = try c.decodeIfPresent(String.self, forKey: .businessEmail)
            address = try c.decodeIfPresent(String.self, forKey: .address)
            storeType = try c.decodeIfPresent(String.self, forKey: .traderType)
            traderCode = try c.decodeIfPresent(String.self, forKey: .traderCode)
            status = try c.decodeIfPresent(String.self, forKey: .status)
            registrationStatus = try c.decodeIfPresent(String.self, forKey: .registrationStatus)
            creditStatus = try c.decodeIfPresent(String.self, forKey: .creditStatus)
        }

        private enum CodingKeys: String, CodingKey {
            case id, name, businessName, tradingName, ownerFullName
            case phoneNumber, businessPhoneNumber, countryCode
            case email, businessEmail, address
            case storeType, traderType, traderCode, status
            case registrationStatus, creditStatus
        }
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
        let pendingApprovalTraders: Int?
        let pendingApprovalTradersPercentLabel: String?
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: RootKeys.self)
        if container.contains(.store) {
            store = try container.decodeIfPresent(Store.self, forKey: .store)
        } else {
            store = try Store(from: decoder)
        }
    }

    private enum RootKeys: String, CodingKey { case store }

    struct Store: Decodable {
        let id: Int64?
        let name: String?
        let address: String?
        let street: String?
        let tagList: String?
        let contactNumber: String?
        let storeDescription: String?
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

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decodeIfPresent(Int64.self, forKey: .id)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            address = try c.decodeIfPresent(String.self, forKey: .address)
            street = try c.decodeIfPresent(String.self, forKey: .street)
            tagList = try c.decodeIfPresent(String.self, forKey: .tagList)
            contactNumber = try c.decodeIfPresent(String.self, forKey: .contactNumber)
            storeDescription = try c.decodeIfPresent(String.self, forKey: .storeDescription)
            buildingNumber = try c.decodeIfPresent(String.self, forKey: .buildingNumber)
            vatNumber = try c.decodeIfPresent(String.self, forKey: .vatNumber)
            addressStreet1 = try c.decodeIfPresent(String.self, forKey: .addressStreet1)
            addressStreet2 = try c.decodeIfPresent(String.self, forKey: .addressStreet2)
            addressSuburb = try c.decodeIfPresent(String.self, forKey: .addressSuburb)
            addressCity = try c.decodeIfPresent(String.self, forKey: .addressCity)
            addressState = try c.decodeIfPresent(String.self, forKey: .addressState)
            addressCountry = try c.decodeIfPresent(String.self, forKey: .addressCountry)
            addressPostalCode = try c.decodeIfPresent(String.self, forKey: .addressPostalCode)
            latitude = Self.decodeFlexibleDouble(c, .latitude)
            longitude = Self.decodeFlexibleDouble(c, .longitude)
            isClickCollect = Self.decodeFlexibleBool(c, .isClickCollect)
            isClickDeliver = Self.decodeFlexibleBool(c, .isClickDeliver)
            workingDays = try c.decodeIfPresent(String.self, forKey: .workingDays)
            tradingTime = try c.decodeIfPresent(String.self, forKey: .tradingTime)
            timeZone = try c.decodeIfPresent(String.self, forKey: .timeZone)
            timeOffset = Self.decodeFlexibleInt64(c, .timeOffset)
            currencyId = Self.decodeFlexibleString(c, .currencyId)
            followerCount = Self.decodeFlexibleInt(c, .followerCount)
            reviewCount = Self.decodeFlexibleInt(c, .reviewCount)
        }

        private enum CodingKeys: String, CodingKey {
            case id, name, address, street, tagList, contactNumber
            case storeDescription = "description"
            case buildingNumber, vatNumber
            case addressStreet1, addressStreet2, addressSuburb, addressCity
            case addressState, addressCountry, addressPostalCode
            case latitude, longitude, isClickCollect, isClickDeliver
            case workingDays, tradingTime, timeZone, timeOffset, currencyId
            case followerCount, reviewCount
        }

        private static func decodeFlexibleBool(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Bool? {
            if let value = try? c.decode(Bool.self, forKey: key) { return value }
            if let value = try? c.decode(Int.self, forKey: key) { return value != 0 }
            if let value = try? c.decode(String.self, forKey: key) {
                return value == "1" || value.lowercased() == "true"
            }
            return nil
        }

        private static func decodeFlexibleString(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
            if let value = try? c.decode(String.self, forKey: key) { return value }
            if let value = try? c.decode(Int64.self, forKey: key) { return String(value) }
            return nil
        }

        private static func decodeFlexibleInt(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
            if let value = try? c.decode(Int.self, forKey: key) { return value }
            if let value = try? c.decode(String.self, forKey: key) { return Int(value) }
            return nil
        }

        private static func decodeFlexibleInt64(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int64? {
            if let value = try? c.decode(Int64.self, forKey: key) { return value }
            if let value = try? c.decode(String.self, forKey: key) { return Int64(value) }
            return nil
        }

        private static func decodeFlexibleDouble(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
            if let value = try? c.decode(Double.self, forKey: key) { return value }
            if let value = try? c.decode(String.self, forKey: key) { return Double(value) }
            return nil
        }
    }
}

// MARK: - Reference data (Create Trader wizard lookups)

struct ReferenceData: Decodable {
    let productCategories: [ProductCategory]?
    let distributors: [Distributor]?
    let traderTypes: [TraderType]?

    struct ProductCategory: Decodable {
        let id: Int64
        let title: String?
        let slug: String?
        let parentId: Int64?
    }

    struct Distributor: Decodable {
        let id: Int64
        let distributorCode: String?
        let companyLegalName: String?
        let tradingName: String?
        let companyEmail: String?
        let companyPhoneNumber: String?
        let address: String?

        /// Best label for a distributor in a picker.
        var displayName: String {
            if let t = tradingName, !t.trimmingCharacters(in: .whitespaces).isEmpty { return t }
            return companyLegalName ?? distributorCode ?? "Distributor #\(id)"
        }
    }

    struct TraderType: Decodable {
        let id: Int64
        let name: String?
        let slug: String?
        let icon: String?
        let sortOrder: Int?
    }
}

// MARK: - Create Trader

struct CreateTraderData: Decodable {
    let trader: Trader?

    struct Trader: Decodable {
        let id: String?
        let businessName: String?
        let tradingName: String?
        let registrationStatus: String?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = JSONDecoding.flexString(c, key: .id)
            businessName = try c.decodeIfPresent(String.self, forKey: .businessName)
            tradingName = try c.decodeIfPresent(String.self, forKey: .tradingName)
            registrationStatus = try c.decodeIfPresent(String.self, forKey: .registrationStatus)
        }

        private enum CodingKeys: String, CodingKey {
            case id, businessName, tradingName, registrationStatus
        }
    }
}

// MARK: - Address autocomplete (Google proxy)

struct AutocompleteData: Decodable {
    let status: String?
    let predictions: [Prediction]?

    struct Prediction: Decodable {
        let description: String?
        let placeId: String?
    }
}

struct CoordinateData: Decodable {
    let latitude: Double?
    let longitude: Double?
    let formattedAddress: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        latitude = CoordinateData.flexDouble(c, .latitude)
        longitude = CoordinateData.flexDouble(c, .longitude)
        formattedAddress = try c.decodeIfPresent(String.self, forKey: .formattedAddress)
    }

    private enum CodingKeys: String, CodingKey {
        case latitude, longitude, formattedAddress
    }

    private static func flexDouble(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let v = try? c.decode(Double.self, forKey: key) { return v }
        if let v = try? c.decode(String.self, forKey: key) { return Double(v) }
        return nil
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
