import UIKit

/// Label factories mirroring TextAppearance.AnokiX.* in text_styles.xml.
extension UILabel {

    static func make(_ text: String? = nil,
                     font: UIFont,
                     color: UIColor,
                     align: NSTextAlignment = .natural,
                     lines: Int = 0) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = font
        l.textColor = color
        l.textAlignment = align
        l.numberOfLines = lines
        return l
    }

    static func display(_ text: String? = nil) -> UILabel {
        make(text, font: AppFonts.bold(AppMetrics.textDisplay), color: AppColors.purplePrimary)
    }
    static func headline(_ text: String? = nil) -> UILabel {
        make(text, font: AppFonts.bold(AppMetrics.textHeadline), color: AppColors.textPrimary)
    }
    static func title(_ text: String? = nil) -> UILabel {
        make(text, font: AppFonts.bold(AppMetrics.textTitle), color: AppColors.textPrimary)
    }
    static func body(_ text: String? = nil) -> UILabel {
        make(text, font: AppFonts.regular(AppMetrics.textBody), color: AppColors.textPrimary)
    }
    static func bodySecondary(_ text: String? = nil) -> UILabel {
        make(text, font: AppFonts.regular(AppMetrics.textBodySM), color: AppColors.textSecondary)
    }
    static func caption(_ text: String? = nil) -> UILabel {
        make(text, font: AppFonts.regular(AppMetrics.textCaption), color: AppColors.textSecondary)
    }
    static func label(_ text: String? = nil) -> UILabel {
        make(text, font: AppFonts.light(AppMetrics.textLabel), color: AppColors.textTertiary)
    }
}
