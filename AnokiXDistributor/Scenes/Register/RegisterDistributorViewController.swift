import UIKit
import GoogleMaps
import CoreLocation
import UniformTypeIdentifiers
import PhotosUI

/// Port of RegisterDistributorActivity — the public 8-step "Create Account" wizard
/// wired to POST /api/distributor/register (a public endpoint: no auth token).
///
/// Steps: 1 Company · 2 Business · 3 Contacts · 4 Location · 5 Documents ·
///        6 Service · 7 Wallet · 8 Terms.
///
/// Every step stack stays in the hierarchy (just hidden), so field values survive
/// forward/back navigation. Product categories come from `ApiClient.getReference`;
/// the map uses Google Maps (parity with Create Trader / Add Store).
final class RegisterDistributorViewController: BaseSecondaryViewController, GMSMapViewDelegate,
    UIDocumentPickerDelegate, PHPickerViewControllerDelegate, UITableViewDataSource, UITableViewDelegate {

    override var screenTitle: String { S.registerAccountTitle }
    override var screenSubtitle: String? { S.registerAccountSubtitle }

    private let stepKeys = [S.rStepCompany, S.rStepBusiness, S.rStepContacts, S.rStepLocation,
                            S.rStepDocuments, S.rStepService, S.rStepWallet, S.rStepTerms]
    private let stepLocation = 3, stepDocuments = 4, stepService = 5, stepTerms = 7
    private var currentStep = 0

    private static let logoKey = "__logo__"

    // Dropdown option sets (mirror the Android arrays): display labels paired with
    // the API codes the web frontend submits (see the Chrome payload dump). Codes
    // confirmed by the dump: sole_proprietor, 1_10, under_1m, absa, cheque, 1_3,
    // regional. The rest follow the same pattern and are pending confirmation.
    private let businessTypes = ["Sole Proprietor", "(Pty) Ltd", "Close Corporation", "Partnership", "Trust", "Other"]
    private let businessTypeCodes = ["sole_proprietor", "pty_ltd", "close_corporation", "partnership", "trust", "other"]
    private let employeeRanges = ["1-10", "11-50", "51-200", "201-500", "500+"]
    private let employeeRangeCodes = ["1_10", "11_50", "51_200", "201_500", "500_plus"]
    private let turnoverRanges = ["Under R1 million", "R1M-R5M", "R5M-R20M", "R20M-R50M", "Over R50M"]
    private let turnoverRangeCodes = ["under_1m", "1m_5m", "5m_20m", "20m_50m", "over_50m"]
    private let banks = ["ABSA", "FNB", "Nedbank", "Standard Bank", "Capitec", "Investec", "TymeBank", "Other"]
    private let bankCodes = ["absa", "fnb", "nedbank", "standard_bank", "capitec", "investec", "tymebank", "other"]
    private let accountTypes = ["Cheque / Current", "Savings", "Business", "Transmission"]
    private let accountTypeCodes = ["cheque", "savings", "business", "transmission"]
    private let fleetSizes = ["No fleet", "1-3 vehicles", "4-10 vehicles", "11-20 vehicles", "21+ vehicles"]
    private let fleetSizeCodes = ["no_fleet", "1_3", "4_10", "11_20", "21_plus"]

    // Delivery-day chips (Sun first, Mon–Fri default on — matches the design table).
    private let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let dayDefaultOn = [false, true, true, true, true, true, false]
    private var selectedDays: [String] = []

    // Chrome
    private let stepperScroll = UIScrollView()
    private let stepperStack = UIStackView.horizontal(spacing: 0, alignment: .center)
    private var stepCircles: [UILabel] = []
    private var stepTitles: [UILabel] = []
    private let formScroll = UIScrollView()
    private let continueButton = GradientButton(title: S.continueButton)
    private var stepStacks: [UIStackView] = []

    // Reference data
    private var primaryCategories: [ReferenceData.ProductCategory] = []
    private var selectedCategoryIds: [Int64] = []

    // Dropdown selections (key -> value sent verbatim to the API)
    private var dropdownValues: [String: String] = [:]
    private var dropdownButtons: [String: UIButton] = [:]

    // Coverage
    private var selectedCoverage: String?
    private var coverageCards: [(view: UIView, value: String, icon: UIImageView, title: UILabel)] = []

    // Company / account fields
    private let companyLegalNameField = UITextField()
    private let tradingNameField = UITextField()
    private let companyRegField = UITextField()
    private let vatField = UITextField()
    private let companyEmailField = UITextField()
    private let companyPhoneField = UITextField()
    private let firstNameField = UITextField()
    private let lastNameField = UITextField()
    private let mobileField = UITextField()
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let confirmPasswordField = UITextField()

    // Banking
    private let accountHolderField = UITextField()
    private let accountNumberField = UITextField()
    private let branchCodeField = UITextField()

    // Country pickers
    private var companyCountry = Countries.default
    private var mobileCountry = Countries.default
    private var primaryCountry = Countries.default
    private let companyCountryButton = UIButton(type: .system)
    private let mobileCountryButton = UIButton(type: .system)
    private let primaryCountryButton = UIButton(type: .system)

    // Primary contact
    private let primaryNameField = UITextField()
    private let primaryPositionField = UITextField()
    private let primaryMobileField = UITextField()
    private let primaryEmailField = UITextField()

    // Additional contacts (dynamic rows)
    private final class ContactRow {
        let container = UIStackView.vertical(spacing: 10, alignment: .fill)
        let header = UILabel.make("", font: AppFonts.bold(14), color: AppColors.purpleDark)
        let nameField = UITextField()
        let positionField = UITextField()
        let mobileField = UITextField()
        let emailField = UITextField()
        var country = Countries.default
        let countryButton = UIButton(type: .system)
    }
    private var contactRows: [ContactRow] = []
    private let additionalContactsStack = UIStackView.vertical(spacing: 16, alignment: .fill)

    // Logo
    private let logoPreview = UIImageView()
    private let logoPlaceholder = UIStackView.vertical(spacing: 6, alignment: .center)
    private var logoData: Data?

    // Categories chips
    private let categoryHint = UILabel.make("Tap to select categories", font: AppFonts.regular(13), color: AppColors.textSecondary)
    private let categoryChipsScroll = UIScrollView()
    private let categoryChips = UIStackView.horizontal(spacing: 8, alignment: .center)

    // Delivery day chips
    private let deliveryDaysStack = UIStackView.horizontal(spacing: 8, alignment: .center)

    // Location
    private let addressField = UITextField()
    private let addressResultsTable = UITableView(frame: .zero, style: .plain)
    private var addressResultsHeight: NSLayoutConstraint!
    private var predictions: [AutocompleteData.Prediction] = []
    private var autocompleteWorkItem: DispatchWorkItem?
    private let mapContainer = UIView()
    private lazy var mapView: GMSMapView = makeMapView()
    private var pickedCoordinate: CLLocationCoordinate2D?
    private var marker: GMSMarker?
    private var didWireMapScroll = false
    private var suppressAddressChange = false

    // Wallet
    private let walletNowRadio = UIImageView()
    private let walletLaterRadio = UIImageView()
    private var createWalletNow = true

    // Terms
    private var termCheckboxes: [UIButton] = []

    // Documents
    private struct DocDef { let key, title, sub: String?; let required: Bool
        init(key: String, title: String, sub: String?, required: Bool) {
            self.key = key; self.title = title; self.sub = sub; self.required = required
        }
    }
    private let docDefs: [DocDef] = [
        DocDef(key: "company_registration_certificate", title: "Company Registration Certificate", sub: nil, required: true),
        DocDef(key: "tax_clearance_certificate", title: "Tax Clearance Certificate", sub: "(If available)", required: false),
        DocDef(key: "vat_registration_certificate", title: "VAT Registration Certificate", sub: "(If available)", required: false),
        DocDef(key: "proof_of_address", title: "Proof of Address", sub: "Municipal bill, Lease, etc.", required: true),
        DocDef(key: "bank_confirmation_letter", title: "Bank Confirmation Letter", sub: nil, required: true),
        DocDef(key: "company_logo", title: "Company Logo", sub: "(Recommended)", required: false)
    ]
    /// Server caps the whole POST at 40 MB; keep each file under 5 MB.
    private static let maxUploadBytes = 5 * 1024 * 1024
    private var docFiles: [String: (data: Data, name: String, mime: String)] = [:]
    private var docSubtitleLabels: [String: UILabel] = [:]
    private var docButtons: [String: UIButton] = [:]
    private var pendingDocKey: String?

    // MARK: - Entry point

    /// Push onto the presenter's nav stack, or present wrapped in a nav controller
    /// when the presenter has none (e.g. the Welcome screen, shown as window root).
    static func open(from presenter: UIViewController) {
        let vc = RegisterDistributorViewController()
        if let nav = presenter.navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            nav.setNavigationBarHidden(true, animated: false)
            presenter.present(nav, animated: true)
        }
    }

    // MARK: - Setup

    override func viewDidLoad() {
        super.viewDidLoad()
        // Back arrow either pops (pushed) or dismisses (presented as nav root).
        header.onLeading = { [weak self] in self?.leave() }
    }

    override func setupContent(in container: UIView) {
        buildStepper(in: container)
        let divider = ListScreenLayout.hairline()
        divider.forAutoLayout()
        container.addSubview(divider)

        let bottomBar = buildBottomBar()
        container.addSubview(bottomBar)

        formScroll.alwaysBounceVertical = true
        formScroll.showsVerticalScrollIndicator = false
        formScroll.forAutoLayout()
        container.addSubview(formScroll)

        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: stepperScroll.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            bottomBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            formScroll.topAnchor.constraint(equalTo: divider.bottomAnchor),
            formScroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            formScroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            formScroll.bottomAnchor.constraint(equalTo: bottomBar.topAnchor)
        ])

        let formStack = UIStackView.vertical(spacing: 0, alignment: .fill)
        formStack.forAutoLayout()
        formScroll.addSubview(formStack)
        NSLayoutConstraint.activate([
            formStack.topAnchor.constraint(equalTo: formScroll.contentLayoutGuide.topAnchor),
            formStack.bottomAnchor.constraint(equalTo: formScroll.contentLayoutGuide.bottomAnchor),
            formStack.leadingAnchor.constraint(equalTo: formScroll.frameLayoutGuide.leadingAnchor),
            formStack.trailingAnchor.constraint(equalTo: formScroll.frameLayoutGuide.trailingAnchor)
        ])

        stepStacks = [buildCompanyStep(), buildBusinessStep(), buildContactsStep(), buildLocationStep(),
                      buildDocumentsStep(), buildServiceStep(), buildWalletStep(), buildTermsStep()]
        for step in stepStacks {
            step.isLayoutMarginsRelativeArrangement = true
            step.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
            formStack.addArrangedSubview(step)
        }
        showStep(0)
    }

    override func loadData() { loadReference() }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didWireMapScroll else { return }
        didWireMapScroll = true
        wireMapScrollBehavior()
    }

    private func leave() {
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    // MARK: - Stepper

    private func buildStepper(in container: UIView) {
        stepperScroll.showsHorizontalScrollIndicator = false
        stepperScroll.backgroundColor = AppColors.surface
        stepperScroll.forAutoLayout()
        container.addSubview(stepperScroll)
        stepperStack.forAutoLayout()
        stepperStack.isLayoutMarginsRelativeArrangement = true
        stepperStack.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        stepperScroll.addSubview(stepperStack)

        NSLayoutConstraint.activate([
            stepperScroll.topAnchor.constraint(equalTo: container.topAnchor),
            stepperScroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stepperScroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stepperScroll.heightAnchor.constraint(equalToConstant: 56),
            stepperStack.topAnchor.constraint(equalTo: stepperScroll.contentLayoutGuide.topAnchor),
            stepperStack.bottomAnchor.constraint(equalTo: stepperScroll.contentLayoutGuide.bottomAnchor),
            stepperStack.leadingAnchor.constraint(equalTo: stepperScroll.contentLayoutGuide.leadingAnchor),
            stepperStack.trailingAnchor.constraint(equalTo: stepperScroll.contentLayoutGuide.trailingAnchor),
            stepperStack.heightAnchor.constraint(equalTo: stepperScroll.frameLayoutGuide.heightAnchor)
        ])

        for (i, key) in stepKeys.enumerated() {
            if i > 0 {
                let connector = UIView()
                connector.backgroundColor = AppColors.border
                connector.constrainHeight(1)
                connector.widthAnchor.constraint(equalToConstant: 20).isActive = true
                stepperStack.addArrangedSubview(connector)
            }
            let circle = UILabel.make("\(i + 1)", font: AppFonts.bold(12), color: .white, align: .center)
            circle.constrainSize(28)
            circle.layer.cornerRadius = 14
            circle.layer.masksToBounds = true
            let title = UILabel.make(key, font: AppFonts.regular(13), color: AppColors.textSecondary)
            title.numberOfLines = 1
            title.lineBreakMode = .byClipping
            title.setContentCompressionResistancePriority(.required, for: .horizontal)
            title.setContentHuggingPriority(.required, for: .horizontal)
            let item = UIStackView.horizontal(spacing: 6, alignment: .center)
            item.isLayoutMarginsRelativeArrangement = true
            item.layoutMargins = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
            item.addArrangedSubview(circle)
            item.addArrangedSubview(title)
            stepperStack.addArrangedSubview(item)
            stepCircles.append(circle)
            stepTitles.append(title)
        }
    }

    private func renderStepper() {
        for i in 0..<stepKeys.count {
            let circle = stepCircles[i]
            let title = stepTitles[i]
            if i < currentStep {
                circle.backgroundColor = AppColors.purplePrimary
                circle.textColor = .white
                circle.text = "✓"
                title.textColor = AppColors.textPrimary
                title.font = AppFonts.regular(13)
            } else if i == currentStep {
                circle.backgroundColor = AppColors.purplePrimary
                circle.textColor = .white
                circle.text = "\(i + 1)"
                title.textColor = AppColors.purplePrimary
                title.font = AppFonts.bold(13)
            } else {
                circle.backgroundColor = AppColors.surface
                circle.layer.borderWidth = 1.5
                circle.layer.borderColor = AppColors.border.cgColor
                circle.textColor = AppColors.textSecondary
                circle.text = "\(i + 1)"
                title.textColor = AppColors.textSecondary
                title.font = AppFonts.regular(13)
            }
            if i <= currentStep { circle.layer.borderWidth = 0 }
        }
    }

    private func buildBottomBar() -> UIView {
        let bar = UIView()
        bar.backgroundColor = AppColors.surface
        bar.forAutoLayout()

        let topLine = ListScreenLayout.hairline()
        topLine.forAutoLayout()
        bar.addSubview(topLine)

        let backButton = UIButton(type: .system)
        backButton.setTitle("Back", for: .normal)
        StyleKit.styleOutlinedButton(backButton)
        backButton.configuration?.baseForegroundColor = AppColors.textPrimary
        backButton.configuration?.background.strokeColor = AppColors.border
        backButton.constrainHeight(46)
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)

        continueButton.constrainHeight(46)
        continueButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        continueButton.addTarget(self, action: #selector(goContinue), for: .touchUpInside)

        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.forAutoLayout()
        row.addArrangedSubview(backButton)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(continueButton)
        bar.addSubview(row)

        NSLayoutConstraint.activate([
            topLine.topAnchor.constraint(equalTo: bar.topAnchor),
            topLine.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            topLine.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            row.topAnchor.constraint(equalTo: bar.topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -12)
        ])
        return bar
    }

    // MARK: - Navigation

    @objc private func goBack() {
        if currentStep == 0 { leave() }
        else { showStep(currentStep - 1) }
    }

    @objc private func goContinue() {
        guard validateStep(currentStep) else { return }
        if currentStep == stepTerms { submit() }
        else { showStep(currentStep + 1) }
    }

    private func showStep(_ index: Int) {
        currentStep = index
        for (i, step) in stepStacks.enumerated() { step.isHidden = i != index }
        continueButton.setTitle(index == stepTerms ? S.registerButton : S.continueButton, for: .normal)
        renderStepper()
        view.endEditing(true)
        formScroll.setContentOffset(.zero, animated: false)
        scrollStepperToCurrent()
    }

    private func scrollStepperToCurrent() {
        stepperScroll.layoutIfNeeded()
        guard stepTitles.indices.contains(currentStep),
              let item = stepTitles[currentStep].superview else { return }
        let target = max(0, item.frame.minX - 40)
        stepperScroll.setContentOffset(CGPoint(x: target, y: 0), animated: true)
    }

    // MARK: - Validation

    private func validateStep(_ step: Int) -> Bool {
        switch step {
        case 0:
            if text(companyLegalNameField).isEmpty { return fail("Please enter the company legal name.") }
            if !isValidEmail(text(companyEmailField)) { return fail("Please enter a valid company email.") }
            if text(companyPhoneField).isEmpty { return fail("Please enter the company phone number.") }
            if text(firstNameField).isEmpty { return fail("Please enter your first name.") }
            if text(lastNameField).isEmpty { return fail("Please enter your last name.") }
            if text(mobileField).isEmpty { return fail("Please enter a mobile number.") }
            if !isValidEmail(text(emailField)) { return fail("Please enter a valid email address.") }
            if text(passwordField).count < 8 { return fail("Password must be at least 8 characters.") }
            if text(passwordField) != text(confirmPasswordField) { return fail("Passwords do not match.") }
            return true
        case 1:
            if dropdownValues["business_type"] == nil { return fail("Please select a business type.") }
            if dropdownValues["bank_name"] == nil { return fail("Please select a bank.") }
            return true
        case 2:
            if text(primaryNameField).isEmpty { return fail("Please enter the primary contact name.") }
            if text(primaryMobileField).isEmpty { return fail("Please enter the primary contact mobile number.") }
            return true
        case stepLocation:
            if pickedCoordinate == nil { return fail("Please select your business location on the map.") }
            return true
        case stepDocuments:
            for d in docDefs where d.required && docFiles[d.key] == nil {
                return fail("Please upload all required documents.")
            }
            return true
        case stepService:
            if selectedCoverage == nil { return fail("Please select your distribution coverage.") }
            return true
        case stepTerms:
            if termCheckboxes.contains(where: { !$0.isSelected }) {
                return fail("Please accept all terms to continue.")
            }
            return true
        default:
            return true
        }
    }

    private func fail(_ message: String) -> Bool {
        toast(message)
        return false
    }

    // MARK: - Step 1: Company

    private func buildCompanyStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Company Information"))
        stack.addArrangedSubview(subtitle("Tell us about your company."))

        stack.addArrangedSubview(buildLogoUploadBox())

        stack.addArrangedSubview(fieldGroup("Company Legal Name *", companyLegalNameField, placeholder: "Enter legal name"))
        stack.addArrangedSubview(fieldGroup("Trading Name", tradingNameField, placeholder: "Enter trading name"))
        stack.addArrangedSubview(fieldGroup("Company Registration Number", companyRegField, placeholder: "Enter registration number"))
        stack.addArrangedSubview(fieldGroup("VAT Number", vatField, placeholder: "Enter VAT number"))
        stack.addArrangedSubview(fieldGroup("Company Email *", companyEmailField, placeholder: "Enter company email", keyboard: .emailAddress))
        stack.addArrangedSubview(phoneGroup("Company Phone *", button: companyCountryButton, country: companyCountry, field: companyPhoneField, kind: .company))

        stack.addArrangedSubview(sectionTitle("Account Sign-In"))
        stack.addArrangedSubview(subtitle("Create your login credentials."))
        stack.addArrangedSubview(fieldGroup("First Name *", firstNameField, placeholder: "Enter first name"))
        stack.addArrangedSubview(fieldGroup("Last Name *", lastNameField, placeholder: "Enter last name"))
        stack.addArrangedSubview(phoneGroup("Mobile Number *", button: mobileCountryButton, country: mobileCountry, field: mobileField, kind: .mobile))
        stack.addArrangedSubview(fieldGroup("Email Address *", emailField, placeholder: "Enter email address", keyboard: .emailAddress))
        stack.addArrangedSubview(secureFieldGroup("Password *", passwordField, placeholder: "At least 8 characters"))
        stack.addArrangedSubview(secureFieldGroup("Confirm Password *", confirmPasswordField, placeholder: "Re-enter password"))
        return stack
    }

    private func buildLogoUploadBox() -> UIView {
        let box = UIView()
        box.backgroundColor = AppColors.surface
        box.layer.cornerRadius = AppMetrics.radiusMD
        box.layer.borderWidth = 1.5
        box.layer.borderColor = AppColors.border.cgColor
        box.constrainHeight(140)
        box.isUserInteractionEnabled = true
        box.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(pickLogo)))

        let icon = UIImageView(image: UIImage(systemName: "photo.badge.plus"))
        icon.tintColor = AppColors.purplePrimary
        icon.contentMode = .scaleAspectFit
        icon.constrainSize(34)
        let label = UILabel.make("Upload Company Logo", font: AppFonts.bold(13), color: AppColors.purplePrimary)
        let hint = UILabel.make("PNG or JPG, square recommended", font: AppFonts.regular(11), color: AppColors.textSecondary)
        logoPlaceholder.addArrangedSubview(icon)
        logoPlaceholder.addArrangedSubview(label)
        logoPlaceholder.addArrangedSubview(hint)
        logoPlaceholder.forAutoLayout()
        box.addSubview(logoPlaceholder)

        logoPreview.contentMode = .scaleAspectFill
        logoPreview.clipsToBounds = true
        logoPreview.layer.cornerRadius = AppMetrics.radiusSM
        logoPreview.isHidden = true
        logoPreview.forAutoLayout()
        box.addSubview(logoPreview)

        NSLayoutConstraint.activate([
            logoPlaceholder.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            logoPlaceholder.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            logoPreview.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            logoPreview.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            logoPreview.widthAnchor.constraint(equalToConstant: 110),
            logoPreview.heightAnchor.constraint(equalToConstant: 110)
        ])
        return box
    }

    @objc private func pickLogo() {
        pendingDocKey = Self.logoKey
        presentSourceSheet(allowFiles: false, from: logoPlaceholder)
    }

    // MARK: - Step 2: Business

    private func buildBusinessStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Business Information"))
        stack.addArrangedSubview(subtitle("Tell us more about your operation."))
        stack.addArrangedSubview(dropdownGroup("Type of Business *", key: "business_type", title: "Type of Business", options: businessTypes, codes: businessTypeCodes))
        stack.addArrangedSubview(dropdownGroup("Year Established", key: "year_established", title: "Year Established", options: buildYears()))
        stack.addArrangedSubview(dropdownGroup("Number of Employees", key: "number_of_employees", title: "Number of Employees", options: employeeRanges, codes: employeeRangeCodes))
        stack.addArrangedSubview(dropdownGroup("Annual Turnover", key: "annual_turnover", title: "Annual Turnover", options: turnoverRanges, codes: turnoverRangeCodes))

        stack.addArrangedSubview(sectionTitle("Banking Details"))
        stack.addArrangedSubview(dropdownGroup("Bank Name *", key: "bank_name", title: "Bank Name", options: banks, codes: bankCodes))
        stack.addArrangedSubview(dropdownGroup("Account Type", key: "account_type", title: "Account Type", options: accountTypes, codes: accountTypeCodes))
        stack.addArrangedSubview(fieldGroup("Account Holder Name", accountHolderField, placeholder: "Enter account holder name"))
        stack.addArrangedSubview(fieldGroup("Account Number", accountNumberField, placeholder: "Enter account number", keyboard: .numberPad))
        stack.addArrangedSubview(fieldGroup("Branch Code", branchCodeField, placeholder: "Enter branch code", keyboard: .numberPad))
        return stack
    }

    private func buildYears() -> [String] {
        return (1950...2026).reversed().map { String($0) }
    }

    // MARK: - Step 3: Contacts

    private func buildContactsStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Contact Persons"))
        stack.addArrangedSubview(subtitle("Who should we reach out to?"))

        stack.addArrangedSubview(UILabel.make("Primary Contact", font: AppFonts.bold(15), color: AppColors.purpleDark))
        stack.addArrangedSubview(fieldGroup("Full Name *", primaryNameField, placeholder: "Enter full name"))
        stack.addArrangedSubview(fieldGroup("Position", primaryPositionField, placeholder: "e.g. Operations Manager"))
        stack.addArrangedSubview(phoneGroup("Mobile Number *", button: primaryCountryButton, country: primaryCountry, field: primaryMobileField, kind: .primary))
        stack.addArrangedSubview(fieldGroup("Email Address", primaryEmailField, placeholder: "Enter email address", keyboard: .emailAddress))

        additionalContactsStack.forAutoLayout()
        stack.addArrangedSubview(additionalContactsStack)

        let addButton = UIButton(type: .system)
        addButton.setTitle("+ Add Another Contact", for: .normal)
        addButton.setTitleColor(AppColors.purplePrimary, for: .normal)
        addButton.titleLabel?.font = AppFonts.bold(14)
        addButton.layer.cornerRadius = AppMetrics.radiusMD
        addButton.layer.borderWidth = 1
        addButton.layer.borderColor = AppColors.purplePrimary.cgColor
        addButton.constrainHeight(46)
        addButton.addTarget(self, action: #selector(addContactRow), for: .touchUpInside)
        stack.addArrangedSubview(addButton)
        return stack
    }

    @objc private func addContactRow() {
        let row = ContactRow()
        row.container.isLayoutMarginsRelativeArrangement = true
        row.container.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        row.container.backgroundColor = AppColors.surfaceVariant
        row.container.layer.cornerRadius = AppMetrics.radiusMD

        let headerRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.header.text = "Additional Contact \(contactRows.count + 1)"
        headerRow.addArrangedSubview(row.header)
        headerRow.addArrangedSubview(UIView())
        let remove = UIButton(type: .system)
        remove.setImage(UIImage(systemName: "trash"), for: .normal)
        remove.tintColor = AppColors.danger
        remove.constrainSize(24)
        remove.addAction(UIAction { [weak self] _ in self?.removeContactRow(row) }, for: .touchUpInside)
        headerRow.addArrangedSubview(remove)
        row.container.addArrangedSubview(headerRow)

        row.container.addArrangedSubview(fieldGroup("Full Name", row.nameField, placeholder: "Enter full name"))
        row.container.addArrangedSubview(fieldGroup("Position", row.positionField, placeholder: "Position"))
        row.container.addArrangedSubview(phoneGroup("Mobile Number", button: row.countryButton, country: row.country, field: row.mobileField, kind: .contact(row)))
        row.container.addArrangedSubview(fieldGroup("Email Address", row.emailField, placeholder: "Email address", keyboard: .emailAddress))

        additionalContactsStack.addArrangedSubview(row.container)
        contactRows.append(row)
    }

    private func removeContactRow(_ row: ContactRow) {
        row.container.removeFromSuperview()
        contactRows.removeAll { $0 === row }
        for (i, r) in contactRows.enumerated() { r.header.text = "Additional Contact \(i + 1)" }
    }

    // MARK: - Step 4: Location

    private func buildLocationStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Business Location"))
        stack.addArrangedSubview(subtitle("Where is your business located?"))
        stack.addArrangedSubview(fieldGroup("Address", addressField, placeholder: "Search for your business address"))
        addressField.addTarget(self, action: #selector(addressChanged), for: .editingChanged)

        addressResultsTable.dataSource = self
        addressResultsTable.delegate = self
        addressResultsTable.isHidden = true
        addressResultsTable.layer.cornerRadius = AppMetrics.radiusMD
        addressResultsTable.layer.borderWidth = 1
        addressResultsTable.layer.borderColor = AppColors.border.cgColor
        addressResultsTable.register(UITableViewCell.self, forCellReuseIdentifier: "pred")
        addressResultsHeight = addressResultsTable.heightAnchor.constraint(equalToConstant: 0)
        addressResultsHeight.isActive = true
        stack.addArrangedSubview(addressResultsTable)

        stack.addArrangedSubview(subtitle("Tap the map to drop a pin, or drag the pin to set the location."))
        mapContainer.forAutoLayout()
        mapContainer.constrainHeight(320)
        mapView.forAutoLayout()
        mapContainer.addSubview(mapView)
        mapView.pinEdges(to: mapContainer)
        stack.addArrangedSubview(mapContainer)
        return stack
    }

    // MARK: - Step 5: Documents

    private func buildDocumentsStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 10, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Required Documents"))
        stack.addArrangedSubview(subtitle("Upload the documents to verify your business."))
        for def in docDefs { stack.addArrangedSubview(documentRow(def)) }
        stack.addArrangedSubview(subtitle("Accepted formats: JPG, PNG, PDF (Max 5MB)"))
        return stack
    }

    private func documentRow(_ def: DocDef) -> UIView {
        let card = StyleKit.cardView()
        let iconTile = StyleKit.iconTile(color: AppColors.surfaceVariant)
        iconTile.constrainSize(40)
        let icon = UIImageView(image: UIImage(systemName: "doc.fill"))
        icon.tintColor = AppColors.textSecondary
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        iconTile.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20)
        ])

        let title = UILabel.make(def.required ? def.title + " *" : def.title, font: AppFonts.bold(13), color: AppColors.textPrimary, lines: 0)
        let textCol = UIStackView.vertical(spacing: 2, alignment: .leading)
        textCol.addArrangedSubview(title)
        if let subText = def.sub {
            let sub = UILabel.make(subText, font: AppFonts.regular(11), color: AppColors.textSecondary, lines: 0)
            docSubtitleLabels[def.key] = sub
            textCol.addArrangedSubview(sub)
        } else {
            let sub = UILabel.make("", font: AppFonts.regular(11), color: AppColors.textSecondary, lines: 0)
            sub.isHidden = true
            docSubtitleLabels[def.key] = sub
            textCol.addArrangedSubview(sub)
        }

        let upload = UIButton(type: .system)
        upload.setTitle("Upload", for: .normal)
        upload.setTitleColor(AppColors.purplePrimary, for: .normal)
        upload.titleLabel?.font = AppFonts.bold(12)
        upload.layer.cornerRadius = AppMetrics.radiusSM
        upload.layer.borderWidth = 1
        upload.layer.borderColor = AppColors.border.cgColor
        upload.contentEdgeInsets = UIEdgeInsets(top: 9, left: 16, bottom: 9, right: 16)
        upload.addAction(UIAction { [weak self] _ in
            self?.pendingDocKey = def.key
            self?.presentSourceSheet(allowFiles: true, from: upload)
        }, for: .touchUpInside)
        upload.setContentHuggingPriority(.required, for: .horizontal)
        docButtons[def.key] = upload

        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.forAutoLayout()
        row.addArrangedSubview(iconTile)
        row.addArrangedSubview(textCol)
        row.addArrangedSubview(upload)
        card.addSubview(row)
        row.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        return card
    }

    // MARK: - Step 6: Service

    private func buildServiceStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Service & Coverage"))
        stack.addArrangedSubview(subtitle("How do you serve your customers?"))

        stack.addArrangedSubview(UILabel.make("Distribution Coverage *", font: AppFonts.bold(14), color: AppColors.textPrimary))
        let coverageRow = UIStackView.horizontal(spacing: 12, alignment: .fill)
        coverageRow.distribution = .fillEqually
        coverageRow.addArrangedSubview(coverageCard(value: "Local", systemIcon: "mappin.and.ellipse", desc: "Within your city"))
        coverageRow.addArrangedSubview(coverageCard(value: "Regional", systemIcon: "map", desc: "Across provinces"))
        coverageRow.addArrangedSubview(coverageCard(value: "National", systemIcon: "globe.africa.fill", desc: "Country-wide"))
        stack.addArrangedSubview(coverageRow)

        stack.addArrangedSubview(UILabel.make("Product Categories You Serve", font: AppFonts.bold(14), color: AppColors.textPrimary))
        let categoryField = tappableField()
        categoryField.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(pickCategories)))
        let catStack = UIStackView.vertical(spacing: 6, alignment: .fill)
        catStack.isLayoutMarginsRelativeArrangement = true
        catStack.layoutMargins = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        catStack.addArrangedSubview(categoryHint)
        categoryChipsScroll.showsHorizontalScrollIndicator = false
        categoryChips.forAutoLayout()
        categoryChipsScroll.addSubview(categoryChips)
        categoryChips.pinEdges(to: categoryChipsScroll)
        categoryChips.heightAnchor.constraint(equalTo: categoryChipsScroll.heightAnchor).isActive = true
        categoryChipsScroll.heightAnchor.constraint(equalToConstant: 30).isActive = true
        categoryChipsScroll.isHidden = true
        catStack.addArrangedSubview(categoryChipsScroll)
        categoryField.addSubview(catStack)
        catStack.forAutoLayout()
        catStack.pinEdges(to: categoryField)
        stack.addArrangedSubview(categoryField)

        stack.addArrangedSubview(dropdownGroup("Number of Active Clients", key: "active_clients_range", title: "Active Clients", options: employeeRanges, codes: employeeRangeCodes))
        stack.addArrangedSubview(dropdownGroup("Delivery Fleet Size", key: "delivery_fleet_size", title: "Delivery Fleet Size", options: fleetSizes, codes: fleetSizeCodes))

        stack.addArrangedSubview(UILabel.make("Preferred Delivery Days", font: AppFonts.bold(14), color: AppColors.textPrimary))
        let daysScroll = UIScrollView()
        daysScroll.showsHorizontalScrollIndicator = false
        deliveryDaysStack.forAutoLayout()
        daysScroll.addSubview(deliveryDaysStack)
        deliveryDaysStack.pinEdges(to: daysScroll)
        deliveryDaysStack.heightAnchor.constraint(equalTo: daysScroll.heightAnchor).isActive = true
        daysScroll.heightAnchor.constraint(equalToConstant: 38).isActive = true
        buildDeliveryDayChips()
        stack.addArrangedSubview(daysScroll)
        return stack
    }

    private func coverageCard(value: String, systemIcon: String, desc: String) -> UIView {
        let card = UIView()
        card.layer.cornerRadius = AppMetrics.radiusMD
        card.layer.borderWidth = 1
        card.layer.borderColor = AppColors.border.cgColor
        card.backgroundColor = AppColors.surface
        card.isUserInteractionEnabled = true
        let icon = UIImageView(image: UIImage(systemName: systemIcon))
        icon.tintColor = AppColors.textSecondary
        icon.contentMode = .scaleAspectFit
        icon.constrainSize(24)
        let title = UILabel.make(value, font: AppFonts.bold(13), color: AppColors.textPrimary, align: .center)
        let sub = UILabel.make(desc, font: AppFonts.regular(10), color: AppColors.textSecondary, align: .center, lines: 2)
        let inner = UIStackView.vertical(spacing: 6, alignment: .center)
        inner.forAutoLayout()
        inner.addArrangedSubview(icon)
        inner.addArrangedSubview(title)
        inner.addArrangedSubview(sub)
        card.addSubview(inner)
        inner.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 6, bottom: 14, right: 6))
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(coverageTapped(_:))))
        card.tag = coverageCards.count
        coverageCards.append((card, value, icon, title))
        return card
    }

    @objc private func coverageTapped(_ gesture: UITapGestureRecognizer) {
        guard let tag = gesture.view?.tag, coverageCards.indices.contains(tag) else { return }
        selectedCoverage = coverageCards[tag].value
        applyCoverageSelection()
    }

    private func applyCoverageSelection() {
        for entry in coverageCards {
            let selected = entry.value == selectedCoverage
            entry.view.backgroundColor = selected ? AppColors.purpleLight : AppColors.surface
            entry.view.layer.borderColor = (selected ? AppColors.purplePrimary : AppColors.border).cgColor
            entry.view.layer.borderWidth = selected ? 1.5 : 1
            entry.icon.tintColor = selected ? AppColors.purplePrimary : AppColors.textSecondary
            entry.title.textColor = selected ? AppColors.purplePrimary : AppColors.textPrimary
        }
    }

    private func buildDeliveryDayChips() {
        for (i, day) in dayLabels.enumerated() {
            let chip = PaddingLabel(insets: UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
            chip.text = day
            chip.font = AppFonts.regular(13)
            chip.layer.cornerRadius = 16
            chip.layer.borderWidth = 1
            chip.layer.masksToBounds = true
            chip.isUserInteractionEnabled = true
            chip.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleDay(_:))))
            deliveryDaysStack.addArrangedSubview(chip)
            if dayDefaultOn[i] { selectedDays.append(day) }
            styleDayChip(chip, selected: dayDefaultOn[i])
        }
    }

    private func styleDayChip(_ chip: PaddingLabel, selected: Bool) {
        chip.textColor = selected ? AppColors.purplePrimary : AppColors.textSecondary
        chip.backgroundColor = selected ? AppColors.purpleLight : AppColors.surface
        chip.layer.borderColor = (selected ? AppColors.purplePrimary : AppColors.border).cgColor
    }

    @objc private func toggleDay(_ gesture: UITapGestureRecognizer) {
        guard let chip = gesture.view as? PaddingLabel, let day = chip.text else { return }
        if let idx = selectedDays.firstIndex(of: day) {
            selectedDays.remove(at: idx)
            styleDayChip(chip, selected: false)
        } else {
            selectedDays.append(day)
            styleDayChip(chip, selected: true)
        }
    }

    @objc private func pickCategories() {
        guard !primaryCategories.isEmpty else { return }
        let options = primaryCategories.map { $0.title ?? "" }
        let preselected = Set(primaryCategories.enumerated()
            .filter { selectedCategoryIds.contains($0.element.id) }.map { $0.offset })
        let picker = MultiSelectViewController(title: "Product Categories", options: options, selected: preselected) { [weak self] indices in
            guard let self = self else { return }
            self.selectedCategoryIds = indices.sorted().map { self.primaryCategories[$0].id }
            self.renderCategoryChips()
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }

    private func renderCategoryChips() {
        categoryChips.arrangedSubviews.forEach { $0.removeFromSuperview() }
        categoryHint.isHidden = !selectedCategoryIds.isEmpty
        categoryChipsScroll.isHidden = selectedCategoryIds.isEmpty
        for cat in primaryCategories where selectedCategoryIds.contains(cat.id) {
            categoryChips.addArrangedSubview(removableChip(cat.title ?? "") { [weak self] in
                self?.selectedCategoryIds.removeAll { $0 == cat.id }
                self?.renderCategoryChips()
            })
        }
    }

    // MARK: - Step 7: Wallet

    private func buildWalletStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Activate Merchant Wallet"))
        stack.addArrangedSubview(subtitle("Powered by IMB."))

        let iconTile = UIView()
        iconTile.backgroundColor = AppColors.purplePrimary
        iconTile.layer.cornerRadius = 18
        iconTile.constrainSize(84)
        let walletIcon = UIImageView(image: UIImage(systemName: "wallet.pass.fill"))
        walletIcon.tintColor = .white
        walletIcon.contentMode = .scaleAspectFit
        walletIcon.forAutoLayout()
        iconTile.addSubview(walletIcon)
        NSLayoutConstraint.activate([
            walletIcon.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            walletIcon.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor),
            walletIcon.widthAnchor.constraint(equalToConstant: 40),
            walletIcon.heightAnchor.constraint(equalToConstant: 40)
        ])
        let iconRow = UIStackView.horizontal(spacing: 0, alignment: .center)
        iconRow.distribution = .equalCentering
        iconRow.addArrangedSubview(UIView())
        iconRow.addArrangedSubview(iconTile)
        iconRow.addArrangedSubview(UIView())
        stack.addArrangedSubview(iconRow)

        stack.addArrangedSubview(UILabel.make("Benefits", font: AppFonts.bold(16), color: AppColors.purpleDark))
        for benefit in ["Faster payments", "Access to credit", "Insurance solutions", "Rewards & cashback", "Business growth tools"] {
            let check = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
            check.tintColor = AppColors.success
            check.contentMode = .scaleAspectFit
            check.constrainSize(18)
            let label = UILabel.make(benefit, font: AppFonts.regular(14), color: AppColors.textPrimary)
            let row = UIStackView.horizontal(spacing: 10, alignment: .center)
            row.addArrangedSubview(check)
            row.addArrangedSubview(label)
            stack.addArrangedSubview(row)
        }

        let panel = UIStackView.vertical(spacing: 0, alignment: .fill)
        panel.backgroundColor = AppColors.surfaceVariant
        panel.layer.cornerRadius = AppMetrics.radiusMD
        panel.layer.borderWidth = 1
        panel.layer.borderColor = AppColors.border.cgColor
        panel.addArrangedSubview(walletOptionRow(radio: walletNowRadio, title: "Create Wallet Now", now: true))
        panel.addArrangedSubview(walletOptionRow(radio: walletLaterRadio, title: "Activate Later", now: false))
        stack.addArrangedSubview(panel)
        setWallet(true)
        return stack
    }

    private func walletOptionRow(radio: UIImageView, title: String, now: Bool) -> UIView {
        radio.contentMode = .scaleAspectFit
        radio.constrainSize(20)
        let label = UILabel.make(title, font: AppFonts.regular(14), color: AppColors.textPrimary)
        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        row.addArrangedSubview(radio)
        row.addArrangedSubview(label)
        row.addArrangedSubview(UIView())
        row.isUserInteractionEnabled = true
        row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: now ? #selector(walletNow) : #selector(walletLater)))
        return row
    }

    @objc private func walletNow() { setWallet(true) }
    @objc private func walletLater() { setWallet(false) }

    private func setWallet(_ now: Bool) {
        createWalletNow = now
        walletNowRadio.image = UIImage(systemName: now ? "largecircle.fill.circle" : "circle")
        walletNowRadio.tintColor = now ? AppColors.info : AppColors.textTertiary
        walletLaterRadio.image = UIImage(systemName: now ? "circle" : "largecircle.fill.circle")
        walletLaterRadio.tintColor = now ? AppColors.textTertiary : AppColors.info
    }

    // MARK: - Step 8: Terms

    private func buildTermsStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 10, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Terms & Conditions"))
        stack.addArrangedSubview(subtitle("Please review and accept to continue."))
        let terms = ["I confirm that the information provided is accurate and correct.",
                     "I agree to the Terms of Service and Privacy Policy.",
                     "I agree to KYC verification and identity checks.",
                     "I consent to receive electronic communications from anokiX."]
        for t in terms { stack.addArrangedSubview(termRow(t)) }
        return stack
    }

    private func termRow(_ text: String) -> UIView {
        let checkbox = UIButton(type: .custom)
        let symbol = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        let empty = UIImage(systemName: "square", withConfiguration: symbol)?
            .withTintColor(AppColors.textTertiary, renderingMode: .alwaysOriginal)
        let checked = UIImage(systemName: "checkmark.square.fill", withConfiguration: symbol)?
            .withTintColor(AppColors.purplePrimary, renderingMode: .alwaysOriginal)
        checkbox.setImage(empty, for: .normal)
        checkbox.setImage(checked, for: .selected)
        checkbox.imageView?.contentMode = .scaleAspectFit
        checkbox.setContentHuggingPriority(.required, for: .horizontal)
        checkbox.setContentCompressionResistancePriority(.required, for: .horizontal)
        checkbox.constrainSize(24)
        checkbox.addAction(UIAction { _ in checkbox.isSelected.toggle() }, for: .touchUpInside)
        termCheckboxes.append(checkbox)
        let label = UILabel.make(text, font: AppFonts.regular(13), color: AppColors.textPrimary, lines: 0)
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleTerm(_:))))
        label.tag = termCheckboxes.count - 1
        let row = UIStackView.horizontal(spacing: 10, alignment: .top)
        row.addArrangedSubview(checkbox)
        row.addArrangedSubview(label)
        return row
    }

    @objc private func toggleTerm(_ gesture: UITapGestureRecognizer) {
        guard let idx = gesture.view?.tag, termCheckboxes.indices.contains(idx) else { return }
        termCheckboxes[idx].isSelected.toggle()
    }

    // MARK: - Reference data

    private func loadReference() {
        ApiClient.shared.getReference { [weak self] result in
            guard let self = self, case .success(let data) = result else { return }
            self.primaryCategories = (data.productCategories ?? []).filter { $0.parentId == nil }
        }
    }

    // MARK: - Submit

    private func submit() {
        var form: [String: String] = [:]
        form["company_legal_name"] = text(companyLegalNameField)
        form["trading_name"] = text(tradingNameField)
        form["company_registration_number"] = text(companyRegField)
        form["vat_number"] = text(vatField)
        form["company_email"] = text(companyEmailField)
        form["company_phone_number"] = fullPhone(companyCountry, companyPhoneField)

        form["first_name"] = text(firstNameField)
        form["last_name"] = text(lastNameField)
        form["mobile_number"] = fullPhone(mobileCountry, mobileField)
        form["email"] = text(emailField)
        form["password"] = text(passwordField)

        for (k, v) in dropdownValues { form[k] = v }
        form["account_holder_name"] = text(accountHolderField)
        form["account_number"] = text(accountNumberField)
        form["branch_code"] = text(branchCodeField)

        form["contact_persons"] = buildContactsJson()

        form["address"] = text(addressField)
        if let coord = pickedCoordinate {
            form["latitude"] = String(coord.latitude)
            form["longitude"] = String(coord.longitude)
        }

        if let coverage = selectedCoverage { form["distribution_coverage"] = coverage.lowercased() } // local/regional/national
        form["service_product_categories"] = selectedCategoryIds.map(String.init).joined(separator: ",")
        form["preferred_delivery_days"] = buildDeliveryDays()
        form["payment_method"] = createWalletNow ? "wallet" : "later"

        var files: [Http.FilePart] = docFiles.compactMap { key, value in
            // The cropped logo from step 1 takes precedence over a doc-row logo upload.
            if key == "company_logo" && logoData != nil { return nil }
            return Http.FilePart(field: key, fileName: value.name, mimeType: value.mime, data: value.data)
        }
        if let logo = logoData {
            files.append(Http.FilePart(field: "company_logo", fileName: "company_logo.jpg",
                                       mimeType: "image/jpeg", data: logo))
        }

        continueButton.isEnabled = false
        continueButton.setTitle(S.registering, for: .normal)
        ApiClient.shared.registerDistributor(form: form, files: files) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                let submitted = RegisterSubmittedViewController()
                self.navigationController?.pushViewController(submitted, animated: true)
            case .failure(let error):
                self.continueButton.isEnabled = true
                self.continueButton.setTitle(S.registerButton, for: .normal)
                self.toast(error.message)
            }
        }
    }

    private func buildContactsJson() -> String {
        var contacts: [[String: String]] = []
        contacts.append([
            "full_name": text(primaryNameField),
            "position": text(primaryPositionField),
            "mobile_number": fullPhone(primaryCountry, primaryMobileField),
            "email": text(primaryEmailField)
        ])
        for row in contactRows {
            let name = text(row.nameField)
            if name.isEmpty { continue }
            contacts.append([
                "full_name": name,
                "position": text(row.positionField),
                "mobile_number": fullPhone(row.country, row.mobileField),
                "email": text(row.emailField)
            ])
        }
        guard let data = try? JSONSerialization.data(withJSONObject: contacts),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }

    /// Web payload format: "{dayNum}:{open}.00-{close}.00" entries joined by "/",
    /// where dayNum is the ISO weekday (Mon=1 … Sun=7). Example for Mon–Fri 8–18:
    /// "1:8.00-18.00/2:8.00-18.00/3:8.00-18.00/4:8.00-18.00/5:8.00-18.00".
    /// iOS has no per-day hour editor (chips are on/off only), so the default
    /// 8.00–18.00 business window is sent for every selected day.
    private func buildDeliveryDays() -> String {
        var parts: [String] = []
        for num in 1...7 {
            let idx = (num == 7) ? 0 : num // dayLabels is Sun-first (0=Sun … 6=Sat)
            guard selectedDays.contains(dayLabels[idx]) else { continue }
            parts.append("\(num):8.00-18.00")
        }
        return parts.joined(separator: "/")
    }

    // MARK: - Address autocomplete

    @objc private func addressChanged() {
        guard !suppressAddressChange else { return }
        let keyword = text(addressField)
        autocompleteWorkItem?.cancel()
        guard keyword.count >= 3 else { hideAddressResults(); return }
        let work = DispatchWorkItem { [weak self] in self?.queryAutocomplete(keyword) }
        autocompleteWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func queryAutocomplete(_ keyword: String) {
        ApiClient.shared.getAddressAutocomplete(keyword: keyword) { [weak self] result in
            guard let self = self, case .success(let data) = result else { return }
            self.predictions = data.predictions ?? []
            if self.predictions.isEmpty { self.hideAddressResults() }
            else {
                self.addressResultsTable.isHidden = false
                self.addressResultsHeight.constant = CGFloat(min(self.predictions.count, 5)) * 44
                self.addressResultsTable.reloadData()
            }
        }
    }

    private func hideAddressResults() {
        predictions = []
        addressResultsTable.isHidden = true
        addressResultsHeight.constant = 0
    }

    // MARK: - Google Maps

    private func makeMapView() -> GMSMapView {
        let sa = CLLocationCoordinate2D(latitude: -29.8587, longitude: 31.0218)
        let camera = GMSCameraPosition.camera(withTarget: sa, zoom: 9)
        let map = GMSMapView(frame: .zero, camera: camera)
        map.delegate = self
        map.layer.cornerRadius = AppMetrics.radiusMD
        map.clipsToBounds = true
        map.settings.zoomGestures = true
        map.settings.scrollGestures = true
        map.settings.compassButton = false
        return map
    }

    private func wireMapScrollBehavior() {
        mapView.isExclusiveTouch = true
        for recognizer in mapView.gestureRecognizers ?? [] {
            recognizer.cancelsTouchesInView = false
            recognizer.addTarget(self, action: #selector(mapGestureChanged(_:)))
        }
    }

    @objc private func mapGestureChanged(_ recognizer: UIGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed: formScroll.isScrollEnabled = false
        default: formScroll.isScrollEnabled = true
        }
    }

    func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
        placePin(at: coordinate, zoom: false)
        reverseGeocode(coordinate)
    }

    func mapView(_ mapView: GMSMapView, didEndDragging marker: GMSMarker) {
        pickedCoordinate = marker.position
        reverseGeocode(marker.position)
    }

    private func placePin(at coord: CLLocationCoordinate2D, zoom: Bool) {
        pickedCoordinate = coord
        if marker == nil {
            let pin = GMSMarker(position: coord)
            pin.isDraggable = true
            pin.map = mapView
            marker = pin
        } else {
            marker?.position = coord
        }
        if zoom { mapView.animate(to: GMSCameraPosition.camera(withTarget: coord, zoom: 15)) }
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) {
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: coord.latitude, longitude: coord.longitude)) { [weak self] placemarks, _ in
            guard let self = self, let p = placemarks?.first else { return }
            let line = [p.name, p.locality, p.country].compactMap { $0 }.joined(separator: ", ")
            if !line.isEmpty { self.setAddressText(line) }
        }
    }

    private func setAddressText(_ value: String) {
        suppressAddressChange = true
        addressField.text = value
        suppressAddressChange = false
    }

    // MARK: - Address results table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { predictions.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "pred", for: indexPath)
        cell.textLabel?.text = predictions[indexPath.row].description
        cell.textLabel?.font = AppFonts.regular(13)
        cell.textLabel?.numberOfLines = 2
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let prediction = predictions[indexPath.row]
        if let desc = prediction.description { setAddressText(desc) }
        hideAddressResults()
        view.endEditing(true)
        guard let placeId = prediction.placeId else { return }
        ApiClient.shared.getCoordinateFromPlaceId(placeId) { [weak self] result in
            guard let self = self, case .success(let data) = result,
                  let lat = data.latitude, let lng = data.longitude else { return }
            if let formatted = data.formattedAddress, !formatted.isEmpty { self.setAddressText(formatted) }
            self.placePin(at: CLLocationCoordinate2D(latitude: lat, longitude: lng), zoom: true)
        }
    }

    // MARK: - Image / file picking

    private func presentSourceSheet(allowFiles: Bool, from sourceView: UIView) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in
            self?.presentPhotoLibrary()
        })
        if allowFiles {
            sheet.addAction(UIAlertAction(title: "Choose File", style: .default) { [weak self] _ in
                self?.presentFilePicker()
            })
        }
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel) { [weak self] _ in
            self?.pendingDocKey = nil
        })
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = sourceView
            pop.sourceRect = sourceView.bounds
        }
        present(sheet, animated: true)
    }

    private func presentPhotoLibrary() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentFilePicker() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image, .pdf])
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let key = pendingDocKey, let result = results.first else { pendingDocKey = nil; return }
        let provider = result.itemProvider
        guard provider.canLoadObject(ofClass: UIImage.self) else { pendingDocKey = nil; return }
        let suggested = provider.suggestedName ?? "photo"
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self = self, let image = object as? UIImage else {
                DispatchQueue.main.async { self?.pendingDocKey = nil }
                return
            }
            DispatchQueue.main.async {
                if key == Self.logoKey {
                    self.applyLogo(image)
                } else if let data = Self.downscaledJpeg(image, maxDimension: 1440, quality: 0.6) {
                    self.applyPickedFile(key: key, data: data, name: suggested + ".jpg", mime: "image/jpeg")
                }
                self.pendingDocKey = nil
            }
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let key = pendingDocKey else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard var data = try? Data(contentsOf: url) else { toast("Could not read file"); return }
        var name = url.lastPathComponent
        var mime = mimeType(for: url)

        if mime.hasPrefix("image/"), let image = UIImage(data: data),
           let jpeg = Self.downscaledJpeg(image, maxDimension: 1440, quality: 0.6) {
            data = jpeg
            name = url.deletingPathExtension().lastPathComponent + ".jpg"
            mime = "image/jpeg"
        }
        guard data.count <= Self.maxUploadBytes else {
            toast("File is too large. Please choose a file under 5 MB.")
            return
        }
        applyPickedFile(key: key, data: data, name: name, mime: mime)
        pendingDocKey = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        pendingDocKey = nil
    }

    private func applyLogo(_ image: UIImage) {
        let crop = LogoCropViewController(image: downscaledForCrop(image))
        crop.onConfirm = { [weak self] cropped in
            self?.applyCroppedLogo(cropped)
        }
        crop.onUploadNew = { [weak self] in
            self?.pickLogo()
        }
        present(crop, animated: true)
    }

    private func downscaledForCrop(_ image: UIImage) -> UIImage {
        let maxDim: CGFloat = 1500
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDim else { return image }
        let scale = maxDim / longest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private func applyCroppedLogo(_ image: UIImage) {
        guard let data = Self.downscaledJpeg(image, maxDimension: 600, quality: 0.85) else { return }
        logoData = data
        logoPreview.image = UIImage(data: data)
        logoPreview.isHidden = false
        logoPlaceholder.isHidden = true
    }

    private func applyPickedFile(key: String, data: Data, name: String, mime: String) {
        docFiles[key] = (data, name, mime)
        docSubtitleLabels[key]?.text = name
        docSubtitleLabels[key]?.textColor = AppColors.success
        docSubtitleLabels[key]?.isHidden = false
        docButtons[key]?.setTitle("Change", for: .normal)
    }

    private func mimeType(for url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension), let mime = type.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }

    private static func downscaledJpeg(_ image: UIImage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    // MARK: - Country pickers

    private enum PhoneKind { case company, mobile, primary, contact(ContactRow) }

    private func phoneGroup(_ label: String, button: UIButton, country: Country,
                            field: UITextField, kind: PhoneKind) -> UIStackView {
        let title = UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textPrimary)
        configureCountryButton(button, country: country)
        button.addAction(UIAction { [weak self] _ in self?.pickCountry(kind, button: button) }, for: .touchUpInside)

        field.placeholder = "Phone number"
        field.keyboardType = .phonePad
        field.font = AppFonts.regular(14)
        field.textColor = AppColors.textPrimary

        let container = UIView()
        container.backgroundColor = AppColors.surface
        container.layer.cornerRadius = AppMetrics.radiusMD
        container.layer.borderWidth = 1
        container.layer.borderColor = AppColors.border.cgColor
        container.constrainHeight(48)
        let divider = UIView()
        divider.backgroundColor = AppColors.border
        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.forAutoLayout()
        button.setContentHuggingPriority(.required, for: .horizontal)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(button)
        row.addArrangedSubview(divider)
        row.addArrangedSubview(field)
        container.addSubview(row)
        row.pinEdges(to: container, insets: UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 12))
        field.heightAnchor.constraint(equalToConstant: 44).isActive = true
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true
        divider.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let stack = UIStackView.vertical(spacing: 5, alignment: .fill)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(container)
        return stack
    }

    private func configureCountryButton(_ button: UIButton, country: Country) {
        var config = UIButton.Configuration.plain()
        config.title = "\(country.flag) \(country.dialCode)"
        config.image = UIImage(systemName: "chevron.down")
        config.imagePlacement = .trailing
        config.imagePadding = 4
        config.baseForegroundColor = AppColors.textPrimary
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 10, weight: .regular)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.regular(14); return out
        }
        button.configuration = config
    }

    private func pickCountry(_ kind: PhoneKind, button: UIButton) {
        let picker = CountryPickerViewController()
        picker.onSelect = { [weak self] country in
            guard let self = self else { return }
            switch kind {
            case .company: self.companyCountry = country
            case .mobile: self.mobileCountry = country
            case .primary: self.primaryCountry = country
            case .contact(let row): row.country = country
            }
            self.configureCountryButton(button, country: country)
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }

    private func fullPhone(_ country: Country, _ field: UITextField) -> String {
        var number = text(field).filter { $0.isNumber }
        if number.isEmpty { return "" }
        if number.hasPrefix("0") { number.removeFirst() }
        return country.dialCode + number
    }

    // MARK: - View builders

    private func sectionTitle(_ text: String) -> UILabel {
        UILabel.make(text, font: AppFonts.bold(18), color: AppColors.purpleDark, lines: 0)
    }

    private func subtitle(_ text: String) -> UILabel {
        UILabel.make(text, font: AppFonts.regular(13), color: AppColors.textSecondary, lines: 0)
    }

    private func fieldGroup(_ label: String, _ field: UITextField, placeholder: String,
                            keyboard: UIKeyboardType = .default) -> UIStackView {
        StyleKit.styleInput(field)
        field.placeholder = placeholder
        field.keyboardType = keyboard
        if keyboard == .emailAddress { field.autocapitalizationType = .none }
        let title = UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textPrimary)
        let stack = UIStackView.vertical(spacing: 5, alignment: .fill)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(field)
        return stack
    }

    private func secureFieldGroup(_ label: String, _ field: UITextField, placeholder: String) -> UIStackView {
        let group = fieldGroup(label, field, placeholder: placeholder)
        field.isSecureTextEntry = true
        field.autocapitalizationType = .none
        field.textContentType = .oneTimeCode  // avoid the iOS strong-password overlay
        let eye = UIButton(type: .system)
        eye.setImage(UIImage(systemName: "eye"), for: .normal)
        eye.tintColor = AppColors.textSecondary
        eye.frame = CGRect(x: 0, y: 0, width: 38, height: 24)
        eye.addAction(UIAction { _ in
            field.isSecureTextEntry.toggle()
            eye.setImage(UIImage(systemName: field.isSecureTextEntry ? "eye" : "eye.slash"), for: .normal)
        }, for: .touchUpInside)
        field.rightView = eye
        field.rightViewMode = .always
        return group
    }

    /// `codes` are the API values submitted for each option; when nil the option
    /// label is sent verbatim (used by the numeric year dropdown).
    private func dropdownGroup(_ label: String, key: String, title: String,
                              options: [String], codes: [String]? = nil) -> UIStackView {
        let titleLabel = UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textPrimary)
        let button = UIButton(type: .system)
        configurePickerButton(button, placeholder: "Select")
        button.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            let picker = RegisterOptionPickerViewController(title: title, options: options) { [weak self] index in
                guard let self = self else { return }
                self.dropdownValues[key] = (codes ?? options)[index] // submit the API code
                self.setPickerTitle(button, options[index])          // show the display label
            }
            self.present(UINavigationController(rootViewController: picker), animated: true)
        }, for: .touchUpInside)
        dropdownButtons[key] = button
        let stack = UIStackView.vertical(spacing: 5, alignment: .fill)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(button)
        return stack
    }

    private func tappableField() -> UIView {
        let field = UIView()
        field.backgroundColor = AppColors.surface
        field.layer.cornerRadius = AppMetrics.radiusMD
        field.layer.borderWidth = 1
        field.layer.borderColor = AppColors.border.cgColor
        field.isUserInteractionEnabled = true
        return field
    }

    private func removableChip(_ title: String, onRemove: @escaping () -> Void) -> UIView {
        let chip = UIView()
        chip.backgroundColor = AppColors.purpleLight
        chip.layer.cornerRadius = AppMetrics.radiusSM
        let label = UILabel.make(title, font: AppFonts.medium(11), color: AppColors.purplePrimary)
        let remove = UIButton(type: .system)
        remove.setImage(UIImage(systemName: "xmark"), for: .normal)
        remove.tintColor = AppColors.purplePrimary
        remove.constrainSize(14)
        remove.addAction(UIAction { _ in onRemove() }, for: .touchUpInside)
        let row = UIStackView.horizontal(spacing: 6, alignment: .center)
        row.forAutoLayout()
        row.addArrangedSubview(label)
        row.addArrangedSubview(remove)
        chip.addSubview(row)
        row.pinEdges(to: chip, insets: UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 8))
        return chip
    }

    private func configurePickerButton(_ button: UIButton, placeholder: String) {
        var config = UIButton.Configuration.bordered()
        config.baseForegroundColor = AppColors.textSecondary
        config.background.strokeColor = AppColors.border
        config.background.backgroundColor = AppColors.surface
        config.cornerStyle = .medium
        config.title = placeholder
        config.image = UIImage(systemName: "chevron.down")
        config.imagePlacement = .trailing
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.regular(AppMetrics.textBody); return out
        }
        button.configuration = config
        button.contentHorizontalAlignment = .leading
        button.constrainHeight(48)
    }

    private func setPickerTitle(_ button: UIButton, _ title: String) {
        guard var config = button.configuration else { return }
        config.title = title
        config.baseForegroundColor = AppColors.textPrimary
        button.configuration = config
    }

    private func text(_ field: UITextField) -> String {
        field.text?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    private func isValidEmail(_ email: String) -> Bool {
        guard !email.isEmpty else { return false }
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}

/// Lightweight single-select list picker (handles long lists like the year dropdown
/// where an action sheet would be unusable).
final class RegisterOptionPickerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let options: [String]
    private let onPick: (Int) -> Void
    private let tableView = UITableView(frame: .zero, style: .plain)

    init(title: String, options: [String], onPick: @escaping (Int) -> Void) {
        self.options = options
        self.onPick = onPick
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.surface
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                           target: self, action: #selector(close))
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "opt")
        tableView.forAutoLayout()
        view.addSubview(tableView)
        tableView.pinEdges(to: view)
    }

    @objc private func close() { dismiss(animated: true) }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { options.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "opt", for: indexPath)
        cell.textLabel?.text = options[indexPath.row]
        cell.textLabel?.font = AppFonts.regular(15)
        cell.textLabel?.textColor = AppColors.textPrimary
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        dismiss(animated: true) { [weak self] in self?.onPick(indexPath.row) }
    }
}
