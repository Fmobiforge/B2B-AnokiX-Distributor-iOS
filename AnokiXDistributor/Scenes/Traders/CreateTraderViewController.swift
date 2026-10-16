import UIKit
import GoogleMaps
import CoreLocation
import UniformTypeIdentifiers
import PhotosUI

/// Port of CreateTraderActivity — the 8-step trader wizard, wired to
/// /api/distributor/traders/create when adding and /api/distributor/traders/update
/// when editing an existing trader.
///
/// Steps: 1 Owner · 2 Business · 3 Trader · 4 Location · 5 Verify ·
///        6 Distributor · 7 Wallet · 8 Terms.
///
/// All step stacks stay in the view hierarchy (just hidden), so every field keeps
/// its value when navigating back and forth. Lookup data comes from
/// `ApiClient.getReference`; the distributor the trader belongs to is this portal's
/// own, read from `ApiClient.getBaseInfo`. The map uses Google Maps (parity with
/// AddEditStore).
///
/// Edit mode takes the record the Traders list already holds, so the wizard prefills
/// from it rather than re-fetching.
final class CreateTraderViewController: BaseSecondaryViewController, GMSMapViewDelegate,
    UIDocumentPickerDelegate, PHPickerViewControllerDelegate, UITableViewDataSource, UITableViewDelegate {

    var onSaved: (() -> Void)?

    /// The trader being edited, or nil when registering a new one.
    private let editingTrader: TradersData.Trader?
    /// The fuller copy from traders/get-by-id, once it lands.
    private var detail: TradersData.Trader?
    /// Whatever we currently know about the trader: detail if it has arrived, else the row.
    private var record: TradersData.Trader? { detail ?? editingTrader }
    private var isEditMode: Bool { editingTrader != nil }

    init(editing trader: TradersData.Trader? = nil) {
        self.editingTrader = trader
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var screenTitle: String { isEditMode ? S.editTraderTitle : S.addNewTrader }
    override var screenSubtitle: String? { isEditMode ? S.editTraderSubtitle : S.createTraderSubtitle }

    private let stepKeys = [S.stepOwner, S.stepBusiness, S.stepTrader, S.stepLocation,
                            S.stepVerify, S.stepDistributor, S.stepWallet, S.stepTerms]
    private let stepTrader = 2, stepLocation = 3, stepVerify = 4, stepDistributor = 5, stepTerms = 7
    private var currentStep = 0

    private static let minPassword = 8

    /// Delivery days are stored by index with Sunday first ("1:8.00-18.00" is Monday),
    /// so this order doubles as the value sent to the API.
    private let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let paymentLabels = ["Wallet", "EFT", "Cash", "Card"]
    private let paymentValues = ["wallet", "eft", "cash", "card"]

    // Chrome
    private let stepperScroll = UIScrollView()
    private let stepperStack = UIStackView.horizontal(spacing: 0, alignment: .center)
    private var stepCircles: [UILabel] = []
    private var stepTitles: [UILabel] = []
    private let formScroll = UIScrollView()
    private let continueButton = GradientButton(title: S.continueButton, style: .primary)
    private var stepStacks: [UIStackView] = []

    // Reference data
    private var traderTypes: [ReferenceData.TraderType] = []
    private var primaryCategories: [ReferenceData.ProductCategory] = []

    /// This portal's own distributor — the only one a trader can be registered under.
    private var currentDistributorId = ""
    private let distributorChip = PaddingLabel(insets: UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12))

    // Selections
    private var selectedTraderTypeSlug: String?
    private var traderTypeCards: [UIView] = []
    private var selectedCategoryIds: [Int64] = []
    private var paymentMethodValue: String?
    private var createWalletNow = true

    // Owner / Business fields
    private let firstNameField = UITextField()
    private let lastNameField = UITextField()
    private let idNumberField = UITextField()
    private let passportField = UITextField()
    private let ownerEmailField = UITextField()
    private let passwordField = UITextField()
    private let confirmPasswordField = UITextField()
    private let businessNameField = UITextField()
    private let tradingNameField = UITextField()
    private let businessRegField = UITextField()
    private let businessEmailField = UITextField()

    // Company logo (12.Trader-BizInfo1.png), cropped through LogoCropViewController.
    private static let logoKey = "__logo__"
    private let logoPreview = UIImageView()
    private let logoPlaceholder = UIStackView.vertical(spacing: 6, alignment: .center)
    private var logoData: Data?

    // Phone fields + country pickers
    private var ownerCountry = Countries.default
    private var businessCountry = Countries.default
    private let ownerCountryButton = UIButton(type: .system)
    private let businessCountryButton = UIButton(type: .system)
    private let ownerMobileField = UITextField()
    private let businessPhoneField = UITextField()

    // Trader / category fields
    private let traderTypeContainer = UIStackView.vertical(spacing: 12, alignment: .fill)
    private let categoryHint = UILabel.make(S.selectCategoriesHint, font: AppFonts.regular(13), color: AppColors.textSecondary)
    private let categoryChipsScroll = UIScrollView()
    private let categoryChips = UIStackView.horizontal(spacing: 8, alignment: .center)

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

    // Distributor
    private let deliveryDaysStack = UIStackView.vertical(spacing: 0, alignment: .fill)
    private var deliveryDayRows: [DeliveryDayRow] = []
    private let paymentButton = UIButton(type: .system)

    /// A day row on step 6: the tick plus its opening and closing time.
    private final class DeliveryDayRow {
        let dayIndex: Int
        let toggle: UIButton
        let openButton: UIButton
        let closeButton: UIButton
        var isSelected = false

        init(dayIndex: Int, toggle: UIButton, openButton: UIButton, closeButton: UIButton) {
            self.dayIndex = dayIndex
            self.toggle = toggle
            self.openButton = openButton
            self.closeButton = closeButton
        }

        var openText: String { openButton.configuration?.title ?? "" }
        var closeText: String { closeButton.configuration?.title ?? "" }
    }

    // Wallet
    private let walletNowRadio = UIImageView()
    private let walletLaterRadio = UIImageView()

    // Terms
    private var termCheckboxes: [UIButton] = []

    // Documents
    /// `key` is the multipart field used when uploading; `responseKey` is the key the same
    /// document comes back under. The API reads "business_registration_document" but
    /// writes "registration_document", so the two names have to be tracked separately.
    private struct DocDef { let key, responseKey, title, sub: String; let required: Bool }
    private let docDefs: [DocDef] = [
        DocDef(key: "business_registration_document", responseKey: "registration_document", title: "Business Registration Document", sub: "CIPC, Business Permit, etc.", required: true),
        DocDef(key: "owner_id_document", responseKey: "id_document", title: "Owner ID Document", sub: "ID or Passport", required: true),
        DocDef(key: "proof_of_address", responseKey: "proof_of_address", title: "Proof of Address", sub: "Municipal bill, Lease, etc.", required: true),
        DocDef(key: "store_front_photo", responseKey: "store_front_photo", title: "Store Front Photo", sub: "Clear photo of your store", required: true),
        DocDef(key: "store_interior_photo", responseKey: "store_interior_photo", title: "Store Interior Photo", sub: "Inside view of your store", required: true),
        DocDef(key: "additional_documents", responseKey: "additional_documents", title: "Additional Documents", sub: "(If any)", required: false)
    ]
    /// The total POST is capped at 40 MB by the server. With up to 6 documents
    /// that means each file must stay under 5 MB (6 × 5 MB ≈ 30 MB, leaving room
    /// for the form fields). Guard every picked file against this limit.
    private static let maxUploadBytes = 5 * 1024 * 1024
    private var docFiles: [String: (data: Data, name: String, mime: String)] = [:]
    private var docSubtitleLabels: [String: UILabel] = [:]
    private var docButtons: [String: UIButton] = [:]
    private var pendingDocKey: String?

    // MARK: - Setup

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

        stepStacks = [buildOwnerStep(), buildBusinessStep(), buildTraderStep(), buildLocationStep(),
                      buildVerifyStep(), buildDistributorStep(), buildWalletStep(), buildTermsStep()]
        for step in stepStacks {
            step.isLayoutMarginsRelativeArrangement = true
            step.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
            formStack.addArrangedSubview(step)
        }
        if let trader = editingTrader { prefill(from: trader) }
        showStep(0)
    }

    override func loadData() {
        loadReference()
        loadCurrentDistributor()
        loadTraderDetail()
    }

    // MARK: - Prefill (edit mode)

    /// Paints the record onto every step. Trader type and categories need the reference
    /// lists, so those are re-applied in `loadReference()` once they arrive.
    private func prefill(from trader: TradersData.Trader) {
        firstNameField.text = trader.ownerFirstName
        lastNameField.text = trader.ownerLastName
        idNumberField.text = trader.idNumber
        passportField.text = trader.passportNumber
        ownerEmailField.text = trader.email
        ownerCountry = setPhone(trader.mobileNumber, fallback: ownerCountry,
                                button: ownerCountryButton, field: ownerMobileField)

        businessNameField.text = trader.businessName
        tradingNameField.text = trader.tradingName
        businessRegField.text = trader.businessRegistrationNumber
        businessEmailField.text = trader.businessEmail
        businessCountry = setPhone(trader.businessPhoneNumber, fallback: businessCountry,
                                   button: businessCountryButton, field: businessPhoneField)

        selectedTraderTypeSlug = trader.traderType
        selectedCategoryIds = trader.categoryIds

        addressField.text = trader.address
        if let lat = trader.latitude, let lng = trader.longitude {
            placePin(at: CLLocationCoordinate2D(latitude: lat, longitude: lng), zoom: true)
        }

        applyDeliveryDays(TradersData.parseDeliveryDays(trader.preferredDeliveryDays))
        if let index = paymentValues.firstIndex(where: {
            $0.caseInsensitiveCompare(trader.paymentMethod ?? "") == .orderedSame
        }) {
            paymentMethodValue = paymentValues[index]
            setPickerTitle(paymentButton, paymentLabels[index])
        }

        renderStoredDocuments(trader)
        loadExistingLogo(trader.companyLogoUrl)

        // An approved trader already accepted the terms; keep them ticked so an edit does
        // not force the distributor to re-consent on the owner's behalf.
        termCheckboxes.forEach { $0.isSelected = true }
    }

    /// Pulls the full record for the trader being edited. The list row has no owner
    /// fields, so step 1 stays blank until this lands and fills in the linked user
    /// account's name, email and mobile number.
    private func loadTraderDetail() {
        guard let id = editingTrader?.id, !id.isEmpty else { return }
        ApiClient.shared.getTraderById(id: id) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                // Detail is the fuller copy, but it lands after the screen is already
                // interactive — only fill what the list row could not, so a fast typist's
                // input is never overwritten.
                if let trader = data.trader {
                    self.detail = trader
                    self.fillGaps(from: trader)
                }
                self.prefillOwner(data.user)
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    /// Re-applies the parts of the record the list row could not supply. Text fields are
    /// only filled when still empty; the rest (selections, schedule, documents, logo) is
    /// repainted because the row carried no version of it to overwrite.
    private func fillGaps(from trader: TradersData.Trader) {
        fillIfEmpty(idNumberField, trader.idNumber)
        fillIfEmpty(passportField, trader.passportNumber)
        fillIfEmpty(businessNameField, trader.businessName)
        fillIfEmpty(tradingNameField, trader.tradingName)
        fillIfEmpty(businessRegField, trader.businessRegistrationNumber)
        fillIfEmpty(businessEmailField, trader.businessEmail)
        fillIfEmpty(addressField, trader.address)
        if text(businessPhoneField).isEmpty {
            businessCountry = setPhone(trader.businessPhoneNumber, fallback: businessCountry,
                                       button: businessCountryButton, field: businessPhoneField)
        }

        if pickedCoordinate == nil, let lat = trader.latitude, let lng = trader.longitude {
            placePin(at: CLLocationCoordinate2D(latitude: lat, longitude: lng), zoom: true)
        }

        selectedTraderTypeSlug = trader.traderType
        normaliseTraderTypeSelection()
        applyTraderTypeSelection()

        selectedCategoryIds = trader.categoryIds
        renderCategoryChips()

        applyDeliveryDays(TradersData.parseDeliveryDays(trader.preferredDeliveryDays))
        if let index = paymentValues.firstIndex(where: {
            $0.caseInsensitiveCompare(trader.paymentMethod ?? "") == .orderedSame
        }) {
            paymentMethodValue = paymentValues[index]
            setPickerTitle(paymentButton, paymentLabels[index])
        }
        renderStoredDocuments(trader)
        loadExistingLogo(trader.companyLogoUrl)
    }

    /// Owner Information (step 1) comes from the linked user account, not the trader row.
    private func prefillOwner(_ user: TraderDetailData.Owner?) {
        guard let user = user else { return }
        fillIfEmpty(firstNameField, user.firstName)
        fillIfEmpty(lastNameField, user.lastName)
        fillIfEmpty(ownerEmailField, user.email)
        if text(ownerMobileField).isEmpty {
            ownerCountry = setPhone(user.phoneNumber, fallback: ownerCountry,
                                    button: ownerCountryButton, field: ownerMobileField)
        }
    }

    /// Used by the late-arriving detail response so it never overwrites typed input.
    private func fillIfEmpty(_ field: UITextField, _ value: String?) {
        guard text(field).isEmpty, let value = value, !value.isEmpty else { return }
        field.text = value
    }

    /// Documents already uploaded are listed by name; only replacements are re-sent.
    private func renderStoredDocuments(_ trader: TradersData.Trader) {
        for def in docDefs {
            // Skip anything the user has already replaced in this session.
            guard docFiles[def.key] == nil else { continue }
            let name = trader.documentName(def.responseKey)
            guard !name.isEmpty else { continue }
            docSubtitleLabels[def.key]?.text = "On file: \(name)"
            docSubtitleLabels[def.key]?.textColor = AppColors.success
            docButtons[def.key]?.setTitle("Replace", for: .normal)
        }
    }

    /// Shows the logo already on file so an edit does not look like it has none.
    private func loadExistingLogo(_ urlString: String?) {
        // A freshly cropped logo always wins.
        guard logoData == nil,
              let urlString = urlString, let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                guard let self = self, self.logoData == nil else { return }
                self.logoPreview.image = image
                self.logoPreview.isHidden = false
                self.logoPlaceholder.isHidden = true
            }
        }.resume()
    }

    /// Splits a stored MSISDN ("27821234567") back into the country picker and the
    /// national part so the field reads the way the user typed it. Returns the country to
    /// select, or `fallback` when the dial code could not be matched.
    @discardableResult
    private func setPhone(_ stored: String?, fallback: Country,
                          button: UIButton, field: UITextField) -> Country {
        var digits = (stored ?? "").trimmingCharacters(in: .whitespaces)
        guard !digits.isEmpty else { return fallback }
        if digits.hasPrefix("+") { digits.removeFirst() }
        // Longest dial code first, so "+27" is not shadowed by a shorter "+2…" entry.
        let match = Countries.all
            .filter { digits.hasPrefix($0.dialCode.dropFirst()) }
            .max { $0.dialCode.count < $1.dialCode.count }
        guard let match = match else {
            field.text = digits
            return fallback
        }
        configureCountryButton(button, country: match)
        field.text = String(digits.dropFirst(match.dialCode.count - 1))
        return match
    }

    /// Ticks the saved days and fills their opening hours ("1:8.00-18.00").
    private func applyDeliveryDays(_ saved: [Int: String]) {
        for row in deliveryDayRows {
            guard let hours = saved[row.dayIndex] else {
                setDay(row, selected: false)
                continue
            }
            setDay(row, selected: true)
            let parts = hours.split(separator: "-", maxSplits: 1)
            if parts.count == 2 {
                setPickerTitle(row.openButton, parts[0].trimmingCharacters(in: .whitespaces))
                setPickerTitle(row.closeButton, parts[1].trimmingCharacters(in: .whitespaces))
            }
        }
    }

    /// Resolves the distributor this portal signs in as. Traders created here always
    /// belong to it, so step 6 shows it as a fixed chip instead of a picker.
    private func loadCurrentDistributor() {
        ApiClient.shared.getBaseInfo { [weak self] result in
            guard let self = self, case .success(let data) = result,
                  let portal = data.portalInfo else { return }
            if let id = portal.id, !id.isEmpty { self.currentDistributorId = id }
            // Registering a trader is a legal relationship, so the chip names the
            // distributor's registered entity rather than its trading name.
            let label = [portal.companyLegalName, portal.tradingName]
                .compactMap { $0 }.first { !$0.isEmpty } ?? ""
            self.distributorChip.text = label
            self.distributorChip.isHidden = label.isEmpty
        }
    }

    /// The signed-in distributor, falling back to whatever the record already carried if
    /// base-info has not answered yet — better to leave the link untouched than clear it.
    private func resolveDistributorId() -> String {
        if !currentDistributorId.isEmpty { return currentDistributorId }
        return (record?.preferredDistributorIds ?? "").trimmingCharacters(in: .whitespaces)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didWireMapScroll else { return }
        didWireMapScroll = true
        wireMapScrollBehavior()
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
            // Single line + don't compress, so the stepper scrolls horizontally and
            // shows each full step title instead of truncating ("O…", "Bu…").
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
                // Completed: purple fill, white check.
                circle.backgroundColor = AppColors.purplePrimary
                circle.textColor = .white
                circle.text = "✓"
                title.textColor = AppColors.textPrimary
                title.font = AppFonts.regular(13)
            } else if i == currentStep {
                // Current: purple fill, white number.
                circle.backgroundColor = AppColors.purplePrimary
                circle.textColor = .white
                circle.text = "\(i + 1)"
                title.textColor = AppColors.purplePrimary
                title.font = AppFonts.bold(13)
            } else {
                // Upcoming: white fill, gray number + border.
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
        let spacer = UIView()
        row.addArrangedSubview(spacer)
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
        if currentStep == 0 { navigationController?.popViewController(animated: true) }
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
        continueButton.setTitle(index == stepTerms ? submitLabel : S.continueButton, for: .normal)
        renderStepper()
        view.endEditing(true)
        formScroll.setContentOffset(.zero, animated: false)
    }

    // MARK: - Validation

    private func validateStep(_ step: Int) -> Bool {
        switch step {
        case 0:
            if text(firstNameField).isEmpty { return fail("Please enter the owner's first name.") }
            if text(lastNameField).isEmpty { return fail("Please enter the owner's last name.") }
            if text(idNumberField).isEmpty && text(passportField).isEmpty {
                return fail("Provide an ID number or passport number.")
            }
            if text(ownerMobileField).isEmpty { return fail("Please enter a mobile number.") }
            if !isValidEmail(text(ownerEmailField)) { return fail("Please enter a valid email address.") }
            return validatePassword()
        case 1:
            if text(businessNameField).isEmpty { return fail("Please enter the business name.") }
            return true
        case stepTrader:
            if (selectedTraderTypeSlug ?? "").isEmpty { return fail("Please select a trader classification.") }
            return true
        case stepLocation:
            if pickedCoordinate == nil { return fail("Please select your business location on the map.") }
            return true
        case stepVerify:
            // When editing, a document already on file satisfies the requirement — only a
            // replacement is re-uploaded.
            for d in docDefs where d.required && docFiles[d.key] == nil && !hasStoredDocument(d) {
                return fail("Please upload all required documents.")
            }
            return true
        case stepDistributor:
            for row in deliveryDayRows where row.isSelected
                && (row.openText.isEmpty || row.closeText.isEmpty) {
                return fail("Set an opening and closing time for every selected delivery day.")
            }
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

    /// A new trader needs a password to sign in with. Editing leaves it blank to keep the
    /// current one, so the rules only apply once something has been typed.
    private func validatePassword() -> Bool {
        let password = passwordField.text ?? ""
        let confirm = confirmPasswordField.text ?? ""
        if isEditMode && password.isEmpty && confirm.isEmpty { return true }
        if password.count < Self.minPassword {
            return fail("Password must be at least 8 characters.")
        }
        if password != confirm {
            return fail("The two passwords do not match.")
        }
        return true
    }

    /// True when the trader being edited already has a file stored for this document.
    private func hasStoredDocument(_ def: DocDef) -> Bool {
        guard let trader = record else { return false }
        return !trader.documentName(def.responseKey).isEmpty
    }

    private func fail(_ message: String) -> Bool {
        toast(message)
        return false
    }

    // MARK: - Step 1: Owner

    private func buildOwnerStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Owner Information"))
        stack.addArrangedSubview(subtitle("Tell us about the business owner."))
        stack.addArrangedSubview(fieldGroup("Owner First Name", firstNameField, placeholder: "Enter first name"))
        stack.addArrangedSubview(fieldGroup("Owner Last Name", lastNameField, placeholder: "Enter last name"))
        stack.addArrangedSubview(fieldGroup("ID Number", idNumberField, placeholder: "Enter ID number", keyboard: .numberPad))
        stack.addArrangedSubview(fieldGroup("Passport Number", passportField, placeholder: "Enter passport number"))
        stack.addArrangedSubview(subtitle("Provide either your ID number or passport number."))

        let infoBox = UIStackView.vertical(spacing: 3, alignment: .leading)
        infoBox.isLayoutMarginsRelativeArrangement = true
        infoBox.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        infoBox.backgroundColor = AppColors.infoBg
        infoBox.layer.cornerRadius = AppMetrics.radiusSM
        infoBox.addArrangedSubview(UILabel.make(S.accountSignIn, font: AppFonts.bold(13), color: AppColors.info))
        infoBox.addArrangedSubview(UILabel.make(
            isEditMode ? S.accountSignInHelpEdit : S.accountSignInHelpCreate,
            font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 0))
        stack.addArrangedSubview(infoBox)

        stack.addArrangedSubview(phoneGroup("Mobile Number", country: .owner, field: ownerMobileField))
        stack.addArrangedSubview(fieldGroup("Email Address", ownerEmailField, placeholder: "Enter email address", keyboard: .emailAddress))

        // Editing leaves the password blank to keep the current one (11.Trader-OwnerInfo.png).
        stack.addArrangedSubview(passwordGroup(S.passwordLabel, passwordField,
                                               placeholder: isEditMode ? "Enter new password (optional)"
                                                                      : "Enter password"))
        stack.addArrangedSubview(passwordGroup("Confirm Password", confirmPasswordField,
                                               placeholder: isEditMode ? "Confirm new password (optional)"
                                                                      : "Confirm password"))
        stack.addArrangedSubview(subtitle(isEditMode ? S.passwordHelpEdit : S.passwordHelpCreate))
        return stack
    }

    /// A secure field with an eye button that flips it between dots and plain text.
    private func passwordGroup(_ label: String, _ field: UITextField,
                               placeholder: String) -> UIStackView {
        StyleKit.styleInput(field)
        field.placeholder = placeholder
        field.isSecureTextEntry = true
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.textContentType = .oneTimeCode   // stops iOS offering to save/fill our own password

        let eye = UIButton(type: .system)
        eye.setImage(UIImage(systemName: "eye"), for: .normal)
        eye.tintColor = AppColors.textSecondary
        eye.accessibilityLabel = "Toggle password visibility"
        eye.constrainSize(24)
        eye.addAction(UIAction { _ in
            field.isSecureTextEntry.toggle()
            eye.setImage(UIImage(systemName: field.isSecureTextEntry ? "eye" : "eye.slash"), for: .normal)
        }, for: .touchUpInside)

        field.rightView = eye
        field.rightViewMode = .always

        let title = UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textPrimary)
        let stack = UIStackView.vertical(spacing: 5, alignment: .fill)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(field)
        return stack
    }

    // MARK: - Step 2: Business

    private func buildBusinessStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Business Information"))
        stack.addArrangedSubview(subtitle("Tell us about your business."))
        stack.addArrangedSubview(UILabel.make("Company Logo (Optional)",
                                              font: AppFonts.regular(13), color: AppColors.textPrimary))
        stack.addArrangedSubview(buildLogoUploadBox())
        stack.addArrangedSubview(fieldGroup("Business Name", businessNameField, placeholder: "Enter business name"))
        stack.addArrangedSubview(fieldGroup("Trading Name", tradingNameField, placeholder: "Enter trading name"))
        stack.addArrangedSubview(fieldGroup("Business Registration Number (Optional)", businessRegField, placeholder: "Enter registration number"))
        stack.addArrangedSubview(phoneGroup("Business Phone Number", country: .business, field: businessPhoneField))
        stack.addArrangedSubview(fieldGroup("Business Email Address", businessEmailField, placeholder: "Enter business email", keyboard: .emailAddress))
        return stack
    }

    /// Dashed drop box that swaps to a preview once a logo has been cropped.
    private func buildLogoUploadBox() -> UIView {
        let box = UIView()
        box.backgroundColor = AppColors.surfaceVariant
        box.layer.cornerRadius = AppMetrics.radiusMD
        box.layer.borderWidth = 1
        box.layer.borderColor = AppColors.border.cgColor
        box.isUserInteractionEnabled = true
        box.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(pickLogo)))
        box.forAutoLayout()
        NSLayoutConstraint.activate([
            box.heightAnchor.constraint(equalToConstant: 115),
            box.widthAnchor.constraint(equalToConstant: 150)
        ])

        let icon = UIImageView(image: UIImage(systemName: "plus"))
        icon.tintColor = AppColors.purplePrimary
        icon.contentMode = .scaleAspectFit
        icon.constrainSize(24)
        logoPlaceholder.addArrangedSubview(icon)
        logoPlaceholder.addArrangedSubview(UILabel.make(isEditMode ? "Change logo" : "Upload logo",
                                                        font: AppFonts.bold(12),
                                                        color: AppColors.purplePrimary))
        logoPlaceholder.forAutoLayout()
        box.addSubview(logoPlaceholder)

        logoPreview.contentMode = .scaleAspectFill
        logoPreview.clipsToBounds = true
        logoPreview.layer.cornerRadius = AppMetrics.radiusMD
        logoPreview.isHidden = true
        logoPreview.forAutoLayout()
        box.addSubview(logoPreview)

        NSLayoutConstraint.activate([
            logoPlaceholder.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            logoPlaceholder.centerYAnchor.constraint(equalTo: box.centerYAnchor)
        ])
        logoPreview.pinEdges(to: box)

        // Keep the box at its natural width instead of stretching across the step.
        let row = UIStackView.horizontal(spacing: 0, alignment: .center)
        row.addArrangedSubview(box)
        row.addArrangedSubview(UIView())
        return row
    }

    @objc private func pickLogo() {
        pendingDocKey = Self.logoKey
        presentPhotoLibrary()
    }

    private func applyLogo(_ image: UIImage) {
        let crop = LogoCropViewController(image: image)
        crop.onConfirm = { [weak self] cropped in self?.applyCroppedLogo(cropped) }
        crop.onUploadNew = { [weak self] in self?.pickLogo() }
        present(crop, animated: true)
    }

    private func applyCroppedLogo(_ image: UIImage) {
        logoData = image.jpegData(compressionQuality: 0.9)
        logoPreview.image = image
        logoPreview.isHidden = false
        logoPlaceholder.isHidden = true
    }

    // MARK: - Step 3: Trader

    private func buildTraderStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Trader Classification"))
        stack.addArrangedSubview(subtitle("What type of trader are you?"))
        stack.addArrangedSubview(traderTypeContainer)

        stack.addArrangedSubview(sectionTitle("Primary Product Categories"))
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
        return stack
    }

    private func renderTraderTypes() {
        traderTypeContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        traderTypeCards.removeAll()
        var row: UIStackView?
        for (index, type) in traderTypes.enumerated() {
            if index % 2 == 0 {
                row = UIStackView.horizontal(spacing: 12, alignment: .fill)
                row?.distribution = .fillEqually
                traderTypeContainer.addArrangedSubview(row!)
            }
            let card = traderTypeCard(type)
            traderTypeCards.append(card)
            row?.addArrangedSubview(card)
        }
        // Balance the last row if odd count.
        if traderTypes.count % 2 == 1 { row?.addArrangedSubview(UIView()) }
        applyTraderTypeSelection()
    }

    private func traderTypeCard(_ type: ReferenceData.TraderType) -> UIView {
        let card = UIView()
        card.layer.cornerRadius = AppMetrics.radiusMD
        card.layer.borderWidth = 1
        card.isUserInteractionEnabled = true
        card.tag = Int(type.id)
        let icon = UIImageView(image: UIImage(systemName: "storefront.fill") ?? UIImage(systemName: "building.2.fill"))
        icon.contentMode = .scaleAspectFit
        icon.constrainSize(24)
        let label = UILabel.make(type.name ?? "", font: AppFonts.regular(13), color: AppColors.textPrimary, align: .center, lines: 2)
        let inner = UIStackView.vertical(spacing: 8, alignment: .center)
        inner.forAutoLayout()
        inner.addArrangedSubview(icon)
        inner.addArrangedSubview(label)
        card.addSubview(inner)
        inner.pinEdges(to: card, insets: UIEdgeInsets(top: 16, left: 8, bottom: 16, right: 8))
        let tap = UITapGestureRecognizer(target: self, action: #selector(traderTypeTapped(_:)))
        card.addGestureRecognizer(tap)
        return card
    }

    @objc private func traderTypeTapped(_ gesture: UITapGestureRecognizer) {
        guard let id = gesture.view?.tag,
              let type = traderTypes.first(where: { Int($0.id) == id }) else { return }
        selectedTraderTypeSlug = type.slug
        applyTraderTypeSelection()
    }

    private func applyTraderTypeSelection() {
        for (i, card) in traderTypeCards.enumerated() {
            let selected = traderTypes[i].slug == selectedTraderTypeSlug
            card.backgroundColor = selected ? AppColors.purpleLight : AppColors.surface
            card.layer.borderColor = (selected ? AppColors.purplePrimary : AppColors.border).cgColor
            card.layer.borderWidth = selected ? 1.5 : 1
            if let inner = card.subviews.first as? UIStackView {
                (inner.arrangedSubviews.first as? UIImageView)?.tintColor = selected ? AppColors.purplePrimary : AppColors.textPrimary
                (inner.arrangedSubviews.last as? UILabel)?.textColor = selected ? AppColors.purplePrimary : AppColors.textPrimary
            }
        }
    }

    @objc private func pickCategories() {
        guard !primaryCategories.isEmpty else { return }
        let options = primaryCategories.map { $0.title ?? "" }
        let preselected = Set(primaryCategories.enumerated()
            .filter { selectedCategoryIds.contains($0.element.id) }.map { $0.offset })
        let picker = MultiSelectViewController(title: "Primary Product Categories", options: options, selected: preselected) { [weak self] indices in
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

    // MARK: - Step 4: Location

    private func buildLocationStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Business Location"))
        stack.addArrangedSubview(subtitle("Where is your business located?"))
        stack.addArrangedSubview(fieldGroup("Address of your business", addressField, placeholder: "Search for your business address"))
        addressField.addTarget(self, action: #selector(addressChanged), for: .editingChanged)

        addressResultsTable.dataSource = self
        addressResultsTable.delegate = self
        addressResultsTable.isHidden = true
        addressResultsTable.layer.cornerRadius = AppMetrics.radiusMD
        addressResultsTable.layer.borderWidth = 1
        addressResultsTable.layer.borderColor = AppColors.border.cgColor
        addressResultsTable.register(UITableViewCell.self, forCellReuseIdentifier: "pred")
        addressResultsTable.isScrollEnabled = true
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

    // MARK: - Step 5: Verify

    private func buildVerifyStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 10, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Business Verification"))
        stack.addArrangedSubview(subtitle("Upload the required documents."))
        for def in docDefs {
            stack.addArrangedSubview(documentRow(def))
        }
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
        let sub = UILabel.make(def.sub, font: AppFonts.regular(11), color: AppColors.textSecondary, lines: 0)
        docSubtitleLabels[def.key] = sub
        let textCol = UIStackView.vertical(spacing: 2, alignment: .leading)
        textCol.addArrangedSubview(title)
        textCol.addArrangedSubview(sub)

        let upload = UIButton(type: .system)
        upload.setTitle("Upload", for: .normal)
        upload.setTitleColorCompat(AppColors.purplePrimary)
        upload.titleLabel?.font = AppFonts.bold(12)
        upload.layer.cornerRadius = AppMetrics.radiusSM
        upload.layer.borderWidth = 1
        upload.layer.borderColor = AppColors.border.cgColor
        upload.contentEdgeInsetsCompat(top: 9, left: 16, bottom: 9, right: 16)
        upload.addAction(UIAction { [weak self] _ in self?.pickDocument(def.key, from: upload) }, for: .touchUpInside)
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

    /// Let the user pick from the Photo Library (PHPicker) or Files (document picker).
    /// The Simulator's Files app is usually empty, so Photo Library is the reliable
    /// way to test uploads there.
    private func pickDocument(_ key: String, from sourceView: UIView) {
        pendingDocKey = key
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in
            self?.presentPhotoLibrary()
        })
        sheet.addAction(UIAlertAction(title: "Choose File", style: .default) { [weak self] _ in
            self?.presentFilePicker()
        })
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel) { [weak self] _ in
            self?.pendingDocKey = nil
        })
        if let pop = sheet.popoverPresentationController {  // iPad anchor
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

    // PHPicker (Photo Library)
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
            // The logo goes through the crop editor; documents upload as picked.
            if key == Self.logoKey {
                DispatchQueue.main.async {
                    self.pendingDocKey = nil
                    self.applyLogo(Self.downscaledForCrop(image))
                }
                return
            }
            // Downscale + compress so KYC photos upload quickly (avoids the
            // multipart request timing out on large full-resolution images).
            guard let data = Self.downscaledJpeg(image, maxDimension: 1440, quality: 0.6) else {
                DispatchQueue.main.async { self.pendingDocKey = nil }
                return
            }
            DispatchQueue.main.async {
                self.applyPickedFile(key: key, data: data, name: suggested + ".jpg", mime: "image/jpeg")
                self.pendingDocKey = nil
            }
        }
    }

    /// The crop editor works on-screen, so a screen-sized image is plenty.
    private static func downscaledForCrop(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1500
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Resizes an image so its longest side is at most `maxDimension`, then JPEG-encodes it.
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

    // Files (document picker)
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let key = pendingDocKey else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard var data = try? Data(contentsOf: url) else { toast("Could not read file"); return }
        var name = url.lastPathComponent
        var mime = mimeType(for: url)

        // Files picked here are uploaded as-is, so a full-resolution photo or scan
        // can easily exceed the 40 MB cap. Re-encode images through the same
        // downscale used for the photo library; PDFs/other types can't be shrunk
        // here and are size-checked as-is.
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

    private func applyPickedFile(key: String, data: Data, name: String, mime: String) {
        docFiles[key] = (data, name, mime)
        docSubtitleLabels[key]?.text = name
        docSubtitleLabels[key]?.textColor = AppColors.success
        docButtons[key]?.setTitle("Change", for: .normal)
    }

    private func mimeType(for url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension), let mime = type.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }

    // MARK: - Step 6: Distributor

    private func buildDistributorStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Select Preferred Distributor"))
        stack.addArrangedSubview(subtitle(S.registeredUnderYou))
        stack.addArrangedSubview(UILabel.make("Preferred Distributors", font: AppFonts.semibold(16), color: AppColors.topTitle))

        // This is the distributor portal, so the trader always belongs to the signed-in
        // distributor — the web multi-select is replaced by a read-only chip naming it
        // (16.Trader-Distributor.png).
        StyleKit.styleBadge(distributorChip)   // resets insets, so widen them afterwards
        distributorChip.insets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        distributorChip.font = AppFonts.bold(12)
        distributorChip.textColor = AppColors.purplePrimary
        distributorChip.backgroundColor = AppColors.purpleLight
        distributorChip.isHidden = true
        let chipRow = UIStackView.horizontal(spacing: 0, alignment: .center)
        chipRow.isLayoutMarginsRelativeArrangement = true
        chipRow.layoutMargins = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        chipRow.addArrangedSubview(distributorChip)
        chipRow.addArrangedSubview(UIView())
        let chipField = tappableField()
        chipField.isUserInteractionEnabled = false
        chipRow.forAutoLayout()
        chipField.addSubview(chipRow)
        chipRow.pinEdges(to: chipField)
        chipField.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        stack.addArrangedSubview(chipField)

        stack.addArrangedSubview(UILabel.make("Preferred Delivery Days",
                                              font: AppFonts.regular(13), color: AppColors.textPrimary))
        stack.addArrangedSubview(UILabel.make(S.deliveryDaysHelp,
                                              font: AppFonts.regular(12),
                                              color: AppColors.textTertiary, lines: 0))
        let daysBox = tappableField()
        daysBox.isUserInteractionEnabled = true
        deliveryDaysStack.isLayoutMarginsRelativeArrangement = true
        deliveryDaysStack.layoutMargins = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        deliveryDaysStack.forAutoLayout()
        daysBox.addSubview(deliveryDaysStack)
        deliveryDaysStack.pinEdges(to: daysBox)
        buildDeliveryDayRows()
        stack.addArrangedSubview(daysBox)

        stack.addArrangedSubview(UILabel.make("Preferred Payment Method", font: AppFonts.regular(13), color: AppColors.textPrimary))
        configurePickerButton(paymentButton, placeholder: "Select payment method")
        paymentButton.addTarget(self, action: #selector(pickPayment), for: .touchUpInside)
        stack.addArrangedSubview(paymentButton)
        return stack
    }

    /// One row per day (16.Trader-Distributor.png): tick the day, then set its opening
    /// and closing time. Ticking a fresh day seeds the standard 08:00–18:00 window so the
    /// common case needs a single tap.
    private func buildDeliveryDayRows() {
        for (index, label) in dayLabels.enumerated() {
            let toggle = UIButton(type: .custom)
            let symbol = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
            toggle.setImage(UIImage(systemName: "square", withConfiguration: symbol)?
                .withTintColor(AppColors.textTertiary, renderingMode: .alwaysOriginal), for: .normal)
            toggle.setImage(UIImage(systemName: "checkmark.square.fill", withConfiguration: symbol)?
                .withTintColor(AppColors.purplePrimary, renderingMode: .alwaysOriginal), for: .selected)
            toggle.constrainSize(24)
            toggle.setContentHuggingPriority(.required, for: .horizontal)

            let name = UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textPrimary)

            let openButton = timeButton()
            let closeButton = timeButton()
            let row = DeliveryDayRow(dayIndex: index, toggle: toggle,
                                     openButton: openButton, closeButton: closeButton)
            deliveryDayRows.append(row)

            toggle.addAction(UIAction { [weak self] _ in
                self?.setDay(row, selected: !row.isSelected, seedDefaultHours: true)
            }, for: .touchUpInside)
            name.isUserInteractionEnabled = true
            name.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dayNameTapped(_:))))
            name.tag = index
            openButton.addAction(UIAction { [weak self] _ in self?.pickTime(openButton) }, for: .touchUpInside)
            closeButton.addAction(UIAction { [weak self] _ in self?.pickTime(closeButton) }, for: .touchUpInside)

            let dash = UILabel.make("–", font: AppFonts.regular(13), color: AppColors.textTertiary)
            dash.setContentHuggingPriority(.required, for: .horizontal)

            let line = UIStackView.horizontal(spacing: 6, alignment: .center)
            line.isLayoutMarginsRelativeArrangement = true
            line.layoutMargins = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
            line.addArrangedSubview(toggle)
            line.addArrangedSubview(name)
            line.addArrangedSubview(UIView())
            line.addArrangedSubview(openButton)
            line.addArrangedSubview(dash)
            line.addArrangedSubview(closeButton)
            deliveryDaysStack.addArrangedSubview(line)

            setDay(row, selected: false)
        }
    }

    private func timeButton() -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.bordered()
        config.title = ""
        config.baseForegroundColor = AppColors.textPrimary
        config.background.strokeColor = AppColors.border
        config.background.backgroundColor = AppColors.surface
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.regular(13); return out
        }
        button.configuration = config
        button.widthAnchor.constraint(equalToConstant: 72).isActive = true
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    @objc private func dayNameTapped(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag, deliveryDayRows.indices.contains(index) else { return }
        let row = deliveryDayRows[index]
        setDay(row, selected: !row.isSelected, seedDefaultHours: true)
    }

    /// Times only make sense on a day that is actually selected.
    private func setDay(_ row: DeliveryDayRow, selected: Bool, seedDefaultHours: Bool = false) {
        row.isSelected = selected
        row.toggle.isSelected = selected
        if selected && seedDefaultHours && row.openText.isEmpty && row.closeText.isEmpty {
            setPickerTitle(row.openButton, "8.00")
            setPickerTitle(row.closeButton, "18.00")
        }
        for button in [row.openButton, row.closeButton] {
            button.isEnabled = selected
            button.alpha = selected ? 1 : 0.45
        }
    }

    /// Times round-trip as "8.00" / "18.30", which is the format the API stores.
    private func pickTime(_ button: UIButton) {
        let current = button.configuration?.title ?? ""
        let parts = current.split(separator: ".")
        let hour = parts.count > 0 ? (Int(parts[0]) ?? 8) : 8
        let minute = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0

        let picker = TimeWheelViewController(hour: hour, minute: minute)
        picker.onPick = { [weak self] pickedHour, pickedMinute in
            self?.setPickerTitle(button, String(format: "%d.%02d", pickedHour, pickedMinute))
        }
        present(picker, animated: true)
    }

    /// "1:8.00-18.00/3:8.00-18.00" — day index first, Sunday is 0.
    private func deliveryDaysParam() -> String {
        deliveryDayRows
            .filter { $0.isSelected && !$0.openText.isEmpty && !$0.closeText.isEmpty }
            .map { "\($0.dayIndex):\($0.openText)-\($0.closeText)" }
            .joined(separator: "/")
    }

    @objc private func pickPayment() {
        let sheet = UIAlertController(title: "Preferred Payment Method", message: nil, preferredStyle: .actionSheet)
        for (i, label) in paymentLabels.enumerated() {
            sheet.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                self?.paymentMethodValue = self?.paymentValues[i]
                self?.setPickerTitle(self!.paymentButton, label)
            })
        }
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        present(sheet, animated: true)
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

        stack.addArrangedSubview(UILabel.make("Benefits", font: AppFonts.semibold(16), color: AppColors.topTitle))
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
        for t in terms {
            stack.addArrangedSubview(termRow(t))
        }
        return stack
    }

    private func termRow(_ text: String) -> UIView {
        // .custom (not .system) so there's no tinted highlight background drawn
        // around the box when selected — just the checkbox glyph itself. Per-state
        // colours (alwaysOriginal): gray empty square / purple filled check (Android parity).
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
            self.traderTypes = (data.traderTypes ?? []).sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
            self.primaryCategories = (data.productCategories ?? []).filter { $0.parentId == nil }
            // The saved trader type and categories only become selectable now that the
            // lookup lists have arrived.
            self.normaliseTraderTypeSelection()
            self.renderTraderTypes()
            self.renderCategoryChips()
        }
    }

    /// The API stores trader_type as a numeric id on some records and as a slug on others.
    /// Resolve whichever came back to the slug the cards are keyed by.
    private func normaliseTraderTypeSelection() {
        let saved = (selectedTraderTypeSlug ?? "").trimmingCharacters(in: .whitespaces)
        guard !saved.isEmpty else { return }
        if let match = traderTypes.first(where: {
            $0.slug?.caseInsensitiveCompare(saved) == .orderedSame || String($0.id) == saved
        }) {
            selectedTraderTypeSlug = match.slug
        }
    }

    // MARK: - Submit

    private var submitLabel: String { isEditMode ? S.saveChangesButton : S.registerButton }

    private func submit() {
        var form: [String: String] = [:]
        if let id = editingTrader?.id { form["id"] = id }

        form["first_name"] = text(firstNameField)
        form["last_name"] = text(lastNameField)
        form["id_number"] = text(idNumberField)
        form["passport_number"] = text(passportField)
        form["mobile_number"] = fullPhone(ownerCountry, ownerMobileField)
        form["email"] = text(ownerEmailField)
        form["business_name"] = text(businessNameField)
        form["trading_name"] = text(tradingNameField)
        form["business_registration_number"] = text(businessRegField)
        form["business_phone_number"] = fullPhone(businessCountry, businessPhoneField)
        form["business_email"] = text(businessEmailField)
        form["trader_type"] = selectedTraderTypeSlug ?? ""
        form["primary_product_category_ids"] = selectedCategoryIds.map(String.init).joined(separator: ",")
        form["address"] = text(addressField)
        if let coord = pickedCoordinate {
            form["latitude"] = String(coord.latitude)
            form["longitude"] = String(coord.longitude)
        }
        // This is the distributor portal: the trader belongs to us and nobody else.
        let distributorId = resolveDistributorId()
        if !distributorId.isEmpty { form["preferred_distributor_ids"] = distributorId }
        form["preferred_delivery_days"] = deliveryDaysParam()
        if let payment = paymentMethodValue { form["payment_method"] = payment }
        // Blank on an edit means "keep the current password", so only send a real value.
        let password = passwordField.text ?? ""
        if !password.isEmpty { form["password"] = password }
        form["create_wallet"] = createWalletNow ? "1" : "0"

        var files: [Http.FilePart] = docFiles.map { key, value in
            Http.FilePart(field: key, fileName: value.name, mimeType: value.mime, data: value.data)
        }
        if let logo = logoData {
            files.append(Http.FilePart(field: "company_logo", fileName: "company_logo.jpg",
                                       mimeType: "image/jpeg", data: logo))
        }

        continueButton.isEnabled = false
        continueButton.setTitle(isEditMode ? S.saving : S.registering, for: .normal)

        let completion: (Result<CreateTraderData, ApiError>) -> Void = { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                // Pop straight back to the Traders list; it shows a non-blocking
                // success banner once it reappears (see TradersViewController).
                self.onSaved?()
                self.navigationController?.popViewController(animated: true)
            case .failure(let error):
                self.continueButton.isEnabled = true
                self.continueButton.setTitle(self.submitLabel, for: .normal)
                self.toast(error.message)
            }
        }

        if isEditMode {
            ApiClient.shared.updateTrader(form: form, files: files, completion: completion)
        } else {
            ApiClient.shared.createTrader(form: form, files: files, completion: completion)
        }
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

    // MARK: - Country pickers

    private enum PhoneKind { case owner, business }

    private func phoneGroup(_ label: String, country kind: PhoneKind, field: UITextField) -> UIStackView {
        let title = UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textPrimary)

        let button = kind == .owner ? ownerCountryButton : businessCountryButton
        configureCountryButton(button, country: kind == .owner ? ownerCountry : businessCountry)
        button.addAction(UIAction { [weak self] _ in self?.pickCountry(kind) }, for: .touchUpInside)

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

    private func pickCountry(_ kind: PhoneKind) {
        let picker = CountryPickerViewController()
        picker.onSelect = { [weak self] country in
            guard let self = self else { return }
            switch kind {
            case .owner:
                self.ownerCountry = country
                self.configureCountryButton(self.ownerCountryButton, country: country)
            case .business:
                self.businessCountry = country
                self.configureCountryButton(self.businessCountryButton, country: country)
            }
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
        UILabel.make(text, font: AppFonts.semibold(18), color: AppColors.topTitle, lines: 0)
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
        // Leave room on the right for the trailing chevron accessory below.
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 34)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.regular(AppMetrics.textBody); return out
        }
        button.configuration = config
        button.contentHorizontalAlignment = .leading
        button.constrainHeight(48)

        // A small chevron pinned to the right edge. (The configuration's own image sits
        // right after the title, so on a full-width field it lands mid-row instead.)
        let chevron = UIImageView(image: UIImage(systemName: "chevron.down",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
        chevron.tintColor = AppColors.textSecondary
        chevron.isUserInteractionEnabled = false
        chevron.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(chevron)
        NSLayoutConstraint.activate([
            chevron.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12),
            chevron.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
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

private extension UIButton {
    /// Sets the title colour whether the button uses a configuration or legacy styling.
    func setTitleColorCompat(_ color: UIColor) {
        if configuration != nil {
            configuration?.baseForegroundColor = color
        } else {
            setTitleColor(color, for: .normal)
        }
    }

    func contentEdgeInsetsCompat(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        if configuration != nil {
            configuration?.contentInsets = NSDirectionalEdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
        } else {
            contentEdgeInsets = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        }
    }
}

// MARK: - Time wheel

/// A compact 24-hour time picker sheet, used for the delivery-day opening hours on
/// step 6. A plain `UIDatePicker` in a sheet keeps the wheel laid out by UIKit instead
/// of stuffing it into a `UIAlertController`, which Apple does not support.
private final class TimeWheelViewController: UIViewController {

    var onPick: ((Int, Int) -> Void)?

    private let picker = UIDatePicker()
    private let initialHour: Int
    private let initialMinute: Int

    init(hour: Int, minute: Int) {
        initialHour = hour
        initialMinute = minute
        super.init(nibName: nil, bundle: nil)
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

        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        picker.minuteInterval = 15
        // en_GB forces the 24-hour wheel the "8.00-18.00" format is written in.
        picker.locale = Locale(identifier: "en_GB")
        var components = DateComponents()
        components.hour = initialHour
        components.minute = initialMinute
        if let date = Calendar.current.date(from: components) { picker.date = date }

        let cancel = UIButton(type: .system)
        cancel.setTitle(S.cancel, for: .normal)
        StyleKit.styleOutlinedButton(cancel)
        cancel.configuration?.baseForegroundColor = AppColors.textPrimary
        cancel.configuration?.background.strokeColor = AppColors.border
        cancel.constrainHeight(46)
        cancel.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)

        let set = UIButton(type: .system)
        set.setTitle("Set time", for: .normal)
        StyleKit.stylePrimaryButton(set)
        set.constrainHeight(46)
        set.addAction(UIAction { [weak self] _ in self?.confirm() }, for: .touchUpInside)

        let buttons = UIStackView.horizontal(spacing: 12, alignment: .fill)
        buttons.distribution = .fillEqually
        buttons.addArrangedSubview(cancel)
        buttons.addArrangedSubview(set)

        let stack = UIStackView.vertical(spacing: 16, alignment: .fill)
        stack.addArrangedSubview(UILabel.make("Select time", font: AppFonts.bold(16),
                                              color: AppColors.textPrimary, align: .center))
        stack.addArrangedSubview(picker)
        stack.addArrangedSubview(buttons)
        stack.forAutoLayout()
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func confirm() {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: picker.date)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        dismiss(animated: true) { [weak self] in self?.onPick?(hour, minute) }
    }
}
