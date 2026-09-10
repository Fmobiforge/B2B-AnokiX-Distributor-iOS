import Foundation
import SwiftyJSON

/// An error carrying the server-provided (or synthesized) message.
struct ApiError: Error {
    let message: String
}

/// Typed facade over `Http`, port of network/ApiClient.java.
final class ApiClient {

    static let shared = ApiClient()

    static let baseURL = "http://109.176.30.129/ax/"

    /// Report files are served by their own service — a different port from the JSON API,
    /// with no `/ax/` prefix — which authenticates from the request body instead of an
    /// Authorization header. It is the only endpoint that does not sit under `baseURL`.
    static let reportDownloadURL = "http://109.176.30.129:5721/api/report-download"

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

    /// Request a password reset email. Public endpoint (no token). The backend always returns a
    /// generic success and never reveals whether the email exists, so only status/message matter.
    func forgotPassword(email: String, completion: @escaping (Result<Void, ApiError>) -> Void) {
        let form = ["email": email, "portal_type": "distributor"]
        Http.postForm(baseUrl: Self.baseURL, path: "api/common/forgot-password", form: form, token: nil) { [weak self] r in
            self?.deliverStatusOnly(r, completion: completion)
        }
    }

    // MARK: Push / device tokens (FCM)

    /// Register this device's FCM token so the backend can target it with pushes
    /// (api/common/device-tokens). Best-effort: only status/message matter, and a failure
    /// (e.g. the endpoint not yet live) surfaces via the completion but never crashes the app.
    func registerDeviceToken(_ token: String, completion: @escaping (Result<Void, ApiError>) -> Void) {
        // Field is `device_token` (not `token` — that key is reserved by the API gateway).
        let form = ["device_token": token, "platform": "ios"]
        Http.postForm(baseUrl: Self.baseURL, path: "api/common/device-tokens", form: form,
                      token: session.token) { [weak self] r in
            self?.deliverStatusOnly(r, completion: completion)
        }
    }

    /// Remove this device's FCM token on logout (api/common/device-tokens/delete).
    func unregisterDeviceToken(_ token: String, completion: @escaping (Result<Void, ApiError>) -> Void) {
        let form = ["device_token": token]
        Http.postForm(baseUrl: Self.baseURL, path: "api/common/device-tokens/delete", form: form,
                      token: session.token) { [weak self] r in
            self?.deliverStatusOnly(r, completion: completion)
        }
    }

    func getDashboard(completion: @escaping (Result<DashboardData, ApiError>) -> Void) {
        getAuthed("api/distributor/dashboard", query: nil, type: DashboardData.self, completion: completion)
    }

    /// The distributor's anokiX (IMB) wallet — balance shown on the dashboard.
    /// Pass `refresh: true` to bypass the short-lived balance cache (manual refresh button).
    func getWallet(refresh: Bool = false, completion: @escaping (Result<WalletData, ApiError>) -> Void) {
        getAuthed("api/common/wallet", query: refresh ? ["refresh": "1"] : nil,
                  type: WalletData.self, completion: completion)
    }

    /// Open a PayCloud Hosted Checkout to fund the wallet (api/common/topup/create). Returns
    /// the `pay_url` the app must open plus the `merchant_order_no` to poll afterwards.
    func createTopup(amount: Double, returnUrl: String,
                     completion: @escaping (Result<TopupCreateData, ApiError>) -> Void) {
        let form = ["amount": String(format: "%.2f", amount),
                    "return_url": returnUrl,
                    "portal": "distributor"]
        postAuthed("api/common/topup/create", form: form, type: TopupCreateData.self, completion: completion)
    }

    /// Poll a top-up after the user comes back from PayCloud (api/common/topup/status).
    /// The money has landed only when `credit_status=credited`.
    func getTopupStatus(merchantOrderNo: String,
                        completion: @escaping (Result<TopupStatusData, ApiError>) -> Void) {
        getAuthed("api/common/topup/status", query: ["merchant_order_no": merchantOrderNo],
                  type: TopupStatusData.self, completion: completion)
    }

    func getStores(keyword: String, completion: @escaping (Result<StoresData, ApiError>) -> Void) {
        let q = ["offset": "0", "page_size": "50", "keyword": keyword]
        getAuthed("api/distributor/stores/all", query: q, type: StoresData.self, completion: completion)
    }

