import Foundation
import SwiftyJSON

/// An error carrying the server-provided (or synthesized) message.
struct ApiError: Error {
    let message: String
}

/// Typed facade over `Http`, port of network/ApiClient.java.
final class ApiClient {

    static let shared = ApiClient()

    static let baseURL = "http://155.117.20.51/ax/"

    private let session = SessionManager.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private init() {}

    // MARK: - Endpoints

    func login(email: String, password: String, completion: @escaping (Result<LoginData, ApiError>) -> Void) {
        let form = ["email": email, "password": password, "portal_type": "distributor"]
        Http.postForm(baseUrl: Self.baseURL, path: "api/common/login", form: form, token: nil) { [weak self] r in
            self?.deliver(r, type: LoginData.self, completion: completion)
        }
    }

    func getDashboard(completion: @escaping (Result<DashboardData, ApiError>) -> Void) {
        getAuthed("api/distributor/dashboard", query: nil, type: DashboardData.self, completion: completion)
    }

    func getStores(keyword: String, completion: @escaping (Result<StoresData, ApiError>) -> Void) {
        let q = ["offset": "0", "page_size": "50", "keyword": keyword]
        getAuthed("api/distributor/stores/all", query: q, type: StoresData.self, completion: completion)
    }

    func getTraders(search: String, completion: @escaping (Result<TradersData, ApiError>) -> Void) {
        getTraders(search: search, status: "", registrationStatus: "", completion: completion)
    }

    func getTraders(search: String, status: String, registrationStatus: String,
                    completion: @escaping (Result<TradersData, ApiError>) -> Void) {
        let q = ["search": search, "status": status,
                 "registration_status": registrationStatus, "credit_status": ""]
        getAuthed("api/distributor/traders", query: q, type: TradersData.self, completion: completion)
    }

    /// Lookup data for the Create Trader wizard (categories, distributors, trader types).
    func getReference(completion: @escaping (Result<ReferenceData, ApiError>) -> Void) {
        getAuthed("api/common/reference", query: nil, type: ReferenceData.self, completion: completion)
    }

    /// Google Places autocomplete (proxied) for the business address search.
    func getAddressAutocomplete(keyword: String,
                                completion: @escaping (Result<AutocompleteData, ApiError>) -> Void) {
        let q = ["keyword": keyword, "str_countries": "country:ZA", "search_type": "address"]
        getAuthed("api/common/google-auto-complete", query: q, type: AutocompleteData.self, completion: completion)
    }

    /// Resolve a place_id from autocomplete into latitude/longitude + formatted address.
    func getCoordinateFromPlaceId(_ placeId: String,
                                  completion: @escaping (Result<CoordinateData, ApiError>) -> Void) {
        getAuthed("api/common/get-coordinate-from-placeid", query: ["place_id": placeId],
                  type: CoordinateData.self, completion: completion)
    }

    /// Public distributor self-registration ("Create Account"). Multipart with logo +
    /// KYC documents; sends **no token** (public endpoint — mirrors the Android client).
    func registerDistributor(form: [String: String], files: [Http.FilePart],
                             completion: @escaping (Result<RegisterDistributorData, ApiError>) -> Void) {
        Http.postMultipart(baseUrl: Self.baseURL, path: "api/distributor/register",
                           form: form, files: files, token: nil) { [weak self] r in
            self?.deliver(r, type: RegisterDistributorData.self, completion: completion)
        }
    }

    /// Create a trader under the logged-in distributor (multipart, with KYC documents).
    func createTrader(form: [String: String], files: [Http.FilePart],
                      completion: @escaping (Result<CreateTraderData, ApiError>) -> Void) {
        Http.postMultipart(baseUrl: Self.baseURL, path: "api/distributor/traders/create",
                           form: form, files: files, token: session.token) { [weak self] r in
            self?.deliver(r, type: CreateTraderData.self, completion: completion)
        }
    }

    func getProducts(completion: @escaping (Result<ProductsData, ApiError>) -> Void) {
        getAuthed("api/distributor/products", query: nil, type: ProductsData.self, completion: completion)
    }

    func getProductById(id: String, completion: @escaping (Result<ProductDetailData, ApiError>) -> Void) {
        getAuthed("api/distributor/products/get-by-id", query: ["id": id],
                  type: ProductDetailData.self, completion: completion)
    }

