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
    let portalInfo: PortalInfo?

    // Pending-approval branch: when the distributor account is still awaiting approval the
    // login call returns status=true with no token; these fields describe the application
    // under review instead (see PendingApprovalViewController).
    let pendingApproval: Bool?
    let accountStatus: String?
    let registrationStatus: String?
    let submittedAt: String?
    let reference: String?
    let businessName: String?
    let wallet: Wallet?

    struct Wallet: Decodable {
        let status: String?
        let accountNumber: String?
        let activatedAt: String?
        let lastError: String?
        let configured: Bool?
    }

    struct User: Decodable {
        let id: String?
        let firstName: String?
        let lastName: String?
        let email: String?
        let phoneNumber: String?
        let roleType: String?
        let roleLabel: String?
    }

    /// Branding for the logged-in distributor company. `companyLogoUrl` is an absolute URL
    /// to the uploaded logo (may be nil/empty when none was set).
    struct PortalInfo: Decodable {
        let companyLogoUrl: String?
    }
}

// MARK: - Wallet

/// data block of GET /api/common/wallet — the distributor's anokiX (IMB) wallet.
/// Consumed by the dashboard wallet card + detail panel and Settings → Business → Wallet.
struct WalletData: Decodable {
    let status: String?
    let accountNumber: String?
    let activatedAt: String?
    let configured: Bool?
    let paymentsEnabled: Bool?
    let balance: Balance?

    struct Balance: Decodable {
        let current: Double?
        let available: Double?
        let pending: Double?
        let asOf: String?
        let stale: Bool?
        let transactions: [Transaction]?
    }

    /// One movement on the wallet ledger. `amount` arrives as a signed string.
    struct Transaction: Decodable {
        let date: String?
        let amount: String?
        let transactionId: Int64?
        let proofOfPayment: Bool?
        let pending: Bool?
    }
}

// MARK: - Wallet top-up (PayCloud)

/// data block of POST /api/common/topup/create — a freshly opened PayCloud Hosted Checkout
/// for funding the wallet. The app opens `payUrl` and then polls `TopupStatusData`.
struct TopupCreateData: Decodable {
    let merchantOrderNo: String?
    let payUrl: String?
    let amount: Double?
    let currency: String?
}

/// data block of GET /api/common/topup/status. `status=paid` only means the card was
/// charged; the money is in the wallet when `creditStatus == "credited"`.
struct TopupStatusData: Decodable {
    let merchantOrderNo: String?
    let tradeNo: String?
    let amount: Double?
    let currency: String?
    /// pending | paid | failed | cancelled
    let status: String?
    /// none | pending | credited | failed
    let creditStatus: String?
    let creditedAt: String?
    let createdAt: String?

    var isCredited: Bool { creditStatus?.lowercased() == "credited" }

    /// Terminal failure — nothing more to wait for.
    var isFailed: Bool {
        let s = status?.lowercased()
        return s == "failed" || s == "cancelled" || creditStatus?.lowercased() == "failed"
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

// MARK: - Register Distributor

/// `data` block of POST /api/distributor/register. Only the identity/status fields
/// needed to confirm the registration succeeded are modelled (mirrors the Android DTO).
struct RegisterDistributorData: Decodable {
    let user: User?
    let distributor: Distributor?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        user = try c.decodeIfPresent(User.self, forKey: .user)
        distributor = try c.decodeIfPresent(Distributor.self, forKey: .distributor)
    }

    private enum CodingKeys: String, CodingKey { case user, distributor }

    struct User: Decodable {
        let id: String?
        let firstName: String?
        let lastName: String?
        let email: String?
        let phoneNumber: String?
        let status: String?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = JSONDecoding.flexString(c, key: .id)
            firstName = try c.decodeIfPresent(String.self, forKey: .firstName)
            lastName = try c.decodeIfPresent(String.self, forKey: .lastName)
            email = try c.decodeIfPresent(String.self, forKey: .email)
            phoneNumber = try c.decodeIfPresent(String.self, forKey: .phoneNumber)
            status = try c.decodeIfPresent(String.self, forKey: .status)
        }

        private enum CodingKeys: String, CodingKey {
            case id, firstName, lastName, email, phoneNumber, status
        }
    }

