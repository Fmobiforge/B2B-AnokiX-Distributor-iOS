import UIKit

/// Airtime & VAS › Dynamic services. Builds an exact-value bundle from one or more service
/// lines and provisions it straight onto a number — the path Limes recommends when the fixed
/// catalog cannot express the amount.
///
/// Units follow the Limes API: VOICE is minutes, SMS a message count, GPA_CREDIT Rand, and
/// DATA/WHATSAPP are *bytes*. The operator still types GB (as on the web portal) and the
/// conversion happens here, with the byte figure echoed under the field.
final class AirtimeDynamicServicesView: VasSectionView {

    private static let bytesPerGB: Int64 = 1_073_741_824

    /// The services the Limes dynamic endpoint accepts, with the unit each one is typed in.
    private enum Service: Int, CaseIterable {
        case voice, data, sms, whatsapp, airtime

        var label: String {
            switch self {
            case .voice: return "Voice"
            case .data: return "Data"
            case .sms: return "SMS"
            case .whatsapp: return "WhatsApp"
            case .airtime: return "Airtime credit"
            }
        }
        var code: String {
            switch self {
            case .voice: return "VOICE"
            case .data: return "DATA"
            case .sms: return "SMS"
            case .whatsapp: return "WHATSAPP"
            case .airtime: return "GPA_CREDIT"
            }
        }
        var amountLabel: String {
            switch self {
            case .voice: return "Amount (minutes)"
            case .data, .whatsapp: return "Amount (GB)"
            case .sms: return "Amount (messages)"
            case .airtime: return "Amount (Rand)"
            }
        }
        /// True when the typed amount is GB and must be sent to Limes as bytes.
        var inGigabytes: Bool { self == .data || self == .whatsapp }
        /// True when the unit only makes sense as a whole number (minutes, messages, bytes).
        var wholeUnits: Bool { self != .airtime }
    }

    /// One bundle line: its views plus the state the request is built from.
    private final class Line {
        let container = UIStackView.vertical(spacing: 10, alignment: .fill)
        let serviceButton = UIButton(type: .system)
        let amountLabel = UILabel.make("", font: AppFonts.semibold(13), color: AppColors.textPrimary)
        let amountField = UITextField()
        let bytesNote = UILabel.make("", font: AppFonts.regular(11), color: AppColors.success)
        let expiryField = VasDateField(placeholder: "Select date")
        let priceField = UITextField()
        var removeButton: UIButton!
        var service: Service = .voice
        var expiryDate = ""

        var amount: Double { VasFormat.parse(amountField.text) }
        var price: Double { VasFormat.parse(priceField.text) }
        var bytesValue: Int64 { Int64((amount * Double(AirtimeDynamicServicesView.bytesPerGB)).rounded()) }

        /// The value in the unit Limes expects: bytes for data, a whole count for minutes and
        /// messages, and the exact Rand figure for airtime credit — rounding R10,50 up to R11
        /// there would quietly sell the customer something they did not ask for.
        var apiValue: Any {
            if service.inGigabytes { return bytesValue }
            if !service.wholeUnits && amount != amount.rounded() { return amount }
            return Int64(amount.rounded())
        }

        /// True once this line carries an amount the API would accept.
        var hasAmount: Bool {
            service.inGigabytes ? bytesValue > 0 : amount > 0
        }
    }

    private let msisdnField = UITextField()
    private let linesContainer = UIStackView.vertical(spacing: 12, alignment: .fill)
    private var totalLabel: UILabel!
    private var provisionButton: UIButton!
    private var lines: [Line] = []

