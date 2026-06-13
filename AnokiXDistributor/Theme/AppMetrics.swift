import UIKit

/// Port of res/values/dimens.xml. iOS points map 1:1 to Android dp.
enum AppMetrics {

    // Spacing scale (4pt base)
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 20
    static let spacing2XL: CGFloat = 24

    // Screen padding
    static let screenPaddingHorizontal: CGFloat = 16
    static let screenPaddingVertical: CGFloat = 16

    // Corner radii
    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 10
    static let radiusLG: CGFloat = 12
    static let radiusXL: CGFloat = 16

    // Component sizes
    static let searchBarHeight: CGFloat = 40
    static let filterButtonSize: CGFloat = 40
    static let filterPillHeight: CGFloat = 34
    static let headerIconSize: CGFloat = 36
    static let listItemPadding: CGFloat = 12
    static let cardMarginBottom: CGFloat = 8

    // Typography sizes
    static let textDisplay: CGFloat = 18
    static let textHeadline: CGFloat = 16
    static let textTitle: CGFloat = 14
    static let textBody: CGFloat = 13
    static let textBodySM: CGFloat = 12
    static let textCaption: CGFloat = 11
    static let textLabel: CGFloat = 10
    static let textMicro: CGFloat = 9
    static let textStatValue: CGFloat = 17
    static let textKpiValue: CGFloat = 20
    static let bottomNavTextSize: CGFloat = 10

    // Drawer
    static let drawerWidth: CGFloat = 280
    static let drawerItemHeight: CGFloat = 44
    static let drawerIconSize: CGFloat = 22
}