    struct Distributor: Decodable {
        let id: String?
        let distributorCode: String?
        let companyLegalName: String?
        let tradingName: String?
        let status: String?
        let registrationStatus: String?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = JSONDecoding.flexString(c, key: .id)
            distributorCode = try c.decodeIfPresent(String.self, forKey: .distributorCode)
            companyLegalName = try c.decodeIfPresent(String.self, forKey: .companyLegalName)
            tradingName = try c.decodeIfPresent(String.self, forKey: .tradingName)
            status = try c.decodeIfPresent(String.self, forKey: .status)
            registrationStatus = try c.decodeIfPresent(String.self, forKey: .registrationStatus)
        }

        private enum CodingKeys: String, CodingKey {
            case id, distributorCode, companyLegalName, tradingName, status, registrationStatus
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
    let user: AccountUser?
    let portalInfo: PortalInfo?
    let currencies: [Currency]?
    let timezones: [Timezone]?
    let brands: [Brand]?
    let productCategories: [ProductCategory]?
    let productUnits: [ProductUnit]?

    /// Logged-in account (Settings → Profile).
    struct AccountUser: Decodable {
        let id: String?
        let email: String?
        let firstName: String?
        let lastName: String?
        let phoneNumber: String?
    }

    /// Distributor portal record (Settings header + company name).
    struct PortalInfo: Decodable {
        let id: String?
        let companyLegalName: String?
        let tradingName: String?
        let companyEmail: String?
        let companyLogoUrl: String?
    }

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

    /// Looks up `key` and its camelCase form (handles mixed server / decoder key shapes).
    func flexString(_ key: String) -> String {
        let direct = string(key)
        if !direct.isEmpty { return direct }
        return string(Self.snakeToCamel(key))
    }

    private static func snakeToCamel(_ key: String) -> String {
        let parts = key.split(separator: "_")
        guard parts.count > 1 else { return key }
        return parts.enumerated().map { index, part in
            index == 0 ? String(part) : part.capitalized
        }.joined()
    }

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
    /// Raw `stock_logs` at the data root (same pattern as `selectedProducts`).
    let stockLogs: JSONValue?
    /// Alternate key used by some API builds (`promotion_stock_logs` table name).
    let promotionStockLogs: JSONValue?
    /// Populated by `ApiClient` when SwiftyJSON finds logs Codable missed.
    var enrichedStockLogs: [StockLog]?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        promotion = try c.decodeIfPresent(Promotion.self, forKey: .promotion)
        stockLogs = try c.decodeIfPresent(JSONValue.self, forKey: .stockLogs)
        promotionStockLogs = try c.decodeIfPresent(JSONValue.self, forKey: .promotionStockLogs)
        enrichedStockLogs = nil
    }

    private enum CodingKeys: String, CodingKey {
        case promotion, stockLogs, promotionStockLogs
    }

    /// Parsed stock log rows — checks all known locations/keys (matches Android).
    func resolvedStockLogs() -> [StockLog] {
        if let enriched = enrichedStockLogs, !enriched.isEmpty { return enriched }
        for raw in candidateStockLogSources() {
            let parsed = Self.parseStockLogs(raw)
            if !parsed.isEmpty { return parsed }
        }
        return []
    }

    private func candidateStockLogSources() -> [JSONValue?] {
        [
            promotion?.stockLogs,
            promotion?.promotionStockLogs,
            stockLogs,
            promotionStockLogs
        ]
    }

    /// Defensive parser for `stock_logs` (array or wrapped object), mirroring Android/Gson leniency.
    static func parseStockLogs(_ raw: JSONValue?) -> [StockLog] {
        guard let raw = raw else { return [] }
        if case .null = raw { return [] }

        let unwrapped = raw.unwrapped
        let elements: [JSONValue]
        if let array = unwrapped.arrayValue {
            elements = array
        } else if let items = unwrapped["items"]?.arrayValue {
            elements = items
        } else if let data = unwrapped["data"]?.arrayValue {
            elements = data
        } else if unwrapped.objectValue != nil {
            elements = [unwrapped]
        } else {
            return []
        }
        return elements.compactMap { el in
            let row = el.unwrapped
            guard row.objectValue != nil else { return nil }
            return StockLog(json: row)
        }
    }

