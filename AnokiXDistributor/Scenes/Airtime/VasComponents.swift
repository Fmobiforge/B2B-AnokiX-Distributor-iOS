import UIKit

/// What a section view needs from the screen around it: somewhere to present pickers and
/// alerts, and a way to tell the other tabs that their data just went stale.
protocol VasSectionHost: AnyObject {
    func vasPresent(_ viewController: UIViewController)
    /// The "Something went wrong" dialog — Limes' replies are long and worth reading in full.
    func vasShowError(_ message: String)
    func vasShowAlert(title: String, message: String)
    /// Re-reads the VAS history + KPI figures after any sale or provisioning.
    func vasRefreshTransactions()
    /// A new customer was onboarded, so the Customers tab must not show a stale list.
    func vasCustomerOnboarded()
}

/// Base for the six Airtime & VAS sections: a vertical stack the subclass fills with cards,
/// plus the form widgets they all share.
class VasSectionView: UIView {

    weak var host: VasSectionHost?
    let stack = UIStackView.vertical(spacing: 12, alignment: .fill)

    init() {
        super.init(frame: .zero)
        stack.forAutoLayout()
        addSubview(stack)
        stack.pinEdges(to: self)
        build()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Subclass hook — called once from `init`.
    func build() {}

    /// Subclass hook — called each time the tab becomes visible; load lazily from here.
    func onShown() {}

    // MARK: Cards

    /// White card with a bold title, optional body copy, and a stack to fill.
    func makeCard(title: String?, body: String? = nil) -> (card: UIView, content: UIStackView) {
        let view = StyleKit.cardView()
        let content = UIStackView.vertical(spacing: 10, alignment: .fill)
        content.forAutoLayout()
        view.addSubview(content)
        content.pinEdges(to: view, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        if let title {
            content.addArrangedSubview(UILabel.make(title, font: AppFonts.bold(16), color: AppColors.textPrimary, lines: 0))
        }
        if let body {
            content.addArrangedSubview(UILabel.make(body, font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 0))
        }
        return (view, content)
    }

    // MARK: Form widgets

    /// Label above a bordered text field — the iOS twin of StoreFieldLabel + StoreFieldInput.
    func labeledField(_ title: String, _ field: UITextField, placeholder: String? = nil,
                      keyboard: UIKeyboardType = .default) -> UIStackView {
        StyleKit.styleInput(field)
        field.placeholder = placeholder
        field.keyboardType = keyboard
        field.autocorrectionType = .no
        let s = UIStackView.vertical(spacing: 6, alignment: .fill)
        s.addArrangedSubview(UILabel.make(title, font: AppFonts.semibold(13), color: AppColors.textPrimary))
        s.addArrangedSubview(field)
        return s
    }

    /// Label above a tap-to-select dropdown. The caller keeps the API code by index; the
    /// button always shows the label at that index.
    func labeledDropdown(_ title: String, button: UIButton, options: [String],
                         selected: Int = 0, onPick: @escaping (Int) -> Void) -> UIStackView {
        styleDropdown(button)
        setDropdownTitle(button, options.indices.contains(selected) ? options[selected] : "Select…",
                         chosen: options.indices.contains(selected))
        button.addAction(UIAction { [weak self] _ in
            self?.presentOptions(title, options: options) { index in
                self?.setDropdownTitle(button, options[index], chosen: true)
                onPick(index)
            }
        }, for: .touchUpInside)

        let s = UIStackView.vertical(spacing: 6, alignment: .fill)
        s.addArrangedSubview(UILabel.make(title, font: AppFonts.semibold(13), color: AppColors.textPrimary))
        s.addArrangedSubview(button)
        return s
    }

    func styleDropdown(_ button: UIButton) {
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        config.background.backgroundColor = AppColors.surface
        config.background.cornerRadius = AppMetrics.radiusMD
        config.background.strokeColor = AppColors.border
        config.background.strokeWidth = 1
        config.image = UIImage(systemName: "chevron.down")
        config.imagePlacement = .trailing
        config.imagePadding = 8
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        button.configuration = config
        button.contentHorizontalAlignment = .leading
        button.tintColor = AppColors.textSecondary
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
    }

    /// Writes the selected label into a dropdown, switching it from hint grey to body colour.
    func setDropdownTitle(_ button: UIButton, _ title: String, chosen: Bool) {
        var config = button.configuration
        config?.attributedTitle = AttributedString(title, attributes: AttributeContainer([
            .font: AppFonts.regular(13),
            .foregroundColor: chosen ? AppColors.textPrimary : AppColors.textSecondary
        ]))
        button.configuration = config
    }

    func presentOptions(_ title: String, options: [String], onPick: @escaping (Int) -> Void) {
        guard let host else { return }
        let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for (i, option) in options.enumerated() {
            sheet.addAction(UIAlertAction(title: option, style: .default) { _ in onPick(i) })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = self
            pop.sourceRect = CGRect(x: bounds.midX, y: bounds.midY, width: 0, height: 0)
        }
        host.vasPresent(sheet)
    }

    // MARK: Small pieces

    func primaryButton(_ title: String, color: UIColor = AppColors.purplePrimary,
                       action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        StyleKit.stylePrimaryButton(button)
        button.configuration?.baseBackgroundColor = color
        button.setTitle(title, for: .normal)
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    func outlinedButton(_ title: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = AppColors.textPrimary
        config.background.strokeColor = AppColors.border
        config.background.strokeWidth = 1
        config.background.cornerRadius = AppMetrics.radiusMD
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var out = $0; out.font = AppFonts.bold(14); return out
        }
        button.configuration = config
        button.setTitle(title, for: .normal)
        button.heightAnchor.constraint(equalToConstant: 46).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    /// Pale blue explainer block ("How this page works" / "When do I need this?").
    static func infoBanner(_ text: NSAttributedString) -> UIView {
        let box = UIView()
        box.backgroundColor = UIColor(hex: 0xF0F7FF)
        box.layer.cornerRadius = AppMetrics.radiusMD
        box.layer.borderWidth = 1
        box.layer.borderColor = UIColor(hex: 0xCFE3FA).cgColor

        let label = UILabel()
        label.attributedText = text
        label.numberOfLines = 0
        label.forAutoLayout()
        box.addSubview(label)
        label.pinEdges(to: box, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        return box
    }

    func hairline() -> UIView {
        let line = UIView()
        line.backgroundColor = AppColors.border
        line.constrainHeight(1)
        return line
    }

    func padded(_ view: UIView, insets: UIEdgeInsets) -> UIView {
        let wrap = UIView()
        view.forAutoLayout()
        wrap.addSubview(view)
        view.pinEdges(to: wrap, insets: insets)
        return wrap
    }

    func centeredMessage(_ text: String) -> UIView {
        let label = UILabel.make(text, font: AppFonts.regular(13), color: AppColors.textSecondary,
                                 align: .center, lines: 0)
        return padded(label, insets: UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 0))
    }

    func loadingIndicator() -> UIView {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = AppColors.purplePrimary
        spinner.startAnimating()
        spinner.forAutoLayout()
        let wrap = UIView()
        wrap.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: wrap.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 18),
            spinner.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -18)
        ])
        return wrap
    }

    /// A left label / right value row, the shape used across the order + bundle summaries.
    func summaryRow(_ left: UILabel, _ right: UILabel) -> UIStackView {
        left.setContentHuggingPriority(.defaultLow, for: .horizontal)
        right.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.addArrangedSubview(left)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(right)
        return row
    }

    func statusPill(_ style: (label: String, fg: UIColor, bg: UIColor)) -> PaddingLabel {
        let pill = StyleKit.badgeLabel()
        pill.text = style.label
        pill.textColor = style.fg
        pill.backgroundColor = style.bg
        pill.font = AppFonts.semibold(AppMetrics.textLabel)
        return pill
    }

    func text(_ field: UITextField) -> String {
        (field.text ?? "").trimmingCharacters(in: .whitespaces)
    }
}

