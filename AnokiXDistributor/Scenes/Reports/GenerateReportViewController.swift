import UIKit

/// "Generate a report" (New-Design/Report/3.Generate-Report.png, 4.Generate-Report-Options.png).
///
/// A bottom sheet rather than a centre dialog: the three fields are all pickers, and a
/// sheet keeps them within thumb reach. Category narrows the Report list — the API's
/// `report_key` is all the generate call needs, so Category is an optional filter rather
/// than a required step and defaults to "All Categories".
///
/// "Generate again" on a report card opens the same sheet with that report's category,
/// report and original period already selected, so the user only confirms.
final class GenerateReportViewController: UIViewController {

    /// Called after a successful generate, with the server's confirmation message.
    var onGenerated: ((String) -> Void)?

    /// Category options from the requirements — the web dropdown, in its own order.
    private static let categories = ["Sales", "Traders", "Inventory", "Deliveries", "Finance", "Products"]

    private let data: ReportsData
    private var category = ""
    private var selected: ReportsData.Available?
    private var periodStart: Date
    private var periodEnd: Date

    private let categoryField = FieldRow(placeholder: S.allCategories, icon: "chevron.down")
    private let reportField = FieldRow(placeholder: S.chooseAReport, icon: "chevron.down")
    private let aboutLabel = UILabel.make(font: AppFonts.regular(11),
                                          color: AppColors.textSecondary, lines: 0)
    private let periodField = FieldRow(placeholder: "", icon: "calendar")
    private let submitButton = UIButton(type: .system)

    init(data: ReportsData, repeating: ReportsData.Report?) {
        self.data = data

        // Default to the last 30 days, matching the range the web dialog opens with.
        let today = Calendar.current.startOfDay(for: Date())
        periodEnd = today
        periodStart = Calendar.current.date(byAdding: .day, value: -30, to: today) ?? today

        super.init(nibName: nil, bundle: nil)

        // Seed from the report being regenerated, so the sheet opens ready to confirm.
        if let report = repeating {
            selected = data.findAvailable(name: report.name, category: report.category)
            category = selected?.category ?? ""
            if let from = Self.parseApiDate(report.periodFrom),
               let to = Self.parseApiDate(report.periodTo) {
                periodStart = from
                periodEnd = to
            }
        }

        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.surface

        let title = UILabel.make(S.generateReportTitle, font: AppFonts.bold(AppMetrics.textHeadline),
                                 color: AppColors.textPrimary)
        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark"), for: .normal)
        close.tintColor = AppColors.textSecondary
        close.constrainSize(32)
        close.setContentHuggingPriority(.required, for: .horizontal)
        close.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)

        let titleRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        titleRow.addArrangedSubview(title)
        titleRow.addArrangedSubview(UIView())
        titleRow.addArrangedSubview(close)

        let help = PaddingLabel(insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        help.text = S.generateReportHelp
        help.font = AppFonts.regular(AppMetrics.textCaption)
        help.textColor = AppColors.textSecondary
        help.numberOfLines = 0
        help.backgroundColor = AppColors.surfaceVariant
        help.layer.cornerRadius = AppMetrics.radiusMD
        help.layer.masksToBounds = true

        categoryField.onTap = { [weak self] in self?.pickCategory() }
        reportField.onTap = { [weak self] in self?.pickReport() }
        periodField.onTap = { [weak self] in self?.pickPeriod() }

        let cancel = UIButton(type: .system)
        StyleKit.styleOutlinedButton(cancel)
        cancel.setTitle(S.cancel, for: .normal)
        cancel.constrainHeight(46)
        cancel.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)

        StyleKit.stylePrimaryButton(submitButton)
        submitButton.setTitle(S.generate, for: .normal)
        submitButton.constrainHeight(46)
        submitButton.addAction(UIAction { [weak self] _ in self?.submit() }, for: .touchUpInside)

        let buttons = UIStackView.horizontal(spacing: 12, alignment: .fill)
        buttons.distribution = .fillEqually
        buttons.addArrangedSubview(cancel)
        buttons.addArrangedSubview(submitButton)