    struct StockLog {
        let productName: String?
        let productId: String?
        let action: String?
        let quantity: String?
        let createdAt: String?

        init(productName: String?, productId: String?, action: String?,
             quantity: String?, createdAt: String?) {
            self.productName = productName
            self.productId = productId
            self.action = action
            self.quantity = quantity
            self.createdAt = createdAt
        }

        init(json: JSONValue) {
            let productLabel = Self.firstNonEmpty(
                json.flexString("product_name"),
                json.flexString("name"),
                json.flexString("product_title"),
                json["product"]?.flexString("name") ?? "",
                json.flexString("product_id"),
                json.flexString("id"),
                json["product"]?.flexString("id") ?? ""
            )
            productName = productLabel
            productId = Self.firstNonEmpty(
                json.flexString("product_id"),
                json.flexString("id"),
                json["product"]?.flexString("id") ?? ""
            )
            action = json.flexString("action").isEmpty
                ? json["action"]?.stringValue
                : json.flexString("action")
            quantity = json["quantity"]?.stringValue ?? json.flexString("quantity")
            createdAt = Self.firstNonEmpty(
                json.flexString("created_at"),
                json.flexString("date"),
                json.flexString("logged_at")
            )
        }

        private static func firstNonEmpty(_ values: String...) -> String? {
            for v in values where !v.isEmpty { return v }
            return nil
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
        let stockLogs: JSONValue?
        let promotionStockLogs: JSONValue?

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
            stockLogs = try c.decodeIfPresent(JSONValue.self, forKey: .stockLogs)
            promotionStockLogs = try c.decodeIfPresent(JSONValue.self, forKey: .promotionStockLogs)
        }

        private enum CodingKeys: String, CodingKey {
            case id, name, campaignType, status, objective
            case promotionDescription = "description"
            case startDate, endDate, budget, dailyBudget, productsCost
            case address, placeId, lat, lng
            case bannerFile, videoFile
            case reach, clicks, ctr, revenue, attributedSales
            case traderSegments, selectedProducts, stockLogs, promotionStockLogs
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

// MARK: - Orders (GET api/distributor/orders)

/// Orders list payload. Property names are camelCase; the shared decoder uses
/// `.convertFromSnakeCase`, so JSON keys like `order_number` / `status_counts`
/// map automatically.
struct OrdersData: Decodable {
    let orders: [OrderDTO]?
    let pagination: OrderPagination?
    let statusCounts: OrderStatusCounts?
}

struct OrderDTO: Decodable {
    let id: Int
    let orderNumber: String?
    let traderId: Int?
    let distributorId: Int?
    let status: String?
    let statusKey: String?
    let subtotal: Double?
    let totalAmount: Double?
    let itemCount: Int?
    let lineCount: Int?
    let deliveryDate: String?
    let deliveryStartTime: String?
    let deliveryEndTime: String?
    let notes: String?
    let trader: OrderTraderDTO?
    let products: [String]?       // list endpoint only
    let items: [OrderItemDTO]?    // detail endpoint only
    let createdAt: String?
    let updatedAt: String?

    var resolvedStatusKey: String {
        if let k = statusKey, !k.isEmpty { return k }
        return status?.lowercased() ?? "pending"
    }

    var traderName: String {
        if let n = trader?.name, !n.trimmingCharacters(in: .whitespaces).isEmpty { return n }
        return "Trader"
    }

    var amount: Double { totalAmount ?? subtotal ?? 0 }
}

struct OrderTraderDTO: Decodable {
    let id: Int?
    let name: String?
    let phone: String?
    let location: String?
    let segment: String?
}

/// Line item on the detail response (`orders/get-by-id`). The fields are flat —
/// `name` and `image_url` sit directly on the item, not under a nested product.
struct OrderItemDTO: Decodable {
    let id: Int?
    let productId: Int?
    let name: String?
    let quantity: Int?
    let unitPrice: Double?
    let lineTotal: Double?
    let status: String?
    let imageUrl: String?
}

struct OrderPagination: Decodable {
    let page: Int?
    let perPage: Int?
    let total: Int?
    let totalPages: Int?
}

struct OrderStatusCounts: Decodable {
    let all: Int?
    let pending: Int?
    let accepted: Int?
    let picking: Int?
    let packing: Int?
    let readyForDelivery: Int?
    let outForDelivery: Int?
    let delivered: Int?
    let cancelled: Int?
    let failed: Int?

