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
        let summaryCards: [SummaryCard]?
        let overview: [OverviewItem]?
        let revenueOverview: RevenueOverview?
        let topSellingCategories: TopCategories?
        let recentOrders: RecentOrders?
    }
    struct Meta: Decodable {
        let dateRangeLabel: String?
        let comparePeriodLabel: String?
        let currency: Currency?
    }
    struct Currency: Decodable {
        let code: String?
        let symbol: String?
    }
    struct SummaryCard: Decodable {
        let key: String?
        let label: String?
        let value: Double?
        let formattedValue: String?
        let isMoney: Bool?
        let trend: Trend?
        let compareLabel: String?
        let sparkline: [Double]?
        let color: String?
    }
    struct OverviewItem: Decodable {
        let key: String?
        let label: String?
        let value: Int64?
        let actionLabel: String?
        let actionRoute: String?
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
        let total: Double?
        let formattedTotal: String?
    }
    struct CategoryItem: Decodable {
        let name: String?
        let amount: Double?
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
        let amount: Double?
        let formattedAmount: String?
        let status: String?
        let statusLabel: String?
        let statusColor: String?
        let date: String?
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
    let total: Int?

    /// The list returns flat rows (category / brand / unit denormalised onto each
    /// record as `*_title` / `*_name`), so values are decoded leniently.
    struct Product: Decodable {
        let id: String?
        let name: String?
        let sku: String?
        let barcode: String?
        let sellingPrice: String?
        let stock: String?
        let stockQuantity: String?
        let status: String?
        let brandName: String?
        let categoryTitle: String?
        let parentCategoryTitle: String?
        let unitName: String?
        let imageUrl: String?
        let primaryProductImageUrl: String?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = JSONDecoding.flexString(c, key: .id)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            sku = try c.decodeIfPresent(String.self, forKey: .sku)
            barcode = JSONDecoding.flexString(c, key: .barcode)
            sellingPrice = JSONDecoding.flexString(c, key: .sellingPrice)
            stock = JSONDecoding.flexString(c, key: .stock)
            stockQuantity = JSONDecoding.flexString(c, key: .stockQuantity)
            status = try c.decodeIfPresent(String.self, forKey: .status)
            brandName = try c.decodeIfPresent(String.self, forKey: .brandName)
            categoryTitle = try c.decodeIfPresent(String.self, forKey: .categoryTitle)
            parentCategoryTitle = try c.decodeIfPresent(String.self, forKey: .parentCategoryTitle)
            unitName = try c.decodeIfPresent(String.self, forKey: .unitName)
            imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
            primaryProductImageUrl = try c.decodeIfPresent(String.self, forKey: .primaryProductImageUrl)
        }

        private enum CodingKeys: String, CodingKey {
            case id, name, sku, barcode, sellingPrice, stock, stockQuantity, status
            case brandName, categoryTitle, parentCategoryTitle, unitName
            case imageUrl, primaryProductImageUrl
        }

        /// Best available stock figure.
        var stockValue: String? { stockQuantity ?? stock }
        /// Best available list thumbnail URL.
        var listImageUrl: String? { imageUrl ?? primaryProductImageUrl }
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
    let brands: [Brand]?
    let productCategories: [ProductCategory]?
    let productUnits: [ProductUnit]?

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
    struct Brand: Decodable {
        let id: Int64
        let name: String?
    }
    struct ProductCategory: Decodable {
        let id: Int64
        let title: String?
        let slug: String?
        let parentId: Int64?
    }
    struct ProductUnit: Decodable {
        let id: String?
        let name: String?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = JSONDecoding.flexString(c, key: .id)
            name = try c.decodeIfPresent(String.self, forKey: .name)
        }
        private enum CodingKeys: String, CodingKey { case id, name }
    }
}

// MARK: - Product detail (get-by-id + create/update response)

struct ProductDetailData: Decodable {
    let product: Product?

    struct Product: Decodable {
        let id: String?
        let name: String?
        let brandId: String?
        let parentCategoryId: String?
        let categoryId: String?
        let barcode: String?
        let sku: String?
        let productDescription: String?

