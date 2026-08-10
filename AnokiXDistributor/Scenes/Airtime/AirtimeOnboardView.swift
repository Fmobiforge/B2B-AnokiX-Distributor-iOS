import UIKit

/// Airtime & VAS › Onboard customer. Registers an end-customer in the Limes CRM so an
/// account exists before a SIM is assigned. "View request body" previews the exact JSON the
/// server would POST to Limes without sending anything, which is how an operator checks a
/// half-filled form.
final class AirtimeOnboardView: VasSectionView {

    // Label/value pairs for the Limes system codes. Labels are what the operator reads; the
    // value at the same index is what the API expects.
    private static let titles = (labels: ["Mr", "Mrs", "Ms", "Dr"], values: ["Mr", "Mrs", "Ms", "Dr"])
    private static let idTypes = (labels: ["SA ID", "Passport"], values: ["ID", "PASSPORT"])
    private static let taxSchemes = (labels: ["VB8 · VAT 15%"], values: ["VB8"])
    private static let plans = (labels: ["STD9 · Standard"], values: ["STD9"])
    private static let languages = (labels: ["English", "Afrikaans"], values: ["en-gb", "af-za"])
    private static let roles = (labels: ["Customer"], values: ["CUSTOMER"])
    private static let media = (labels: ["Email", "SMS", "Post"], values: ["EMAIL", "SMS", "POST"])
    private static let countries = (labels: ["South Africa"], values: ["South Africa"])

    private static let explainer =
        "<b>When do I need this?</b> Only when signing a customer up to a SIM / contract "
        + "subscription — onboard them here, then activate their SIM on the <b>Subscription</b> "
        + "tab. For airtime, data or bundle top-ups you don't need this: use <b>Catalog & orders</b> "
        + "or <b>Dynamic services</b>, which provision straight to a phone number."

    private let firstNameField = UITextField()
    private let lastNameField = UITextField()
    private let idNumberField = UITextField()
    private let emailField = UITextField()
    private let phoneField = UITextField()
    private let streetNoField = UITextField()
    private let streetNameField = UITextField()
    private let suburbField = UITextField()
    private let cityField = UITextField()
    private let provinceField = UITextField()
    private let postCodeField = UITextField()

    private var createButton: UIButton!
    private var previewButton: UIButton!

    private var titleIndex = 0, idTypeIndex = 0, taxIndex = 0, planIndex = 0
    private var languageIndex = 0, roleIndex = 0, mediaIndex = 0, countryIndex = 0

    override func build() {
        let (cardView, content) = makeCard(
            title: "Onboard a customer",
            body: "Register the customer with Limes so an account exists before you assign them "
                + "a SIM & number. The system codes are pre-filled with the values the Limes API expects.")
        content.addArrangedSubview(VasSectionView.infoBanner(NSAttributedString.vasExplainer(Self.explainer)))

        // Identity
        content.addArrangedSubview(labeledDropdown("Title", button: UIButton(type: .system),
                                                   options: Self.titles.labels) { [weak self] in self?.titleIndex = $0 })
        content.addArrangedSubview(labeledField("First name", firstNameField, placeholder: "First name"))
        firstNameField.autocapitalizationType = .words
        content.addArrangedSubview(labeledField("Last name", lastNameField, placeholder: "Last name"))
        lastNameField.autocapitalizationType = .words

        content.addArrangedSubview(labeledDropdown("ID type", button: UIButton(type: .system),
                                                   options: Self.idTypes.labels) { [weak self] in
            self?.idTypeIndex = $0
            self?.applyIdType()
        })
        content.addArrangedSubview(labeledField("ID number", idNumberField, placeholder: "13 digits"))
        applyIdType()

        content.addArrangedSubview(labeledField("Email", emailField,
                                                placeholder: "name@example.com", keyboard: .emailAddress))
        emailField.autocapitalizationType = .none
        content.addArrangedSubview(labeledField("Mobile number", phoneField,
                                                placeholder: "27821234567", keyboard: .phonePad))

        // Limes system codes
        content.addArrangedSubview(labeledDropdown("Tax scheme", button: UIButton(type: .system),
                                                   options: Self.taxSchemes.labels) { [weak self] in self?.taxIndex = $0 })
        content.addArrangedSubview(labeledDropdown("Collection plan", button: UIButton(type: .system),
                                                   options: Self.plans.labels) { [weak self] in self?.planIndex = $0 })
        content.addArrangedSubview(labeledDropdown("Bill language", button: UIButton(type: .system),
                                                   options: Self.languages.labels) { [weak self] in self?.languageIndex = $0 })
        content.addArrangedSubview(labeledDropdown("Contact role", button: UIButton(type: .system),
                                                   options: Self.roles.labels) { [weak self] in self?.roleIndex = $0 })
        content.addArrangedSubview(labeledDropdown("Bill media", button: UIButton(type: .system),
                                                   options: Self.media.labels) { [weak self] in self?.mediaIndex = $0 })
        content.addArrangedSubview(labeledDropdown("Country", button: UIButton(type: .system),
                                                   options: Self.countries.labels) { [weak self] in self?.countryIndex = $0 })

        // Billing address
        content.addArrangedSubview(hairline())
        content.addArrangedSubview(UILabel.make("Billing address", font: AppFonts.bold(14), color: AppColors.textPrimary))
        content.addArrangedSubview(labeledField("Street no.", streetNoField, placeholder: "Street no."))
        content.addArrangedSubview(labeledField("Street name", streetNameField, placeholder: "Street name"))
        content.addArrangedSubview(labeledField("Suburb", suburbField, placeholder: "Suburb"))
        content.addArrangedSubview(labeledField("City", cityField, placeholder: "City"))
        content.addArrangedSubview(labeledField("Province", provinceField, placeholder: "Province"))
        content.addArrangedSubview(labeledField("Postal code", postCodeField,
                                                placeholder: "Postal code", keyboard: .numberPad))

        createButton = primaryButton("Create customer", color: AppColors.success) { [weak self] in self?.submit() }
        previewButton = outlinedButton("View request body") { [weak self] in self?.preview() }
        content.addArrangedSubview(createButton)
        content.addArrangedSubview(previewButton)

        stack.addArrangedSubview(cardView)
    }