    func count(for key: String) -> Int {
        switch key {
        case "all": return all ?? 0
        case "pending": return pending ?? 0
        case "accepted": return accepted ?? 0
        case "picking": return picking ?? 0
        case "packing": return packing ?? 0
        case "ready_for_delivery": return readyForDelivery ?? 0
        case "out_for_delivery": return outForDelivery ?? 0
        case "delivered": return delivered ?? 0
        case "cancelled": return cancelled ?? 0
        case "failed": return failed ?? 0
        default: return 0
        }
    }
}

struct OrderDetailData: Decodable {
    let order: OrderDTO?
}

// MARK: - Deliveries

struct DeliveriesData: Decodable {
    let deliveries: [DeliveryDTO]?
    let summary: DeliverySummary?
    let statusCounts: DeliveryStatusCounts?
    let areas: [String]?
    let pagination: DeliveryPagination?
}

struct DeliveryDTO: Decodable {
    let id: Int
    let deliveryNumber: String?
    let orderNumber: String?
    let traderId: Int?
    let traderName: String?
    let traderPhone: String?
    let area: String?
    let driver: String?
    let rawStatus: String?       // ReadyForDelivery / OutForDelivery / Delivered ...
    let deliveryDate: String?
    let deliveryAt: String?
    let updatedAt: String?
    let itemCount: Int?
    let totalAmount: Double?
    let status: String?          // delivered / delayed / in_transit / failed / returned
    let onTime: Bool?

    var resolvedTraderName: String {
        if let n = traderName, !n.trimmingCharacters(in: .whitespaces).isEmpty { return n }
        return "Trader"
    }
}

struct DeliverySummary: Decodable {
    let totalDeliveries: Int?
    let onTime: Int?
    let onTimePct: Double?
    let inTransit: Int?
    let inTransitPct: Double?
    let delayed: Int?
    let delayedPct: Double?
    let failed: Int?
    let failedPct: Double?
    let delivered: Int?
}

struct DeliveryStatusCounts: Decodable {
    let all: Int?
    let inTransit: Int?
    let delivered: Int?
    let delayed: Int?
    let failed: Int?
    let returned: Int?

    func count(for key: String) -> Int {
        switch key {
        case "all": return all ?? 0
        case "in_transit": return inTransit ?? 0
        case "delivered": return delivered ?? 0
        case "delayed": return delayed ?? 0
        case "failed": return failed ?? 0
        case "returned": return returned ?? 0
        default: return 0
        }
    }
}

struct DeliveryPagination: Decodable {
    let page: Int?
    let perPage: Int?
    let total: Int?
    let totalPages: Int?
}

struct DeliveryDetailData: Decodable {
    let delivery: DeliveryDetailDTO?
}

struct DeliveryDetailDTO: Decodable {
    let id: Int
    let orderNumber: String?
    let deliveryNumber: String?
    let traderId: Int?
    let status: String?           // raw e.g. "ReadyForDelivery"
    let statusKey: String?
    let deliveryStatus: String?   // computed (delivered / delayed ...)
    let subtotal: Double?
    let totalAmount: Double?
    let itemCount: Int?
    let deliveryDate: String?
    let deliveryStartTime: String?
    let deliveryEndTime: String?
    let deliveryAt: String?
    let area: String?
    let notes: String?
    let trader: OrderTraderDTO?
    let items: [DeliveryItemDTO]?
    let createdAt: String?
    let updatedAt: String?

