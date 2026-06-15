import UIKit

/// Converts network DTOs into the UI model objects the cells render.
/// Port of data/ApiMapper.java.
enum ApiMapper {

    private static let avatarColors: [UIColor] = [
        AppColors.purplePrimary, AppColors.info, AppColors.success, AppColors.warning, AppColors.danger
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
            let category = p.category.map { safe($0.title) } ?? ""
            return ProductItem(id: safe(p.id),
                               name: safe(p.name),
                               sku: safe(p.sku),
                               category: category,
                               price: formatPrice(p.sellingPrice),
                               stockStatus: stockStatus(p.stock),
                               imageUrl: p.imageUrl)
        }
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