    /// A SA ID is 13 digits; a passport is alphanumeric — so the keyboard follows the ID type.
    private func applyIdType() {
        let saId = Self.idTypes.values[idTypeIndex] == "ID"
        idNumberField.keyboardType = saId ? .numberPad : .asciiCapable
        idNumberField.autocapitalizationType = saId ? .none : .allCharacters
        idNumberField.placeholder = saId ? "13 digits" : "Passport number"
        if idNumberField.isFirstResponder { idNumberField.reloadInputViews() }
    }

    // MARK: Request

    /// The onboard form as the flat field map both `onboard-customer` and its preview take.
    /// The optional passport fields are always sent blank — the server omits them.
    private func buildForm() -> [String: String] {
        [
            "title": Self.titles.values[titleIndex],
            "firstname": text(firstNameField),
            "lastname": text(lastNameField),
            "id_type": Self.idTypes.values[idTypeIndex],
            "id_number": text(idNumberField),
            "id_issuer": "",
            "id_issued_date": "",
            "id_expiry_date": "",
            "email": text(emailField),
            "tax_scheme": Self.taxSchemes.values[taxIndex],
            "collection_plan": Self.plans.values[planIndex],
            "bill_language": Self.languages.values[languageIndex],
            "contact_role": Self.roles.values[roleIndex],
            "bill_media": Self.media.values[mediaIndex],
            "country": Self.countries.values[countryIndex],
            "phone": text(phoneField),
            "street_no": text(streetNoField),
            "street_name": text(streetNameField),
            "suburb": text(suburbField),
            "city": text(cityField),
            "province": text(provinceField),
            "post_code": text(postCodeField)
        ]
    }

    private func submit() {
        guard validate() else { return }
        createButton.isEnabled = false
        createButton.setTitle("Processing…", for: .normal)

        ApiClient.shared.onboardVasCustomer(form: buildForm()) { [weak self] result in
            guard let self else { return }
            self.createButton.isEnabled = true
            self.createButton.setTitle("Create customer", for: .normal)
            switch result {
            case .success(let data):
                let existed = data.customer?.alreadyExists ?? false
                self.host?.vasShowAlert(
                    title: "Customer created",
                    message: existed
                        ? "Limes already had this customer. Go straight to the Subscription tab to activate their SIM."
                        : "The customer is registered with Limes. Activate their SIM on the Subscription tab.")
                self.host?.vasCustomerOnboarded()
            case .failure(let error):
                self.host?.vasShowError(error.message)
            }
        }
    }

    private func preview() {
        previewButton.isEnabled = false
        // The preview runs no validation on purpose — seeing a half-filled body is the point.
        ApiClient.shared.previewVasOnboard(form: buildForm()) { [weak self] result in
            guard let self else { return }
            self.previewButton.isEnabled = true
            switch result {
            case .success(let text):
                self.host?.vasShowAlert(title: "Request body", message: text)
            case .failure(let error):
                self.host?.vasShowError(error.message)
            }
        }
    }

    private func validate() -> Bool {
        if text(firstNameField).isEmpty {
            return fail("Please enter the customer's first name.")
        }
        if text(lastNameField).isEmpty {
            return fail("Please enter the customer's last name.")
        }
        if text(idNumberField).isEmpty {
            return fail("Please enter the customer's ID or passport number.")
        }
        let email = text(emailField)
        if email.isEmpty || !email.contains("@") || !email.contains(".") {
            return fail("Please enter a valid email address.")
        }
        let phone = text(phoneField)
        if phone.isEmpty {
            return fail("Please enter the customer's mobile number.")
        }
        if !VasFormat.isValidMsisdn(phone) {
            return fail("Enter a valid mobile number, e.g. 082 123 4567.")
        }
        return true
    }

    private func fail(_ message: String) -> Bool {
        host?.vasShowAlert(title: "Check your details", message: message)
        return false
    }
}