    /// Create a product (multipart: text fields + primary image, additional images, datasheet).
    func createProduct(form: [String: String], files: [Http.FilePart],
                       completion: @escaping (Result<ProductDetailData, ApiError>) -> Void) {
        Http.postMultipart(baseUrl: Self.baseURL, path: "api/distributor/products/create",
                           form: form, files: files, token: session.token) { [weak self] r in
            self?.deliver(r, type: ProductDetailData.self, completion: completion)
        }
    }

    /// Update an existing product (partial — only sent fields change).
    func updateProduct(form: [String: String], files: [Http.FilePart],
                       completion: @escaping (Result<ProductDetailData, ApiError>) -> Void) {
        Http.postMultipart(baseUrl: Self.baseURL, path: "api/distributor/products/update",
                           form: form, files: files, token: session.token) { [weak self] r in
            self?.deliver(r, type: ProductDetailData.self, completion: completion)
        }
    }

    func deleteProduct(id: String, completion: @escaping (Result<Void, ApiError>) -> Void) {
        // The delete endpoint returns "data": [] (an empty array), so it must not be
        // decoded into a ProductDetailData object — only status/message matter.
        Http.postForm(baseUrl: Self.baseURL, path: "api/distributor/products/delete",
                      form: ["id": id], token: session.token) { [weak self] r in
            self?.deliverStatus(r, completion: completion)
        }
    }

    // MARK: Promotions

    /// Promotions/campaigns list + KPI summary. Pass "" for all campaign types.
    func getPromotions(campaignType: String,
                       completion: @escaping (Result<PromotionsData, ApiError>) -> Void) {
        getAuthed("api/distributor/promotions", query: ["campaign_type": campaignType],
                  type: PromotionsData.self, completion: completion)
    }

    /// Full campaign detail (+ selected_products, media) for the edit/view flow.
    func getPromotionById(id: String,
                          completion: @escaping (Result<PromotionDetailData, ApiError>) -> Void) {
        Http.get(baseUrl: Self.baseURL, path: "api/distributor/promotions/get-by-id",
                 query: ["id": id], token: session.token) { [weak self] r in
            self?.deliverPromotionDetail(r, completion: completion)
        }
    }

    /// Create a campaign (multipart: text fields; media goes through upload-media after).
    func createPromotion(form: [String: String], files: [Http.FilePart],
                         completion: @escaping (Result<PromotionDetailData, ApiError>) -> Void) {
        Http.postMultipart(baseUrl: Self.baseURL, path: "api/distributor/promotions/create",
                           form: form, files: files, token: session.token) { [weak self] r in
            self?.deliver(r, type: PromotionDetailData.self, completion: completion)
        }
    }

    /// Update an existing campaign (partial — only sent fields change).
    func updatePromotion(form: [String: String], files: [Http.FilePart],
                         completion: @escaping (Result<PromotionDetailData, ApiError>) -> Void) {
        Http.postMultipart(baseUrl: Self.baseURL, path: "api/distributor/promotions/update",
                           form: form, files: files, token: session.token) { [weak self] r in
            self?.deliver(r, type: PromotionDetailData.self, completion: completion)
        }
    }

    /// Upload / replace the banner and/or video for an existing campaign.
    func uploadPromotionMedia(id: String, files: [Http.FilePart],
                              completion: @escaping (Result<PromotionDetailData, ApiError>) -> Void) {
        Http.postMultipart(baseUrl: Self.baseURL, path: "api/distributor/promotions/upload-media",
                           form: ["id": id], files: files, token: session.token) { [weak self] r in
            self?.deliver(r, type: PromotionDetailData.self, completion: completion)
        }
    }

    func deletePromotion(id: String, completion: @escaping (Result<Void, ApiError>) -> Void) {
        // The delete endpoint returns "data": [] (an empty array); only status/message matter.
        Http.postForm(baseUrl: Self.baseURL, path: "api/distributor/promotions/delete",
                      form: ["id": id], token: session.token) { [weak self] r in
            self?.deliverStatus(r, completion: completion)
        }
    }

    func getInventorySummary(completion: @escaping (Result<InventorySummaryData, ApiError>) -> Void) {
        getAuthed("api/distributor/inventory/summary", query: nil, type: InventorySummaryData.self, completion: completion)
    }

    // MARK: Orders

