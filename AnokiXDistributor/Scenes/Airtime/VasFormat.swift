import UIKit

/// Formatting shared by every Airtime & VAS section — the UIKit twin of the Android
/// `VasFormat` + the number/status helpers that used to live on `AirtimeViewController`.
enum VasFormat {

    // MARK: Money

    private static let moneyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "\u{00A0}"
        f.decimalSeparator = ","
        f.groupingSize = 3
        f.usesGroupingSeparator = true
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    /// South-African money, e.g. "R 5 050,00" — space-grouped thousands, comma decimal.
    static func money(_ value: Double) -> String {
        "R " + (moneyFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value))
    }

    static func money(_ value: String?) -> String { money(parse(value)) }

    /// Lenient number parse for API strings and free-text input that may be blank.
    /// Accepts both "10.50" and the comma decimal a SA keyboard produces.
    static func parse(_ value: String?) -> Double {
        guard let raw = value?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return 0 }
        return Double(raw.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private static let plainFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "\u{00A0}"
        f.maximumFractionDigits = 0
        return f
    }()

    /// Space-grouped byte count for the Dynamic services "= N bytes" hint.
    static func bytes(_ value: Int64) -> String {
        plainFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    // MARK: Numbers

    /// SA mobile number: 10 digits (0xxxxxxxxx) or 11 digits (27xxxxxxxxx).
    static func isValidMsisdn(_ raw: String) -> Bool {
        let digits = raw.filter(\.isNumber)
        return (digits.count == 10 && digits.hasPrefix("0"))
            || (digits.count == 11 && digits.hasPrefix("27"))
    }

    /// ICCIDs printed on SA SIMs are 19–20 digits — a phone number pasted here is a typo.
    static func isValidIccid(_ raw: String) -> Bool {
        let digits = raw.filter(\.isNumber)
        return digits.count >= 18 && digits.count <= 22
    }

    /// 27821234567 / 0821234567 → "082 123 4567" when it resolves to a 10-digit local number.
    static func msisdn(_ raw: String?) -> String {
        guard let raw else { return "" }
        var digits = raw.filter(\.isNumber)
        if digits.hasPrefix("27") && digits.count == 11 {
            digits = "0" + digits.dropFirst(2)
        }
        guard digits.count == 10 else { return raw }
        let a = digits.prefix(3)
        let b = digits.dropFirst(3).prefix(3)
        let c = digits.dropFirst(6)
        return "\(a) \(b) \(c)"
    }

    // MARK: Dates

    private static let txnInFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy HH:mm:ss"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()
    private static let txnTimeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()
    private static let isoFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()

    static func time(_ createdAt: String?) -> String {
        guard let createdAt else { return "" }
        if let d = txnInFmt.date(from: createdAt) { return txnTimeFmt.string(from: d) }
        return createdAt
    }

    /// The plain `yyyy-MM-dd` the Limes `expiryDate` field takes — nothing to localise.
    static func isoDate(_ date: Date) -> String { isoFmt.string(from: date) }

    static func date(fromIso value: String) -> Date? { isoFmt.date(from: value) }

    // MARK: Status

    /// Transaction status pill label + colours, mirroring the Android `styleStatus`.
    static func statusStyle(_ status: String?) -> (label: String, fg: UIColor, bg: UIColor) {
        let s = (status ?? "").lowercased()
        if s.contains("fail") || s.contains("error") || s.contains("declin") {
            return ("Failed", AppColors.danger, AppColors.dangerBg)
        }
        if s.contains("success") || s.contains("complete") || s.contains("paid") {
            return ("Success", AppColors.success, AppColors.successBg)
        }
        let raw = status ?? ""
        let label = raw.isEmpty ? "Pending" : raw.prefix(1).uppercased() + raw.dropFirst()
        return (label, AppColors.purplePrimary, AppColors.purpleLight)
    }

    /// Limes account/SIM status: ACT is live, anything else is pending or suspended.
    static func limesStatusStyle(_ status: String?) -> (label: String, fg: UIColor, bg: UIColor) {
        let s = (status ?? "").trimmingCharacters(in: .whitespaces)
        let active = s.caseInsensitiveCompare("ACT") == .orderedSame
            || s.caseInsensitiveCompare("ACTIVE") == .orderedSame
        return (s.isEmpty ? "—" : s.uppercased(),
                active ? AppColors.success : AppColors.warning,
                active ? AppColors.successBg : AppColors.warningBg)
    }

    // MARK: Icons

    /// Category id/name → an SF Symbol, mirroring the Android `VasIcons`.
    static func categoryIcon(id: String?, name: String?) -> String {
        let key = ((id ?? "") + " " + (name ?? "")).lowercased()
        if key.contains("whatsapp") || key.contains("sms") || key.contains("message") { return "message.fill" }
        if key.contains("data") || key.contains("fwa") || key.contains("wifi") { return "wifi" }
        if key.contains("voice") || key.contains("airtime") || key.contains("call") { return "phone.fill" }
        if key.contains("service") || key.contains("fee") || key.contains("wallet") { return "creditcard.fill" }
        let bundleKeys = ["combo", "bundle", "subscription", "package", "gsm", "flte",
                          "supplementary", "choose", "recharge", "convert", "day", "week"]
        if bundleKeys.contains(where: { key.contains($0) }) { return "square.grid.2x2.fill" }
        return "antenna.radiowaves.left.and.right"
    }
}