        let unitId: String?
        let unitsPerCase: String?
        let dimType: String?
        let measurementsType: String?
        let weight: String?
        let dimWeight: String?
        let dimLength: String?
        let dimWidth: String?
        let dimHeight: String?

        let sellingPrice: String?
        let costPrice: String?
        let stock: String?
        let stockQuantity: String?
        let reorderLevel: String?
        let promotionPrice: String?
        let promotionStartDate: String?
        let promotionEndDate: String?
        let availableForOrdering: String?
        let status: String?

        let primaryProductImageUrl: String?
        let imageUrl: String?
        let productDatasheetUrl: String?
        let additionalImages: [AdditionalImage]?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = JSONDecoding.flexString(c, key: .id)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            brandId = JSONDecoding.flexString(c, key: .brandId)
            parentCategoryId = JSONDecoding.flexString(c, key: .parentCategoryId)
            categoryId = JSONDecoding.flexString(c, key: .categoryId)
            barcode = JSONDecoding.flexString(c, key: .barcode)
            sku = try c.decodeIfPresent(String.self, forKey: .sku)
            productDescription = try c.decodeIfPresent(String.self, forKey: .productDescription)
            unitId = JSONDecoding.flexString(c, key: .unitId)
            unitsPerCase = JSONDecoding.flexString(c, key: .unitsPerCase)
            dimType = try c.decodeIfPresent(String.self, forKey: .dimType)
            measurementsType = try c.decodeIfPresent(String.self, forKey: .measurementsType)
            weight = JSONDecoding.flexString(c, key: .weight)
            dimWeight = JSONDecoding.flexString(c, key: .dimWeight)
            dimLength = JSONDecoding.flexString(c, key: .dimLength)
            dimWidth = JSONDecoding.flexString(c, key: .dimWidth)
            dimHeight = JSONDecoding.flexString(c, key: .dimHeight)
            sellingPrice = JSONDecoding.flexString(c, key: .sellingPrice)
            costPrice = JSONDecoding.flexString(c, key: .costPrice)
            stock = JSONDecoding.flexString(c, key: .stock)
            stockQuantity = JSONDecoding.flexString(c, key: .stockQuantity)
            reorderLevel = JSONDecoding.flexString(c, key: .reorderLevel)
            promotionPrice = JSONDecoding.flexString(c, key: .promotionPrice)
            promotionStartDate = try c.decodeIfPresent(String.self, forKey: .promotionStartDate)
            promotionEndDate = try c.decodeIfPresent(String.self, forKey: .promotionEndDate)
            availableForOrdering = JSONDecoding.flexString(c, key: .availableForOrdering)
            status = try c.decodeIfPresent(String.self, forKey: .status)
            primaryProductImageUrl = try c.decodeIfPresent(String.self, forKey: .primaryProductImageUrl)
            imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
            productDatasheetUrl = try c.decodeIfPresent(String.self, forKey: .productDatasheetUrl)
            additionalImages = try c.decodeIfPresent([AdditionalImage].self, forKey: .additionalImages)
        }

        private enum CodingKeys: String, CodingKey {
            case id, name, brandId, parentCategoryId, categoryId, barcode, sku
            case productDescription = "description"
            case unitId, unitsPerCase, dimType, measurementsType, weight, dimWeight
            case dimLength, dimWidth, dimHeight
            case sellingPrice, costPrice, stock, stockQuantity, reorderLevel
            case promotionPrice, promotionStartDate, promotionEndDate, availableForOrdering, status
            case primaryProductImageUrl, imageUrl, productDatasheetUrl, additionalImages
        }
    }

    struct AdditionalImage: Decodable {
        let id: String?
        let fileUrl: String?
        let originalName: String?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = JSONDecoding.flexString(c, key: .id)
            fileUrl = try c.decodeIfPresent(String.self, forKey: .fileUrl)
            originalName = try c.decodeIfPresent(String.self, forKey: .originalName)
        }
        private enum CodingKeys: String, CodingKey { case id, fileUrl, originalName }
    }
}

// MARK: - Arbitrary JSON (promotion trader_segments / selected_products)

