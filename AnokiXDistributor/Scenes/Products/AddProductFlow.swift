import UIKit
import SwiftyJSON

/// Shared pieces of the Add Product flow — the portal's /products/create page: method chooser,
/// barcode lookup and the Hirt & Carter library. The portal draws these pages in violet rather
/// than the brand blue, so they carry their own palette.
///
/// Every screen of the flow receives `onSaved`; once a product is saved the flow calls it and
/// returns to the screen that opened the chooser (`finish(from:)`).
enum AddProductFlow {

    enum Palette {
        static let violet = UIColor(hex: 0x7C3AED)
        static let violetDark = UIColor(hex: 0x6D28D9)
        static let violetBorder = UIColor(hex: 0xC4B5FD)
        static let violetTint = UIColor(hex: 0xEFE7FD)     // #7C3AED at 12% over white
        static let violetWash = UIColor(hex: 0xF7F3FE)     // #7C3AED at 6% over white
        static let slate = UIColor(hex: 0x64748B)
        static let slateBg = UIColor(hex: 0xF1F5F9)
        static let slateBorder = UIColor(hex: 0xE2E8F0)
        static let muted = UIColor(hex: 0x94A3B8)
        static let placeholder = UIColor(hex: 0xCBD5E1)
        static let page = UIColor(hex: 0xF8FAFC)
        static let green = UIColor(hex: 0x15803D)
        static let greenIcon = UIColor(hex: 0x22C55E)
        static let greenBg = UIColor(hex: 0xF0FDF4)
        static let greenBorder = UIColor(hex: 0xBBF7D0)
        static let red = UIColor(hex: 0xDC2626)
        static let redIcon = UIColor(hex: 0xEF4444)
        static let redBg = UIColor(hex: 0xFEF2F2)
        static let redBorder = UIColor(hex: 0xFECACA)
        static let invalid = UIColor(hex: 0xF87171)
        static let tagPurple = UIColor(hex: 0x531DAB)
        static let tagPurpleBg = UIColor(hex: 0xF9F0FF)
        static let tagPurpleBorder = UIColor(hex: 0xD3ADF7)
        static let infoBg = UIColor(hex: 0xE6F4FF)
        static let infoBorder = UIColor(hex: 0x91CAFF)
        static let infoIcon = UIColor(hex: 0x1677FF)
    }

    // MARK: Values

    /// Digits only, capped at `max` characters — the portal's barcode sanitiser.
    static func digits(_ value: String?, max: Int = 14) -> String {
        String((value ?? "").filter { $0.isASCII && $0.isNumber }.prefix(max))
    }

    /// A GTIN / EAN / UPC: 8 to 14 digits.
    static func isBarcode(_ value: String?) -> Bool {
        let v = (value ?? "").trimmingCharacters(in: .whitespaces)
        return (8...14).contains(v.count) && v.allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// 2617 → "2,617".
    static func count(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }

    /// First non-blank string (or number) among `keys` of a raw record.
    static func str(_ json: JSON, _ keys: String...) -> String? {
        for key in keys {
            let v = json[key]
            let s: String?
            switch v.type {
            case .string: s = v.string
            case .number: s = v.numberValue.stringValue
            default: s = nil
            }
            if let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { return s }
        }
        return nil
    }

    /// Relative upload paths ("uploads/…") are served from the API host.
    static func absoluteURL(_ value: String?) -> URL? {
        guard let v = value?.trimmingCharacters(in: .whitespaces), !v.isEmpty else { return nil }
        if v.hasPrefix("http://") || v.hasPrefix("https://") { return URL(string: v) }
        return URL(string: ApiClient.baseURL + (v.hasPrefix("/") ? String(v.dropFirst()) : v))
    }

    // MARK: Navigation

    /// After a product is saved: back to the screen that opened the Add Product chooser.
    static func finish(from vc: UIViewController) {
        guard let nav = vc.navigationController else { return }
        if let i = nav.viewControllers.firstIndex(where: { $0 is AddProductOptionsViewController }), i > 0 {
            nav.popToViewController(nav.viewControllers[i - 1], animated: true)
        } else {
            nav.popToRootViewController(animated: true)
        }
    }

    /// Cancel on a lookup result: back to the barcode field, emptied (as on the portal).
    static func backToEmptyBarcode(from vc: UIViewController) {
        guard let nav = vc.navigationController else { return }
        if let barcode = nav.viewControllers.last(where: { $0 is BarcodeVerifyViewController })
            as? BarcodeVerifyViewController {
            barcode.clearBarcode()
            nav.popToViewController(barcode, animated: true)
        } else {
            nav.popViewController(animated: true)
        }
    }

    // MARK: Building blocks

    /// Violet primary action (Continue / Verify / Use this product).
    static func primaryButton(_ title: String, height: CGFloat = 46) -> UIButton {
        let b = UIButton(type: .system)
        var c = UIButton.Configuration.filled()
        c.title = title
        c.baseBackgroundColor = Palette.violet
        c.baseForegroundColor = .white
        c.cornerStyle = .fixed
        c.background.cornerRadius = 10
        c.imagePadding = 8
        c.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
        c.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.semibold(15); return out
        }
        b.configuration = c
        b.constrainHeight(height)
        return b
    }