    /// Orders list for a status tab. Empty/null filters are omitted; `status` "all"
    /// is also omitted so the backend returns every status.
    func getOrders(traderId: String?, search: String, dateFrom: String, dateTo: String,
                   status: String, page: Int, perPage: Int,
                   completion: @escaping (Result<OrdersData, ApiError>) -> Void) {
        var q: [String: String] = ["page": String(page), "per_page": String(perPage)]
        if !status.isEmpty, status != "all" { q["status"] = status }
        if let traderId = traderId, !traderId.isEmpty { q["trader_id"] = traderId }
        let trimmed = search.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { q["search"] = trimmed }
        if !dateFrom.isEmpty { q["date_from"] = dateFrom }
        if !dateTo.isEmpty { q["date_to"] = dateTo }
        getAuthed("api/distributor/orders", query: q, type: OrdersData.self, completion: completion)
    }

    /// Full order detail (+ items) for the tracking screen.
    func getOrderById(id: String, completion: @escaping (Result<OrderDetailData, ApiError>) -> Void) {
        getAuthed("api/distributor/orders/get-by-id", query: ["id": id], type: OrderDetailData.self, completion: completion)
    }

    /// Advance an order through the fulfilment flow. `action` is one of
    /// accept / reject / pick / pack / ready / dispatch / deliver.
    func orderAction(_ action: String, orderId: Int,
                     completion: @escaping (Result<Void, ApiError>) -> Void) {
        Http.postForm(baseUrl: Self.baseURL, path: "api/distributor/orders/\(action)",
                      form: ["order_id": String(orderId)], token: session.token) { [weak self] r in
            self?.deliverStatus(r, completion: completion)
        }
    }

    func getBaseInfo(completion: @escaping (Result<BaseInfoData, ApiError>) -> Void) {
        getAuthed("api/common/base-info", query: nil, type: BaseInfoData.self, completion: completion)
    }

    func getStore(id: String, completion: @escaping (Result<StoreDetailData, ApiError>) -> Void) {
        getAuthed("api/distributor/stores", query: ["id": id], type: StoreDetailData.self, completion: completion)
    }

    func createStore(form: [String: String], completion: @escaping (Result<StoreDetailData, ApiError>) -> Void) {
        postAuthed("api/distributor/stores/create", form: form, type: StoreDetailData.self, completion: completion)
    }

    func updateStore(form: [String: String], completion: @escaping (Result<StoreDetailData, ApiError>) -> Void) {
        postAuthed("api/distributor/stores/update", form: form, type: StoreDetailData.self, completion: completion)
    }

    // MARK: - Internals

    private func getAuthed<T: Decodable>(_ path: String, query: [String: String]?, type: T.Type,
                                         completion: @escaping (Result<T, ApiError>) -> Void) {
        Http.get(baseUrl: Self.baseURL, path: path, query: query, token: session.token) { [weak self] r in
            self?.deliver(r, type: type, completion: completion)
        }
    }

    private func postAuthed<T: Decodable>(_ path: String, form: [String: String], type: T.Type,
                                          completion: @escaping (Result<T, ApiError>) -> Void) {
        Http.postForm(baseUrl: Self.baseURL, path: path, form: form, token: session.token) { [weak self] r in
            self?.deliver(r, type: type, completion: completion)
        }
    }

    /// Parses the `{ status, message, data }` envelope with SwiftyJSON, then decodes `data` with Codable.
    private func deliver<T: Decodable>(_ r: Http.Result, type: T.Type,
                                       completion: @escaping (Result<T, ApiError>) -> Void) {
        var result: Result<T, ApiError>
        if let body = r.body, !body.isEmpty {
            let envelope = JSON(parseJSON: body)
            if envelope["status"].boolValue {
                let dataJson = envelope["data"]
                if dataJson.type == .null {
                    result = .failure(ApiError(message: "Empty response from server"))
                } else if let raw = try? dataJson.rawData() {
                    do {
                        result = .success(try decoder.decode(T.self, from: raw))
                    } catch {
                        print("\(Http.tag): decode failed for \(T.self): \(error)")
                        result = .failure(ApiError(message: "Unexpected response from server"))
                    }
                } else {
                    result = .failure(ApiError(message: "Unexpected response from server"))
                }
            } else {
                let message = envelope["message"].string ?? "Request failed"
                result = .failure(ApiError(message: message))
            }
        } else {
            result = .failure(ApiError(message: "Network error (HTTP \(r.code))"))
        }
        DispatchQueue.main.async { completion(result) }
    }