    override func build() {
        let (formCard, form) = makeCard(
            title: "Compose a custom bundle",
            body: "Build exact-value bundles and provision them straight onto the number. "
                + "Data is entered in GB and converted to bytes for you.")

        form.addArrangedSubview(labeledField("Phone number (MSISDN)", msisdnField,
                                             placeholder: "082 123 4567", keyboard: .phonePad))
        form.addArrangedSubview(UILabel.make("Bundle lines", font: AppFonts.bold(14), color: AppColors.textPrimary))
        form.addArrangedSubview(linesContainer)

        let add = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.title = "+ Add service"
        config.baseForegroundColor = AppColors.purplePrimary
        config.background.strokeColor = AppColors.border
        config.background.strokeWidth = 1
        config.background.cornerRadius = AppMetrics.radiusMD
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var out = $0; out.font = AppFonts.bold(13); return out
        }
        add.configuration = config
        add.addAction(UIAction { [weak self] _ in self?.addLine() }, for: .touchUpInside)
        let addRow = UIStackView.horizontal(spacing: 0, alignment: .center)
        addRow.addArrangedSubview(add)
        addRow.addArrangedSubview(UIView())
        form.addArrangedSubview(addRow)
        stack.addArrangedSubview(formCard)

        let (totalCard, totalContent) = makeCard(title: nil)
        totalLabel = UILabel.make(VasFormat.money(0), font: AppFonts.bold(20), color: AppColors.purplePrimary)
        totalContent.addArrangedSubview(summaryRow(
            UILabel.make("Bundle total", font: AppFonts.regular(13), color: AppColors.textSecondary),
            totalLabel))
        provisionButton = primaryButton("Provision services", color: AppColors.success) { [weak self] in
            self?.provision()
        }
        totalContent.addArrangedSubview(provisionButton)
        totalContent.addArrangedSubview(UILabel.make(
            "Paid from your anokiX wallet. Change how you pay in Settings → Preferences.",
            font: AppFonts.regular(11), color: AppColors.textTertiary, lines: 0))
        stack.addArrangedSubview(totalCard)