        let periodGroup = fieldGroup(S.periodLabel, periodField)
        let stack = UIStackView.vertical(spacing: 14, alignment: .fill)
        stack.addArrangedSubview(titleRow)
        stack.addArrangedSubview(help)
        stack.addArrangedSubview(fieldGroup(S.reportCategoryLabel, categoryField))
        stack.addArrangedSubview(fieldGroup(S.reportLabel, reportField, extra: aboutLabel))
        stack.addArrangedSubview(periodGroup)
        stack.addArrangedSubview(buttons)
        stack.setCustomSpacing(20, after: periodGroup)
        stack.forAutoLayout()

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.forAutoLayout()
        scroll.addSubview(stack)
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20)
        ])

        render()
    }

    private func fieldGroup(_ title: String, _ field: UIView, extra: UIView? = nil) -> UIView {
        let label = UILabel.make(title, font: AppFonts.bold(AppMetrics.textCaption),
                                 color: AppColors.textPrimary)
        let group = UIStackView.vertical(spacing: 6, alignment: .fill)
        group.addArrangedSubview(label)
        group.addArrangedSubview(field)
        if let extra = extra { group.addArrangedSubview(extra) }
        return group
    }

    // MARK: Rendering

    private func render() {
        categoryField.setValue(category.isEmpty ? nil : Self.capitalised(category))
        reportField.setValue(selected?.name)

        let about = (selected?.about ?? "").trimmingCharacters(in: .whitespaces)
        aboutLabel.text = about
        aboutLabel.isHidden = about.isEmpty

        periodField.setValue(FilterUiHelper.formatDateRange(start: periodStart, end: periodEnd))
    }

    // MARK: Pickers

    private func pickCategory() {
        let options = [S.allCategories] + Self.categories
        presentPicker(options: options, title: S.reportCategoryLabel, anchor: categoryField) { [weak self] value in
            guard let self = self else { return }
            self.category = (value == S.allCategories) ? "" : value
            // A report from another category would contradict the new filter.
            if let current = self.selected, !self.matches(current) {
                self.selected = nil
            }
            self.render()
        }
    }

    private func pickReport() {
        let options = (data.available ?? []).filter { matches($0) }
        guard !options.isEmpty else {
            presentAlert(S.errNoReportsInCategory)
            return
        }
        presentPicker(options: options.map { $0.name ?? "" }, title: S.reportLabel,
                anchor: reportField) { [weak self] value in
            guard let self = self else { return }
            self.selected = options.first { $0.name == value }
            self.render()
        }
    }

    private func pickPeriod() {
        let picker = DateRangeSheetViewController(start: periodStart, end: periodEnd)
        picker.onPick = { [weak self] start, end in
            self?.periodStart = start
            self?.periodEnd = end
            self?.render()
        }
        present(picker, animated: true)
    }

    private func presentPicker(options: [String], title: String, anchor: UIView,
                         onPick: @escaping (String) -> Void) {
        let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for option in options {
            sheet.addAction(UIAlertAction(title: option, style: .default) { _ in onPick(option) })
        }
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        sheet.popoverPresentationController?.sourceView = anchor   // iPad anchor
        sheet.popoverPresentationController?.sourceRect = anchor.bounds
        present(sheet, animated: true)
    }

    private func matches(_ option: ReportsData.Available) -> Bool {
        guard !category.isEmpty else { return true }
        return option.category?.trimmingCharacters(in: .whitespaces)
            .caseInsensitiveCompare(category) == .orderedSame
    }

    // MARK: Submit

    private func submit() {
        guard let key = selected?.key, !key.isEmpty else {
            presentAlert(S.errChooseReport)
            return
        }
        submitButton.isEnabled = false
        submitButton.setTitle(S.generatingReport, for: .normal)

        ApiClient.shared.generateReport(reportKey: key,
                                        from: Self.formatApiDate(periodStart),
                                        to: Self.formatApiDate(periodEnd)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                self.dismiss(animated: true) { self.onGenerated?(message) }
            case .failure(let error):
                self.submitButton.isEnabled = true
                self.submitButton.setTitle(S.generate, for: .normal)
                self.presentAlert(error.message)
            }
        }
    }

    private func presentAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.ok, style: .default))
        present(alert, animated: true)
    }

    // MARK: Dates

    /// The API takes and returns plain calendar dates.
    private static func apiFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func formatApiDate(_ date: Date) -> String {
        apiFormatter().string(from: date)
    }

    private static func parseApiDate(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        return apiFormatter().date(from: raw)
    }

    /// The API sends categories lower-cased; the picker shows them capitalised.
    private static func capitalised(_ value: String) -> String {
        guard let first = value.first else { return "" }
        return String(first).uppercased() + value.dropFirst()
    }
}