/// Pick-only date field: a wheel `UIDatePicker` as the input view with a Clear/Done toolbar,
/// the same pattern the product promotion dates use. Reports the plain `yyyy-MM-dd` the Limes
/// `expiryDate` takes, and refuses past dates — a bundle that expired yesterday cannot be
/// provisioned.
final class VasDateField: UITextField, UITextFieldDelegate {

    /// Fires with the picked date (or "" when cleared).
    var onPick: ((String) -> Void)?

    private let picker = UIDatePicker()

    init(placeholder: String) {
        super.init(frame: .zero)
        StyleKit.styleInput(self)
        self.placeholder = placeholder

        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        inputView = picker
        tintColor = .clear          // pick-only — hide the text caret
        delegate = self

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.setItems([
            UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearDate)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(commitDate))
        ], animated: false)
        inputAccessoryView = toolbar

        let glyph = UIImageView(image: UIImage(systemName: "calendar"))
        glyph.tintColor = AppColors.textSecondary
        glyph.contentMode = .center
        glyph.frame = CGRect(x: 0, y: 0, width: 30, height: 20)
        rightView = glyph
        rightViewMode = .always
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func commitDate() {
        let value = VasFormat.isoDate(picker.date)
        text = value
        onPick?(value)
        resignFirstResponder()
    }

    @objc private func clearDate() {
        text = ""
        onPick?("")
        resignFirstResponder()
    }

    /// Sync the wheel to whatever is already in the field. The floor is set here rather than
    /// in `init` so a session left open overnight still refuses yesterday.
    func textFieldDidBeginEditing(_ textField: UITextField) {
        picker.minimumDate = Date()
        if let value = text, let date = VasFormat.date(fromIso: value) {
            picker.date = date
        }
    }

    /// Pick-only: the keyboard is replaced by the wheel, so typing and paste are refused.
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool { false }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool { false }
}

/// A tappable card container — UIControl so the whole card fires one action; content stacks
/// set `isUserInteractionEnabled = false` so hit-testing resolves to the control.
final class VasTapCard: UIControl {
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handleTap() { onTap?() }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }
}

extension NSAttributedString {
    /// Renders the small subset of markup the VAS explainer copy uses (`<b>…</b>`) so the
    /// step names stand out exactly as they do on the web portal.
    static func vasExplainer(_ html: String, size: CGFloat = 12) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let regular: [NSAttributedString.Key: Any] = [
            .font: AppFonts.regular(size), .foregroundColor: AppColors.textPrimary]
        let bold: [NSAttributedString.Key: Any] = [
            .font: AppFonts.bold(size), .foregroundColor: AppColors.textPrimary]

        var rest = html[...]
        while let open = rest.range(of: "<b>") {
            out.append(NSAttributedString(string: String(rest[rest.startIndex..<open.lowerBound]), attributes: regular))
            let after = rest[open.upperBound...]
            guard let close = after.range(of: "</b>") else {
                out.append(NSAttributedString(string: String(after), attributes: bold))
                return out
            }
            out.append(NSAttributedString(string: String(after[after.startIndex..<close.lowerBound]), attributes: bold))
            rest = after[close.upperBound...]
        }
        out.append(NSAttributedString(string: String(rest), attributes: regular))

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        out.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: out.length))
        return out
    }
}