    var resolvedTraderName: String {
        if let n = trader?.name, !n.trimmingCharacters(in: .whitespaces).isEmpty { return n }
        return "Trader"
    }
}

struct DeliveryItemDTO: Decodable {
    let id: Int?
    let productId: Int?
    let name: String?
    let quantity: Int?
    let unitPrice: Double?
    let lineTotal: Double?
    let status: String?
    let imageUrl: String?
}

// MARK: - Returns (GRNs)

struct ReturnsData: Decodable {
    let returns: [ReturnDTO]?
    let summary: ReturnSummary?
    let statusCounts: ReturnStatusCounts?
    let pagination: ReturnPagination?
}

struct ReturnDTO: Decodable {
    let id: Int
    let grnNumber: String?
    let sourceGrvId: Int?
    let traderId: Int?
    let traderName: String?
    let traderPhone: String?
    let reason: String?           // damaged / expired / ...
    let reasonLabel: String?      // "Damaged Items"
    let status: String?           // pending / approved / rejected
    let rawStatus: String?
    let itemCount: Int?
    let totalQuantity: Int?
    let note: String?
    let decisionNote: String?
    let creditNoteNumber: String?
    let creditNoteTotal: Double?
    let approvedAt: String?
    let createdAt: String?

    var resolvedTraderName: String {
        if let n = traderName, !n.trimmingCharacters(in: .whitespaces).isEmpty { return n }
        return "Trader"
    }
}

struct ReturnSummary: Decodable {
    let totalReturns: Int?
    let pending: Int?
    let approved: Int?
    let rejected: Int?
    let totalValue: Double?
}

struct ReturnStatusCounts: Decodable {
    let all: Int?
    let pending: Int?
    let approved: Int?
    let rejected: Int?

    func count(for key: String) -> Int {
        switch key {
        case "all": return all ?? 0
        case "pending": return pending ?? 0
        case "approved": return approved ?? 0
        case "rejected": return rejected ?? 0
        default: return 0
        }
    }
}

struct ReturnPagination: Decodable {
    let page: Int?
    let perPage: Int?
    let total: Int?
    let totalPages: Int?
}

struct ReturnDetailData: Decodable {
    let returnItem: ReturnDetailDTO?

    /// `return` is a Swift keyword, so the JSON member is bound explicitly.
    enum CodingKeys: String, CodingKey {
        case returnItem = "return"
    }
}

struct ReturnDetailDTO: Decodable {
    let id: Int
    let grnNumber: String?
    let sourceGrvId: Int?
    let traderId: Int?
    let traderName: String?
    let traderPhone: String?
    let reason: String?
    let reasonLabel: String?
    let status: String?           // pending / approved / rejected
    let rawStatus: String?
    let itemCount: Int?
    let totalQuantity: Int?
    let note: String?
    let decisionNote: String?
    let creditNoteNumber: String?
    let creditNoteTotal: Double?
    let approvedAt: String?
    let createdAt: String?
    let items: [ReturnItemDTO]?

    var resolvedTraderName: String {
        if let n = traderName, !n.trimmingCharacters(in: .whitespaces).isEmpty { return n }
        return "Trader"
    }
}

struct ReturnItemDTO: Decodable {
    let id: Int?
    let productId: Int?
    let name: String?
    let quantity: Int?
    let unitCost: Double?
    let lineTotal: Double?
    let reason: String?
}

// MARK: - Finances (wallet ledger)

struct FinancesData: Decodable {
    let transactions: [FinanceTransactionDTO]?
    let summary: FinanceSummaryDTO?
}

struct FinanceTransactionDTO: Decodable {
    let id: Int
    let reference: String?
    let type: String?             // order_payment / invoice / payout / credit_note
    let traderName: String?
    let traderPhone: String?
    let orderNumber: String?
    let description: String?      // "Order payment · ORD000029"
    let amount: Double?
    let currency: String?         // "ZAR"
    let status: String?           // paid / pending / overdue / partial
    let paymentMethod: String?    // not yet returned by the API — reserved
    let createdAt: String?        // "2026-07-15 13:58:09"