    /// Parses promotion detail and back-fills stock logs from SwiftyJSON when Codable misses them.
    private func deliverPromotionDetail(_ r: Http.Result,
                                        completion: @escaping (Result<PromotionDetailData, ApiError>) -> Void) {
        var result: Result<PromotionDetailData, ApiError>
        if let body = r.body, !body.isEmpty {
            let envelope = JSON(parseJSON: body)
            if envelope["status"].boolValue {
                let dataJson = envelope["data"]
                if dataJson.type == .null {
                    result = .failure(ApiError(message: "Empty response from server"))
                } else if let raw = try? dataJson.rawData() {
                    do {
                        var data = try decoder.decode(PromotionDetailData.self, from: raw)
                        if data.resolvedStockLogs().isEmpty {
                            data.enrichedStockLogs = Self.parseStockLogsFromEnvelope(dataJson)
                        }
                        result = .success(data)
                    } catch {
                        print("\(Http.tag): decode failed for PromotionDetailData: \(error)")
                        result = .failure(ApiError(message: "Unexpected response from server"))
                    }
                } else {
                    result = .failure(ApiError(message: "Unexpected response from server"))
                }
            } else {
                result = .failure(ApiError(message: envelope["message"].string ?? "Request failed"))
            }
        } else {
            result = .failure(ApiError(message: "Network error (HTTP \(r.code))"))
        }
        DispatchQueue.main.async { completion(result) }
    }

    /// Reads `stock_logs` directly from the envelope (mirrors Android Gson raw parsing).
    private static func parseStockLogsFromEnvelope(_ dataJson: JSON) -> [PromotionDetailData.StockLog] {
        let sources: [JSON] = [
            dataJson["promotion"]["stock_logs"],
            dataJson["promotion"]["promotion_stock_logs"],
            dataJson["stock_logs"],
            dataJson["promotion_stock_logs"]
        ]
        for source in sources {
            let logs = parseStockLogsFromSwiftyJSON(unwrapSwiftyJSON(source))
            if !logs.isEmpty { return logs }
        }
        return []
    }

    /// A JSON-encoded string payload is sometimes returned instead of a structured array.
    private static func unwrapSwiftyJSON(_ json: JSON) -> JSON {
        if json.type == .string, let text = json.string {
            let parsed = JSON(parseJSON: text)
            if parsed.type != .null { return parsed }
        }
        return json
    }

    private static func parseStockLogsFromSwiftyJSON(_ json: JSON) -> [PromotionDetailData.StockLog] {
        guard json.type == .array else {
            if json.type == .dictionary {
                if json["items"].type == .array {
                    return parseStockLogsFromSwiftyJSON(json["items"])
                }
                if json["data"].type == .array {
                    return parseStockLogsFromSwiftyJSON(json["data"])
                }
                return [stockLogFromSwiftyJSON(json)].compactMap { $0 }
            }
            return []
        }
        return json.arrayValue.compactMap { stockLogFromSwiftyJSON($0) }
    }

    private static func stockLogFromSwiftyJSON(_ item: JSON) -> PromotionDetailData.StockLog? {
        guard item.type == .dictionary else { return nil }
        let productName = firstNonEmpty(
            item["product_name"].string,
            item["name"].string,
            item["product_title"].string,
            item["product"]["name"].string,
            item["product_id"].string,
            item["id"].string,
            item["product"]["id"].string
        )
        let productId = firstNonEmpty(
            item["product_id"].string,
            item["id"].string,
            item["product"]["id"].string
        )
        let action = item["action"].string
        let quantity: String? = {
            if let q = item["quantity"].string { return q }
            if item["quantity"].exists() { return item["quantity"].stringValue }
            return nil
        }()
        let createdAt = firstNonEmpty(
            item["created_at"].string,
            item["date"].string,
            item["logged_at"].string
        )
        return PromotionDetailData.StockLog(
            productName: productName,
            productId: productId,
            action: action,
            quantity: quantity,
            createdAt: createdAt
        )
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for v in values {
            if let v = v, !v.isEmpty { return v }
        }
        return nil
    }

    /// Check only the `status`/`message` of an envelope, ignoring the shape of `data`.
    /// Used by endpoints (e.g. products/delete) whose `data` block is not a typed
    /// object — decoding it into one would fail and surface a false error.
    private func deliverStatus(_ r: Http.Result, completion: @escaping (Result<Void, ApiError>) -> Void) {
        var result: Result<Void, ApiError>
        if let body = r.body, !body.isEmpty {
            let envelope = JSON(parseJSON: body)
            if envelope["status"].boolValue {
                result = .success(())
            } else {
                result = .failure(ApiError(message: envelope["message"].string ?? "Request failed"))
            }
        } else {
            result = .failure(ApiError(message: "Network error (HTTP \(r.code))"))
        }
        DispatchQueue.main.async { completion(result) }
    }
}