    /// Neutral secondary action (Cancel / Not this product).
    static func secondaryButton(_ title: String, height: CGFloat = 46) -> UIButton {
        let b = UIButton(type: .system)
        var c = UIButton.Configuration.plain()
        c.title = title
        c.baseForegroundColor = AppColors.textPrimary
        c.background.backgroundColor = AppColors.surface
        c.background.strokeColor = AppColors.border
        c.background.strokeWidth = 1
        c.background.cornerRadius = 10
        c.cornerStyle = .fixed
        c.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        c.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.semibold(15); return out
        }
        c.titleAlignment = .center
        b.configuration = c
        b.titleLabel?.numberOfLines = 2
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: height).isActive = true
        return b
    }

    /// Spinner inside the button while a request runs; taps are ignored meanwhile.
    static func setBusy(_ button: UIButton, _ busy: Bool) {
        button.configuration?.showsActivityIndicator = busy
        button.isUserInteractionEnabled = !busy
    }

    /// Rounded white panel with a coloured 1pt border; clips banners to its corners.
    static func panel(border: UIColor) -> UIView {
        let v = UIView()
        v.backgroundColor = AppColors.surface
        v.layer.cornerRadius = 16
        v.layer.borderWidth = 1
        v.layer.borderColor = border.cgColor
        v.clipsToBounds = true
        return v
    }

    /// Full-width centred banner row: icon + bold text.
    static func banner(_ text: String, symbol: String, textColor: UIColor, iconColor: UIColor,
                       background: UIColor, fontSize: CGFloat = 15) -> UIView {
        let bar = UIView()
        bar.backgroundColor = background
        let icon = UIImageView(image: UIImage(systemName: symbol,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: fontSize + 2, weight: .semibold)))
        icon.tintColor = iconColor
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let label = UILabel.make(text, font: AppFonts.bold(fontSize), color: textColor, align: .center, lines: 0)
        let row = UIStackView.horizontal(spacing: 10, alignment: .center)
        row.addArrangedSubview(icon)
        row.addArrangedSubview(label)
        row.forAutoLayout()
        bar.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: bar.topAnchor, constant: 16),
            row.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -16),
            row.centerXAnchor.constraint(equalTo: bar.centerXAnchor),
            row.leadingAnchor.constraint(greaterThanOrEqualTo: bar.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(lessThanOrEqualTo: bar.trailingAnchor, constant: -20)
        ])
        return bar
    }

    static func line(_ color: UIColor = AppColors.border) -> UIView {
        let v = UIView()
        v.backgroundColor = color
        v.constrainHeight(1)
        return v
    }

    /// Vertical scroll + content stack filling `container`; the stack follows the keyboard.
    static func scrollStack(in container: UIView, keyboardGuide: UIKeyboardLayoutGuide? = nil,
                            insets: UIEdgeInsets = UIEdgeInsets(top: 20, left: 16, bottom: 32, right: 16),
                            spacing: CGFloat = 0) -> UIStackView {
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.keyboardDismissMode = .interactive
        scroll.forAutoLayout()
        container.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: container.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: keyboardGuide?.topAnchor ?? container.bottomAnchor)
        ])
        let stack = UIStackView.vertical(spacing: spacing, alignment: .fill)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = insets
        stack.forAutoLayout()
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor)
        ])
        return stack
    }

    /// Bordered single-line input (bg_login_input look).
    static func input(_ placeholder: String? = nil, keyboard: UIKeyboardType = .default) -> UITextField {
        let f = UITextField()
        StyleKit.styleInput(f)
        f.placeholder = placeholder
        f.keyboardType = keyboard
        return f
    }

    static func fieldLabel(_ text: String) -> UILabel {
        UILabel.make(text, font: AppFonts.semibold(13), color: AppColors.textPrimary, lines: 0)
    }

    /// Label above a control.
    static func field(_ label: String, _ control: UIView) -> UIStackView {
        let s = UIStackView.vertical(spacing: 6, alignment: .fill)
        s.addArrangedSubview(fieldLabel(label))
        s.addArrangedSubview(control)
        return s
    }
}

// MARK: - Scan or Enter Barcode

/// "Scan or Enter Barcode" — the portal's barcode verification step.
///
/// A valid 8–14 digit barcode is checked in the distributor's own catalogue first
/// (get-by-barcode → `ProductFoundViewController`), then in the Hirt & Carter catalogue
/// (external-lookup → `HcProductViewController`, or `BarcodeNotFoundViewController`).
/// A barcode scanner that types into the field (keyboard wedge) works like typing.
final class BarcodeVerifyViewController: BaseSecondaryViewController, UITextFieldDelegate {

    override var screenTitle: String { "Add New Product" }

    var onSaved: (() -> Void)?
    var initialBarcode: String?

    private let barcodeField = UITextField()
    private let shell = UIView()
    private let validIcon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
    private var verifyButton: UIButton!
    private var busy = false

