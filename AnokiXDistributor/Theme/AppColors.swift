import UIKit

/// Direct port of res/values/colors.xml. Single source of truth for the palette.
/// Mirrors the web portal (distributor.anokix.com). The `purple*` names are historical:
/// they now hold the portal's brand blue. Violet survives only as a gradient accent.
enum AppColors {

    static let purplePrimary      = UIColor(hex: 0x0D47A1)
    static let purpleDark         = UIColor(hex: 0x0D3A7A)
    static let topTitle           = UIColor(hex: 0x1A237E)
    static let purpleLight        = UIColor(hex: 0xE7EDF6)
    static let purpleTextLight     = UIColor(hex: 0xB9CBE8)
    static let background          = UIColor(hex: 0xF5F7FA)
    static let surface             = UIColor(hex: 0xFFFFFF)
    static let surfaceVariant      = UIColor(hex: 0xFAFBFC)
    static let surfaceElevated     = UIColor(hex: 0xFFFFFF)
    static let textPrimary         = UIColor(hex: 0x1A237E)
    static let textSecondary       = UIColor(hex: 0x5C6B7A)
    static let textTertiary        = UIColor(hex: 0x8A96A3)
    static let border              = UIColor(hex: 0xDCE1E8)
    static let borderLight         = UIColor(hex: 0xE8ECF1)
    static let divider             = UIColor(hex: 0xE8ECF1)
    static let success             = UIColor(hex: 0x2E7D32)
    static let successBg           = UIColor(hex: 0xE8F5E9)
    static let warning             = UIColor(hex: 0xE65100)
    static let warningBg           = UIColor(hex: 0xFFF3E0)
    static let danger              = UIColor(hex: 0xC62828)
    static let dangerBg            = UIColor(hex: 0xFDECEC)
    static let info                = UIColor(hex: 0x1565C0)
    static let infoBg              = UIColor(hex: 0xE3F2FD)
    static let accent              = UIColor(hex: 0xFF6F00)
    static let accentBg            = UIColor(hex: 0xFFF0E0)
    static let loginBg             = UIColor(hex: 0x000920)
    static let drawerBg            = UIColor(hex: 0x000920)
    static let drawerItemSelected  = UIColor(hex: 0x6366F1)
    static let drawerText          = UIColor(hex: 0xFFFFFF)
    static let drawerTextMuted     = UIColor(white: 1, alpha: 0.65)
    static let drawerBadgeBg       = UIColor(hex: 0x6366F1, alpha: 0.22)
    static let drawerBadgeBorder   = UIColor(hex: 0x8B5CF6, alpha: 0.35)
    static let drawerBadgeText     = UIColor(hex: 0xC4B5FD)
    static let drawerDivider       = UIColor(hex: 0x1B2440)
    static let statLowStock        = UIColor(hex: 0xE65100)
    static let statOutOfStock      = UIColor(hex: 0xC62828)
    static let statExpiring        = UIColor(hex: 0xF57F17)

    // Gradients: nav active item / avatars, and the auth-screen call to action.
    static let gradientStart       = UIColor(hex: 0x6366F1)
    static let gradientEnd         = UIColor(hex: 0x8B5CF6)
    static let authGradientStart   = UIColor(hex: 0x1E9DE6)
    static let authGradientCenter  = UIColor(hex: 0x4F8FF7)
    static let authGradientEnd     = UIColor(hex: 0x8B5CF6)
    static let authLink            = UIColor(hex: 0x43AEE1)

    // Chart series (portal: revenue violet, orders blue).
    static let chartViolet         = UIColor(hex: 0x8B5CF6)
    static let chartBlue           = UIColor(hex: 0x1565C0)

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