    var resolvedTraderName: String {
        if let n = traderName, !n.trimmingCharacters(in: .whitespaces).isEmpty { return n }
        return "Trader"
    }
}

struct FinanceSummaryDTO: Decodable {
    let received: Double?
    let receivedMonth: Double?
    let pending: Double?
    let commissionMonth: Double?
    let overdue: Double?          // reserved — API does not yet return it
    let count: Int?
}

// MARK: - Notifications (common)

struct NotificationsData: Decodable {
    let notifications: [NotificationDTO]?
    let unreadCount: Int?
    let pagination: NotificationPagination?
}

struct NotificationDTO: Decodable {
    let id: String
    let userId: String?
    /// e.g. "order.status", "return.decision", "stock.low".
    let type: String?
    let title: String?
    let body: String?
    /// Routing payload (route + order_id/grn_id/product_id…).
    let data: NotificationPayload?
    let readAt: String?
    /// "dd/MM/yyyy HH:mm:ss".
    let createdAt: String?
    var isRead: Bool?
}

struct NotificationPayload: Decodable {
    let route: String?
    let orderId: Int?
    let orderNumber: String?
    let grnId: Int?
    let grnNumber: String?
    let deliveryId: Int?
    let productId: Int?
    let status: String?
    let decision: String?
}

struct NotificationPagination: Decodable {
    let page: Int?
    let perPage: Int?
    let total: Int?
    let totalPages: Int?
}

/// Response for GET api/common/notifications/unread-count.
struct UnreadCountData: Decodable {
    let unreadCount: Int?
}

// MARK: - Settings: preferences / profile

/// data block of GET api/common/preferences. `notifications` may arrive as an object or, when
/// never set, an empty array; the custom decoder tolerates both and leaves it nil for arrays.
struct PreferencesData: Decodable {
    let preferences: Preferences?

    struct Preferences: Decodable {
        let language: String?
        let currency: String?
        let timezone: String?
        let dateFormat: String?
        let notifications: NotificationFlags?

        enum CodingKeys: String, CodingKey {
            case language, currency, timezone, dateFormat, notifications
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            language = try c.decodeIfPresent(String.self, forKey: .language)
            currency = try c.decodeIfPresent(String.self, forKey: .currency)
            timezone = try c.decodeIfPresent(String.self, forKey: .timezone)
            dateFormat = try c.decodeIfPresent(String.self, forKey: .dateFormat)
            // Empty array → decode fails → nil (treated as "all on" by the screen).
            notifications = try? c.decodeIfPresent(NotificationFlags.self, forKey: .notifications)
        }

        /// Toggle value, defaulting to true when notifications are unset.
        func notif(_ key: NotificationKey) -> Bool {
            guard let n = notifications else { return true }
            switch key {
            case .orderAlerts: return n.orderAlerts ?? true
            case .lowStockAlerts: return n.lowStockAlerts ?? true
            case .deliveryUpdates: return n.deliveryUpdates ?? true
            case .financeReminders: return n.financeReminders ?? true
            case .reportReady: return n.reportReady ?? true
            }
        }
    }

    enum NotificationKey { case orderAlerts, lowStockAlerts, deliveryUpdates, financeReminders, reportReady }

    struct NotificationFlags: Decodable {
        let orderAlerts: Bool?
        let lowStockAlerts: Bool?
        let deliveryUpdates: Bool?
        let financeReminders: Bool?
        let reportReady: Bool?
    }
}

/// data block of POST api/common/profile/update.
struct ProfileUpdateData: Decodable {
    let user: ProfileUser?

    struct ProfileUser: Decodable {
        let id: String?
        let firstName: String?
        let lastName: String?
        let email: String?
        let phoneNumber: String?
    }
}

// MARK: - Settings: business profile (7-step)

/// data block of GET api/distributor/business/profile — the full distributor record used to
/// pre-fill the 7-step Business editor. Numeric-or-string fields use `flexString`.
struct BusinessProfileData: Decodable {
    let profile: Profile?

    struct Profile: Decodable {
        let companyLegalName: String?
        let tradingName: String?
        let companyLogoUrl: String?
        let companyRegistrationNumber: String?
        let vatNumber: String?
        let companyEmail: String?
        let companyPhoneNumber: String?
        let businessType: String?
        let businessEstablishedYear: String?
        let employeeCount: String?
        let annualTurnover: String?
        let bankName: String?
        let accountHolderName: String?
        let accountNumber: String?
        let accountType: String?
        let branchCode: String?
        let contactPersons: [Contact]?
        let address: String?
        let latitude: Double?
        let longitude: Double?
        let distributionCoverage: String?
        let primaryProductCategoryIds: String?
        let activeClientsCount: String?
        let deliveryFleetSize: String?
        let preferredDeliveryDays: String?
        let documents: Documents?