    override func setupContent(in container: UIView) {
        let stack = AddProductFlow.scrollStack(in: container, keyboardGuide: view.keyboardLayoutGuide)

        let card = UIView()
        StyleKit.styleCard(card, radius: 16)
        let inner = UIStackView.vertical(spacing: 0, alignment: .fill)
        inner.isLayoutMarginsRelativeArrangement = true
        inner.layoutMargins = UIEdgeInsets(top: 24, left: 20, bottom: 20, right: 20)
        inner.forAutoLayout()
        card.addSubview(inner)
        inner.pinEdges(to: card)

        let title = UILabel.make("Scan or Enter Barcode", font: AppFonts.bold(22), color: AppColors.textPrimary, lines: 0)
        let subtitle = UILabel.make("Scan the product barcode or enter it manually to verify if it exists in our product library.",
                                    font: AppFonts.regular(14), color: AppColors.textSecondary, lines: 0)
        inner.addArrangedSubview(title)
        inner.setCustomSpacing(8, after: title)
        inner.addArrangedSubview(subtitle)
        inner.setCustomSpacing(24, after: subtitle)
        inner.addArrangedSubview(buildField())
        inner.setCustomSpacing(18, after: inner.arrangedSubviews.last!)

        verifyButton = AddProductFlow.primaryButton("Verify Product", height: 48)
        verifyButton.configuration?.background.cornerRadius = 12
        verifyButton.addTarget(self, action: #selector(verify), for: .touchUpInside)
        inner.addArrangedSubview(verifyButton)
        inner.setCustomSpacing(22, after: verifyButton)
        inner.addArrangedSubview(buildHowItWorks())
        stack.addArrangedSubview(card)

        let cancel = AddProductFlow.secondaryButton("Cancel", height: 42)
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        let cancelRow = UIStackView.horizontal(spacing: 0, alignment: .center)
        cancelRow.addArrangedSubview(UIView())
        cancelRow.addArrangedSubview(cancel)
        cancelRow.addArrangedSubview(UIView())
        cancelRow.arrangedSubviews.first!.widthAnchor
            .constraint(equalTo: cancelRow.arrangedSubviews.last!.widthAnchor).isActive = true
        cancel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        stack.setCustomSpacing(20, after: card)
        stack.addArrangedSubview(cancelRow)

        barcodeField.text = AddProductFlow.digits(initialBarcode)
        renderValidity()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if (barcodeField.text ?? "").isEmpty { barcodeField.becomeFirstResponder() }
    }

    /// Outlined field with the label sitting on its top border, as on the portal.
    private func buildField() -> UIView {
        let wrap = UIView()
        shell.backgroundColor = AppColors.surface
        shell.layer.cornerRadius = 12
        shell.layer.borderWidth = 2
        shell.forAutoLayout()
        wrap.addSubview(shell)

        let icon = UIImageView(image: UIImage(systemName: "barcode"))
        icon.tintColor = AddProductFlow.Palette.muted
        icon.contentMode = .scaleAspectFit
        icon.constrainSize(22)

        barcodeField.font = AppFonts.semibold(18)
        barcodeField.textColor = AppColors.textPrimary
        barcodeField.keyboardType = .numberPad
        barcodeField.autocorrectionType = .no
        barcodeField.attributedPlaceholder = NSAttributedString(string: "6001234567890", attributes: [
            .foregroundColor: AddProductFlow.Palette.placeholder, .font: AppFonts.medium(18)])
        barcodeField.delegate = self
        barcodeField.addTarget(self, action: #selector(barcodeChanged), for: .editingChanged)
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                         UIBarButtonItem(title: "Verify", style: .done, target: self, action: #selector(verify))]
        barcodeField.inputAccessoryView = toolbar

        validIcon.tintColor = AddProductFlow.Palette.greenIcon
        validIcon.contentMode = .scaleAspectFit
        validIcon.constrainSize(22)
        validIcon.isHidden = true

        let row = UIStackView.horizontal(spacing: 10, alignment: .center)
        row.addArrangedSubview(icon)
        row.addArrangedSubview(barcodeField)
        row.addArrangedSubview(validIcon)
        row.forAutoLayout()
        shell.addSubview(row)

        let label = PaddingLabel(insets: UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 6))
        label.text = "Barcode"
        label.font = AppFonts.semibold(12)
        label.textColor = AddProductFlow.Palette.violet
        label.backgroundColor = AppColors.surface
        label.forAutoLayout()
        wrap.addSubview(label)

        NSLayoutConstraint.activate([
            shell.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 9),
            shell.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            shell.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
            shell.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
            shell.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            row.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -14),
            row.topAnchor.constraint(equalTo: shell.topAnchor, constant: 4),
            row.bottomAnchor.constraint(equalTo: shell.bottomAnchor, constant: -4),
            barcodeField.heightAnchor.constraint(equalToConstant: 48),
            label.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 14),
            label.centerYAnchor.constraint(equalTo: shell.topAnchor)
        ])
        return wrap
    }

    /// Three steps stacked vertically on phones, joined by down arrows.
    private func buildHowItWorks() -> UIView {
        let box = UIView()
        box.backgroundColor = AddProductFlow.Palette.page
        box.layer.cornerRadius = 12
        box.layer.borderWidth = 1
        box.layer.borderColor = AddProductFlow.Palette.slateBorder.cgColor
        let stack = UIStackView.vertical(spacing: 8, alignment: .fill)
        stack.forAutoLayout()
        box.addSubview(stack)
        stack.pinEdges(to: box, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))

        let steps: [(String, String)] = [
            ("magnifyingglass", "We will check our Master Product Library"),
            ("plus.circle", "If found, you can add it to your catalogue"),
            ("doc.badge.plus", "If not found, you can create a new product")
        ]
        for (i, step) in steps.enumerated() {
            let tile = UIView()
            tile.backgroundColor = AppColors.surface
            tile.layer.cornerRadius = 12
            tile.layer.borderWidth = 1
            tile.layer.borderColor = AddProductFlow.Palette.slateBorder.cgColor
            tile.constrainSize(44)
            let icon = UIImageView(image: UIImage(systemName: step.0))
            icon.tintColor = AddProductFlow.Palette.slate
            icon.contentMode = .scaleAspectFit
            icon.forAutoLayout()
            tile.addSubview(icon)
            NSLayoutConstraint.activate([
                icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 20),
                icon.heightAnchor.constraint(equalToConstant: 20)
            ])
            let text = UILabel.make(step.1, font: AppFonts.medium(12), color: AppColors.textSecondary, lines: 0)
            let row = UIStackView.horizontal(spacing: 10, alignment: .center)
            row.addArrangedSubview(tile)
            row.addArrangedSubview(text)
            stack.addArrangedSubview(row)
            if i < steps.count - 1 {
                let arrow = UIImageView(image: UIImage(systemName: "arrow.down",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
                arrow.tintColor = AddProductFlow.Palette.placeholder
                arrow.contentMode = .center
                stack.addArrangedSubview(arrow)
            }
        }
        return box
    }

    // MARK: Field state

    @objc private func barcodeChanged() {
        let clean = AddProductFlow.digits(barcodeField.text)
        if clean != barcodeField.text { barcodeField.text = clean }
        renderValidity()
    }

    func textFieldDidBeginEditing(_ textField: UITextField) { renderValidity() }
    func textFieldDidEndEditing(_ textField: UITextField) { renderValidity() }

    func clearBarcode() {
        barcodeField.text = ""
        renderValidity()
    }

    /// Violet while empty, green with a tick when valid, red otherwise.
    private func renderValidity() {
        let value = barcodeField.text ?? ""
        let valid = AddProductFlow.isBarcode(value)
        let color: UIColor
        if value.isEmpty {
            color = barcodeField.isFirstResponder ? AddProductFlow.Palette.violet : AddProductFlow.Palette.violetBorder
        } else {
            color = valid ? AddProductFlow.Palette.greenIcon : AddProductFlow.Palette.invalid
        }
        shell.layer.borderColor = color.cgColor
        validIcon.isHidden = !valid
    }

    // MARK: Lookup

    @objc private func cancelTapped() { navigationController?.popViewController(animated: true) }

    @objc private func verify() {
        guard !busy else { return }
        let barcode = (barcodeField.text ?? "").trimmingCharacters(in: .whitespaces)
        guard AddProductFlow.isBarcode(barcode) else {
            toast("Please enter a valid barcode (8–14 digits).")
            return
        }
        view.endEditing(true)
        setBusy(true)
        ApiClient.shared.getProductByBarcode(barcode) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let product?):
                self.setBusy(false)
                let found = ProductFoundViewController()
                found.product = product
                found.onSaved = self.onSaved
                self.navigationController?.pushViewController(found, animated: true)
            case .success(nil):
                self.lookUpExternally(barcode)
            case .failure(let error):
                self.setBusy(false)
                self.toast(error.message.isEmpty ? "Failed to verify product" : error.message)
            }
        }
    }

    /// Not in the distributor's catalogue — try Hirt & Carter.
    private func lookUpExternally(_ barcode: String) {
        ApiClient.shared.hcLookup(barcode: barcode) { [weak self] result in
            guard let self = self else { return }
            self.setBusy(false)
            switch result {
            case .success(let data):
                if data.found, let product = data.product {
                    let detail = HcProductViewController()
                    detail.product = product
                    detail.source = .barcode(barcode)
                    detail.onSaved = self.onSaved
                    self.navigationController?.pushViewController(detail, animated: true)
                } else {
                    self.openNotFound(barcode, canRequest: data.available)
                }
            case .failure:
                self.toast("Catalogue lookup unavailable — you can still create the product manually")
                self.openNotFound(barcode, canRequest: false)
            }
        }
    }

    private func openNotFound(_ barcode: String, canRequest: Bool) {
        let notFound = BarcodeNotFoundViewController()
        notFound.barcode = barcode
        notFound.canRequest = canRequest
        notFound.onSaved = onSaved
        navigationController?.pushViewController(notFound, animated: true)
    }

    private func setBusy(_ value: Bool) {
        busy = value
        AddProductFlow.setBusy(verifyButton, value)
    }
}

