import UIKit

/// Small stacked form used by the three stock actions (adjust / transfer / receive).
/// Presented as a sheet so it reads like the web dialogs but stays thumb-friendly.
final class StockFormViewController: UIViewController {

    var onSubmit: (() -> Void)?

    private let titleText: String
    private let helpText: String?
    private let submitTitle: String

    private let fieldStack = UIStackView.vertical(spacing: 10, alignment: .fill)
    private let errorLabel = UILabel.make(font: AppFonts.regular(AppMetrics.textCaption),
                                          color: AppColors.danger, lines: 0)
    private let submitButton = UIButton(type: .system)

    init(title: String, help: String?, submitTitle: String) {
        self.titleText = title
        self.helpText = help
        self.submitTitle = submitTitle
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.surface
        title = titleText
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                           target: self, action: #selector(cancel))

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.keyboardDismissMode = .onDrag
        scroll.forAutoLayout()
        view.addSubview(scroll)

        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.forAutoLayout()
        scroll.addSubview(stack)

        if let help = helpText {
            stack.addArrangedSubview(UILabel.make(help, font: AppFonts.regular(AppMetrics.textCaption),
                                                  color: AppColors.textSecondary, lines: 0))
        }
        stack.addArrangedSubview(fieldStack)

        // The action bar is docked to the bottom rather than sitting at the end of the
        // scroll content: a longer form (Add staff runs to six fields) pushes the button
        // past the medium detent, and an action you have to go looking for reads as missing.
        // The error sits with it so a rejected submit is visible from wherever you tapped.
        errorLabel.isHidden = true

        submitButton.setTitle(submitTitle, for: .normal)
        StyleKit.stylePrimaryButton(submitButton)
        submitButton.constrainHeight(48)
        submitButton.addTarget(self, action: #selector(submit), for: .touchUpInside)

        let actionBar = UIView()
        actionBar.backgroundColor = AppColors.surface
        actionBar.forAutoLayout()
        view.addSubview(actionBar)

        let topLine = ListScreenLayout.hairline()
        topLine.forAutoLayout()
        actionBar.addSubview(topLine)

        let barContent = UIStackView.vertical(spacing: 10, alignment: .fill)
        barContent.forAutoLayout()
        barContent.addArrangedSubview(errorLabel)
        barContent.addArrangedSubview(submitButton)
        actionBar.addSubview(barContent)

        // Sit above the home indicator normally, and ride up with the keyboard when one
        // opens — the safe-area constraint yields to the required keyboard one.
        let restingBottom = actionBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        restingBottom.priority = .defaultHigh

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: actionBar.topAnchor),

            actionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            actionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            actionBar.bottomAnchor.constraint(lessThanOrEqualTo: view.keyboardLayoutGuide.topAnchor),
            restingBottom,

            topLine.topAnchor.constraint(equalTo: actionBar.topAnchor),
            topLine.leadingAnchor.constraint(equalTo: actionBar.leadingAnchor),
            topLine.trailingAnchor.constraint(equalTo: actionBar.trailingAnchor),

            barContent.topAnchor.constraint(equalTo: actionBar.topAnchor, constant: 12),
            barContent.leadingAnchor.constraint(equalTo: actionBar.leadingAnchor, constant: 16),
            barContent.trailingAnchor.constraint(equalTo: actionBar.trailingAnchor, constant: -16),
            barContent.bottomAnchor.constraint(equalTo: actionBar.bottomAnchor, constant: -12),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    /// Wraps the form in a navigation controller and presents it as a medium sheet.
    func wrappedInNavigation() -> UIViewController {
        let nav = UINavigationController(rootViewController: self)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        return nav
    }

    // MARK: Field builders

    @discardableResult
    func addTextField(placeholder: String, keyboard: UIKeyboardType = .default,
                      text: String? = nil) -> UITextField {
        let field = UITextField()
        StyleKit.styleInput(field)
        field.placeholder = placeholder
        field.keyboardType = keyboard
        field.text = text
        fieldStack.addArrangedSubview(field)
        return field
    }

    /// Password field with the eye button that flips between dots and plain text.
    @discardableResult
    func addSecureField(placeholder: String) -> UITextField {
        let field = addTextField(placeholder: placeholder)
        field.isSecureTextEntry = true
        field.autocapitalizationType = .none
        field.autocorrectionType = .no

        let toggle = UIButton(type: .system)
        toggle.setImage(UIImage(systemName: "eye"), for: .normal)
        toggle.tintColor = AppColors.textSecondary
        toggle.frame = CGRect(x: 0, y: 0, width: 38, height: 38)
        toggle.addAction(UIAction { [weak field] _ in
            guard let field = field else { return }
            field.isSecureTextEntry.toggle()
            toggle.setImage(UIImage(systemName: field.isSecureTextEntry ? "eye" : "eye.slash"),
                            for: .normal)
        }, for: .touchUpInside)
        field.rightView = toggle
        field.rightViewMode = .always
        return field
    }

    /// Caption under the previous field (e.g. "They sign in with this.").
    func addCaption(_ text: String) {
        let label = UILabel.make(text, font: AppFonts.regular(AppMetrics.textMicro),
                                 color: AppColors.textSecondary, lines: 0)
        fieldStack.addArrangedSubview(label)
        if fieldStack.arrangedSubviews.count >= 2 {
            fieldStack.setCustomSpacing(4, after: fieldStack.arrangedSubviews[fieldStack.arrangedSubviews.count - 2])
        }
    }

    @discardableResult
    func addPicker(title: String, options: [String], selectedIndex: Int?) -> StockFormPicker {
        let picker = StockFormPicker(title: title, options: options, selectedIndex: selectedIndex)
        picker.presenter = self
        fieldStack.addArrangedSubview(picker)
        return picker
    }

    @discardableResult
    func addDatePicker(title: String) -> StockFormDateField {
        let field = StockFormDateField(title: title)
        field.presenter = self
        fieldStack.addArrangedSubview(field)
        return field
    }

    @discardableResult
    func addHint() -> UILabel {
        let hint = UILabel.make(font: AppFonts.regular(AppMetrics.textMicro),
                                color: AppColors.textSecondary, lines: 0)
        fieldStack.addArrangedSubview(hint)
        return hint
    }

    // MARK: State

    func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = message.isEmpty
    }