        enum CodingKeys: String, CodingKey {
            case companyLegalName, tradingName, companyLogoUrl, companyRegistrationNumber,
                 vatNumber, companyEmail, companyPhoneNumber, businessType, businessEstablishedYear,
                 employeeCount, annualTurnover, bankName, accountHolderName, accountNumber,
                 accountType, branchCode, contactPersons, address, latitude, longitude,
                 distributionCoverage, primaryProductCategoryIds, activeClientsCount,
                 deliveryFleetSize, preferredDeliveryDays, documents
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            companyLegalName = try? c.decodeIfPresent(String.self, forKey: .companyLegalName)
            tradingName = try? c.decodeIfPresent(String.self, forKey: .tradingName)
            companyLogoUrl = try? c.decodeIfPresent(String.self, forKey: .companyLogoUrl)
            companyRegistrationNumber = JSONDecoding.flexString(c, key: .companyRegistrationNumber)
            vatNumber = JSONDecoding.flexString(c, key: .vatNumber)
            companyEmail = try? c.decodeIfPresent(String.self, forKey: .companyEmail)
            companyPhoneNumber = JSONDecoding.flexString(c, key: .companyPhoneNumber)
            businessType = try? c.decodeIfPresent(String.self, forKey: .businessType)
            businessEstablishedYear = JSONDecoding.flexString(c, key: .businessEstablishedYear)
            employeeCount = try? c.decodeIfPresent(String.self, forKey: .employeeCount)
            annualTurnover = try? c.decodeIfPresent(String.self, forKey: .annualTurnover)
            bankName = try? c.decodeIfPresent(String.self, forKey: .bankName)
            accountHolderName = try? c.decodeIfPresent(String.self, forKey: .accountHolderName)
            accountNumber = JSONDecoding.flexString(c, key: .accountNumber)
            accountType = try? c.decodeIfPresent(String.self, forKey: .accountType)
            branchCode = JSONDecoding.flexString(c, key: .branchCode)
            contactPersons = try? c.decodeIfPresent([Contact].self, forKey: .contactPersons)
            address = try? c.decodeIfPresent(String.self, forKey: .address)
            latitude = try? c.decodeIfPresent(Double.self, forKey: .latitude)
            longitude = try? c.decodeIfPresent(Double.self, forKey: .longitude)
            distributionCoverage = try? c.decodeIfPresent(String.self, forKey: .distributionCoverage)
            primaryProductCategoryIds = JSONDecoding.flexString(c, key: .primaryProductCategoryIds)
            activeClientsCount = JSONDecoding.flexString(c, key: .activeClientsCount)
            deliveryFleetSize = JSONDecoding.flexString(c, key: .deliveryFleetSize)
            preferredDeliveryDays = try? c.decodeIfPresent(String.self, forKey: .preferredDeliveryDays)
            documents = try? c.decodeIfPresent(Documents.self, forKey: .documents)
        }
    }

    struct Contact: Decodable {
        let fullName: String?
        let position: String?
        let mobileNumber: String?
        let emailAddress: String?
    }

    struct Documents: Decodable {
        let companyRegistrationCertificate: [DocFile]?
        let proofOfAddress: [DocFile]?
        let bankConfirmationLetter: [DocFile]?
        let taxClearanceCertificate: [DocFile]?
        let vatRegistrationCertificate: [DocFile]?
    }

    struct DocFile: Decodable {
        let id: Int64?
        let fileUrl: String?
        let originalName: String?
    }
}

// MARK: - Airtime & VAS

/// `data` block of GET api/common/vas/transactions — recent transactions + KPI summary.
struct VasTransactionsData: Decodable {
    let transactions: [Transaction]
    let summary: Summary?

    enum CodingKeys: String, CodingKey { case transactions, summary }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        transactions = (try? c.decode([Transaction].self, forKey: .transactions)) ?? []
        summary = try? c.decodeIfPresent(Summary.self, forKey: .summary)
    }

    struct Transaction: Decodable, Identifiable {
        let id: String
        let msisdn: String?
        let name: String?
        let category: String?
        let amount: String?
        let commission: String?
        let status: String?
        let createdAt: String?