/// Holds a value of unknown JSON shape, mirroring Gson's `JsonElement` on Android.
/// The promotion `trader_segments` and `selected_products` payloads vary across
/// server builds (id arrays vs. objects, numbers vs. strings, or a JSON-encoded
/// string), so the UI walks this defensively instead of decoding into a fixed type.
indirect enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
        if let v = try? c.decode([JSONValue].self) { self = .array(v); return }
        if let v = try? c.decode(Double.self) { self = .number(v); return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        self = .null
    }

    /// Coerces scalars to a string (numbers lose a trailing ".0"), like reading a
    /// Gson primitive `getAsString()`.
    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .number(let n): return n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(n)
        case .bool(let b): return b ? "1" : "0"
        default: return nil
        }
    }

    var arrayValue: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    var objectValue: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }

    subscript(_ key: String) -> JSONValue? { objectValue?[key] }

    /// Array under `key` (or empty), mirroring Android's `optArray`.
    func array(_ key: String) -> [JSONValue] { self[key]?.arrayValue ?? [] }

    /// String under `key` (or ""), mirroring Android's `jStr`.
    func string(_ key: String) -> String { self[key]?.stringValue ?? "" }

    /// A value sometimes arrives as a JSON-encoded string; parse it into its element
    /// (Android's `unwrap`). Returns `self` when it is already structured JSON.
    var unwrapped: JSONValue {
        if case .string(let s) = self,
           let data = s.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(JSONValue.self, from: data) {
            return parsed
        }
        return self
    }
}

// MARK: - Promotions list (+ KPI summary)

/// data block of GET /api/distributor/promotions — the campaign list plus a
/// `summary` block whose `summaryCards` feed the KPI cards at the top of the screen.
struct PromotionsData: Decodable {
    let promotions: [Promotion]?
    let total: Int?
    let summary: Summary?

    struct Promotion: Decodable {
        let id: String?
        let status: String?
        let campaignType: String?
        let name: String?
        let startDate: String?
        let endDate: String?
        let budget: Double?
        let dailyBudget: Double?
        let productsCost: Double?
        let reach: Double?
        let clicks: Double?
        let revenue: Double?
        let ctr: Double?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = JSONDecoding.flexString(c, key: .id)
            status = try c.decodeIfPresent(String.self, forKey: .status)
            campaignType = try c.decodeIfPresent(String.self, forKey: .campaignType)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            startDate = try c.decodeIfPresent(String.self, forKey: .startDate)
            endDate = try c.decodeIfPresent(String.self, forKey: .endDate)
            budget = Self.flexDouble(c, .budget)
            dailyBudget = Self.flexDouble(c, .dailyBudget)
            productsCost = Self.flexDouble(c, .productsCost)
            reach = Self.flexDouble(c, .reach)
            clicks = Self.flexDouble(c, .clicks)
            revenue = Self.flexDouble(c, .revenue)
            ctr = Self.flexDouble(c, .ctr)
        }

        private enum CodingKeys: String, CodingKey {
            case id, status, campaignType, name, startDate, endDate
            case budget, dailyBudget, productsCost, reach, clicks, revenue, ctr
        }

        private static func flexDouble(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
            if let v = try? c.decode(Double.self, forKey: key) { return v }
            if let v = try? c.decode(String.self, forKey: key) { return Double(v) }
            return nil
        }
    }

    struct Summary: Decodable {
        let currency: Currency?
        let summaryCards: [SummaryCard]?
    }
    struct Currency: Decodable {
        let code: String?
        let symbol: String?
    }
    struct SummaryCard: Decodable {
        let key: String?
        let label: String?
        let formattedValue: String?
        let isMoney: Bool?
        let trend: Trend?
    }
    struct Trend: Decodable {
        let direction: String?
        let percentage: Double?
        let label: String?
    }
}

// MARK: - Promotion detail (create / get-by-id / update response)

/// data block of the single-promotion endpoints, shaped as `data.promotion`.
/// Scalar numerics are decoded leniently to strings so they prefill text fields
/// whether the server emits `5000` or `"5000"`. `traderSegments` / `selectedProducts`
/// are kept as raw `JSONValue` and parsed defensively by the wizard.
struct PromotionDetailData: Decodable {
    let promotion: Promotion?
    /// May be returned at the data root or nested under `Promotion`.
    let stockLogs: [StockLog]?