        addLine()
    }

    // MARK: Lines

    private func addLine() {
        let line = Line()
        let box = UIView()
        box.backgroundColor = AppColors.surfaceVariant
        box.layer.cornerRadius = AppMetrics.radiusMD
        box.layer.borderWidth = 1
        box.layer.borderColor = AppColors.border.cgColor

        line.removeButton = UIButton(type: .system)
        line.removeButton.setImage(UIImage(systemName: "trash"), for: .normal)
        line.removeButton.tintColor = AppColors.danger
        line.removeButton.setContentHuggingPriority(.required, for: .horizontal)
        line.removeButton.addAction(UIAction { [weak self, weak line] _ in
            guard let self, let line else { return }
            self.removeLine(line)
        }, for: .touchUpInside)

        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        header.addArrangedSubview(UILabel.make("Service", font: AppFonts.semibold(13), color: AppColors.textPrimary))
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(line.removeButton)
        line.container.addArrangedSubview(header)

        styleDropdown(line.serviceButton)
        setDropdownTitle(line.serviceButton, line.service.label, chosen: true)
        line.serviceButton.addAction(UIAction { [weak self, weak line] _ in
            guard let self, let line else { return }
            self.presentOptions("Service", options: Service.allCases.map(\.label)) { index in
                line.service = Service.allCases[index]
                self.setDropdownTitle(line.serviceButton, line.service.label, chosen: true)
                self.applyService(line)
            }
        }, for: .touchUpInside)
        line.container.addArrangedSubview(line.serviceButton)

        StyleKit.styleInput(line.amountField)
        line.amountField.keyboardType = .decimalPad
        line.amountField.placeholder = "0"
        line.amountField.addAction(UIAction { [weak self, weak line] _ in
            guard let self, let line else { return }
            self.applyService(line)
        }, for: .editingChanged)
        line.container.addArrangedSubview(line.amountLabel)
        line.container.addArrangedSubview(line.amountField)
        line.bytesNote.numberOfLines = 0
        line.container.addArrangedSubview(line.bytesNote)

        line.expiryField.onPick = { [weak line] iso in line?.expiryDate = iso }
        line.container.addArrangedSubview(UILabel.make("Expires", font: AppFonts.semibold(13), color: AppColors.textPrimary))
        line.container.addArrangedSubview(line.expiryField)

        StyleKit.styleInput(line.priceField)
        line.priceField.keyboardType = .decimalPad
        line.priceField.placeholder = "R 0.00"
        line.priceField.addAction(UIAction { [weak self] _ in self?.updateTotal() }, for: .editingChanged)
        line.container.addArrangedSubview(UILabel.make("Price (R)", font: AppFonts.semibold(13), color: AppColors.textPrimary))
        line.container.addArrangedSubview(line.priceField)

        line.container.forAutoLayout()
        box.addSubview(line.container)
        line.container.pinEdges(to: box, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))

        linesContainer.addArrangedSubview(box)
        lines.append(line)
        applyService(line)
        updateRemoveVisibility()
        updateTotal()
    }

    private func removeLine(_ line: Line) {
        guard let index = lines.firstIndex(where: { $0 === line }) else { return }
        // The box wrapping the line is what was added to the container.
        line.container.superview?.removeFromSuperview()
        lines.remove(at: index)
        updateRemoveVisibility()
        updateTotal()
    }

    /// A single line cannot be removed — the bundle would then have nothing to provision.
    private func updateRemoveVisibility() {
        let hideRemove = lines.count <= 1
        lines.forEach { $0.removeButton.isHidden = hideRemove }
    }

    /// Re-labels the amount field for the chosen service and echoes the byte conversion.
    private func applyService(_ line: Line) {
        line.amountLabel.text = line.service.amountLabel
        if line.service.inGigabytes && line.bytesValue > 0 {
            line.bytesNote.isHidden = false
            line.bytesNote.text = "= \(VasFormat.bytes(line.bytesValue)) bytes"
        } else {
            line.bytesNote.isHidden = true
        }
    }

    private func updateTotal() {
        totalLabel.text = VasFormat.money(lines.reduce(0.0) { $0 + $1.price })
    }

    // MARK: Provision

    private func provision() {
        guard validate() else { return }
        let customerId = host?.vasActingCustomerId ?? ""
        guard !customerId.isEmpty else {
            _ = fail("Choose the customer you are acting for first.")
            return
        }
        provisionButton.isEnabled = false
        provisionButton.setTitle("Processing…", for: .normal)

        ApiClient.shared.provisionVasDynamicServices(msisdn: text(msisdnField),
                                                     services: buildServices(),
                                                     customerId: customerId) { [weak self] result in
            guard let self else { return }
            self.provisionButton.isEnabled = true
            self.provisionButton.setTitle("Provision services", for: .normal)
            switch result {
            case .success:
                self.host?.vasShowAlert(
                    title: "Services provisioned",
                    message: "Your custom bundle has been submitted. Check Recent transactions for the outcome.")
                self.host?.vasRefreshTransactions()
            case .failure(let error):
                self.host?.vasShowError(error.message)
            }
        }
    }

    /// The `services` array of the dynamic-services request; prices go in cents.
    private func buildServices() -> [[String: Any]] {
        lines.map { line -> [String: Any] in
            var entry: [String: Any] = [
                "definitionCode": line.service.code,
                "value": line.apiValue,
                "priceInCents": Int((line.price * 100).rounded())
            ]
            if !line.expiryDate.isEmpty { entry["expiryDate"] = line.expiryDate }
            return entry
        }
    }

    private func validate() -> Bool {
        let msisdn = text(msisdnField)
        if msisdn.isEmpty {
            return fail("Please enter the recipient's mobile number.")
        }
        if !VasFormat.isValidMsisdn(msisdn) {
            return fail("Enter a valid mobile number, e.g. 082 123 4567.")
        }
        if lines.isEmpty {
            return fail("Add at least one service line.")
        }
        for line in lines {
            if !line.hasAmount {
                return fail("Enter an amount greater than zero for every service line.")
            }
            if line.price <= 0 {
                return fail("Enter a price greater than R0.00 for every service line.")
            }
        }
        return true
    }

    private func fail(_ message: String) -> Bool {
        host?.vasShowAlert(title: "Check your details", message: message)
        return false
    }
}