        enum CodingKeys: String, CodingKey {
            case id, msisdn, name, category, amount, commission, status, createdAt
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = JSONDecoding.flexString(c, key: .id) ?? UUID().uuidString
            msisdn = JSONDecoding.flexString(c, key: .msisdn)
            name = try? c.decodeIfPresent(String.self, forKey: .name)
            category = try? c.decodeIfPresent(String.self, forKey: .category)
            amount = JSONDecoding.flexString(c, key: .amount)
            commission = JSONDecoding.flexString(c, key: .commission)
            status = try? c.decodeIfPresent(String.self, forKey: .status)
            createdAt = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        }
    }

    /// Header KPI figures for the VAS dashboard.
    struct Summary: Decodable {
        let salesToday: Double
        let countToday: Double
        let commissionMonth: Double
        let walletBalance: Double

        enum CodingKeys: String, CodingKey {
            case salesToday, countToday, commissionMonth, walletBalance
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            salesToday = (try? c.decode(Double.self, forKey: .salesToday)) ?? 0
            countToday = (try? c.decode(Double.self, forKey: .countToday)) ?? 0
            commissionMonth = (try? c.decode(Double.self, forKey: .commissionMonth)) ?? 0
            walletBalance = (try? c.decode(Double.self, forKey: .walletBalance)) ?? 0
        }
    }
}

/// `data` block of GET api/common/vas/categories. The categories form a tree; only leaf
/// nodes (no children) that have products are purchasable, so `leaves` flattens the tree
/// depth-first (respecting displayOrder) into the flat list the UI shows.
struct VasCategoriesData: Decodable {
    let configured: Bool
    let commissionRate: Double
    let categories: [Node]

    enum CodingKeys: String, CodingKey { case configured, commissionRate, categories }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        configured = (try? c.decode(Bool.self, forKey: .configured)) ?? false
        commissionRate = (try? c.decode(Double.self, forKey: .commissionRate)) ?? 0
        categories = (try? c.decode([Node].self, forKey: .categories)) ?? []
    }

    struct Node: Decodable, Identifiable {
        let id: String
        let name: String
        let displayOrder: Int
        let children: [Node]
        let productCount: Int
        let hasProducts: Bool

        enum CodingKeys: String, CodingKey {
            case id, name, displayOrder, children, productCount, hasProducts
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = JSONDecoding.flexString(c, key: .id) ?? ""
            name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
            displayOrder = (try? c.decode(Int.self, forKey: .displayOrder)) ?? 0
            children = (try? c.decode([Node].self, forKey: .children)) ?? []
            productCount = (try? c.decode(Int.self, forKey: .productCount)) ?? 0
            hasProducts = (try? c.decode(Bool.self, forKey: .hasProducts)) ?? false
        }

        var isLeaf: Bool { children.isEmpty }
    }

    /// Depth-first flatten to the selectable leaf categories, ordered by displayOrder.
    var leaves: [Node] {
        var out: [Node] = []
        func walk(_ nodes: [Node]) {
            for node in nodes.sorted(by: { $0.displayOrder < $1.displayOrder }) {
                if node.isLeaf {
                    if node.hasProducts || node.productCount > 0 { out.append(node) }
                } else {
                    walk(node.children)
                }
            }
        }
        walk(categories)
        return out
    }
}

/// `data` block of GET api/common/vas/products.
struct VasProductsData: Decodable {
    let products: [Product]

    enum CodingKeys: String, CodingKey { case products }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        products = (try? c.decode([Product].self, forKey: .products)) ?? []
    }

    struct Product: Decodable, Identifiable {
        let id: String
        let sku: String?
        let name: String?
        let description: String?
        let price: Double
        let brand: String?
        let displayOrder: Int
        let isAdHoc: Bool

        enum CodingKeys: String, CodingKey {
            case id, sku, name, description, price, brand, displayOrder, isAdHoc
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = JSONDecoding.flexString(c, key: .id) ?? ""
            sku = JSONDecoding.flexString(c, key: .sku)
            name = try? c.decodeIfPresent(String.self, forKey: .name)
            description = try? c.decodeIfPresent(String.self, forKey: .description)
            price = (try? c.decode(Double.self, forKey: .price)) ?? 0
            brand = try? c.decodeIfPresent(String.self, forKey: .brand)
            displayOrder = (try? c.decode(Int.self, forKey: .displayOrder)) ?? 0
            isAdHoc = (try? c.decode(Bool.self, forKey: .isAdHoc)) ?? false
        }
    }
}
