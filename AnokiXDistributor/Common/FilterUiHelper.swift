import UIKit

/// Port of FilterUiHelper.java — date-range pills and dropdown filters.
enum FilterUiHelper {

    typealias DateRangeHandler = (_ start: Date, _ end: Date, _ formatted: String) -> Void
    typealias OptionHandler = (_ index: Int, _ value: String) -> Void

    /// Matches Android defaultWeekRangeUtc — 4 Jun – 10 Jun 2026.
    static func defaultWeekRange() -> (start: Date, end: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var start = DateComponents()
        start.year = 2026; start.month = 6; start.day = 4
        var end = DateComponents()
        end.year = 2026; end.month = 6; end.day = 10
        return (
            calendar.date(from: start) ?? Date(),
            calendar.date(from: end) ?? Date()
        )
    }

    static func formatDateRange(start: Date, end: Date) -> String {
        let dayMonth = DateFormatter()
        dayMonth.timeZone = TimeZone(identifier: "UTC")
        dayMonth.dateFormat = "d MMM"

        let dayMonthYear = DateFormatter()
        dayMonthYear.timeZone = TimeZone(identifier: "UTC")
        dayMonthYear.dateFormat = "d MMM yyyy"

        let cal = Calendar(identifier: .gregorian)
        let sameYear = cal.component(.year, from: start) == cal.component(.year, from: end)
        if sameYear {
            return "\(dayMonth.string(from: start)) – \(dayMonthYear.string(from: end))"
        }
        return "\(dayMonthYear.string(from: start)) – \(dayMonthYear.string(from: end))"
    }

    static func bindDateRangePicker(on control: UIControl,
                                    label: UILabel,
                                    from viewController: UIViewController,
                                    start: Date,
                                    end: Date,
                                    onSelect: @escaping DateRangeHandler) {
        var rangeStart = start
        var rangeEnd = end
        label.text = formatDateRange(start: start, end: end)

        control.addAction(UIAction { [weak viewController] _ in
            guard let viewController else { return }
            let picker = UIAlertController(title: S.selectDateRange, message: nil, preferredStyle: .actionSheet)
            picker.addAction(UIAlertAction(title: S.thisWeek, style: .default) { _ in
                let range = defaultWeekRange()
                rangeStart = range.start
                rangeEnd = range.end
                let formatted = formatDateRange(start: range.start, end: range.end)
                label.text = formatted
                onSelect(range.start, range.end, formatted)
            })
            picker.addAction(UIAlertAction(title: S.cancel, style: .cancel))
            if let popover = picker.popoverPresentationController {
                popover.sourceView = control
                popover.sourceRect = control.bounds
            }
            viewController.present(picker, animated: true)
        }, for: .touchUpInside)
    }

    static func bindDropdown(on control: UIControl,
                             label: UILabel,
                             options: [String],
                             selectedIndex: Int,
                             title: String?,
                             from viewController: UIViewController,
                             onSelect: @escaping OptionHandler) {
        guard !options.isEmpty else { return }
        let index = max(0, min(selectedIndex, options.count - 1))
        label.text = options[index]

        control.addAction(UIAction { [weak viewController] _ in
            guard let viewController else { return }
            let picker = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
            for (i, option) in options.enumerated() {
                picker.addAction(UIAlertAction(title: option, style: .default) { _ in
                    label.text = option
                    onSelect(i, option)
                })
            }
            picker.addAction(UIAlertAction(title: S.cancel, style: .cancel))
            if let popover = picker.popoverPresentationController {
                popover.sourceView = control
                popover.sourceRect = control.bounds
            }
            viewController.present(picker, animated: true)
        }, for: .touchUpInside)
    }
}