    func setSubmitting(_ submitting: Bool) {
        submitButton.isEnabled = !submitting
        if submitting { showError("") }
    }

    @objc private func cancel() { dismiss(animated: true) }
    @objc private func submit() { onSubmit?() }
}

/// Tap-to-choose row backed by an action sheet — the iOS twin of ProductDropdown.
final class StockFormPicker: UIControl {

    weak var presenter: UIViewController?
    var onChange: ((Int) -> Void)?
    private(set) var selectedIndex: Int?

    private let titleText: String
    private let options: [String]
    private let label = UILabel()

    init(title: String, options: [String], selectedIndex: Int?) {
        self.titleText = title
        self.options = options
        self.selectedIndex = selectedIndex
        super.init(frame: .zero)

        backgroundColor = AppColors.surface
        layer.cornerRadius = AppMetrics.radiusMD
        layer.borderWidth = 1
        layer.borderColor = AppColors.border.cgColor

        label.font = AppFonts.regular(AppMetrics.textBody)
        label.lineBreakMode = .byTruncatingTail
        label.forAutoLayout()

        let chevron = UIImageView(image: UIImage(systemName: "chevron.down"))
        chevron.tintColor = AppColors.textSecondary
        chevron.contentMode = .scaleAspectFit
        chevron.forAutoLayout()

        addSubviews(label, chevron)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 48),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 14),
            chevron.heightAnchor.constraint(equalToConstant: 14)
        ])

        addTarget(self, action: #selector(pick), for: .touchUpInside)
        renderTitle()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func renderTitle() {
        if let index = selectedIndex, options.indices.contains(index) {
            label.text = options[index]
            label.textColor = AppColors.textPrimary
        } else {
            label.text = titleText
            label.textColor = AppColors.textSecondary
        }
    }

    @objc private func pick() {
        guard let presenter = presenter, !options.isEmpty else { return }
        let sheet = UIAlertController(title: titleText, message: nil, preferredStyle: .actionSheet)
        for (index, option) in options.enumerated() {
            sheet.addAction(UIAlertAction(title: option, style: .default) { [weak self] _ in
                self?.selectedIndex = index
                self?.renderTitle()
                self?.onChange?(index)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = self
        sheet.popoverPresentationController?.sourceRect = bounds
        presenter.present(sheet, animated: true)
    }
}

/// Optional date row (expiry) that yields an API-shaped yyyy-MM-dd string.
final class StockFormDateField: UIControl {

    weak var presenter: UIViewController?
    /// Empty until the user picks a date.
    private(set) var apiDate = ""

    private let titleText: String
    private let label = UILabel()
    private static let apiFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(title: String) {
        self.titleText = title
        super.init(frame: .zero)

        backgroundColor = AppColors.surface
        layer.cornerRadius = AppMetrics.radiusMD
        layer.borderWidth = 1
        layer.borderColor = AppColors.border.cgColor

        label.text = title
        label.font = AppFonts.regular(AppMetrics.textBody)
        label.textColor = AppColors.textSecondary
        label.forAutoLayout()

        let icon = UIImageView(image: UIImage(systemName: "calendar"))
        icon.tintColor = AppColors.textSecondary
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()

        addSubviews(label, icon)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 48),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            icon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16)
        ])

        addTarget(self, action: #selector(pick), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func pick() {
        guard let presenter = presenter else { return }
        let host = DatePickerSheetViewController(title: titleText)
        host.onPick = { [weak self] date in
            guard let self = self else { return }
            if let date = date {
                self.apiDate = Self.apiFormatter.string(from: date)
                self.label.text = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
                self.label.textColor = AppColors.textPrimary
            } else {
                self.apiDate = ""
                self.label.text = self.titleText
                self.label.textColor = AppColors.textSecondary
            }
        }
        presenter.present(host.wrappedInSheet(), animated: true)
    }
}

/// Wheel date picker in a small sheet — `onPick(nil)` clears the value.
final class DatePickerSheetViewController: UIViewController {

    var onPick: ((Date?) -> Void)?

    private let titleText: String
    private let picker = UIDatePicker()

    init(title: String) {
        self.titleText = title
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.surface
        title = titleText
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Clear", style: .plain,
                                                           target: self, action: #selector(clear))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                            target: self, action: #selector(done))

        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.forAutoLayout()
        view.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            picker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12)
        ])
    }

    func wrappedInSheet() -> UIViewController {
        let nav = UINavigationController(rootViewController: self)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        return nav
    }

    // The callback is captured directly so it still fires if this sheet is released
    // while dismissing.
    @objc private func done() {
        let date = picker.date
        let callback = onPick
        dismiss(animated: true) { callback?(date) }
    }

    @objc private func clear() {
        let callback = onPick
        dismiss(animated: true) { callback?(nil) }
    }
}