// MARK: - Product found in our library

/// "Product found in our library" — the barcode already belongs to a product in the
/// distributor's catalogue. "Add To Catalogue" continues to `CatalogueSetupViewController`.
final class ProductFoundViewController: BaseSecondaryViewController {

    override var screenTitle: String { "Add New Product" }

    var product = JSON()
    var onSaved: (() -> Void)?

    static func displayName(_ p: JSON) -> String {
        AddProductFlow.str(p, "name", "description", "title") ?? "Product"
    }

    override func setupContent(in container: UIView) {
        let stack = AddProductFlow.scrollStack(in: container)
        let panel = AddProductFlow.panel(border: AddProductFlow.Palette.greenBorder)
        let content = UIStackView.vertical(spacing: 0, alignment: .fill)
        content.forAutoLayout()
        panel.addSubview(content)
        content.pinEdges(to: panel)

        content.addArrangedSubview(AddProductFlow.banner("Product found in our library", symbol: "checkmark.circle.fill",
            textColor: AddProductFlow.Palette.green, iconColor: AddProductFlow.Palette.greenIcon,
            background: AddProductFlow.Palette.greenBg, fontSize: 16))
        content.addArrangedSubview(AddProductFlow.line(UIColor(hex: 0xDCFCE7)))

        let body = UIStackView.vertical(spacing: 0, alignment: .fill)
        body.isLayoutMarginsRelativeArrangement = true
        body.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let imageBox = UIImageView()
        imageBox.contentMode = .scaleAspectFit
        imageBox.backgroundColor = AddProductFlow.Palette.page
        imageBox.layer.cornerRadius = 12
        imageBox.layer.borderWidth = 1
        imageBox.layer.borderColor = AppColors.border.cgColor
        imageBox.clipsToBounds = true
        imageBox.constrainSize(120)
        let imageRow = UIStackView.horizontal(spacing: 0, alignment: .center)
        imageRow.addArrangedSubview(UIView())
        imageRow.addArrangedSubview(imageBox)
        imageRow.addArrangedSubview(UIView())
        imageRow.arrangedSubviews.first!.widthAnchor
            .constraint(equalTo: imageRow.arrangedSubviews.last!.widthAnchor).isActive = true
        body.addArrangedSubview(imageRow)
        if let url = AddProductFlow.absoluteURL(AddProductFlow.str(product, "primary_product_image_url",
                "thumbnail_image", "image_url", "thumbnail", "image", "media")) {
            ImageLoader.load(url) { [weak imageBox] image in imageBox?.image = image }
        }

        let name = UILabel.make(Self.displayName(product), font: AppFonts.bold(22),
                                color: AppColors.textPrimary, align: .center, lines: 0)
        body.setCustomSpacing(16, after: imageRow)
        body.addArrangedSubview(name)
        body.setCustomSpacing(4, after: name)

        let details: [(String, String?)] = [
            ("Barcode", AddProductFlow.str(product, "barcode")),
            ("Brand", Self.brandName(product)),
            ("Category", Self.categoryName(product)),
            ("Supplier", Self.supplierName(product))
        ]
        for (label, value) in details {
            let l = UILabel.make(label, font: AppFonts.semibold(12), color: AppColors.textSecondary)
            let v = UILabel.make((value?.isEmpty ?? true) ? "\u{2013}" : value, font: AppFonts.semibold(14),
                                 color: AppColors.textPrimary, lines: 0)
            let item = UIStackView.vertical(spacing: 2, alignment: .fill)
            item.addArrangedSubview(l)
            item.addArrangedSubview(v)
            body.setCustomSpacing(12, after: body.arrangedSubviews.last!)
            body.addArrangedSubview(item)
        }

        let prompt = UILabel.make("Would you like to add this product to your catalogue?", font: AppFonts.medium(15),
                                  color: AppColors.textPrimary, align: .center, lines: 0)
        body.setCustomSpacing(24, after: body.arrangedSubviews.last!)
        body.addArrangedSubview(prompt)

        let add = AddProductFlow.primaryButton("Add To Catalogue")
        add.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        let cancel = AddProductFlow.secondaryButton("Cancel")
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        body.setCustomSpacing(18, after: prompt)
        body.addArrangedSubview(add)
        body.setCustomSpacing(12, after: add)
        body.addArrangedSubview(cancel)
        content.addArrangedSubview(body)

        content.addArrangedSubview(AddProductFlow.line(UIColor(hex: 0xDCFCE7)))
        content.addArrangedSubview(AddProductFlow.banner("You will be able to set your own price, stock and promotions.",
            symbol: "info.circle.fill", textColor: AddProductFlow.Palette.green,
            iconColor: AddProductFlow.Palette.greenIcon, background: AddProductFlow.Palette.greenBg, fontSize: 14))
        stack.addArrangedSubview(panel)
    }

    /// `Brand` may be an object or a string; the list endpoints add `brand_name`.
    private static func brandName(_ p: JSON) -> String? {
        nameOf(p["Brand"]) ?? nameOf(p["brand"]) ?? AddProductFlow.str(p, "brand_name")
    }

