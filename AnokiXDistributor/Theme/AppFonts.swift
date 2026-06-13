import UIKit

/// The Android app renders everything in the Inter typeface via the Roboto* custom views
/// (RobotoTextView = regular, RobotoBoldTextView = bold, RobotoLightTextView = light).
///
/// To match exactly, drop `Inter-Regular/Medium/SemiBold/Light.ttf` into Resources/Fonts,
/// add them to `UIAppFonts` in Info.plist, and flip `useInter` to true. Until then we fall
/// back to the system font at the equivalent weight, which is visually very close.
enum AppFonts {

    private static let useInter = false

    static func regular(_ size: CGFloat) -> UIFont { font(size, weight: .regular, name: "Inter-Regular") }
    static func medium(_ size: CGFloat) -> UIFont  { font(size, weight: .medium,  name: "Inter-Medium") }
    static func semibold(_ size: CGFloat) -> UIFont { font(size, weight: .semibold, name: "Inter-SemiBold") }
    static func bold(_ size: CGFloat) -> UIFont    { font(size, weight: .bold,    name: "Inter-SemiBold") }
    static func light(_ size: CGFloat) -> UIFont   { font(size, weight: .light,   name: "Inter-Light") }

    private static func font(_ size: CGFloat, weight: UIFont.Weight, name: String) -> UIFont {
        if useInter, let f = UIFont(name: name, size: size) { return f }
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
}
