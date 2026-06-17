import UIKit

/// Converts network DTOs into the UI model objects the cells render.
/// Port of data/ApiMapper.java.
enum ApiMapper {

    // Same order as Android ApiMapper.AVATAR_COLORS so trader avatars match across platforms.
    private static let avatarColors: [UIColor] = [
        AppColors.danger, AppColors.warning, AppColors.purplePrimary, AppColors.info, AppColors.success
    ]

    // MARK: Stores

    static func toStoreItems(_ data: StoresData?) -> [StoreItem] {
        guard let stores = data?.stores else { return [] }
        return stores.map { s in
            StoreItem(id: String(s.id),
                      name: safe(s.name),
                      address: safe(s.address),
                      followerCount: s.followerCount ?? 0,
                      reviewCount: s.reviewCount ?? 0,
                      status: "Active",
                      area: safe(s.address))
        }
    }

    // MARK: Traders

    static func toTraderItems(_ data: TradersData?) -> [TraderItem] {
        guard let traders = data?.traders else { return [] }
        return traders.enumerated().map { index, t in
            let name = !isEmpty(t.businessName) ? safe(t.businessName)
                : (!isEmpty(t.tradingName) ? safe(t.tradingName) : safe(t.name))
            let phone = formatTraderPhone(countryCode: t.countryCode, phoneNumber: t.phoneNumber)
            return TraderItem(id: safe(t.id),
                              name: name,
                              traderCode: safe(t.traderCode),
                              location: safe(t.address),
                              phone: phone,
                              segment: capitalize(t.storeType),
                              area: safe(t.address),
                              initials: initials(name),
                              avatarColor: avatarColors[index % avatarColors.count],
                              isNew: (t.status ?? "").caseInsensitiveCompare("New") == .orderedSame)
        }
    }

    private static func formatTraderPhone(countryCode: String?, phoneNumber: String?) -> String {
        if isEmpty(countryCode) {
            let raw = safe(phoneNumber).trimmingCharacters(in: .whitespaces)
            if raw.hasPrefix("+") { return raw }
            if raw.allSatisfy(\.isNumber), raw.hasPrefix("27") { return "+\(raw)" }
            return raw
        }
        return "+\(safe(countryCode)) \(safe(phoneNumber))".trimmingCharacters(in: .whitespaces)
    }

    // MARK: Products

    static func toProductItems(_ data: ProductsData?) -> [ProductItem] {
        guard let products = data?.products else { return [] }
        return products.map { p in
            ProductItem(id: safe(p.id),
                        name: safe(p.name),
                        sku: safe(p.sku),
                        category: safe(p.categoryTitle),
                        price: formatPrice(p.sellingPrice),
                        stockStatus: stockStatus(p.stockValue),
                        imageUrl: p.listImageUrl)
        }
    }

    // MARK: Promotions

    static func toPromotionItems(_ data: PromotionsData?) -> [PromotionItem] {
        guard let promotions = data?.promotions else { return [] }
        let symbol = data?.summary?.currency?.symbol ?? "R"
        return promotions.map { p in
            PromotionItem(id: safe(p.id),
                          name: safe(p.name),
                          campaignType: safe(p.campaignType),
                          typeLabel: campaignTypeLabel(p.campaignType),
                          status: safe(p.status),
                          statusLabel: prettify(p.status),
                          dateRange: dateRange(p.startDate, p.endDate),
                          budget: formatMoney(symbol, p.budget ?? 0),
                          reach: formatCount(p.reach ?? 0),
                          clicks: formatCount(p.clicks ?? 0),
                          ctr: formatPercent(p.ctr ?? 0))
        }
    }

    static func campaignTypeLabel(_ type: String?) -> String {
        guard let type = type, !type.isEmpty else { return "" }
        switch type {
        case "best_deal": return "Best Deal"
        case "cant_miss_deal": return "Can't Miss Deal"
        case "exclusive_deal": return "Exclusive Deal"
        case "featured_store": return "Featured Store"
        case "promotion": return "Promotion"
        case "post": return "Post"
        case "story": return "Story"
        default: return prettify(type)
        }
    }

    /// "pending_approval" → "Pending Approval".
    static func prettify(_ value: String?) -> String {
        guard let value = value, !value.isEmpty else { return "" }
        return value.split(whereSeparator: { $0 == "_" || $0 == " " })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static let inDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func dateFormatter(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = pattern
        return f
    }

    /// "2026-06-15" + "2026-06-30" → "15 Jun – 30 Jun 2026".
    private static func dateRange(_ start: String?, _ end: String?) -> String {
        guard let s = parseDate(start), let e = parseDate(end) else {
            return "\(safe(start)) – \(safe(end))".trimmingCharacters(in: .whitespaces)
        }
        let dm = dateFormatter("d MMM")
        let dmy = dateFormatter("d MMM yyyy")
        let y = dateFormatter("yyyy")
        if y.string(from: s) == y.string(from: e) {
            return "\(dm.string(from: s)) – \(dmy.string(from: e))"
        }
        return "\(dmy.string(from: s)) – \(dmy.string(from: e))"
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        return inDateFormatter.date(from: value)
    }

    private static func formatMoney(_ symbol: String, _ value: Double) -> String {
        return symbol + (countFormatter.string(from: NSNumber(value: value)) ?? String(Int(value)))
    }

    private static let countFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.maximumFractionDigits = 0
        return f
    }()

    private static func formatCount(_ value: Double) -> String {
        return countFormatter.string(from: NSNumber(value: value)) ?? String(Int(value))
    }

    private static func formatPercent(_ value: Double) -> String {
        return String(format: "%.1f%%", value)
    }

    // MARK: Helpers

    private static let priceFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    private static func formatPrice(_ value: String?) -> String {
        guard let value = value, let number = Double(value) else { return "R" + safe(value) }
        return "R" + (priceFormatter.string(from: NSNumber(value: number)) ?? value)
    }

    private static func stockStatus(_ stockValue: String?) -> String {
        let stock = Int(Double(stockValue ?? "0") ?? 0)
        if stock <= 0 { return "Out of Stock" }
        if stock <= 10 { return "Low Stock" }
        return "In Stock"
    }

    private static func initials(_ name: String) -> String {
        let parts = name.trimmingCharacters(in: .whitespaces).split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }.map(String.init)
        return letters.isEmpty ? "?" : letters.joined().uppercased()
    }

    private static func capitalize(_ value: String?) -> String {
        guard let value = value, !value.isEmpty else { return "" }
        return value.prefix(1).uppercased() + value.dropFirst()
    }

    private static func isEmpty(_ s: String?) -> Bool {
        (s ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }
    private static func safe(_ s: String?) -> String { s ?? "" }
}