    /// "Parent > Child" when the category comes with its parent, otherwise its title.
    private static func categoryName(_ p: JSON) -> String? {
        let c = p["Category"].exists() ? p["Category"] : p["category"]
        if c.type == .dictionary {
            let parent = nameOf(c["parent"]) ?? nameOf(c["Parent"])
            if let own = nameOf(c) { return parent.map { "\($0) > \(own)" } ?? own }
        } else if let s = nameOf(c) {
            return s
        }
        return AddProductFlow.str(p, "category_title", "category_name")
    }

    private static func supplierName(_ p: JSON) -> String? {
        nameOf(p["Supplier"].exists() ? p["Supplier"] : p["supplier"]) ?? AddProductFlow.str(p, "supplier_name")
    }

    private static func nameOf(_ j: JSON) -> String? {
        switch j.type {
        case .string:
            let s = j.stringValue.trimmingCharacters(in: .whitespaces)
            return s.isEmpty ? nil : s
        case .dictionary:
            return AddProductFlow.str(j, "title", "name")
        default:
            return nil
        }
    }

    @objc private func addTapped() {
        let setup = CatalogueSetupViewController()
        setup.product = product
        setup.onSaved = onSaved
        navigationController?.pushViewController(setup, animated: true)
    }

    @objc private func cancelTapped() { AddProductFlow.backToEmptyBarcode(from: self) }
}

// MARK: - Catalogue setup

/// "Product: …" — price, stock and promotion for a library product being added to the
/// catalogue. Submits through products/create with the record's own fields plus the values
/// entered here — the same payload the portal builds.
final class CatalogueSetupViewController: BaseSecondaryViewController, UITextFieldDelegate {

    override var screenTitle: String { "Add New Product" }

    var product = JSON()
    var onSaved: (() -> Void)?

    /// Record fields the portal forwards to products/create (blank values are left out).
    private static let forwardedFields = [
        "barcode", "sku", "name", "supplier_id", "description", "brand_id", "pack_size_id",
        "unit_id", "parent_category_id", "category_id", "weight", "dim_type", "dim_weight",
        "dim_length", "dim_width", "dim_height", "tiered_price", "shrink_code", "unit_code",
        "units_per_case", "min_order_quantity", "max_order_quantity", "supplier_product_code",
        "tag_list", "cost_price", "hc_gtin", "hc_image"
    ]

    private let sellingPrice = AddProductFlow.input("0.00", keyboard: .decimalPad)
    private let stock = AddProductFlow.input("0", keyboard: .numberPad)
    private let reorder = AddProductFlow.input("0", keyboard: .numberPad)
    private let maxStock = AddProductFlow.input("0", keyboard: .numberPad)
    private let promoPrice = AddProductFlow.input("0.00", keyboard: .decimalPad)
    private let promoStart = AddProductFlow.input("DD/MM/YYYY")
    private let promoEnd = AddProductFlow.input("DD/MM/YYYY")
    private let startPicker = UIDatePicker()
    private let endPicker = UIDatePicker()
    private let availableSwitch = UISwitch()
    private let availableLabel = UILabel()
    private var saveButton: UIButton!
    private var startDate: Date?
    private var endDate: Date?
    private var saving = false