    struct StockLog: Decodable {
        let productName: String?
        let productId: String?
        let action: String?
        let quantity: String?
        let createdAt: String?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            productName = try c.decodeIfPresent(String.self, forKey: .productName)
            productId = JSONDecoding.flexString(c, key: .productId)
            action = try c.decodeIfPresent(String.self, forKey: .action)
            quantity = JSONDecoding.flexString(c, key: .quantity)
            createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        }

        private enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case productId = "product_id"
            case action, quantity
            case createdAt = "created_at"
        }
    }

    struct Promotion: Decodable {
        let id: String?
        let name: String?
        let campaignType: String?
        let status: String?
        let objective: String?
        let promotionDescription: String?

        let startDate: String?
        let endDate: String?
        let budget: String?
        let dailyBudget: String?
        let productsCost: String?

        let address: String?
        let placeId: String?
        let lat: String?
        let lng: String?

        let bannerFile: Media?
        let videoFile: Media?

        /// Analytics (get-by-id).
        let reach: String?
        let clicks: String?
        let ctr: String?
        let revenue: String?
        let attributedSales: String?

        let traderSegments: JSONValue?
        let selectedProducts: JSONValue?
        let stockLogs: [StockLog]?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = JSONDecoding.flexString(c, key: .id)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            campaignType = try c.decodeIfPresent(String.self, forKey: .campaignType)
            status = try c.decodeIfPresent(String.self, forKey: .status)
            objective = try c.decodeIfPresent(String.self, forKey: .objective)
            promotionDescription = try c.decodeIfPresent(String.self, forKey: .promotionDescription)
            startDate = try c.decodeIfPresent(String.self, forKey: .startDate)
            endDate = try c.decodeIfPresent(String.self, forKey: .endDate)
            budget = JSONDecoding.flexString(c, key: .budget)
            dailyBudget = JSONDecoding.flexString(c, key: .dailyBudget)
            productsCost = JSONDecoding.flexString(c, key: .productsCost)
            address = try c.decodeIfPresent(String.self, forKey: .address)
            placeId = try c.decodeIfPresent(String.self, forKey: .placeId)
            lat = JSONDecoding.flexString(c, key: .lat)
            lng = JSONDecoding.flexString(c, key: .lng)
            bannerFile = try c.decodeIfPresent(Media.self, forKey: .bannerFile)
            videoFile = try c.decodeIfPresent(Media.self, forKey: .videoFile)
            reach = JSONDecoding.flexString(c, key: .reach)
            clicks = JSONDecoding.flexString(c, key: .clicks)
            ctr = JSONDecoding.flexString(c, key: .ctr)
            revenue = JSONDecoding.flexString(c, key: .revenue)
            attributedSales = JSONDecoding.flexString(c, key: .attributedSales)
            traderSegments = try c.decodeIfPresent(JSONValue.self, forKey: .traderSegments)
            selectedProducts = try c.decodeIfPresent(JSONValue.self, forKey: .selectedProducts)
            stockLogs = try c.decodeIfPresent([StockLog].self, forKey: .stockLogs)
        }

        private enum CodingKeys: String, CodingKey {
            case id, name, campaignType, status, objective
            case promotionDescription = "description"
            case startDate, endDate, budget, dailyBudget, productsCost
            case address, placeId, lat, lng
            case bannerFile, videoFile
            case reach, clicks, ctr, revenue
            case attributedSales = "attributed_sales"
            case traderSegments, selectedProducts, stockLogs = "stock_logs"
        }
    }

    struct Media: Decodable {
        let id: String?
        let fileUrl: String?
        let url: String?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = JSONDecoding.flexString(c, key: .id)
            fileUrl = try c.decodeIfPresent(String.self, forKey: .fileUrl)
            url = try c.decodeIfPresent(String.self, forKey: .url)
        }
        private enum CodingKeys: String, CodingKey { case id, fileUrl, url }

        /// Best available URL for previewing the media.
        var bestUrl: String? {
            if let f = fileUrl, !f.isEmpty { return f }
            return url
        }
    }
}
