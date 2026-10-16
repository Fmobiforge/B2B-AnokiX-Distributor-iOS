import UIKit

/// The Android app and the web portal render everything in the Inter typeface
/// (RobotoTextView = regular, RobotoBoldTextView = bold, RobotoLightTextView = light).
///
/// `Inter-Regular/Medium/SemiBold/Light.ttf` ship in Resources/Fonts and are registered via
/// `UIAppFonts` in Info.plist. If a face fails to load we fall back to the system font at the
/// equivalent weight.
enum AppFonts {

    private static let useInter = true

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