// MARK: - Tappable value field

/// A read-only field that opens a picker — the sheet's Category / Report / Period rows.
private final class FieldRow: UIControl {

    var onTap: (() -> Void)?

    private let valueLabel = UILabel()
    private let placeholder: String

    init(placeholder: String, icon: String) {
        self.placeholder = placeholder
        super.init(frame: .zero)
        backgroundColor = AppColors.surfaceVariant
        layer.cornerRadius = AppMetrics.radiusMD
        layer.borderWidth = 1
        layer.borderColor = AppColors.border.cgColor

        valueLabel.font = AppFonts.regular(14)
        valueLabel.textColor = AppColors.textSecondary
        valueLabel.text = placeholder
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.forAutoLayout()

        let glyph = UIImageView(image: UIImage(systemName: icon))
        glyph.tintColor = AppColors.textSecondary
        glyph.contentMode = .scaleAspectFit
        glyph.forAutoLayout()

        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.isUserInteractionEnabled = false
        row.addArrangedSubview(valueLabel)
        row.addArrangedSubview(glyph)
        row.forAutoLayout()
        addSubview(row)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 46),
            glyph.widthAnchor.constraint(equalToConstant: 16),
            glyph.heightAnchor.constraint(equalToConstant: 16),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// A nil or empty value falls back to the placeholder, in the muted colour.
    func setValue(_ value: String?) {
        let text = (value ?? "").trimmingCharacters(in: .whitespaces)
        valueLabel.text = text.isEmpty ? placeholder : text
        valueLabel.textColor = text.isEmpty ? AppColors.textSecondary : AppColors.textPrimary
    }
}

// MARK: - Date range sheet

/// Two date wheels for the report period. UIKit has no range picker, so the sheet shows a
/// "from" and a "to" wheel and keeps them ordered — picking a start after the end pushes
/// the end along rather than letting an impossible range be submitted.
private final class DateRangeSheetViewController: UIViewController {

    var onPick: ((Date, Date) -> Void)?

    private let fromPicker = UIDatePicker()
    private let toPicker = UIDatePicker()

    init(start: Date, end: Date) {
        super.init(nibName: nil, bundle: nil)
        fromPicker.date = start
        toPicker.date = end
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.surface

        for picker in [fromPicker, toPicker] {
            picker.datePickerMode = .date
            picker.preferredDatePickerStyle = .compact
            // A report can only cover data that already exists.
            picker.maximumDate = Date()
        }
        fromPicker.addTarget(self, action: #selector(fromChanged), for: .valueChanged)

        let apply = UIButton(type: .system)
        StyleKit.stylePrimaryButton(apply)
        apply.setTitle(S.apply, for: .normal)
        apply.constrainHeight(46)
        apply.addAction(UIAction { [weak self] _ in self?.confirm() }, for: .touchUpInside)

        let stack = UIStackView.vertical(spacing: 16, alignment: .fill)
        stack.addArrangedSubview(UILabel.make(S.periodLabel, font: AppFonts.bold(16),
                                              color: AppColors.textPrimary, align: .center))
        stack.addArrangedSubview(row(S.periodFrom, fromPicker))
        stack.addArrangedSubview(row(S.periodTo, toPicker))
        stack.addArrangedSubview(apply)
        stack.forAutoLayout()
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func row(_ title: String, _ picker: UIDatePicker) -> UIView {
        let label = UILabel.make(title, font: AppFonts.regular(14), color: AppColors.textSecondary)
        picker.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.addArrangedSubview(label)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(picker)
        return row
    }

    /// Keep the range ordered: a start past the end drags the end with it.
    @objc private func fromChanged() {
        if fromPicker.date > toPicker.date {
            toPicker.date = fromPicker.date
        }
        toPicker.minimumDate = fromPicker.date
    }

    private func confirm() {
        let start = fromPicker.date
        let end = max(toPicker.date, start)
        dismiss(animated: true) { [weak self] in self?.onPick?(start, end) }
    }
}
