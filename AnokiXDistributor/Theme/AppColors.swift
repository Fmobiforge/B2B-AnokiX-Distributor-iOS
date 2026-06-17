import UIKit

/// Direct port of res/values/colors.xml. Single source of truth for the palette.
enum AppColors {

    static let purplePrimary      = UIColor(hex: 0x7C3AED)
    static let purpleDark         = UIColor(hex: 0x5B21B6)
    static let topTitle           = UIColor(hex: 0x1A237E)
    static let purpleLight        = UIColor(hex: 0xEDE9FE)
    static let purpleTextLight     = UIColor(hex: 0xC4B5FD)
    static let background          = UIColor(hex: 0xF1F5F9)
    static let surface             = UIColor(hex: 0xFFFFFF)
    static let surfaceVariant      = UIColor(hex: 0xF8FAFC)
    static let surfaceElevated     = UIColor(hex: 0xFFFFFF)
    static let textPrimary         = UIColor(hex: 0x0F172A)
    static let textSecondary       = UIColor(hex: 0x64748B)
    static let textTertiary        = UIColor(hex: 0x94A3B8)
    static let border              = UIColor(hex: 0xE2E8F0)
    static let borderLight         = UIColor(hex: 0xF1F5F9)
    static let divider             = UIColor(hex: 0xE2E8F0)
    static let success             = UIColor(hex: 0x16A34A)
    static let successBg           = UIColor(hex: 0xDCFCE7)
    static let warning             = UIColor(hex: 0xEA580C)
    static let warningBg           = UIColor(hex: 0xFFEDD5)
    static let danger              = UIColor(hex: 0xDC2626)
    static let dangerBg            = UIColor(hex: 0xFEE2E2)
    static let info                = UIColor(hex: 0x2563EB)
    static let infoBg              = UIColor(hex: 0xDBEAFE)
    static let loginBg             = UIColor(hex: 0x000920)
    static let drawerBg            = UIColor(hex: 0x000920)
    static let drawerItemSelected  = UIColor(hex: 0x7B61FF)
    static let drawerText          = UIColor(hex: 0xFFFFFF)
    static let drawerTextMuted     = UIColor(hex: 0xB4C3D8)
    static let drawerBadgeBg       = UIColor(hex: 0x2E1065)
    static let drawerBadgeText     = UIColor(hex: 0xC4B5FD)
    static let statLowStock        = UIColor(hex: 0xEA580C)
    static let statOutOfStock      = UIColor(hex: 0xDC2626)
    static let statExpiring        = UIColor(hex: 0xD97706)

    /// Resolves a server-provided hex string (e.g. dashboard category colors) with a fallback.
    static func fromHex(_ string: String?, fallback: UIColor = AppColors.purplePrimary) -> UIColor {
        guard var hex = string?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty else {
            return fallback
        }
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard let value = UInt32(hex, radix: 16) else { return fallback }
        if hex.count <= 6 { return UIColor(hex: Int(value)) }
        // 8-digit AARRGGBB / RRGGBBAA fallback -> ignore alpha, use RGB
        return UIColor(hex: Int(value & 0xFFFFFF))
    }
}

extension UIColor {
    /// 0xRRGGBB integer initializer.
    convenience init(hex: Int, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}