    private let apiFormat: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private let shownFormat: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "dd/MM/yyyy"; return f
    }()

    private var requiredFields: [UITextField] { [sellingPrice, stock, reorder, maxStock, promoPrice] }

    override func setupContent(in container: UIView) {
        let stack = AddProductFlow.scrollStack(in: container, keyboardGuide: view.keyboardLayoutGuide)
        let panel = UIView()
        StyleKit.styleCard(panel, radius: 16)
        let form = UIStackView.vertical(spacing: 14, alignment: .fill)
        form.isLayoutMarginsRelativeArrangement = true
        form.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        form.forAutoLayout()
        panel.addSubview(form)
        form.pinEdges(to: panel)

        form.addArrangedSubview(UILabel.make("Product: \(ProductFoundViewController.displayName(product))",
                                             font: AppFonts.bold(20), color: AppColors.textPrimary, lines: 0))
        reorder.text = "200"
        maxStock.text = "3000"
        form.addArrangedSubview(AddProductFlow.field("Selling Price (R)", sellingPrice))
        form.addArrangedSubview(AddProductFlow.field("Stock Quantity", stock))
        form.addArrangedSubview(AddProductFlow.field("Reorder Level", reorder))
        form.addArrangedSubview(AddProductFlow.field("Maximum Stock Level", maxStock))
        form.addArrangedSubview(AddProductFlow.field("Promotion Price (R) *", promoPrice))
        for field in requiredFields {
            field.addTarget(self, action: #selector(fieldEdited(_:)), for: .editingChanged)
        }

        attachDatePicker(promoStart, picker: startPicker)
        attachDatePicker(promoEnd, picker: endPicker)
        form.addArrangedSubview(AddProductFlow.field("Promotion Start Date", promoStart))
        form.addArrangedSubview(AddProductFlow.field("Promotion End Date", promoEnd))

        availableSwitch.isOn = true
        availableSwitch.onTintColor = AppColors.purplePrimary
        availableSwitch.addTarget(self, action: #selector(renderAvailable), for: .valueChanged)
        availableLabel.font = AppFonts.semibold(13)
        let availRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        availRow.addArrangedSubview(UILabel.make("Available For Ordering", font: AppFonts.semibold(14),
                                                 color: AppColors.textPrimary, lines: 0))
        availRow.addArrangedSubview(UIView())
        availRow.addArrangedSubview(availableSwitch)
        availRow.addArrangedSubview(availableLabel)
        availableLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 26).isActive = true
        form.addArrangedSubview(availRow)
        renderAvailable()

        let cancel = AddProductFlow.secondaryButton("Cancel")
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        saveButton = AddProductFlow.primaryButton("Save Product")
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)
        let actions = UIStackView.horizontal(spacing: 12, alignment: .fill)
        actions.distribution = .fillEqually
        actions.addArrangedSubview(cancel)
        actions.addArrangedSubview(saveButton)
        form.setCustomSpacing(24, after: availRow)
        form.addArrangedSubview(actions)
        stack.addArrangedSubview(panel)
    }

    @objc private func renderAvailable() {
        availableLabel.text = availableSwitch.isOn ? "Yes" : "No"
        availableLabel.textColor = availableSwitch.isOn ? AppColors.success : AppColors.textSecondary
    }

    @objc private func fieldEdited(_ field: UITextField) {
        field.layer.borderColor = AppColors.border.cgColor
    }

    // MARK: Dates

    private func attachDatePicker(_ field: UITextField, picker: UIDatePicker) {
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        field.inputView = picker
        field.tintColor = .clear
        field.delegate = self
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearDate)),
                         UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                         UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(commitDate))]
        field.inputAccessoryView = toolbar
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField === promoStart {
            if let d = startDate { startPicker.date = d }
        } else if textField === promoEnd {
            // The end date cannot fall before the start date.
            endPicker.minimumDate = startDate
            if let d = endDate ?? startDate { endPicker.date = d }
        }
    }

    @objc private func commitDate() {
        if promoStart.isFirstResponder {
            startDate = startPicker.date
            promoStart.text = shownFormat.string(from: startPicker.date)
            if let end = endDate, end < startPicker.date {
                endDate = nil
                promoEnd.text = ""
            }
        } else if promoEnd.isFirstResponder {
            endDate = endPicker.date
            promoEnd.text = shownFormat.string(from: endPicker.date)
        }
        view.endEditing(true)
    }

    @objc private func clearDate() {
        if promoStart.isFirstResponder { startDate = nil; promoStart.text = "" }
        else if promoEnd.isFirstResponder { endDate = nil; promoEnd.text = "" }
        view.endEditing(true)
    }

    // MARK: Save

    /// Every number here is required and must be above zero, as on the portal.
    private func validate() -> Bool {
        let invalid = requiredFields.filter { field in
            let text = (field.text ?? "").trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
            guard let n = Double(text) else { return true }
            return n == 0
        }
        for field in requiredFields {
            field.layer.borderColor = (invalid.contains(field) ? AddProductFlow.Palette.invalid : AppColors.border).cgColor
        }
        if !invalid.isEmpty {
            toast("Please fill all required fields")
            return false
        }
        return true
    }

    @objc private func cancelTapped() { navigationController?.popViewController(animated: true) }

    @objc private func save() {
        view.endEditing(true)
        guard !saving, validate() else { return }

        var form: [String: String] = [:]
        func put(_ key: String, _ value: String?) {
            if let v = value?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty { form[key] = v }
        }
        // The portal sends the record's id along with its fields.
        put("id", AddProductFlow.str(product, "id", "product_id"))
        for key in Self.forwardedFields { put(key, Self.formValue(product[key])) }
        // Aliases the portal's record mapping falls back to.
        if form["name"] == nil { put("name", AddProductFlow.str(product, "description")) }
        if form["sku"] == nil { put("sku", AddProductFlow.str(product, "barcode")) }
        if form["units_per_case"] == nil { put("units_per_case", AddProductFlow.str(product, "case_code")) }
        if form["tag_list"] == nil { put("tag_list", Self.formValue(product["tags"])) }
        put("case_code", AddProductFlow.str(product, "case_code"))

        put("stock", stock.text)
        put("selling_price", sellingPrice.text)
        put("promotion_price", promoPrice.text)
        put("reorder_level", reorder.text)
        put("max_stock_level", maxStock.text)
        put("promotion_start_date", startDate.map { apiFormat.string(from: $0) })
        put("promotion_end_date", endDate.map { apiFormat.string(from: $0) })
        form["available_for_ordering"] = availableSwitch.isOn ? "1" : "0"

        saving = true
        AddProductFlow.setBusy(saveButton, true)
        ApiClient.shared.createProduct(form: form, files: []) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.onSaved?()
                // Confirm here, then return to the list once the banner has been seen.
                self.successBanner("Product has been saved to your catalogue.")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                    guard let self = self else { return }
                    AddProductFlow.finish(from: self)
                }
            case .failure(let error):
                self.saving = false
                AddProductFlow.setBusy(self.saveButton, false)
                self.toast(error.message.isEmpty ? "Failed to save product" : error.message)
            }
        }
    }

    /// A form value the way the portal's FormData sees it: booleans → 1/0, lists comma-joined.
    private static func formValue(_ j: JSON) -> String? {
        switch j.type {
        case .bool: return j.boolValue ? "1" : "0"
        case .number: return j.numberValue.stringValue
        case .string: return j.stringValue
        case .array:
            let parts = j.arrayValue.compactMap { item -> String? in
                switch item.type {
                case .string: return item.stringValue
                case .number: return item.numberValue.stringValue
                case .bool: return item.boolValue ? "1" : "0"
                default: return nil
                }
            }
            return parts.isEmpty ? nil : parts.joined(separator: ",")
        default:
            return nil   // nested objects are not form fields
        }
    }
}

// MARK: - Barcode not found

/// "Barcode not found in Product Library". Offers Create New Product (barcode prefilled) and —
/// when the Hirt & Carter service answered — a request asking Hirt & Carter to add the product.
final class BarcodeNotFoundViewController: BaseSecondaryViewController {

    override var screenTitle: String { "Add New Product" }

    var barcode = ""
    var canRequest = false
    var onSaved: (() -> Void)?

