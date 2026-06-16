import UIKit
import GoogleMaps
import CoreLocation
import UniformTypeIdentifiers
import PhotosUI

/// Port of CreateTraderActivity — the 8-step "Add New Trader" wizard wired to
/// /api/distributor/traders/create.
///
/// Steps: 1 Owner · 2 Business · 3 Trader · 4 Location · 5 Verify ·
///        6 Distributor · 7 Wallet · 8 Terms.
///
/// All step stacks stay in the view hierarchy (just hidden), so every field keeps
/// its value when navigating back and forth. Lookup data comes from
/// `ApiClient.getReference`; the map uses Google Maps (parity with AddEditStore).
final class CreateTraderViewController: BaseSecondaryViewController, GMSMapViewDelegate,
    UIDocumentPickerDelegate, PHPickerViewControllerDelegate, UITableViewDataSource, UITableViewDelegate {

    var onSaved: (() -> Void)?

    override var screenTitle: String { S.addNewTrader }
    override var screenSubtitle: String? { S.createTraderSubtitle }

    private let stepKeys = [S.stepOwner, S.stepBusiness, S.stepTrader, S.stepLocation,
                            S.stepVerify, S.stepDistributor, S.stepWallet, S.stepTerms]
    private let stepTrader = 2, stepLocation = 3, stepVerify = 4, stepTerms = 7
    private var currentStep = 0

    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let paymentLabels = ["Wallet", "EFT", "Cash", "Card"]
    private let paymentValues = ["wallet", "eft", "cash", "card"]

    // Chrome
    private let stepperScroll = UIScrollView()
    private let stepperStack = UIStackView.horizontal(spacing: 0, alignment: .center)
    private var stepCircles: [UILabel] = []
    private var stepTitles: [UILabel] = []
    private let formScroll = UIScrollView()
    private let continueButton = GradientButton(title: S.continueButton)
    private var stepStacks: [UIStackView] = []

    // Reference data
    private var traderTypes: [ReferenceData.TraderType] = []
    private var primaryCategories: [ReferenceData.ProductCategory] = []
    private var distributors: [ReferenceData.Distributor] = []

    // Selections
    private var selectedTraderTypeSlug: String?
    private var traderTypeCards: [UIView] = []
    private var selectedCategoryIds: [Int64] = []
    private var selectedDistributorIds: [Int64] = []
    private var selectedDays: [String] = []
    private var paymentMethodValue: String?
    private var createWalletNow = true

    // Owner / Business fields
    private let firstNameField = UITextField()
    private let lastNameField = UITextField()
    private let idNumberField = UITextField()
    private let passportField = UITextField()
    private let ownerEmailField = UITextField()
    private let businessNameField = UITextField()
    private let tradingNameField = UITextField()
    private let businessRegField = UITextField()
    private let businessEmailField = UITextField()

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
    private let distributorHint = UILabel.make(S.selectDistributorsHint, font: AppFonts.regular(13), color: AppColors.textSecondary)
    private let distributorChipsScroll = UIScrollView()
    private let distributorChips = UIStackView.horizontal(spacing: 8, alignment: .center)
    private let deliveryDaysStack = UIStackView.horizontal(spacing: 8, alignment: .center)
    private let paymentButton = UIButton(type: .system)

    // Wallet
    private let walletNowRadio = UIImageView()
    private let walletLaterRadio = UIImageView()

    // Terms
    private var termCheckboxes: [UIButton] = []

    // Documents
    private struct DocDef { let key, title, sub: String; let required: Bool }
    private let docDefs: [DocDef] = [
        DocDef(key: "business_registration_document", title: "Business Registration Document", sub: "CIPC, Business Permit, etc.", required: true),
        DocDef(key: "owner_id_document", title: "Owner ID Document", sub: "ID or Passport", required: true),
        DocDef(key: "proof_of_address", title: "Proof of Address", sub: "Municipal bill, Lease, etc.", required: true),
        DocDef(key: "store_front_photo", title: "Store Front Photo", sub: "Clear photo of your store", required: true),
        DocDef(key: "store_interior_photo", title: "Store Interior Photo", sub: "Inside view of your store", required: true),
        DocDef(key: "additional_documents", title: "Additional Documents", sub: "(If any)", required: false)
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
        showStep(0)
    }

    override func loadData() { loadReference() }

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
        continueButton.setTitle(index == stepTerms ? S.registerButton : S.continueButton, for: .normal)
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
            return true
        case 1:
            if text(businessNameField).isEmpty { return fail("Please enter the business name.") }
            return true
        case stepTrader:
            if selectedTraderTypeSlug == nil { return fail("Please select a trader classification.") }
            return true
        case stepLocation:
            if pickedCoordinate == nil { return fail("Please select your business location on the map.") }
            return true
        case stepVerify:
            for d in docDefs where d.required && docFiles[d.key] == nil {
                return fail("Please upload all required documents.")
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
        infoBox.addArrangedSubview(UILabel.make("Owner contact", font: AppFonts.bold(13), color: AppColors.info))
        infoBox.addArrangedSubview(UILabel.make("Provide the owner's mobile number and email address for verification and account communication.",
                                                font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 0))
        stack.addArrangedSubview(infoBox)

        stack.addArrangedSubview(phoneGroup("Mobile Number", country: .owner, field: ownerMobileField))
        stack.addArrangedSubview(fieldGroup("Email Address", ownerEmailField, placeholder: "Enter email address", keyboard: .emailAddress))
        return stack
    }

    // MARK: - Step 2: Business

    private func buildBusinessStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Business Information"))
        stack.addArrangedSubview(subtitle("Tell us about your business."))
        stack.addArrangedSubview(fieldGroup("Business Name", businessNameField, placeholder: "Enter business name"))
        stack.addArrangedSubview(fieldGroup("Trading Name", tradingNameField, placeholder: "Enter trading name"))
        stack.addArrangedSubview(fieldGroup("Business Registration Number (Optional)", businessRegField, placeholder: "Enter registration number"))
        stack.addArrangedSubview(phoneGroup("Business Phone Number", country: .business, field: businessPhoneField))
        stack.addArrangedSubview(fieldGroup("Business Email Address", businessEmailField, placeholder: "Enter business email", keyboard: .emailAddress))
        return stack
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
            guard let self = self, let image = object as? UIImage,
                  // Downscale + compress so KYC photos upload quickly (avoids the
                  // multipart request timing out on large full-resolution images).
                  let data = Self.downscaledJpeg(image, maxDimension: 1440, quality: 0.6) else {
                DispatchQueue.main.async { self?.pendingDocKey = nil }
                return
            }
            DispatchQueue.main.async {
                self.applyPickedFile(key: key, data: data, name: suggested + ".jpg", mime: "image/jpeg")
                self.pendingDocKey = nil
            }
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
        stack.addArrangedSubview(subtitle("Choose the distributor you want to work with."))
        stack.addArrangedSubview(UILabel.make("Preferred Distributors", font: AppFonts.bold(16), color: AppColors.purpleDark))

        let distField = tappableField()
        distField.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(pickDistributors)))
        let distStack = UIStackView.vertical(spacing: 6, alignment: .fill)
        distStack.isLayoutMarginsRelativeArrangement = true
        distStack.layoutMargins = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        distStack.addArrangedSubview(distributorHint)
        distributorChipsScroll.showsHorizontalScrollIndicator = false
        distributorChips.forAutoLayout()
        distributorChipsScroll.addSubview(distributorChips)
        distributorChips.pinEdges(to: distributorChipsScroll)
        distributorChips.heightAnchor.constraint(equalTo: distributorChipsScroll.heightAnchor).isActive = true
        distributorChipsScroll.heightAnchor.constraint(equalToConstant: 30).isActive = true
        distributorChipsScroll.isHidden = true
        distStack.addArrangedSubview(distributorChipsScroll)
        distField.addSubview(distStack)
        distStack.forAutoLayout()
        distStack.pinEdges(to: distField)
        stack.addArrangedSubview(distField)

        stack.addArrangedSubview(UILabel.make("Preferred Delivery Days (Select all that apply)", font: AppFonts.regular(13), color: AppColors.textPrimary))
        let daysScroll = UIScrollView()
        daysScroll.showsHorizontalScrollIndicator = false
        deliveryDaysStack.forAutoLayout()
        daysScroll.addSubview(deliveryDaysStack)
        deliveryDaysStack.pinEdges(to: daysScroll)
        deliveryDaysStack.heightAnchor.constraint(equalTo: daysScroll.heightAnchor).isActive = true
        daysScroll.heightAnchor.constraint(equalToConstant: 38).isActive = true
        buildDeliveryDayChips()
        stack.addArrangedSubview(daysScroll)

        stack.addArrangedSubview(UILabel.make("Preferred Payment Method", font: AppFonts.regular(13), color: AppColors.textPrimary))
        configurePickerButton(paymentButton, placeholder: "Select payment method")
        paymentButton.addTarget(self, action: #selector(pickPayment), for: .touchUpInside)
        stack.addArrangedSubview(paymentButton)
        return stack
    }

    private func buildDeliveryDayChips() {
        for day in dayLabels {
            let chip = PaddingLabel(insets: UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
            chip.text = day
            chip.font = AppFonts.regular(13)
            chip.textColor = AppColors.textSecondary
            chip.backgroundColor = AppColors.surface
            chip.layer.cornerRadius = 16
            chip.layer.borderWidth = 1
            chip.layer.borderColor = AppColors.border.cgColor
            chip.layer.masksToBounds = true
            chip.isUserInteractionEnabled = true
            chip.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleDay(_:))))
            deliveryDaysStack.addArrangedSubview(chip)
        }
    }

    @objc private func toggleDay(_ gesture: UITapGestureRecognizer) {
        guard let chip = gesture.view as? PaddingLabel, let day = chip.text else { return }
        if let idx = selectedDays.firstIndex(of: day) {
            selectedDays.remove(at: idx)
            chip.textColor = AppColors.textSecondary
            chip.backgroundColor = AppColors.surface
            chip.layer.borderColor = AppColors.border.cgColor
        } else {
            selectedDays.append(day)
            chip.textColor = AppColors.purplePrimary
            chip.backgroundColor = AppColors.purpleLight
            chip.layer.borderColor = AppColors.purplePrimary.cgColor
        }
    }

    @objc private func pickDistributors() {
        guard !distributors.isEmpty else { return }
        let options = distributors.map { $0.displayName }
        let preselected = Set(distributors.enumerated()
            .filter { selectedDistributorIds.contains($0.element.id) }.map { $0.offset })
        let picker = MultiSelectViewController(title: "Preferred Distributors", options: options, selected: preselected) { [weak self] indices in
            guard let self = self else { return }
            self.selectedDistributorIds = indices.sorted().map { self.distributors[$0].id }
            self.renderDistributorChips()
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }

    private func renderDistributorChips() {
        distributorChips.arrangedSubviews.forEach { $0.removeFromSuperview() }
        distributorHint.isHidden = !selectedDistributorIds.isEmpty
        distributorChipsScroll.isHidden = selectedDistributorIds.isEmpty
        for dist in distributors where selectedDistributorIds.contains(dist.id) {
            distributorChips.addArrangedSubview(removableChip(dist.displayName) { [weak self] in
                self?.selectedDistributorIds.removeAll { $0 == dist.id }
                self?.renderDistributorChips()
            })
        }
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
            self.distributors = data.distributors ?? []
            self.primaryCategories = (data.productCategories ?? []).filter { $0.parentId == nil }
            self.renderTraderTypes()
        }
    }

    // MARK: - Submit

    private func submit() {
        var form: [String: String] = [:]
        form["first_name"] = text(firstNameField)
        form["last_name"] = text(lastNameField)
        form["id_number"] = text(idNumberField)
        form["passport_number"] = text(passportField)
        form["mobile_number"] = fullPhone(ownerCountry, ownerMobileField)
        form["email_address"] = text(ownerEmailField)
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
        form["preferred_distributor_ids"] = selectedDistributorIds.map(String.init).joined(separator: ",")
        if let first = selectedDistributorIds.first { form["recommended_distributor"] = String(first) }
        form["preferred_delivery_days"] = selectedDays.joined(separator: ",")
        if let payment = paymentMethodValue { form["payment_method"] = payment }
        form["create_wallet"] = createWalletNow ? "1" : "0"

        //let files: [Http.FilePart] = []
        let files: [Http.FilePart] = docFiles.map { key, value in
            Http.FilePart(field: key, fileName: value.name, mimeType: value.mime, data: value.data)
        }

        continueButton.isEnabled = false
        continueButton.setTitle(S.registering, for: .normal)
        ApiClient.shared.createTrader(form: form, files: files) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                // Pop straight back to the Traders list; it shows a non-blocking
                // success banner once it reappears (see TradersViewController).
                self.onSaved?()
                self.navigationController?.popViewController(animated: true)
            case .failure(let error):
                self.continueButton.isEnabled = true
                self.continueButton.setTitle(S.registerButton, for: .normal)
                self.toast(error.message)
            }
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
