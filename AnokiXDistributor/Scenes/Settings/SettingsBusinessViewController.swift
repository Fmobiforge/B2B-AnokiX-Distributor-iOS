import UIKit
import GoogleMaps
import CoreLocation
import UniformTypeIdentifiers

/// Settings → Business: a 7-step editor (Company · Business · Contacts · Location · Documents ·
/// Service · Wallet) pre-filled from GET api/distributor/business/profile. Each step has its own
/// Save Changes button that posts just that step's fields to api/distributor/business/profile/update
/// (multipart). Wallet is read-only and comes from GET api/common/wallet. Port of the Android
/// SettingsBusinessActivity.
final class SettingsBusinessViewController: BaseSecondaryViewController,
    GMSMapViewDelegate, UITableViewDataSource, UITableViewDelegate, UIDocumentPickerDelegate {

    override var screenTitle: String { S.settingsBusinessTitle }

    private let stepNames = ["Company", "Business", "Contacts", "Location", "Documents", "Service", "Wallet"]

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
    private let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private let docKeys = ["company_registration_certificate", "tax_clearance_certificate",
                           "vat_registration_certificate", "proof_of_address", "bank_confirmation_letter"]
    private let docTitles = ["Company Registration Certificate (CIPC)", "Tax Clearance Certificate",
                             "VAT Registration Certificate", "Proof of Address", "Bank Confirmation Letter"]
    private let docRequired = [true, false, false, true, true]

    // Step chrome
    private let stepperRow = UIStackView.horizontal(spacing: 8, alignment: .center)
    private var stepChips: [UIButton] = []
    private let stepsStack = UIStackView.vertical(spacing: 0, alignment: .fill)
    private var stepCards: [UIView] = []
    private var currentStep = 0
    private let contentScroll = UIScrollView()
    private let spinner = UIActivityIndicatorView(style: .medium)

    // Company
    private let companyLegalField = UITextField()
    private let tradingField = UITextField()
    private let regField = UITextField()
    private let vatField = UITextField()
    private let companyEmailField = UITextField()
    private let companyPhoneField = UITextField()
    private var companyCountry = Countries.default
    private let companyCountryButton = UIButton(type: .system)
    private let logoPreview = UIImageView()
    private var logoData: Data?
    private var logoName = "company_logo.jpg"
    private var logoMime = "image/jpeg"

    // Business
    private var dropdownValues: [String: String] = [:]
    private var dropdownButtons: [String: UIButton] = [:]
    private let accountHolderField = UITextField()
    private let accountNumberField = UITextField()
    private let branchField = UITextField()

    // Contacts
    private let primaryNameField = UITextField()
    private let primaryPositionField = UITextField()
    private let primaryPhoneField = UITextField()
    private let primaryEmailField = UITextField()
    private var primaryCountry = Countries.default
    private let primaryCountryButton = UIButton(type: .system)
    private let additionalContactsStack = UIStackView.vertical(spacing: 12, alignment: .fill)
    private final class ContactRowViews {
        let container = UIStackView.vertical(spacing: 8, alignment: .fill)
        let header = UILabel()
        let name = UITextField(); let position = UITextField()
        let phone = UITextField(); let email = UITextField()
        var country = Countries.default
        let countryButton = UIButton(type: .system)
    }

    private enum PhoneKind { case company, primary, contact(ContactRowViews) }
    private var contactRows: [ContactRowViews] = []

    // Location
    private let addressField = UITextField()
    private let addressResultsTable = UITableView(frame: .zero, style: .plain)
    private var addressResultsHeight: NSLayoutConstraint!
    private lazy var mapView = makeMapView()
    private var marker: GMSMarker?
    private var pickedCoordinate: CLLocationCoordinate2D?
    private var predictions: [AutocompleteData.Prediction] = []
    private var autocompleteWorkItem: DispatchWorkItem?
    private var suppressAddressChange = false

    // Documents
    private var docSubtitles: [String: UILabel] = [:]
    private var docData: [String: (data: Data, name: String, mime: String)] = [:]
    private var pendingDocKey: String?

    // Service
    private var coverageCards: [(view: UIView, value: String, icon: UIImageView, title: UILabel)] = []
    private var selectedCoverage: String?
    private let categoryHint = UILabel.make("Select categories…", font: AppFonts.regular(13), color: AppColors.textSecondary)
    private let categoryChips = UIStackView.vertical(spacing: 6, alignment: .leading)
    private var primaryCategories: [ReferenceData.ProductCategory] = []
    private var selectedCategoryIds: [Int64] = []
    private let activeClientsField = UITextField()
    private let fleetField = UITextField()
    private final class DayRow {
        let checkbox = UIButton(type: .custom)
        let open1 = UITextField(); let close1 = UITextField()
        let open2 = UITextField(); let close2 = UITextField()
    }
    private var dayRows: [DayRow] = []

    // Wallet (read-only, from api/common/wallet)
    private var wallet: WalletData?
    private let walletStatusPill = UILabel()
    private let walletStatusIcon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
    private var walletPillBox: UIStackView?
    private let walletRefreshIcon = UIImageView(image: UIImage(systemName: "arrow.clockwise"))
    private let walletAccountLabel = UILabel()
    private let walletActivatedLabel = UILabel()
    private let walletAvailableLabel = UILabel()
    private let walletCurrentLabel = UILabel()
    private let walletPendingLabel = UILabel()
    private let walletTransactionsStack = UIStackView.vertical(spacing: 0, alignment: .fill)
    private let walletEmptyLabel = UILabel()

    // MARK: - Setup

    override func setupContent(in container: UIView) {
        // Stepper (fixed at top).
        let stepperScroll = UIScrollView()
        stepperScroll.showsHorizontalScrollIndicator = false
        stepperScroll.backgroundColor = AppColors.surface
        stepperScroll.forAutoLayout()
        stepperRow.forAutoLayout()
        stepperScroll.addSubview(stepperRow)
        for (i, name) in stepNames.enumerated() {
            let chip = UIButton(type: .system)
            chip.setTitle("\(i + 1). \(name)", for: .normal)
            chip.titleLabel?.font = AppFonts.bold(13)
            chip.layer.cornerRadius = 16
            chip.layer.borderWidth = 1
            chip.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            chip.tag = i
            chip.addTarget(self, action: #selector(stepChipTapped(_:)), for: .touchUpInside)
            stepChips.append(chip)
            stepperRow.addArrangedSubview(chip)
        }

        let divider = ListScreenLayout.hairline()
        divider.forAutoLayout()

        contentScroll.alwaysBounceVertical = true
        contentScroll.showsVerticalScrollIndicator = false
        contentScroll.backgroundColor = AppColors.background
        contentScroll.forAutoLayout()
        stepsStack.forAutoLayout()
        contentScroll.addSubview(stepsStack)

        container.addSubview(stepperScroll)
        container.addSubview(divider)
        container.addSubview(contentScroll)
        spinner.hidesWhenStopped = true
        spinner.forAutoLayout()
        container.addSubview(spinner)

        NSLayoutConstraint.activate([
            stepperScroll.topAnchor.constraint(equalTo: container.topAnchor),
            stepperScroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stepperScroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stepperScroll.heightAnchor.constraint(equalToConstant: 52),

            stepperRow.topAnchor.constraint(equalTo: stepperScroll.contentLayoutGuide.topAnchor),
            stepperRow.bottomAnchor.constraint(equalTo: stepperScroll.contentLayoutGuide.bottomAnchor),
            stepperRow.leadingAnchor.constraint(equalTo: stepperScroll.contentLayoutGuide.leadingAnchor, constant: 16),
            stepperRow.trailingAnchor.constraint(equalTo: stepperScroll.contentLayoutGuide.trailingAnchor, constant: -16),
            stepperRow.heightAnchor.constraint(equalTo: stepperScroll.frameLayoutGuide.heightAnchor),

            divider.topAnchor.constraint(equalTo: stepperScroll.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            contentScroll.topAnchor.constraint(equalTo: divider.bottomAnchor),
            contentScroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            contentScroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            contentScroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stepsStack.topAnchor.constraint(equalTo: contentScroll.contentLayoutGuide.topAnchor, constant: 16),
            stepsStack.bottomAnchor.constraint(equalTo: contentScroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stepsStack.leadingAnchor.constraint(equalTo: contentScroll.frameLayoutGuide.leadingAnchor, constant: 16),
            stepsStack.trailingAnchor.constraint(equalTo: contentScroll.frameLayoutGuide.trailingAnchor, constant: -16),

            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: container.topAnchor, constant: 120)
        ])

        stepCards = [buildCompanyStep(), buildBusinessStep(), buildContactsStep(), buildLocationStep(),
                     buildDocumentsStep(), buildServiceStep(), buildWalletStep()]
        for card in stepCards { stepsStack.addArrangedSubview(card) }
        showStep(0)
    }

    override func loadData() {
        ApiClient.shared.getReference { [weak self] result in
            guard let self = self, case .success(let data) = result else { return }
            self.primaryCategories = (data.productCategories ?? []).filter { $0.parentId == nil }
            self.renderCategoryChips()
        }
        spinner.startAnimating()
        ApiClient.shared.getBusinessProfile { [weak self] result in
            guard let self = self else { return }
            self.spinner.stopAnimating()
            if case .success(let data) = result, let p = data.profile {
                self.bind(p)
            } else if case .failure(let error) = result {
                self.toast(error.message.isEmpty ? "Failed to load business profile." : error.message)
            }
        }
        loadWallet()
    }

    // MARK: - Stepper

    @objc private func stepChipTapped(_ sender: UIButton) { showStep(sender.tag) }

    private func showStep(_ index: Int) {
        currentStep = index
        for (i, card) in stepCards.enumerated() { card.isHidden = i != index }
        for (i, chip) in stepChips.enumerated() {
            let active = i == index
            // Portal chip: selected = brand-blue fill + white; unselected = white + hairline.
            chip.backgroundColor = active ? AppColors.purplePrimary : AppColors.surface
            chip.layer.borderColor = (active ? AppColors.purplePrimary : AppColors.border).cgColor
            chip.setTitleColor(active ? .white : AppColors.textSecondary, for: .normal)
        }
        contentScroll.setContentOffset(.zero, animated: false)
    }

    // MARK: - Field helpers

    private func makeField(_ field: UITextField, placeholder: String = "",
                           keyboard: UIKeyboardType = .default) -> UITextField {
        StyleKit.styleInput(field)
        field.placeholder = placeholder
        field.keyboardType = keyboard
        if keyboard == .emailAddress { field.autocapitalizationType = .none }
        return field
    }

    private func labeled(_ label: String, _ field: UIView) -> UIStackView {
        let stack = UIStackView.vertical(spacing: 5, alignment: .fill)
        stack.addArrangedSubview(UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textPrimary))
        stack.addArrangedSubview(field)
        return stack
    }

    private func card(_ inner: UIView) -> UIView {
        let card = StyleKit.cardView()
        inner.forAutoLayout()
        card.addSubview(inner)
        inner.pinEdges(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        return card
    }

    private func stepTitle(_ title: String, _ sub: String) -> UIStackView {
        let stack = UIStackView.vertical(spacing: 4, alignment: .fill)
        stack.addArrangedSubview(UILabel.make(title, font: AppFonts.semibold(20), color: AppColors.topTitle))
        stack.addArrangedSubview(UILabel.make(sub, font: AppFonts.regular(13), color: AppColors.textSecondary, lines: 0))
        return stack
    }

    private func stepFooter(_ onSave: @escaping () -> Void) -> UIView {
        let reset = UIButton(type: .system)
        var rc = UIButton.Configuration.plain()
        rc.title = "Reset"
        rc.baseForegroundColor = AppColors.textPrimary
        rc.background.strokeColor = AppColors.border
        rc.background.strokeWidth = 1
        rc.background.cornerRadius = AppMetrics.radiusMD
        rc.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { var o = $0; o.font = AppFonts.bold(14); return o }
        reset.configuration = rc
        reset.addAction(UIAction { [weak self] _ in self?.loadData() }, for: .touchUpInside)

        let save = UIButton(type: .system)
        StyleKit.stylePrimaryButton(save, fontSize: 14)
        save.setTitle(S.saveChanges, for: .normal)
        save.addAction(UIAction { _ in onSave() }, for: .touchUpInside)

        let row = UIStackView.horizontal(spacing: 12, alignment: .fill)
        row.distribution = .fillEqually
        row.addArrangedSubview(reset)
        row.addArrangedSubview(save)
        reset.heightAnchor.constraint(equalToConstant: 46).isActive = true
        save.heightAnchor.constraint(equalToConstant: 46).isActive = true
        return row
    }

    // MARK: - Dropdowns

    private func dropdown(_ label: String, key: String, options: [String], codes: [String]) -> UIStackView {
        let button = UIButton(type: .system)
        button.contentHorizontalAlignment = .leading
        button.setTitle("Select…", for: .normal)
        button.setTitleColor(AppColors.textSecondary, for: .normal)
        button.titleLabel?.font = AppFonts.regular(13)
        button.backgroundColor = AppColors.surface
        button.layer.cornerRadius = AppMetrics.radiusMD
        button.layer.borderWidth = 1
        button.layer.borderColor = AppColors.border.cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        button.heightAnchor.constraint(equalToConstant: 45).isActive = true
        button.addAction(UIAction { [weak self] _ in
            self?.presentOptions(label, options: options) { i in
                self?.dropdownValues[key] = codes[i]
                button.setTitle(options[i], for: .normal)
                button.setTitleColor(AppColors.textPrimary, for: .normal)
            }
        }, for: .touchUpInside)
        dropdownButtons[key] = button
        return labeled(label, button)
    }

    private func setDropdown(_ key: String, code: String?, options: [String], codes: [String]) {
        guard let code = code, let i = codes.firstIndex(where: { $0.caseInsensitiveCompare(code) == .orderedSame }) else { return }
        dropdownValues[key] = codes[i]
        dropdownButtons[key]?.setTitle(options[i], for: .normal)
        dropdownButtons[key]?.setTitleColor(AppColors.textPrimary, for: .normal)
    }

    private func presentOptions(_ title: String, options: [String], onPick: @escaping (Int) -> Void) {
        let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for (i, o) in options.enumerated() {
            sheet.addAction(UIAlertAction(title: o, style: .default) { _ in onPick(i) })
        }
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(sheet, animated: true)
    }

    // MARK: - Step 1: Company

    private func buildCompanyStep() -> UIView {
        logoPreview.contentMode = .scaleAspectFill
        logoPreview.clipsToBounds = true
        logoPreview.backgroundColor = AppColors.purpleLight
        logoPreview.layer.cornerRadius = AppMetrics.radiusMD
        logoPreview.image = UIImage(systemName: "photo")
        logoPreview.tintColor = AppColors.purplePrimary
        logoPreview.constrainSize(64)
        logoPreview.isUserInteractionEnabled = true
        logoPreview.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(pickLogo)))

        let logoText = UIStackView.vertical(spacing: 2, alignment: .leading)
        logoText.addArrangedSubview(UILabel.make("Company Logo", font: AppFonts.bold(13), color: AppColors.textPrimary))
        logoText.addArrangedSubview(UILabel.make("JPG, PNG or WEBP, up to 2 MB.", font: AppFonts.regular(11), color: AppColors.textSecondary, lines: 0))
        let logoRow = UIStackView.horizontal(spacing: 12, alignment: .center)
        logoRow.addArrangedSubview(logoPreview)
        logoRow.addArrangedSubview(logoText)

        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(stepTitle("Company Information", "Your registered company identity and logo."))
        stack.addArrangedSubview(logoRow)
        stack.addArrangedSubview(labeled("Company Legal Name", makeField(companyLegalField)))
        stack.addArrangedSubview(labeled("Trading Name", makeField(tradingField)))
        stack.addArrangedSubview(labeled("Registration Number", makeField(regField)))
        stack.addArrangedSubview(labeled("VAT Number", makeField(vatField)))
        stack.addArrangedSubview(labeled("Company Email", makeField(companyEmailField, keyboard: .emailAddress)))
        stack.addArrangedSubview(phoneGroup("Company Phone", button: companyCountryButton, country: companyCountry, field: companyPhoneField, kind: .company))
        stack.addArrangedSubview(stepFooter { [weak self] in self?.saveCompany() })
        return card(stack)
    }

    @objc private func pickLogo() { pickFile(key: "__logo__", imageOnly: true) }

    // MARK: - Step 2: Business

    private func buildBusinessStep() -> UIView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(stepTitle("Business Details", "Company type, size and banking details."))
        stack.addArrangedSubview(dropdown("Business Type", key: "business_type", options: businessTypes, codes: businessTypeCodes))
        stack.addArrangedSubview(dropdown("Year Established", key: "business_established_year", options: years(), codes: years()))
        stack.addArrangedSubview(dropdown("Number of Employees", key: "employee_count", options: employeeRanges, codes: employeeRangeCodes))
        stack.addArrangedSubview(dropdown("Annual Turnover", key: "annual_turnover", options: turnoverRanges, codes: turnoverRangeCodes))
        stack.addArrangedSubview(dropdown("Bank", key: "bank_name", options: banks, codes: bankCodes))
        stack.addArrangedSubview(labeled("Account Holder Name", makeField(accountHolderField)))
        stack.addArrangedSubview(labeled("Account Number", makeField(accountNumberField)))
        stack.addArrangedSubview(dropdown("Account Type", key: "account_type", options: accountTypes, codes: accountTypeCodes))
        stack.addArrangedSubview(labeled("Branch Code", makeField(branchField)))
        stack.addArrangedSubview(stepFooter { [weak self] in self?.saveBusiness() })
        return card(stack)
    }

    private func years() -> [String] { (1950...2026).reversed().map { String($0) } }

    // MARK: - Step 3: Contacts

    private func buildContactsStep() -> UIView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(stepTitle("Contact Persons", "People we can reach at your business."))
        stack.addArrangedSubview(UILabel.make("Primary Contact", font: AppFonts.bold(14), color: AppColors.textPrimary))
        stack.addArrangedSubview(labeled("Full Name", makeField(primaryNameField)))
        stack.addArrangedSubview(labeled("Position", makeField(primaryPositionField)))
        stack.addArrangedSubview(phoneGroup("Phone", button: primaryCountryButton, country: primaryCountry, field: primaryPhoneField, kind: .primary))
        stack.addArrangedSubview(labeled("Email", makeField(primaryEmailField, keyboard: .emailAddress)))

        additionalContactsStack.forAutoLayout()
        stack.addArrangedSubview(additionalContactsStack)

        let add = UIButton(type: .system)
        add.setTitle("+ Add Another Contact", for: .normal)
        add.setTitleColor(AppColors.purplePrimary, for: .normal)
        add.titleLabel?.font = AppFonts.bold(14)
        add.layer.cornerRadius = AppMetrics.radiusMD
        add.layer.borderWidth = 1
        add.layer.borderColor = AppColors.border.cgColor
        add.heightAnchor.constraint(equalToConstant: 46).isActive = true
        add.addAction(UIAction { [weak self] _ in self?.addContactRow(nil) }, for: .touchUpInside)
        stack.addArrangedSubview(add)
        stack.addArrangedSubview(stepFooter { [weak self] in self?.saveContacts() })
        return card(stack)
    }

    private func addContactRow(_ prefill: BusinessProfileData.Contact?) {
        let row = ContactRowViews()
        row.container.isLayoutMarginsRelativeArrangement = true
        row.container.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        row.container.backgroundColor = AppColors.surfaceVariant
        row.container.layer.cornerRadius = AppMetrics.radiusMD

        row.header.text = "Additional Contact \(contactRows.count + 1)"
        row.header.font = AppFonts.bold(13)
        row.header.textColor = AppColors.textPrimary
        let remove = UIButton(type: .system)
        remove.setImage(UIImage(systemName: "trash"), for: .normal)
        remove.tintColor = AppColors.danger
        remove.addAction(UIAction { [weak self] _ in self?.removeContactRow(row) }, for: .touchUpInside)
        let headerRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        headerRow.addArrangedSubview(row.header)
        headerRow.addArrangedSubview(UIView())
        headerRow.addArrangedSubview(remove)

        var phoneNumber = ""
        if let p = prefill {
            let (c, n) = splitPhone(p.mobileNumber)
            row.country = c
            phoneNumber = n
        }

        row.container.addArrangedSubview(headerRow)
        row.container.addArrangedSubview(labeled("Full Name", makeField(row.name)))
        row.container.addArrangedSubview(labeled("Position", makeField(row.position)))
        row.container.addArrangedSubview(phoneGroup("Phone", button: row.countryButton, country: row.country, field: row.phone, kind: .contact(row)))
        row.container.addArrangedSubview(labeled("Email", makeField(row.email, keyboard: .emailAddress)))

        if let p = prefill {
            row.name.text = p.fullName
            row.position.text = p.position
            row.phone.text = phoneNumber
            row.email.text = p.emailAddress
        }
        additionalContactsStack.addArrangedSubview(row.container)
        contactRows.append(row)
    }

    private func removeContactRow(_ row: ContactRowViews) {
        row.container.removeFromSuperview()
        contactRows.removeAll { $0 === row }
        for (i, r) in contactRows.enumerated() { r.header.text = "Additional Contact \(i + 1)" }
    }

    // MARK: - Step 4: Location

    private func buildLocationStep() -> UIView {
        _ = makeField(addressField, placeholder: "Search for your business address…")
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

        mapView.heightAnchor.constraint(equalToConstant: 320).isActive = true
        wireMapScrollBehavior()

        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(stepTitle("Business Location", "Your primary business address."))
        stack.addArrangedSubview(labeled("Address of your business", addressField))
        stack.addArrangedSubview(addressResultsTable)
        stack.addArrangedSubview(mapView)
        stack.addArrangedSubview(stepFooter { [weak self] in self?.saveLocation() })
        return card(stack)
    }

    // MARK: - Step 5: Documents

    private func buildDocumentsStep() -> UIView {
        let stack = UIStackView.vertical(spacing: 10, alignment: .fill)
        stack.addArrangedSubview(stepTitle("Document Upload", "Verification and compliance documents."))
        for (i, key) in docKeys.enumerated() {
            stack.addArrangedSubview(documentRow(key: key, title: docTitles[i], required: docRequired[i]))
        }
        stack.addArrangedSubview(UILabel.make("Accepted formats: JPG, PNG, WEBP, PDF (max 5 MB).",
                                              font: AppFonts.regular(11), color: AppColors.textSecondary, lines: 0))
        stack.addArrangedSubview(stepFooter { [weak self] in self?.saveDocuments() })
        return card(stack)
    }

    private func documentRow(key: String, title: String, required: Bool) -> UIView {
        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        let wrapper = UIView()
        wrapper.layer.cornerRadius = AppMetrics.radiusMD
        wrapper.layer.borderWidth = 1
        wrapper.layer.borderColor = AppColors.border.cgColor

        let icon = UIImageView(image: UIImage(systemName: "doc.fill"))
        icon.tintColor = AppColors.textSecondary
        icon.contentMode = .scaleAspectFit
        icon.constrainSize(22)
        let titleLabel = UILabel.make(required ? title + " *" : title, font: AppFonts.bold(13), color: AppColors.textPrimary, lines: 0)
        let sub = UILabel.make("", font: AppFonts.regular(11), color: AppColors.success, lines: 0)
        sub.isHidden = true
        docSubtitles[key] = sub
        let textCol = UIStackView.vertical(spacing: 2, alignment: .leading)
        textCol.addArrangedSubview(titleLabel)
        textCol.addArrangedSubview(sub)

        let upload = UIButton(type: .system)
        upload.setTitle("Upload", for: .normal)
        upload.setTitleColor(AppColors.purplePrimary, for: .normal)
        upload.titleLabel?.font = AppFonts.bold(12)
        upload.layer.cornerRadius = AppMetrics.radiusSM
        upload.layer.borderWidth = 1
        upload.layer.borderColor = AppColors.border.cgColor
        upload.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        upload.setContentHuggingPriority(.required, for: .horizontal)
        upload.addAction(UIAction { [weak self] _ in self?.pickFile(key: key, imageOnly: false) }, for: .touchUpInside)

        row.addArrangedSubview(icon)
        row.addArrangedSubview(textCol)
        row.addArrangedSubview(upload)
        row.forAutoLayout()
        wrapper.addSubview(row)
        row.pinEdges(to: wrapper)
        return wrapper
    }

    // MARK: - Step 6: Service

    private func buildServiceStep() -> UIView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(stepTitle("Service & Coverage", "Coverage, categories and delivery capacity."))

        stack.addArrangedSubview(UILabel.make("Distribution Coverage", font: AppFonts.bold(14), color: AppColors.textPrimary))
        let coverageRow = UIStackView.horizontal(spacing: 8, alignment: .fill)
        coverageRow.distribution = .fillEqually
        coverageRow.addArrangedSubview(coverageCard(value: "Local", icon: "mappin.and.ellipse", desc: "City / Town"))
        coverageRow.addArrangedSubview(coverageCard(value: "Regional", icon: "map", desc: "Multiple cities"))
        coverageRow.addArrangedSubview(coverageCard(value: "National", icon: "flag.fill", desc: "Across SA"))
        stack.addArrangedSubview(coverageRow)

        stack.addArrangedSubview(UILabel.make("Service Categories", font: AppFonts.bold(14), color: AppColors.textPrimary))
        let categoryField = UIView()
        categoryField.layer.cornerRadius = AppMetrics.radiusMD
        categoryField.layer.borderWidth = 1
        categoryField.layer.borderColor = AppColors.border.cgColor
        categoryField.isUserInteractionEnabled = true
        categoryField.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(pickCategories)))
        let catStack = UIStackView.vertical(spacing: 6, alignment: .fill)
        catStack.isLayoutMarginsRelativeArrangement = true
        catStack.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        catStack.addArrangedSubview(categoryHint)
        catStack.addArrangedSubview(categoryChips)
        catStack.forAutoLayout()
        categoryField.addSubview(catStack)
        catStack.pinEdges(to: categoryField)
        stack.addArrangedSubview(categoryField)

        stack.addArrangedSubview(labeled("Active Clients", makeField(activeClientsField, keyboard: .numberPad)))
        stack.addArrangedSubview(labeled("Delivery Fleet Size (vehicles)", makeField(fleetField, keyboard: .numberPad)))

        stack.addArrangedSubview(UILabel.make("Preferred Delivery Days", font: AppFonts.bold(14), color: AppColors.textPrimary))
        stack.addArrangedSubview(buildDeliveryDaysPanel())
        stack.addArrangedSubview(stepFooter { [weak self] in self?.saveService() })
        return card(stack)
    }

    private func coverageCard(value: String, icon: String, desc: String) -> UIView {
        let cardView = UIView()
        cardView.layer.cornerRadius = AppMetrics.radiusMD
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = AppColors.border.cgColor
        cardView.isUserInteractionEnabled = true
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = AppColors.textSecondary
        iconView.contentMode = .scaleAspectFit
        iconView.constrainSize(22)
        let title = UILabel.make(value, font: AppFonts.bold(13), color: AppColors.textPrimary, align: .center)
        let sub = UILabel.make(desc, font: AppFonts.regular(10), color: AppColors.textSecondary, align: .center, lines: 2)
        let inner = UIStackView.vertical(spacing: 6, alignment: .center)
        inner.forAutoLayout()
        inner.addArrangedSubview(iconView)
        inner.addArrangedSubview(title)
        inner.addArrangedSubview(sub)
        cardView.addSubview(inner)
        inner.pinEdges(to: cardView, insets: UIEdgeInsets(top: 12, left: 4, bottom: 12, right: 4))
        cardView.tag = coverageCards.count
        cardView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(coverageTapped(_:))))
        coverageCards.append((cardView, value, iconView, title))
        return cardView
    }

    @objc private func coverageTapped(_ gesture: UITapGestureRecognizer) {
        guard let tag = gesture.view?.tag, coverageCards.indices.contains(tag) else { return }
        applyCoverage(coverageCards[tag].value)
    }

    private func applyCoverage(_ value: String) {
        selectedCoverage = value
        for entry in coverageCards {
            let selected = entry.value.caseInsensitiveCompare(value) == .orderedSame
            entry.view.backgroundColor = selected ? AppColors.purpleLight : AppColors.surface
            entry.view.layer.borderColor = (selected ? AppColors.purplePrimary : AppColors.border).cgColor
            entry.view.layer.borderWidth = selected ? 1.5 : 1
            entry.icon.tintColor = selected ? AppColors.purplePrimary : AppColors.textSecondary
            entry.title.textColor = selected ? AppColors.purplePrimary : AppColors.textPrimary
        }
    }

    @objc private func pickCategories() {
        guard !primaryCategories.isEmpty else { return }
        let options = primaryCategories.map { $0.title ?? "" }
        let preselected = Set(primaryCategories.enumerated().filter { selectedCategoryIds.contains($0.element.id) }.map { $0.offset })
        let picker = MultiSelectViewController(title: "Service Categories", options: options, selected: preselected) { [weak self] indices in
            guard let self = self else { return }
            self.selectedCategoryIds = indices.sorted().map { self.primaryCategories[$0].id }
            self.renderCategoryChips()
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }

    private func renderCategoryChips() {
        categoryChips.arrangedSubviews.forEach { $0.removeFromSuperview() }
        categoryHint.isHidden = !selectedCategoryIds.isEmpty
        categoryChips.isHidden = selectedCategoryIds.isEmpty
        for cat in primaryCategories where selectedCategoryIds.contains(cat.id) {
            let chip = StyleKit.badgeLabel()
            chip.text = cat.title ?? ""
            chip.textColor = AppColors.purplePrimary
            chip.backgroundColor = AppColors.purpleLight
            categoryChips.addArrangedSubview(chip)
        }
    }

    private func buildDeliveryDaysPanel() -> UIView {
        let panel = UIStackView.vertical(spacing: 6, alignment: .fill)
        let header = UIStackView.horizontal(spacing: 6, alignment: .center)
        header.distribution = .fillEqually
        ["Day", "Open", "Close", "Open", "Close"].forEach {
            header.addArrangedSubview(UILabel.make($0, font: AppFonts.regular(10), color: AppColors.textSecondary, align: .center))
        }
        panel.addArrangedSubview(header)
        dayRows.removeAll()
        for day in dayLabels {
            let r = DayRow()
            r.checkbox.setImage(UIImage(systemName: "square"), for: .normal)
            r.checkbox.setImage(UIImage(systemName: "checkmark.square.fill"), for: .selected)
            r.checkbox.tintColor = AppColors.purplePrimary
            r.checkbox.setTitle(" \(day)", for: .normal)
            r.checkbox.setTitleColor(AppColors.textPrimary, for: .normal)
            r.checkbox.titleLabel?.font = AppFonts.regular(12)
            r.checkbox.contentHorizontalAlignment = .leading
            r.checkbox.addAction(UIAction { _ in r.checkbox.isSelected.toggle() }, for: .touchUpInside)
            [r.open1, r.close1, r.open2, r.close2].forEach { styleTimeField($0) }
            let rowStack = UIStackView.horizontal(spacing: 6, alignment: .center)
            rowStack.distribution = .fillEqually
            rowStack.addArrangedSubview(r.checkbox)
            rowStack.addArrangedSubview(r.open1)
            rowStack.addArrangedSubview(r.close1)
            rowStack.addArrangedSubview(r.open2)
            rowStack.addArrangedSubview(r.close2)
            dayRows.append(r)
            panel.addArrangedSubview(rowStack)
        }
        return panel
    }

    private func styleTimeField(_ field: UITextField) {
        field.backgroundColor = AppColors.surface
        field.layer.cornerRadius = AppMetrics.radiusSM
        field.layer.borderWidth = 1
        field.layer.borderColor = AppColors.border.cgColor
        field.textAlignment = .center
        field.keyboardType = .numberPad
        field.font = AppFonts.regular(12)
        field.textColor = AppColors.textPrimary
        field.heightAnchor.constraint(equalToConstant: 34).isActive = true
    }

    // MARK: - Step 7: Wallet

    private func buildWalletStep() -> UIView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(stepTitle("Wallet", "Your anokiX wallet and payment options."))

        let banner = UIStackView.horizontal(spacing: 12, alignment: .center)
        banner.isLayoutMarginsRelativeArrangement = true
        banner.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        banner.backgroundColor = AppColors.purpleLight
        banner.layer.cornerRadius = AppMetrics.radiusMD
        let wIcon = UIImageView(image: UIImage(systemName: "wallet.pass.fill"))
        wIcon.tintColor = AppColors.purplePrimary
        wIcon.contentMode = .scaleAspectFit
        wIcon.constrainSize(26)
        let wText = UIStackView.vertical(spacing: 2, alignment: .leading)
        wText.addArrangedSubview(UILabel.make("anokiX Wallet", font: AppFonts.bold(14), color: AppColors.textPrimary))
        wText.addArrangedSubview(UILabel.make("Your IMB business account — balances, payments and rewards in one place.",
                                              font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 0))
        banner.addArrangedSubview(wIcon)
        banner.addArrangedSubview(wText)
        stack.addArrangedSubview(banner)

        // Status pill + Refresh.
        walletStatusPill.font = AppFonts.bold(12)
        walletStatusPill.text = "Loading…"
        walletStatusPill.textColor = AppColors.textSecondary
        walletStatusIcon.isHidden = true
        walletStatusPill.textAlignment = .center
        walletStatusPill.layer.cornerRadius = 6
        walletStatusPill.layer.masksToBounds = true
        walletStatusPill.setContentHuggingPriority(.required, for: .horizontal)
        walletStatusIcon.contentMode = .scaleAspectFit
        walletStatusIcon.tintColor = AppColors.success
        walletStatusIcon.constrainSize(13)
        let pillBox = UIStackView.horizontal(spacing: 6, alignment: .center)
        pillBox.isLayoutMarginsRelativeArrangement = true
        pillBox.layoutMargins = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        pillBox.addArrangedSubview(walletStatusIcon)
        pillBox.addArrangedSubview(walletStatusPill)
        pillBox.backgroundColor = AppColors.successBg
        pillBox.layer.cornerRadius = 6
        walletPillBox = pillBox

        let refreshControl = UIControl()
        refreshControl.addTarget(self, action: #selector(walletRefreshTapped), for: .touchUpInside)
        walletRefreshIcon.tintColor = AppColors.textSecondary
        walletRefreshIcon.contentMode = .scaleAspectFit
        walletRefreshIcon.constrainSize(16)
        let refreshRow = UIStackView.horizontal(spacing: 6, alignment: .center)
        refreshRow.isUserInteractionEnabled = false
        refreshRow.addArrangedSubview(walletRefreshIcon)
        refreshRow.addArrangedSubview(UILabel.make("Refresh", font: AppFonts.regular(13), color: AppColors.textPrimary))
        refreshRow.forAutoLayout()
        refreshControl.addSubview(refreshRow)
        refreshRow.pinEdges(to: refreshControl, insets: UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6))

        let statusRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        statusRow.addArrangedSubview(pillBox)
        statusRow.addArrangedSubview(UIView())
        statusRow.addArrangedSubview(refreshControl)
        stack.addArrangedSubview(statusRow)

        // IMB account number panel.
        walletAccountLabel.font = AppFonts.bold(19)
        walletAccountLabel.textColor = AppColors.textPrimary
        walletAccountLabel.text = "—"
        walletActivatedLabel.font = AppFonts.regular(11)
        walletActivatedLabel.textColor = AppColors.textSecondary
        walletActivatedLabel.isHidden = true

        let accountPanel = UIStackView.vertical(spacing: 4, alignment: .fill)
        accountPanel.isLayoutMarginsRelativeArrangement = true
        accountPanel.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        accountPanel.backgroundColor = AppColors.surfaceVariant
        accountPanel.layer.cornerRadius = 10
        accountPanel.layer.borderWidth = 1
        accountPanel.layer.borderColor = AppColors.border.cgColor
        accountPanel.addArrangedSubview(UILabel.make("IMB Account Number", font: AppFonts.regular(12), color: AppColors.textSecondary))
        accountPanel.addArrangedSubview(walletAccountLabel)
        accountPanel.addArrangedSubview(walletActivatedLabel)
        stack.addArrangedSubview(accountPanel)

        // Balances: Available full width, then Current / Pending side by side.
        walletAvailableLabel.font = AppFonts.bold(22)
        walletAvailableLabel.textColor = AppColors.success
        walletCurrentLabel.font = AppFonts.bold(17)
        walletCurrentLabel.textColor = AppColors.textPrimary
        walletPendingLabel.font = AppFonts.bold(17)
        walletPendingLabel.textColor = AppColors.warning
        [walletAvailableLabel, walletCurrentLabel, walletPendingLabel].forEach { $0.text = "—" }

        stack.addArrangedSubview(balanceTile(walletAvailableLabel, "Available"))
        let pairRow = UIStackView.horizontal(spacing: 10, alignment: .fill)
        pairRow.distribution = .fillEqually
        pairRow.addArrangedSubview(balanceTile(walletCurrentLabel, "Current"))
        pairRow.addArrangedSubview(balanceTile(walletPendingLabel, "Pending"))
        stack.addArrangedSubview(pairRow)

        // Recent transactions table.
        stack.addArrangedSubview(UILabel.make("Recent Transactions", font: AppFonts.bold(14), color: AppColors.textPrimary))

        let head = UIStackView.horizontal(spacing: 8, alignment: .center)
        head.isLayoutMarginsRelativeArrangement = true
        head.layoutMargins = UIEdgeInsets(top: 9, left: 12, bottom: 9, right: 12)
        head.backgroundColor = AppColors.surfaceVariant
        head.addArrangedSubview(UILabel.make("Date", font: AppFonts.regular(12), color: AppColors.textSecondary))
        head.addArrangedSubview(UIView())
        head.addArrangedSubview(UILabel.make("Amount", font: AppFonts.regular(12), color: AppColors.textSecondary))
        stack.addArrangedSubview(head)
        stack.addArrangedSubview(walletTransactionsStack)

        walletEmptyLabel.font = AppFonts.regular(13)
        walletEmptyLabel.textColor = AppColors.textSecondary
        walletEmptyLabel.textAlignment = .center
        walletEmptyLabel.text = "No transactions yet."
        walletEmptyLabel.isHidden = true
        stack.addArrangedSubview(walletEmptyLabel)

        return card(stack)
    }

    private func balanceTile(_ value: UILabel, _ caption: String) -> UIView {
        let tile = UIStackView.vertical(spacing: 2, alignment: .fill)
        tile.isLayoutMarginsRelativeArrangement = true
        tile.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        tile.backgroundColor = AppColors.surface
        tile.layer.cornerRadius = AppMetrics.radiusLG
        tile.layer.borderWidth = 1
        tile.layer.borderColor = AppColors.border.cgColor
        tile.addArrangedSubview(value)
        tile.addArrangedSubview(UILabel.make(caption, font: AppFonts.regular(12), color: AppColors.textSecondary))
        return tile
    }

    // MARK: - Wallet data

    /// GET api/common/wallet — balances, IMB account details and the recent ledger.
    private func loadWallet(spin: Bool = false) {
        if spin {
            let rotate = CABasicAnimation(keyPath: "transform.rotation")
            rotate.fromValue = 0
            rotate.toValue = 2 * Double.pi
            rotate.duration = 0.6
            walletRefreshIcon.layer.add(rotate, forKey: "spin")
        }
        ApiClient.shared.getWallet { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                self.wallet = data
                self.applyWallet(data)
            case .failure:
                if self.wallet == nil {           // keep whatever we already show
                    self.setWalletPill(active: false, text: "Could not load your wallet.")
                }
            }
        }
    }

    private func applyWallet(_ data: WalletData) {
        let active = data.status?.lowercased() == "active"
        setWalletPill(active: active, text: active ? "Active" : "Not active")

        let number = data.accountNumber ?? ""
        walletAccountLabel.text = number.isEmpty ? "—" : number
        if let activated = data.activatedAt, !activated.isEmpty {
            walletActivatedLabel.isHidden = false
            walletActivatedLabel.text = "Activated \(activated)"
        } else {
            walletActivatedLabel.isHidden = true
        }

        let b = data.balance
        walletAvailableLabel.text = WalletFormat.zaMoney(b?.available)
        walletCurrentLabel.text = WalletFormat.zaMoney(b?.current)
        walletPendingLabel.text = WalletFormat.zaMoney(b?.pending)

        walletTransactionsStack.arrangedSubviews.forEach {
            walletTransactionsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let transactions = b?.transactions ?? []
        walletEmptyLabel.isHidden = !transactions.isEmpty
        for tx in transactions {
            walletTransactionsStack.addArrangedSubview(transactionRow(tx))
        }
    }

    private func setWalletPill(active: Bool, text: String) {
        walletStatusPill.text = text
        walletStatusPill.textColor = active ? AppColors.success : AppColors.warning
        walletPillBox?.backgroundColor = active ? AppColors.successBg : AppColors.warningBg
        walletStatusIcon.isHidden = !active
    }

    private func transactionRow(_ tx: WalletData.Transaction) -> UIView {
        let amount = Double(tx.amount ?? "") ?? 0
        let value = UILabel.make(WalletFormat.zaMoney(amount), font: AppFonts.bold(13),
                                 color: amount < 0 ? AppColors.danger : AppColors.textPrimary)
        value.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        row.addArrangedSubview(UILabel.make(WalletFormat.ledgerDate(tx.date),
                                            font: AppFonts.regular(13), color: AppColors.textPrimary))
        row.addArrangedSubview(UIView())
        if tx.pending == true {
            let flag = UILabel.make("Pending", font: AppFonts.regular(11), color: AppColors.warning, align: .center)
            flag.setContentHuggingPriority(.required, for: .horizontal)
            let flagBox = UIStackView.horizontal(spacing: 0, alignment: .center)
            flagBox.isLayoutMarginsRelativeArrangement = true
            flagBox.layoutMargins = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
            flagBox.backgroundColor = AppColors.warningBg
            flagBox.layer.cornerRadius = 6
            flagBox.addArrangedSubview(flag)
            flagBox.setContentHuggingPriority(.required, for: .horizontal)
            row.addArrangedSubview(flagBox)
        }
        row.addArrangedSubview(value)

        let hairline = UIView()
        hairline.backgroundColor = AppColors.borderLight
        hairline.constrainHeight(1)

        let wrapper = UIStackView.vertical(spacing: 0, alignment: .fill)
        wrapper.addArrangedSubview(row)
        wrapper.addArrangedSubview(hairline)
        return wrapper
    }

    @objc private func walletRefreshTapped() {
        loadWallet(spin: true)
    }

    // MARK: - Bind from profile

    private func bind(_ p: BusinessProfileData.Profile) {
        companyLegalField.text = p.companyLegalName
        tradingField.text = p.tradingName
        regField.text = p.companyRegistrationNumber
        vatField.text = p.vatNumber
        companyEmailField.text = p.companyEmail
        let (companyC, companyN) = splitPhone(p.companyPhoneNumber)
        companyCountry = companyC
        configureCountryButton(companyCountryButton, country: companyC)
        companyPhoneField.text = companyN
        if let urlString = p.companyLogoUrl, let url = URL(string: urlString) {
            loadLogo(url)
        }

        setDropdown("business_type", code: p.businessType, options: businessTypes, codes: businessTypeCodes)
        setDropdown("business_established_year", code: p.businessEstablishedYear, options: years(), codes: years())
        setDropdown("employee_count", code: p.employeeCount, options: employeeRanges, codes: employeeRangeCodes)
        setDropdown("annual_turnover", code: p.annualTurnover, options: turnoverRanges, codes: turnoverRangeCodes)
        setDropdown("bank_name", code: p.bankName, options: banks, codes: bankCodes)
        accountHolderField.text = p.accountHolderName
        accountNumberField.text = p.accountNumber
        setDropdown("account_type", code: p.accountType, options: accountTypes, codes: accountTypeCodes)
        branchField.text = p.branchCode

        if let contacts = p.contactPersons, !contacts.isEmpty {
            let first = contacts[0]
            primaryNameField.text = first.fullName
            primaryPositionField.text = first.position
            let (primaryC, primaryN) = splitPhone(first.mobileNumber)
            primaryCountry = primaryC
            configureCountryButton(primaryCountryButton, country: primaryC)
            primaryPhoneField.text = primaryN
            primaryEmailField.text = first.emailAddress
            additionalContactsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            contactRows.removeAll()
            for i in 1..<contacts.count { addContactRow(contacts[i]) }
        }

        suppressAddressChange = true
        addressField.text = p.address
        suppressAddressChange = false
        if let lat = p.latitude, let lng = p.longitude {
            placePin(at: CLLocationCoordinate2D(latitude: lat, longitude: lng), zoom: true)
        }

        bindDocuments(p.documents)

        if let cov = p.distributionCoverage, !cov.isEmpty { applyCoverage(cov.capitalized) }
        selectedCategoryIds = (p.primaryProductCategoryIds ?? "").split(separator: ",")
            .compactMap { Int64($0.trimmingCharacters(in: .whitespaces)) }
        renderCategoryChips()
        activeClientsField.text = p.activeClientsCount
        fleetField.text = p.deliveryFleetSize
        applyDeliveryDays(p.preferredDeliveryDays)
    }

    private func loadLogo(_ url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.logoPreview.image = image
                self?.logoPreview.tintColor = nil
            }
        }.resume()
    }

    private func bindDocuments(_ docs: BusinessProfileData.Documents?) {
        guard let docs = docs else { return }
        showDoc("company_registration_certificate", docs.companyRegistrationCertificate)
        showDoc("tax_clearance_certificate", docs.taxClearanceCertificate)
        showDoc("vat_registration_certificate", docs.vatRegistrationCertificate)
        showDoc("proof_of_address", docs.proofOfAddress)
        showDoc("bank_confirmation_letter", docs.bankConfirmationLetter)
    }

    private func showDoc(_ key: String, _ files: [BusinessProfileData.DocFile]?) {
        guard let first = files?.first, let label = docSubtitles[key] else { return }
        label.text = first.originalName
        label.textColor = AppColors.success
        label.isHidden = false
    }

    // MARK: - Per-step save

    private func saveCompany() {
        let legal = text(companyLegalField)
        if legal.isEmpty { toast(S.errBusinessName); return }
        let form: [String: String] = [
            "company_legal_name": legal,
            "trading_name": text(tradingField),
            "company_registration_number": text(regField),
            "vat_number": text(vatField),
            "company_email": text(companyEmailField),
            "company_phone_number": fullPhone(companyCountry, companyPhoneField)
        ]
        var files: [Http.FilePart] = []
        if let data = logoData {
            files.append(Http.FilePart(field: "company_logo", fileName: logoName, mimeType: logoMime, data: data))
        }
        submit(form, files)
    }

    private func saveBusiness() {
        var form: [String: String] = [:]
        ["business_type", "business_established_year", "employee_count", "annual_turnover",
         "bank_name", "account_type"].forEach { if let v = dropdownValues[$0] { form[$0] = v } }
        form["account_holder_name"] = text(accountHolderField)
        form["account_number"] = text(accountNumberField)
        form["branch_code"] = text(branchField)
        submit(form, [])
    }

    private func saveContacts() {
        if text(primaryNameField).isEmpty { toast("Please enter the primary contact name."); return }
        submit(["contact_persons": buildContactsJson()], [])
    }

    private func saveLocation() {
        guard let coord = pickedCoordinate else { toast("Please pick your business location on the map."); return }
        submit(["address": text(addressField),
                "latitude": String(coord.latitude),
                "longitude": String(coord.longitude)], [])
    }

    private func saveDocuments() {
        let files = docData.map { Http.FilePart(field: $0.key, fileName: $0.value.name, mimeType: $0.value.mime, data: $0.value.data) }
        if files.isEmpty { toast("Changes saved successfully"); return }
        submit([:], files)
    }

    private func saveService() {
        var form: [String: String] = [
            "primary_product_category_ids": selectedCategoryIds.map(String.init).joined(separator: ","),
            "active_clients_count": text(activeClientsField),
            "delivery_fleet_size": text(fleetField),
            "preferred_delivery_days": buildDeliveryDays()
        ]
        if let cov = selectedCoverage { form["distribution_coverage"] = cov.lowercased() }
        submit(form, [])
    }

    private func submit(_ form: [String: String], _ files: [Http.FilePart]) {
        spinner.startAnimating()
        ApiClient.shared.updateBusinessProfile(form: form, files: files) { [weak self] result in
            guard let self = self else { return }
            self.spinner.stopAnimating()
            switch result {
            case .success: self.toast("Changes saved successfully")
            case .failure(let error): self.toast(error.message.isEmpty ? S.settingsGenericError : error.message)
            }
        }
    }

    private func buildContactsJson() -> String {
        var array: [[String: String]] = [[
            "full_name": text(primaryNameField),
            "position": text(primaryPositionField),
            "mobile_number": fullPhone(primaryCountry, primaryPhoneField),
            "email_address": text(primaryEmailField)
        ]]
        for r in contactRows where !text(r.name).isEmpty {
            array.append([
                "full_name": text(r.name),
                "position": text(r.position),
                "mobile_number": fullPhone(r.country, r.phone),
                "email_address": text(r.email)
            ])
        }
        guard let data = try? JSONSerialization.data(withJSONObject: array),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }

    // MARK: - Delivery days parse/serialize

    private func applyDeliveryDays(_ value: String?) {
        for r in dayRows {
            r.checkbox.isSelected = false
            [r.open1, r.close1, r.open2, r.close2].forEach { $0.text = "" }
        }
        guard let value = value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        for part in value.split(separator: "/") {
            let dayBody = part.split(separator: ":", maxSplits: 1).map(String.init)
            guard dayBody.count == 2, let num = Int(dayBody[0].trimmingCharacters(in: .whitespaces)) else { continue }
            let idx = num == 7 ? 0 : num
            guard dayRows.indices.contains(idx) else { continue }
            dayRows[idx].checkbox.isSelected = true
            let ranges = dayBody[1].split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            applyRange(ranges.count > 0 ? ranges[0] : "", dayRows[idx].open1, dayRows[idx].close1)
            applyRange(ranges.count > 1 ? ranges[1] : "", dayRows[idx].open2, dayRows[idx].close2)
        }
    }

    private func applyRange(_ range: String, _ open: UITextField, _ close: UITextField) {
        let r = range.trimmingCharacters(in: .whitespaces)
        guard !r.isEmpty, r != "-" else { return }
        let oc = r.split(separator: "-").map(String.init)
        if oc.count > 0 { open.text = stripDecimal(oc[0]) }
        if oc.count > 1 { close.text = stripDecimal(oc[1]) }
    }

    private func buildDeliveryDays() -> String {
        var parts: [String] = []
        for num in 1...7 {
            let idx = num == 7 ? 0 : num
            guard dayRows.indices.contains(idx), dayRows[idx].checkbox.isSelected else { continue }
            let o1 = text(dayRows[idx].open1), c1 = text(dayRows[idx].close1)
            let o2 = text(dayRows[idx].open2), c2 = text(dayRows[idx].close2)
            var body = ""
            if !o1.isEmpty { body += "\(formatHour(o1))-\(formatHour(c1.isEmpty ? "18" : c1))" }
            if !o2.isEmpty { body += ",\(formatHour(o2))-\(formatHour(c2.isEmpty ? "18" : c2))" }
            if body.isEmpty { body = "8.00-18.00" }
            parts.append("\(num):\(body)")
        }
        return parts.joined(separator: "/")
    }

    private func formatHour(_ value: String) -> String { value.contains(".") ? value : value + ".00" }
    private func stripDecimal(_ value: String) -> String { value.hasSuffix(".00") ? String(value.dropLast(3)) : value }

    // MARK: - File picking

    private func pickFile(key: String, imageOnly: Bool) {
        pendingDocKey = key
        let types: [UTType] = imageOnly ? [.image] : [.image, .pdf]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = self
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let key = pendingDocKey else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        let name = url.lastPathComponent
        let m = mime(for: name)
        if key == "__logo__" {
            logoData = data; logoName = name; logoMime = m
            logoPreview.image = UIImage(data: data)
            logoPreview.tintColor = nil
        } else {
            docData[key] = (data, name, m)
            if let label = docSubtitles[key] {
                label.text = name
                label.textColor = AppColors.success
                label.isHidden = false
            }
        }
    }

    private func mime(for name: String) -> String {
        switch (name as NSString).pathExtension.lowercased() {
        case "png": return "image/png"
        case "webp": return "image/webp"
        case "pdf": return "application/pdf"
        default: return "image/jpeg"
        }
    }

    // MARK: - Address autocomplete + map (port of the prior single-screen editor)

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
            if self.predictions.isEmpty { self.hideAddressResults() } else {
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

    private func makeMapView() -> GMSMapView {
        let sa = CLLocationCoordinate2D(latitude: -29.8587, longitude: 31.0218)
        let map = GMSMapView(frame: .zero, camera: GMSCameraPosition.camera(withTarget: sa, zoom: 9))
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
        case .began, .changed: contentScroll.isScrollEnabled = false
        default: contentScroll.isScrollEnabled = true
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
            if !line.isEmpty {
                self.suppressAddressChange = true
                self.addressField.text = line
                self.suppressAddressChange = false
            }
        }
    }

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
        if let desc = prediction.description {
            suppressAddressChange = true
            addressField.text = desc
            suppressAddressChange = false
        }
        hideAddressResults()
        view.endEditing(true)
        guard let placeId = prediction.placeId else { return }
        ApiClient.shared.getCoordinateFromPlaceId(placeId) { [weak self] result in
            guard let self = self, case .success(let data) = result,
                  let lat = data.latitude, let lng = data.longitude else { return }
            if let formatted = data.formattedAddress, !formatted.isEmpty {
                self.suppressAddressChange = true
                self.addressField.text = formatted
                self.suppressAddressChange = false
            }
            self.placePin(at: CLLocationCoordinate2D(latitude: lat, longitude: lng), zoom: true)
        }
    }

    // MARK: - Phone (country picker, matching Android)

    private func phoneGroup(_ label: String, button: UIButton, country: Country,
                            field: UITextField, kind: PhoneKind) -> UIStackView {
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
        container.constrainHeight(45)
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
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true
        divider.heightAnchor.constraint(equalToConstant: 24).isActive = true

        return labeled(label, container)
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
            case .primary: self.primaryCountry = country
            case .contact(let row): row.country = country
            }
            self.configureCountryButton(button, country: country)
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }

    /// Combine the picked country dial code with the typed national number.
    private func fullPhone(_ country: Country, _ field: UITextField) -> String {
        var number = text(field).filter { $0.isNumber }
        if number.isEmpty { return "" }
        if number.hasPrefix("0") { number.removeFirst() }
        return country.dialCode + number
    }

    /// Split a stored number ("+27123…") into its country + national part for editing.
    private func splitPhone(_ raw: String?) -> (Country, String) {
        let value = (raw ?? "").trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("+") {
            let match = Countries.all
                .filter { value.hasPrefix($0.dialCode) }
                .max { $0.dialCode.count < $1.dialCode.count }
            if let c = match {
                return (c, String(value.dropFirst(c.dialCode.count)).filter { $0.isNumber })
            }
        }
        return (Countries.default, value.filter { $0.isNumber })
    }

    // MARK: - Helpers

    private func text(_ field: UITextField) -> String {
        field.text?.trimmingCharacters(in: .whitespaces) ?? ""
    }
}