    override func setupContent(in container: UIView) {
        let stack = AddProductFlow.scrollStack(in: container)
        let panel = AddProductFlow.panel(border: AddProductFlow.Palette.redBorder)
        let content = UIStackView.vertical(spacing: 0, alignment: .fill)
        content.forAutoLayout()
        panel.addSubview(content)
        content.pinEdges(to: panel)

        content.addArrangedSubview(AddProductFlow.banner("Barcode not found in Product Library",
            symbol: "exclamationmark.circle.fill", textColor: AddProductFlow.Palette.red,
            iconColor: AddProductFlow.Palette.redIcon, background: AddProductFlow.Palette.redBg))
        content.addArrangedSubview(AddProductFlow.line(AddProductFlow.Palette.redBorder))

        let body = UIStackView.vertical(spacing: 0, alignment: .fill)
        body.isLayoutMarginsRelativeArrangement = true
        body.layoutMargins = UIEdgeInsets(top: 36, left: 24, bottom: 28, right: 24)

        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 46, weight: .regular)))
        icon.tintColor = AddProductFlow.Palette.muted
        icon.contentMode = .center
        icon.constrainHeight(56)
        body.addArrangedSubview(icon)
        body.setCustomSpacing(20, after: icon)

        let title = UILabel.make("We couldn't find this product in our library.", font: AppFonts.bold(20),
                                 color: AppColors.textPrimary, align: .center, lines: 0)
        let subtitle = UILabel.make("Would you like to create a new product?", font: AppFonts.regular(15),
                                    color: AppColors.textSecondary, align: .center, lines: 0)
        body.addArrangedSubview(title)
        body.setCustomSpacing(8, after: title)
        body.addArrangedSubview(subtitle)
        body.setCustomSpacing(28, after: subtitle)

        let create = AddProductFlow.primaryButton("Create New Product")
        create.addTarget(self, action: #selector(createTapped), for: .touchUpInside)
        body.addArrangedSubview(create)
        if canRequest {
            let request = AddProductFlow.secondaryButton("Request product data from Hirt & Carter")
            request.addTarget(self, action: #selector(requestTapped), for: .touchUpInside)
            body.setCustomSpacing(12, after: create)
            body.addArrangedSubview(request)
        }
        let cancel = AddProductFlow.secondaryButton("Cancel")
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        body.setCustomSpacing(12, after: body.arrangedSubviews.last!)
        body.addArrangedSubview(cancel)

        content.addArrangedSubview(body)
        stack.addArrangedSubview(panel)
    }

    @objc private func createTapped() {
        let wizard = CreateProductViewController()
        wizard.prefill = CreateProductViewController.Prefill(barcode: barcode)
        wizard.onSaved = onSaved
        wizard.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(wizard, animated: true)
    }

    @objc private func requestTapped() {
        let form = HcRequestViewController()
        form.gtin = barcode
        let nav = UINavigationController(rootViewController: form)
        nav.modalPresentationStyle = .pageSheet
        nav.sheetPresentationController?.detents = [.large()]
        present(nav, animated: true)
    }

    @objc private func cancelTapped() { AddProductFlow.backToEmptyBarcode(from: self) }
}

// MARK: - Request product data from Hirt & Carter

/// Sheet asking Hirt & Carter to add a product their catalogue lacks
/// (POST products/external-request), with the portal's fields and messages.
final class HcRequestViewController: UIViewController {

    var gtin = ""

    /// Units offered by the portal's request form.
    private let units = ["g", "kg", "ml", "l", "ea", "pack", "case", "m"]