    /// Soft-deletes a store (is_closed=1). Like products/delete the response carries
    /// no store object, so only the status/message matter.
    func deleteStore(id: String, completion: @escaping (Result<Void, ApiError>) -> Void) {
        Http.postForm(baseUrl: Self.baseURL, path: "api/distributor/stores/delete",
                      form: ["id": id], token: session.token) { [weak self] r in
            self?.deliverStatus(r, completion: completion)
        }
    }

    func getTraders(search: String, completion: @escaping (Result<TradersData, ApiError>) -> Void) {
        getTraders(search: search, status: "", creditStatus: "", completion: completion)
    }

    func getTraders(search: String, status: String, creditStatus: String,
                    completion: @escaping (Result<TradersData, ApiError>) -> Void) {
        let q = ["search": search, "status": status,
                 "credit_status": creditStatus, "registration_status": ""]
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

    /// Full trader record for the Edit wizard. Unlike the list row this also returns the
    /// linked user account, which carries the owner's name, email and mobile number.
    func getTraderById(id: String, completion: @escaping (Result<TraderDetailData, ApiError>) -> Void) {
        getAuthed("api/distributor/traders/get-by-id", query: ["id": id],
                  type: TraderDetailData.self, completion: completion)
    }

    /// Create a trader under the logged-in distributor (multipart, with KYC documents).
    func createTrader(form: [String: String], files: [Http.FilePart],
                      completion: @escaping (Result<CreateTraderData, ApiError>) -> Void) {
        Http.postMultipart(baseUrl: Self.baseURL, path: "api/distributor/traders/create",
                           form: form, files: files, token: session.token) { [weak self] r in
            self?.deliver(r, type: CreateTraderData.self, completion: completion)
        }
    }

    /// Update an existing trader. Same multipart shape as create plus an `id`; documents
    /// and the logo are only re-sent when the user picked a new file.
    func updateTrader(form: [String: String], files: [Http.FilePart],
                      completion: @escaping (Result<CreateTraderData, ApiError>) -> Void) {
        Http.postMultipart(baseUrl: Self.baseURL, path: "api/distributor/traders/update",
                           form: form, files: files, token: session.token) { [weak self] r in
            self?.deliver(r, type: CreateTraderData.self, completion: completion)
        }
    }

    /// Delete a trader. The response carries no trader object, so only the message matters.
    func deleteTrader(id: String, completion: @escaping (Result<String, ApiError>) -> Void) {
        postMessage("api/distributor/traders/delete", form: ["id": id], completion: completion)
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

    // MARK: Warehouse staff

    /// Warehouse staff who can sign in to pick, pack and handle stock.
    func getStaff(completion: @escaping (Result<StaffData, ApiError>) -> Void) {
        getAuthed("api/distributor/staff", query: nil, type: StaffData.self, completion: completion)
    }

    /// Creates a staff login (api/distributor/staff).
    func addStaff(firstName: String, lastName: String, email: String, password: String,
                  phone: String, jobTitle: String,
                  completion: @escaping (Result<String, ApiError>) -> Void) {
        var form = ["first_name": firstName, "last_name": lastName,
                    "email": email, "password": password]
        if !phone.isEmpty { form["phone_number"] = phone }
        if !jobTitle.isEmpty { form["job_title"] = jobTitle }
        postMessage("api/distributor/staff", form: form, completion: completion)
    }

    /// Sets a new sign-in password for a staff member (they are not emailed).
    func setStaffPassword(staffId: Int64, password: String,
                          completion: @escaping (Result<String, ApiError>) -> Void) {
        postMessage("api/distributor/staff/password",
                    form: ["staff_id": String(staffId), "password": password], completion: completion)
    }

    /// Turns a staff member's sign-in on ("active") or off ("disabled").
    func updateStaffStatus(staffId: Int64, status: String,
                           completion: @escaping (Result<String, ApiError>) -> Void) {
        postMessage("api/distributor/staff/update",
                    form: ["staff_id": String(staffId), "status": status], completion: completion)
    }

    // MARK: Card machine (PayCloud POS)

    /// Card machines linked to this account (api/common/pos/terminals).
    func getPosTerminals(completion: @escaping (Result<PosTerminalsData, ApiError>) -> Void) {
        getAuthed("api/common/pos/terminals", query: nil, type: PosTerminalsData.self, completion: completion)
    }

    /// Payments pushed to a card machine, newest first (api/common/pos/payments).
    func getPosPayments(page: Int, perPage: Int,
                        completion: @escaping (Result<PosPaymentsData, ApiError>) -> Void) {
        let q = ["page": String(page), "per_page": String(perPage)]
        getAuthed("api/common/pos/payments", query: q, type: PosPaymentsData.self, completion: completion)
    }

    /// Links a card machine by the serial printed on the device.
    func addPosTerminal(terminalSn: String, label: String,
                        completion: @escaping (Result<String, ApiError>) -> Void) {
        var form = ["terminal_sn": terminalSn]
        if !label.isEmpty { form["label"] = label }
        postMessage("api/common/pos/terminals", form: form, completion: completion)
    }

    /// Unlinks a card machine (api/common/pos/terminals/remove).
    func removePosTerminal(terminalId: Int64,
                           completion: @escaping (Result<String, ApiError>) -> Void) {
        postMessage("api/common/pos/terminals/remove",
                    form: ["terminal_id": String(terminalId)], completion: completion)
    }

    /// Pushes an amount to a card machine so the customer can tap / insert / swipe there.
    /// Card details never reach the app.
    func sendPosPayment(amount: String, terminalId: Int64, description: String,
                        completion: @escaping (Result<String, ApiError>) -> Void) {
        var form = ["amount": amount, "terminal_id": String(terminalId)]
        if !description.isEmpty { form["description"] = description }
        postMessage("api/common/pos/payments", form: form, completion: completion)
    }

    /// Everything the Inventory screen needs: summary, rows, chart, movements, warehouses.
    func getInventoryPage(completion: @escaping (Result<InventoryPageData, ApiError>) -> Void) {
        getAuthed("api/distributor/inventory/page", query: nil, type: InventoryPageData.self, completion: completion)
    }

    /// Stock ledger for one product (Inventory → item → History).
    func getStockHistory(productId: String, limit: Int = 100,
                         completion: @escaping (Result<StockHistoryData, ApiError>) -> Void) {
        let q = ["product_id": productId, "limit": String(limit)]
        getAuthed("api/distributor/inventory/history", query: q, type: StockHistoryData.self, completion: completion)
    }

    /// Sets the counted quantity for a product (Adjust Stock). The callback receives the
    /// server's confirmation message, e.g. "Stock updated from 1000 to 950.".
    func setStock(productId: String, quantity: Int, notes: String,
                  completion: @escaping (Result<String, ApiError>) -> Void) {
        var form = ["product_id": productId, "quantity": String(quantity)]
        if !notes.isEmpty { form["notes"] = notes }
        postMessage("api/distributor/inventory/set-stock", form: form, completion: completion)
    }

    /// Moves units between warehouses; the total on hand does not change.
    func transferStock(productId: String, fromWarehouseId: String, toWarehouseId: String,
                       quantity: Int, notes: String,
                       completion: @escaping (Result<String, ApiError>) -> Void) {
        var form = ["product_id": productId,
                    "from_warehouse_id": fromWarehouseId,
                    "to_warehouse_id": toWarehouseId,
                    "quantity": String(quantity)]
        if !notes.isEmpty { form["notes"] = notes }
        postMessage("api/distributor/inventory/transfer", form: form, completion: completion)
    }

    /// Books new stock into a warehouse (Add Stock / Receive).
    func receiveStock(warehouseId: String, productId: String, quantity: Int, unitCost: String,
                      batchNumber: String, expiryDate: String,
                      completion: @escaping (Result<String, ApiError>) -> Void) {
        var form = ["warehouse_id": warehouseId, "product_id": productId,
                    "quantity": String(quantity)]
        if !unitCost.isEmpty { form["unit_cost"] = unitCost }
        if !batchNumber.isEmpty { form["batch_number"] = batchNumber }
        if !expiryDate.isEmpty { form["expiry_date"] = expiryDate }
        postMessage("api/distributor/inventory/receive", form: form, completion: completion)
    }

    /// POSTs a form and hands back the envelope's `message` — the inventory mutations
    /// echo what changed ("100 units moved.") and their `data` shape varies.
    private func postMessage(_ path: String, form: [String: String],
                             completion: @escaping (Result<String, ApiError>) -> Void) {
        Http.postForm(baseUrl: Self.baseURL, path: path, form: form, token: session.token) { r in
            var result: Result<String, ApiError>
            if let body = r.body, !body.isEmpty {
                let envelope = JSON(parseJSON: body)
                if envelope["status"].boolValue {
                    result = .success(envelope["message"].string ?? "")
                } else {
                    result = .failure(ApiError(message: envelope["message"].string ?? "Request failed"))
                }
            } else {
                result = .failure(ApiError(message: "Network error (HTTP \(r.code))"))
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    // MARK: Support Centre

    /// Support Centre in one call: enabled contact channels, the help-article catalogue
    /// and every ticket this account has raised.
    func getSupportOverview(completion: @escaping (Result<SupportOverviewData, ApiError>) -> Void) {
        getAuthed("api/common/support/overview", query: nil, type: SupportOverviewData.self,
                  completion: completion)
    }

    /// Help-article search.
    func searchSupportArticles(query: String,
                               completion: @escaping (Result<SupportArticlesData, ApiError>) -> Void) {
        getAuthed("api/common/support/articles/search", query: ["q": query],
                  type: SupportArticlesData.self, completion: completion)
    }

    /// Raise a ticket. `channel` is `"web"` for a written request or `"callback"` for a
    /// call-back, which also carries `callback_phone`.
    func createSupportTicket(form: [String: String],
                             completion: @escaping (Result<SupportTicketData, ApiError>) -> Void) {
        postAuthed("api/common/support/tickets", form: form, type: SupportTicketData.self,
                   completion: completion)
    }

    /// One ticket with its full conversation.
    func getSupportTicket(id: String,
                          completion: @escaping (Result<SupportTicketData, ApiError>) -> Void) {
        getAuthed("api/common/support/tickets/\(id)", query: nil, type: SupportTicketData.self,
                  completion: completion)
    }

    /// Post a reply; the response carries the ticket with the new message appended.
    func replySupportTicket(ticketId: String, message: String,
                            completion: @escaping (Result<SupportTicketData, ApiError>) -> Void) {
        postAuthed("api/common/support/tickets/reply",
                   form: ["ticket_id": ticketId, "message": message],
                   type: SupportTicketData.self, completion: completion)
    }

    /// Close a ticket; the response carries it with the closing note appended.
    func closeSupportTicket(ticketId: String,
                            completion: @escaping (Result<SupportTicketData, ApiError>) -> Void) {
        postAuthed("api/common/support/tickets/close", form: ["ticket_id": ticketId],
                   type: SupportTicketData.self, completion: completion)
    }

    // MARK: Reports

    /// Reports dashboard: the catalogue of reports that can be generated, everything
    /// already generated, and the KPI summary. Takes no parameters — the screen's search
    /// and category filters run over the returned list.
    func getReports(completion: @escaping (Result<ReportsData, ApiError>) -> Void) {
        getAuthed("api/distributor/reports", query: nil, type: ReportsData.self, completion: completion)
    }

    /// Build a report for a period — `reportKey` comes from `available[]`.
    ///
    /// The response echoes the new report and a refreshed summary, but the screen reloads
    /// the whole list straight afterwards, so only the envelope's message ("Stock Levels
    /// ready — 10 rows.") is worth carrying back.
    func generateReport(reportKey: String, from: String, to: String,
                        completion: @escaping (Result<String, ApiError>) -> Void) {
        postMessage("api/distributor/reports/generate",
                    form: ["report_key": reportKey, "from": from, "to": to],
                    completion: completion)
    }

    /// Delete a generated report. The response only carries the refreshed summary.
    func deleteReport(id: String, completion: @escaping (Result<String, ApiError>) -> Void) {
        postMessage("api/distributor/reports/delete", form: ["id": id], completion: completion)
    }

    /// Fetch a generated report's file.
    ///
    /// Downloads are served by a separate host and port from the JSON API, and that
    /// service authenticates from the request body rather than a Bearer header — so this
    /// is the one call that does not go through `baseURL`.
    func downloadReport(id: String, completion: @escaping (Result<Http.Download, ApiError>) -> Void) {
        let body: [String: Any] = ["id": Int(id) ?? 0, "token": session.token]
        Http.postJsonForFile(url: Self.reportDownloadURL, json: body, token: nil) { download in
            let result: Result<Http.Download, ApiError>
            if download.ok && !Self.looksLikeJSON(download) {
                result = .success(download)
            } else {
                result = .failure(ApiError(message: Self.downloadError(download)))
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// A JSON body from the download service means an error, not a report.
    private static func looksLikeJSON(_ download: Http.Download) -> Bool {
        (download.mimeType ?? "").lowercased().contains("json")
    }

    /// Surface the download service's own message when it sent one.
    private static func downloadError(_ download: Http.Download) -> String {
        if looksLikeJSON(download), let data = download.data,
           let text = String(data: data, encoding: .utf8) {
            let message = JSON(parseJSON: text)["message"].string ?? ""
            if !message.isEmpty { return message }
        }
        return "Could not download the report (HTTP \(download.code))"
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

    // MARK: Deliveries

    /// Deliveries list + KPI summary + status counts for a date range. Empty filters are
    /// omitted; tab/area/search filtering is then applied locally over the returned set.
    func getDeliveries(dateFrom: String, dateTo: String, search: String, page: Int, perPage: Int,
                       completion: @escaping (Result<DeliveriesData, ApiError>) -> Void) {
        var q: [String: String] = ["page": String(page), "per_page": String(perPage)]
        if !dateFrom.isEmpty { q["date_from"] = dateFrom }
        if !dateTo.isEmpty { q["date_to"] = dateTo }
        let trimmed = search.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { q["search"] = trimmed }
        getAuthed("api/distributor/deliveries", query: q, type: DeliveriesData.self, completion: completion)
    }

    /// Full delivery detail (+ items) for the detail screen.
    func getDeliveryById(id: String, completion: @escaping (Result<DeliveryDetailData, ApiError>) -> Void) {
        getAuthed("api/distributor/deliveries/get-by-id", query: ["id": id],
                  type: DeliveryDetailData.self, completion: completion)
    }

    /// Advance a delivery: `action` is `dispatch` (ReadyForDelivery → OutForDelivery) or
    /// `deliver` (OutForDelivery → Delivered). Returns the updated delivery.
    func deliveryAction(_ action: String, deliveryId: Int,
                        completion: @escaping (Result<DeliveryDetailData, ApiError>) -> Void) {
        Http.postForm(baseUrl: Self.baseURL, path: "api/distributor/deliveries/\(action)",
                      form: ["order_id": String(deliveryId)], token: session.token) { [weak self] r in
            self?.deliver(r, type: DeliveryDetailData.self, completion: completion)
        }
    }

    // MARK: Returns (GRNs)

    /// Returns list + KPI summary + status counts for a date range. Empty filters are omitted;
    /// status tab / reason / search filtering is then applied locally over the returned set.
    func getReturns(dateFrom: String, dateTo: String, search: String, page: Int, perPage: Int,
                    completion: @escaping (Result<ReturnsData, ApiError>) -> Void) {
        var q: [String: String] = ["page": String(page), "per_page": String(perPage)]
        if !dateFrom.isEmpty { q["date_from"] = dateFrom }
        if !dateTo.isEmpty { q["date_to"] = dateTo }
        let trimmed = search.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { q["search"] = trimmed }
        getAuthed("api/distributor/grns", query: q, type: ReturnsData.self, completion: completion)
    }

    /// Finances ledger — GET `api/distributor/finances`. Optionally scoped to a date range that
    /// the screen drives from the range picker; returns the transaction list + KPI summary.
    /// Status / type / method / search filtering is applied locally over the returned set.
    func getFinances(dateFrom: String, dateTo: String,
                     completion: @escaping (Result<FinancesData, ApiError>) -> Void) {
        var q: [String: String] = [:]
        if !dateFrom.isEmpty { q["date_from"] = dateFrom }
        if !dateTo.isEmpty { q["date_to"] = dateTo }
        getAuthed("api/distributor/finances", query: q.isEmpty ? nil : q,
                  type: FinancesData.self, completion: completion)
    }

    /// Full return detail (+ items) for the detail screen.
    func getReturnById(id: String, completion: @escaping (Result<ReturnDetailData, ApiError>) -> Void) {
        getAuthed("api/distributor/grns/get-by-id", query: ["id": id],
                  type: ReturnDetailData.self, completion: completion)
    }

    /// Decide a return: `action` is `approve` or `reject`; `note` is the optional decision
    /// note. Returns the updated return (same shape as get-by-id).
    func returnAction(_ action: String, grnId: Int, note: String,
                      completion: @escaping (Result<ReturnDetailData, ApiError>) -> Void) {
        var form = ["grn_id": String(grnId)]
        if !note.isEmpty { form["note"] = note }
        Http.postForm(baseUrl: Self.baseURL, path: "api/distributor/grns/\(action)",
                      form: form, token: session.token) { [weak self] r in
            self?.deliver(r, type: ReturnDetailData.self, completion: completion)
        }
    }

    // MARK: Notifications (common)

    /// Live unread-notification count (api/common/notifications/unread-count).
    func getUnreadCount(completion: @escaping (Result<UnreadCountData, ApiError>) -> Void) {
        getAuthed("api/common/notifications/unread-count", query: nil, type: UnreadCountData.self, completion: completion)
    }

    /// Notification feed (api/common/notifications). `filter` is "all" (omitted) or "unread";
    /// paged by `page`/`perPage`.
    func getNotifications(filter: String, page: Int, perPage: Int,
                          completion: @escaping (Result<NotificationsData, ApiError>) -> Void) {
        var q: [String: String] = ["page": String(page), "per_page": String(perPage)]
        if !filter.isEmpty && filter != "all" { q["filter"] = filter }
        getAuthed("api/common/notifications", query: q, type: NotificationsData.self, completion: completion)
    }

    /// Mark one notification read (api/common/notifications/read, id=).
    func markNotificationRead(id: String, completion: @escaping (Result<Void, ApiError>) -> Void) {
        Http.postForm(baseUrl: Self.baseURL, path: "api/common/notifications/read",
                      form: ["id": id], token: session.token) { [weak self] r in
            self?.deliverStatusOnly(r, completion: completion)
        }
    }

    /// Mark every notification read (api/common/notifications/read, all=true).
    func markAllNotificationsRead(completion: @escaping (Result<Void, ApiError>) -> Void) {
        Http.postForm(baseUrl: Self.baseURL, path: "api/common/notifications/read",
                      form: ["all": "true"], token: session.token) { [weak self] r in
            self?.deliverStatusOnly(r, completion: completion)
        }
    }

    func getBaseInfo(completion: @escaping (Result<BaseInfoData, ApiError>) -> Void) {
        getAuthed("api/common/base-info", query: nil, type: BaseInfoData.self, completion: completion)
    }

    // MARK: Settings: business profile (7-step)

    /// Full distributor business record for the Business editor.
    func getBusinessProfile(completion: @escaping (Result<BusinessProfileData, ApiError>) -> Void) {
        getAuthed("api/distributor/business/profile", query: nil,
                  type: BusinessProfileData.self, completion: completion)
    }

    /// Save one Business step (multipart so logo/document steps share the path).
    func updateBusinessProfile(form: [String: String], files: [Http.FilePart],
                               completion: @escaping (Result<Void, ApiError>) -> Void) {
        Http.postMultipart(baseUrl: Self.baseURL, path: "api/distributor/business/profile/update",
                           form: form, files: files, token: session.token) { [weak self] r in
            self?.deliverStatusOnly(r, completion: completion)
        }
    }

    // MARK: Settings: profile / preferences

    /// Portal preferences + notification toggles (api/common/preferences).
    func getPreferences(completion: @escaping (Result<PreferencesData, ApiError>) -> Void) {
        getAuthed("api/common/preferences", query: nil, type: PreferencesData.self, completion: completion)
    }

    /// Update the personal profile (api/common/profile/update).
    func updateProfile(firstName: String, lastName: String, email: String, phone: String,
                       completion: @escaping (Result<ProfileUpdateData, ApiError>) -> Void) {
        postAuthed("api/common/profile/update",
                   form: ["first_name": firstName, "last_name": lastName,
                          "email": email, "phone_number": phone],
                   type: ProfileUpdateData.self, completion: completion)
    }

    /// Change the account password (api/common/profile/password).
    func changePassword(currentPassword: String, newPassword: String,
                        completion: @escaping (Result<Void, ApiError>) -> Void) {
        Http.postForm(baseUrl: Self.baseURL, path: "api/common/profile/password",
                      form: ["current_password": currentPassword, "new_password": newPassword],
                      token: session.token) { [weak self] r in
            self?.deliverStatusOnly(r, completion: completion)
        }
    }

    /// Update the 6 notification toggles (api/common/preferences/update, JSON body). The key
    /// set matches the Trader app exactly so one backend gate serves both portals — see
    /// `FCM-settings/3-Event-Catalogue.md` §7.
    func updateNotificationPrefs(orderAlerts: Bool, lowStockAlerts: Bool, deliveryUpdates: Bool,
                                 promotionAlerts: Bool, financeReminders: Bool, reportReady: Bool,
                                 completion: @escaping (Result<Void, ApiError>) -> Void) {
        let notifications: [String: Any] = [
            "orderAlerts": orderAlerts, "lowStockAlerts": lowStockAlerts,
            "deliveryUpdates": deliveryUpdates, "promotionAlerts": promotionAlerts,
            "financeReminders": financeReminders, "reportReady": reportReady
        ]
        postPreferences(["notifications": notifications], completion: completion)
    }

    /// Update the regional preferences (api/common/preferences/update, JSON body).
    func updatePreferences(language: String, currency: String, timezone: String, dateFormat: String,
                           completion: @escaping (Result<Void, ApiError>) -> Void) {
        postPreferences(["language": language, "currency": currency,
                         "timezone": timezone, "date_format": dateFormat], completion: completion)
    }

    private func postPreferences(_ body: [String: Any],
                                 completion: @escaping (Result<Void, ApiError>) -> Void) {
        Http.postJson(baseUrl: Self.baseURL, path: "api/common/preferences/update",
                      json: body, token: session.token) { [weak self] r in
            self?.deliverStatusOnly(r, completion: completion)
        }
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

    // MARK: Airtime & VAS (Limes, common)

    /// VAS dashboard: recent transactions + KPI summary (spend/count today, commission this
    /// month, wallet balance) — api/common/vas/transactions.
    func getVasTransactions(page: Int, perPage: Int,
                            completion: @escaping (Result<VasTransactionsData, ApiError>) -> Void) {
        let q = ["page": String(page), "per_page": String(perPage)]
        getAuthed("api/common/vas/transactions", query: q, type: VasTransactionsData.self, completion: completion)
    }

    /// The Limes VAS category tree (api/common/vas/categories). Flatten via `leaves`. Scoped to
    /// the customer being acted for — see `selectVasCustomer`.
    func getVasCategories(customerId: String,
                          completion: @escaping (Result<VasCategoriesData, ApiError>) -> Void) {
        getAuthed("api/common/vas/categories", query: Self.customerScope(customerId),
                  type: VasCategoriesData.self, completion: completion)
    }

    /// Purchasable products for one leaf category (api/common/vas/products).
    func getVasProducts(category: String, page: Int, limit: Int, customerId: String,
                        completion: @escaping (Result<VasProductsData, ApiError>) -> Void) {
        var q = Self.customerScope(customerId)
        q["category"] = category
        q["page"] = String(page)
        q["limit"] = String(limit)
        getAuthed("api/common/vas/products", query: q, type: VasProductsData.self, completion: completion)
    }

    /// A fresh parameter map already carrying `customer_id`. Limes runs these calls on the
    /// customer's own token, so the id travels with every request the three customer-scoped
    /// tabs make; a blank id is simply omitted rather than sent as an empty string.
    private static func customerScope(_ customerId: String) -> [String: String] {
        let id = customerId.trimmingCharacters(in: .whitespaces)
        return id.isEmpty ? [:] : ["customer_id": id]
    }

    /// Buy a VAS product (api/common/vas/purchase). Paid from the anokiX wallet; the server
    /// debits and forwards to Limes. Only status/message decide success — the failure path
    /// carries the network's reason (e.g. inactive subscriber), and `data` is null.
    func purchaseVas(productId: String, msisdn: String, amount: Double, sku: String, name: String,
                     category: String, customerId: String,
                     completion: @escaping (Result<Void, ApiError>) -> Void) {
        var form = Self.customerScope(customerId)
        form["product_id"] = productId
        form["msisdn"] = msisdn
        form["amount"] = String(amount)
        form["sku"] = sku
        form["name"] = name
        form["category"] = category
        // Postman collection sends earn_commission=1 so the distributor accrues their VAS commission.
        form["earn_commission"] = "1"
        Http.postForm(baseUrl: Self.baseURL, path: "api/common/vas/purchase", form: form,
                      token: session.token) { [weak self] r in
            self?.deliverStatus(r, completion: completion)
        }
    }

    /// Register an end-customer in the Limes CRM (api/common/vas/onboard-customer). Step 1 of
    /// signing someone up to a SIM subscription; upserts by ID number, so a retry reports
    /// `alreadyExists` rather than creating a duplicate.
    func onboardVasCustomer(form: [String: String],
                            completion: @escaping (Result<VasOnboardCustomerData, ApiError>) -> Void) {
        postAuthed("api/common/vas/onboard-customer", form: form,
                   type: VasOnboardCustomerData.self, completion: completion)
    }

    /// Build — but do not send — the JSON body an onboard would POST to Limes
    /// (api/common/vas/onboard-customer/preview). Runs no validation, so a half-filled form
    /// still previews. The body is arbitrary JSON, so it is rendered to text here rather than
    /// forced through Codable.
    func previewVasOnboard(form: [String: String],
                           completion: @escaping (Result<String, ApiError>) -> Void) {
        Http.postForm(baseUrl: Self.baseURL, path: "api/common/vas/onboard-customer/preview",
                      form: form, token: session.token) { r in
            var result: Result<String, ApiError>
            if let body = r.body, !body.isEmpty {
                let envelope = JSON(parseJSON: body)
                if envelope["status"].boolValue {
                    let data = envelope["data"]
                    var text = "\(data["method"].string ?? "POST") "
                        + (data["base_url"].string ?? "") + (data["endpoint"].string ?? "") + "\n"
                    for header in data["headers"].arrayValue { text += header.stringValue + "\n" }
                    text += "\n" + (data["body"].rawString(.utf8, options: [.prettyPrinted]) ?? "{}")
                    result = .success(text)
                } else {
                    result = .failure(ApiError(message: envelope["message"].string ?? "Request failed"))
                }
            } else {
                result = .failure(ApiError(message: "Network error (HTTP \(r.code))"))
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// End-customers this distributor has onboarded (api/common/vas/customers). Pass
    /// `activeOnly` to ask for the ACT customers only — that is the list the "Acting as" picker
    /// offers, because Limes will not authenticate as a customer who is not active yet.
    func getVasCustomers(search: String, limit: Int, activeOnly: Bool = false,
                         completion: @escaping (Result<VasCustomersData, ApiError>) -> Void) {
        var q = ["search": search, "limit": String(limit)]
        if activeOnly { q["active"] = "1" }
        getAuthed("api/common/vas/customers", query: q, type: VasCustomersData.self, completion: completion)
    }

    /// Authenticate as an onboarded customer (api/common/vas/select-customer). Limes issues its
    /// token per customer, so the Subscription, Catalog & orders and Dynamic services tabs only
    /// work once this has been approved; every later call on those tabs carries the same
    /// `customer_id`.
    func selectVasCustomer(customerId: String,
                           completion: @escaping (Result<VasSelectCustomerData, ApiError>) -> Void) {
        postAuthed("api/common/vas/select-customer", form: Self.customerScope(customerId),
                   type: VasSelectCustomerData.self, completion: completion)
    }

    /// SIM subscription products offered by the "Assign a SIM" form (never hardcode these).
    func getVasSubscriptionProducts(
        customerId: String,
        completion: @escaping (Result<VasSubscriptionProductsData, ApiError>) -> Void) {
        getAuthed("api/common/vas/subscription-products", query: Self.customerScope(customerId),
                  type: VasSubscriptionProductsData.self, completion: completion)
    }

    /// SIMs already activated for the selected customer, with the MSISDN Limes assigned to each.
    func getVasSubscriptions(customerId: String,
                             completion: @escaping (Result<VasSubscriptionsData, ApiError>) -> Void) {
        getAuthed("api/common/vas/subscriptions", query: Self.customerScope(customerId),
                  type: VasSubscriptionsData.self, completion: completion)
    }

    /// Activate a SIM / create a subscription (api/common/vas/subscribe). An eSIM carries no
    /// ICCID, so `e_sim=1` is sent instead of the serial; a physical "SIM in hand" sends its
    /// ICCID and activates immediately.
    func subscribeVas(productId: String, iccid: String, eSim: Bool, customerId: String,
                      completion: @escaping (Result<Void, ApiError>) -> Void) {
        var form = Self.customerScope(customerId)
        form["product_id"] = productId
        if eSim { form["e_sim"] = "1" } else { form["iccid"] = iccid }
        Http.postForm(baseUrl: Self.baseURL, path: "api/common/vas/subscribe", form: form,
                      token: session.token) { [weak self] r in
            self?.deliverStatus(r, completion: completion)
        }
    }

    /// Provision custom/variable-value bundles straight onto a number
    /// (api/common/vas/dynamic-services) — the path Limes recommends over order/create for
    /// amounts the fixed catalog cannot express. Expects a JSON body; the charge is the sum
    /// of `priceInCents`.
    func provisionVasDynamicServices(msisdn: String, services: [[String: Any]], customerId: String,
                                     completion: @escaping (Result<Void, ApiError>) -> Void) {
        var json: [String: Any] = [
            "msisdn": msisdn,
            // Postman collection sends earn_commission=1 so the distributor accrues commission.
            "earn_commission": 1,
            "services": services
        ]
        Self.customerScope(customerId).forEach { json[$0.key] = $0.value }
        Http.postJson(baseUrl: Self.baseURL, path: "api/common/vas/dynamic-services", json: json,
                      token: session.token) { [weak self] r in
            self?.deliverStatus(r, completion: completion)
        }
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

    /// Checks only the `status`/`message` of an envelope, ignoring the shape of `data`.
    /// Used by endpoints (e.g. notifications/read) whose `data` block is not consumed.
    private func deliverStatusOnly(_ r: Http.Result, completion: @escaping (Result<Void, ApiError>) -> Void) {
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