    private let errorBox = PaddingLabel(insets: UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
    private let gtinField = AddProductFlow.input()
    private let brandField = AddProductFlow.input()
    private let nameField = AddProductFlow.input()
    private let sizeField = AddProductFlow.input("500")
    private let unitButton = UIButton(type: .system)
    private let skuField = AddProductFlow.input()
    private let noteView = UITextView()
    private let noteCount = UILabel()
    private var fieldErrors: [UIView: UILabel] = [:]
    private var selectedUnit: String?
    private var sendButton: UIButton!
    private let formStack = UIStackView.vertical(spacing: 14, alignment: .fill)
    private let resultStack = UIStackView.vertical(spacing: 18, alignment: .fill)
    private var sending = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.surface
        title = "Request product data"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self,
                                                           action: #selector(close))

        let stack = AddProductFlow.scrollStack(in: view, keyboardGuide: view.keyboardLayoutGuide,
                                               insets: UIEdgeInsets(top: 16, left: 20, bottom: 32, right: 20))
        stack.addArrangedSubview(UILabel.make("Request product data from Hirt & Carter", font: AppFonts.bold(20),
                                              color: AppColors.textPrimary, lines: 0))
        stack.setCustomSpacing(16, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(formStack)
        stack.addArrangedSubview(resultStack)
        resultStack.isHidden = true

        errorBox.font = AppFonts.regular(13)
        errorBox.textColor = AddProductFlow.Palette.red
        errorBox.backgroundColor = AddProductFlow.Palette.redBg
        errorBox.layer.cornerRadius = 8
        errorBox.layer.borderWidth = 1
        errorBox.layer.borderColor = AddProductFlow.Palette.redBorder.cgColor
        errorBox.layer.masksToBounds = true
        errorBox.numberOfLines = 0
        errorBox.isHidden = true
        formStack.addArrangedSubview(errorBox)

        gtinField.text = gtin
        gtinField.isEnabled = false
        gtinField.textColor = AppColors.textSecondary
        gtinField.backgroundColor = AddProductFlow.Palette.page
        brandField.autocapitalizationType = .words
        nameField.autocapitalizationType = .sentences

        formStack.addArrangedSubview(AddProductFlow.field("GTIN / Barcode", gtinField))
        formStack.addArrangedSubview(fieldWithError("Brand *", brandField))
        formStack.addArrangedSubview(fieldWithError("Product name *", nameField))

        configureUnitButton()
        let sizeRow = UIStackView.horizontal(spacing: 12, alignment: .top)
        sizeRow.distribution = .fillEqually
        sizeRow.addArrangedSubview(fieldWithError("Size *", sizeField))
        sizeRow.addArrangedSubview(fieldWithError("Unit *", unitButton))
        formStack.addArrangedSubview(sizeRow)
        formStack.addArrangedSubview(AddProductFlow.field("SKU (optional)", skuField))

        noteView.font = AppFonts.regular(AppMetrics.textBody)
        noteView.textColor = AppColors.textPrimary
        noteView.layer.cornerRadius = AppMetrics.radiusSM
        noteView.layer.borderWidth = 1
        noteView.layer.borderColor = AppColors.border.cgColor
        noteView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        noteView.constrainHeight(88)
        noteView.delegate = self
        noteCount.font = AppFonts.regular(11)
        noteCount.textColor = AppColors.textTertiary
        noteCount.textAlignment = .right
        noteCount.text = "0 / 500"
        let noteGroup = AddProductFlow.field("Note (optional)", noteView)
        noteGroup.addArrangedSubview(noteCount)
        formStack.addArrangedSubview(noteGroup)

        sendButton = AddProductFlow.primaryButton("Send request")
        sendButton.addTarget(self, action: #selector(send), for: .touchUpInside)
        let cancel = AddProductFlow.secondaryButton("Cancel")
        cancel.addTarget(self, action: #selector(close), for: .touchUpInside)
        formStack.setCustomSpacing(22, after: noteGroup)
        formStack.addArrangedSubview(sendButton)
        formStack.addArrangedSubview(cancel)

        for field in [brandField, nameField, sizeField] {
            field.addTarget(self, action: #selector(fieldEdited(_:)), for: .editingChanged)
        }
    }

    private func configureUnitButton() {
        var c = UIButton.Configuration.bordered()
        c.title = "Select unit"
        c.baseForegroundColor = AppColors.textTertiary
        c.background.backgroundColor = AppColors.surface
        c.background.strokeColor = AppColors.border
        c.background.cornerRadius = AppMetrics.radiusSM
        c.cornerStyle = .fixed
        c.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 30)
        c.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.regular(AppMetrics.textBody); return out
        }
        unitButton.configuration = c
        unitButton.contentHorizontalAlignment = .leading
        unitButton.constrainHeight(48)
        let chevron = UIImageView(image: UIImage(systemName: "chevron.down",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
        chevron.tintColor = AppColors.textSecondary
        chevron.forAutoLayout()
        unitButton.addSubview(chevron)
        NSLayoutConstraint.activate([
            chevron.trailingAnchor.constraint(equalTo: unitButton.trailingAnchor, constant: -12),
            chevron.centerYAnchor.constraint(equalTo: unitButton.centerYAnchor)
        ])
        unitButton.showsMenuAsPrimaryAction = true
        unitButton.menu = UIMenu(children: units.map { unit in
            UIAction(title: unit) { [weak self] _ in self?.pickUnit(unit) }
        })
    }

    private func pickUnit(_ unit: String) {
        selectedUnit = unit
        unitButton.configuration?.title = unit
        unitButton.configuration?.baseForegroundColor = AppColors.textPrimary
        setError(nil, for: unitButton)
    }

    /// Label, control and a hidden red message underneath it.
    private func fieldWithError(_ label: String, _ control: UIView) -> UIStackView {
        let group = AddProductFlow.field(label, control)
        let error = UILabel.make(nil, font: AppFonts.regular(12), color: AddProductFlow.Palette.red, lines: 0)
        error.isHidden = true
        group.addArrangedSubview(error)
        fieldErrors[control] = error
        return group
    }

    private func setError(_ message: String?, for control: UIView) {
        fieldErrors[control]?.text = message
        fieldErrors[control]?.isHidden = message == nil
        let color = message == nil ? AppColors.border : AddProductFlow.Palette.invalid
        if let button = control as? UIButton {
            button.configuration?.background.strokeColor = color
        } else {
            control.layer.borderColor = color.cgColor
        }
    }

    @objc private func fieldEdited(_ field: UITextField) { setError(nil, for: field) }

    private func text(_ f: UITextField) -> String { (f.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }

    @objc private func send() {
        guard !sending else { return }
        view.endEditing(true)
        errorBox.isHidden = true
        var ok = true
        if text(brandField).isEmpty { setError("Brand is required", for: brandField); ok = false }
        if text(nameField).isEmpty { setError("Product name is required", for: nameField); ok = false }
        if text(sizeField).isEmpty { setError("Size is required", for: sizeField); ok = false }
        if selectedUnit == nil { setError("Unit is required", for: unitButton); ok = false }
        guard ok, let unit = selectedUnit else { return }

        var form = ["gtin": gtin.trimmingCharacters(in: .whitespaces),
                    "brand": text(brandField),
                    "product_name": text(nameField),
                    "size": text(sizeField),
                    "uom": unit]
        if !text(skuField).isEmpty { form["sku"] = text(skuField) }
        let note = noteView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty { form["note"] = note }

        sending = true
        AddProductFlow.setBusy(sendButton, true)
        ApiClient.shared.requestHcProduct(form: form) { [weak self] result in
            guard let self = self else { return }
            self.sending = false
            AddProductFlow.setBusy(self.sendButton, false)
            switch result {
            case .success(let data):
                self.showResult(alreadyRequested: Self.isAlreadyRequested(data))
            case .failure(let error):
                self.errorBox.text = error.message.isEmpty
                    ? "Could not send the request. Please try again later." : error.message
                self.errorBox.isHidden = false
            }
        }
    }

    /// The API flags repeats with `already_requested`; like the portal, a request created
    /// more than two minutes ago is also an earlier one being returned.
    private static func isAlreadyRequested(_ data: HcRequestData) -> Bool {
        if data.alreadyRequested { return true }
        guard let created = data.createdAt else { return false }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = f.date(from: created.replacingOccurrences(of: "T", with: " ")) else { return false }
        return Date().timeIntervalSince(date) > 120
    }

    private func showResult(alreadyRequested: Bool) {
        formStack.isHidden = true
        let box = UIView()
        box.backgroundColor = AddProductFlow.Palette.greenBg
        box.layer.cornerRadius = 10
        box.layer.borderWidth = 1
        box.layer.borderColor = AddProductFlow.Palette.greenBorder.cgColor
        let icon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        icon.tintColor = AddProductFlow.Palette.greenIcon
        icon.constrainSize(22)
        let title = UILabel.make(alreadyRequested ? "This product has already been requested" : "Request sent",
                                 font: AppFonts.bold(15), color: AppColors.textPrimary, lines: 0)
        let message = UILabel.make(alreadyRequested
            ? "We are already waiting for the data. Check the status under Data requests on the Products page."
            : "We'll notify you when the data and images are ready.",
            font: AppFonts.regular(13), color: AppColors.textSecondary, lines: 0)
        let texts = UIStackView.vertical(spacing: 4, alignment: .fill)
        texts.addArrangedSubview(title)
        texts.addArrangedSubview(message)
        let row = UIStackView.horizontal(spacing: 10, alignment: .top)
        row.addArrangedSubview(icon)
        row.addArrangedSubview(texts)
        row.forAutoLayout()
        box.addSubview(row)
        row.pinEdges(to: box, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        resultStack.addArrangedSubview(box)

        let closeButton = AddProductFlow.primaryButton("Close")
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        resultStack.addArrangedSubview(closeButton)
        resultStack.isHidden = false
    }

    @objc private func close() { dismiss(animated: true) }
}

extension HcRequestViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let current = textView.text as NSString
        return current.replacingCharacters(in: range, with: text).count <= 500
    }

    func textViewDidChange(_ textView: UITextView) {
        noteCount.text = "\(textView.text.count) / 500"
    }
}
