import UIKit
import GoogleMaps
import CoreLocation
import UniformTypeIdentifiers
import PhotosUI

/// Port of CreatePromotionActivity — the 7-step "Create Ads & Promotion" wizard wired to
/// /api/distributor/promotions/{create,update,upload-media}.
///
/// Steps: 1 Type · 2 Details · 3 Targeting · 4 Creative · 5 Products · 6 Budget · 7 Review.
///
/// All step stacks stay in the hierarchy (just hidden) so fields survive back/forward
/// navigation. Trader segments come from `ApiClient.getReference` (traderTypes), the product
/// catalogue from `ApiClient.getProducts`. Media is uploaded through the dedicated
/// upload-media endpoint after the record exists (the API's recommendation for large files).
final class CreatePromotionViewController: BaseSecondaryViewController, GMSMapViewDelegate,
    UIDocumentPickerDelegate, PHPickerViewControllerDelegate, UITableViewDataSource, UITableViewDelegate {

    /// Invoked on success with the banner message to show on the list screen.
    var onSaved: ((String) -> Void)?

    private let editPromotionId: String?

    init(promotionId: String? = nil) {
        self.editPromotionId = promotionId
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var screenTitle: String { editPromotionId == nil ? S.createPromotionTitle : S.editPromotionTitle }
    override var screenSubtitle: String? { S.createPromotionSubtitle }

    // MARK: - Static catalogue

    private let stepKeys = ["Type", "Details", "Targeting", "Creative", "Products", "Budget", "Review"]
    private let stepTargeting = 2, stepProducts = 4, stepBudget = 5, stepReview = 6
    private var currentStep = 0

    private let typeValues = ["best_deal", "cant_miss_deal", "exclusive_deal", "featured_store",
                              "promotion", "post", "story"]
    private let typeLabels = ["Best Deal", "Can't Miss Deal", "Exclusive Deal", "Featured Store",
                              "Promotion", "Post", "Story"]
    private let typeDescs = [
        "Promote price drops and great value offers.",
        "Premium hero placement on homepage.",
        "Exclusive offers available only from you.",
        "Highlight your store to drive more orders.",
        "Discounts, bundles and special offers.",
        "Share news, updates and product highlights.",
        "Short, engaging stories that drive attention."]
    private let typeIconSymbols = ["gift.fill", "flame.fill", "crown.fill", "storefront.fill",
                                   "tag.fill", "doc.text.fill", "iphone"]
    private let typeIconBgColors = [AppColors.dangerBg, AppColors.purpleLight, AppColors.purpleLight,
                                    AppColors.successBg, AppColors.warningBg, AppColors.infoBg, AppColors.purpleLight]
    private let typeIconTints = [AppColors.danger, AppColors.purplePrimary, AppColors.purplePrimary,
                                 AppColors.success, AppColors.warning, AppColors.info, AppColors.purplePrimary]

    private let typeCardTitleTag = 100

    private let objectiveValues = ["awareness", "traffic", "sales", "new_product_launch", "clear_inventory"]
    private let objectiveLabels = ["Awareness", "Traffic", "Sales", "New Product Launch", "Clear Inventory"]

    private static let maxUploadBytes = 5 * 1024 * 1024

    // MARK: - State

    private var typeLocked = false
    private var selectedTypeValue: String?
    private var typeCards: [UIView] = []

    private var selectedObjectiveValue: String?
    private var startDate = ""   // yyyy-MM-dd
    private var endDate = ""

    private var segments: [ReferenceData.TraderType] = []
    private var selectedSegmentIds: [Int64] = []

    private var pickedCoordinate: CLLocationCoordinate2D?
    private var pickedPlaceId = ""
    private var marker: GMSMarker?

    private var bannerData: Data?
    private var videoData: Data?
    private var videoName: String?
    private var bannerExistingUrl: String?
    private var videoExisting = false
    private var pickingVideo = false

    private var catalogue: [PromoProduct] = []
    private var singleLines: [ProductLine] = []
    private var comboDeals: [ComboDeal] = []
    private var b1g1Deals: [B1G1Deal] = []

    // MARK: - Chrome

    private let stepperScroll = UIScrollView()
    private let stepperStack = UIStackView.horizontal(spacing: 0, alignment: .center)
    private var stepCircles: [UILabel] = []
    private var stepTitles: [UILabel] = []
    private let formScroll = UIScrollView()
    private let continueButton = GradientButton(title: S.continueButton, style: .primary)
    private var stepStacks: [UIStackView] = []

    // Step 2 fields
    private let nameField = UITextField()
    private let objectiveButton = UIButton(type: .system)
    private let startDateButton = UIButton(type: .system)
    private let endDateButton = UIButton(type: .system)
    private let budgetField = UITextField()
    private let dailyBudgetField = UITextField()
    private let descriptionView = UITextView()

    // Step 3 location + segments
    private let addressField = UITextField()
    private let addressResultsTable = UITableView(frame: .zero, style: .plain)
    private var addressResultsHeight: NSLayoutConstraint!
    private var predictions: [AutocompleteData.Prediction] = []
    private var autocompleteWorkItem: DispatchWorkItem?
    private var suppressAddressChange = false
    private let mapContainer = UIView()
    private lazy var mapView: GMSMapView = makeMapView()
    private var didWireMapScroll = false
    private let segmentHint = UILabel.make("Tap to select trader segments", font: AppFonts.regular(13), color: AppColors.textSecondary)
    private let segmentChipsScroll = UIScrollView()
    private let segmentChips = UIStackView.horizontal(spacing: 8, alignment: .center)

    // Step 4 creative
    private let tabImage = UIButton(type: .system)
    private let tabVideo = UIButton(type: .system)
    private let imageUploadBox = UIView()
    private let videoUploadBox = UIView()
    private let imagePreview = UIImageView()
    private let imagePlaceholder = UILabel.make("Tap to upload a banner image", font: AppFonts.regular(13), color: AppColors.textSecondary, align: .center)
    private let videoLabel = UILabel.make("Tap to upload a video", font: AppFonts.regular(13), color: AppColors.textSecondary, align: .center)

    // Step 5 products
    private let singleHeader = UILabel.make("Single Products (0)", font: AppFonts.bold(14), color: AppColors.textPrimary)
    private let comboHeader = UILabel.make("Combo Deals (0)", font: AppFonts.bold(14), color: AppColors.textPrimary)
    private let b1g1Header = UILabel.make("Buy1Get1 Free Deals (0)", font: AppFonts.bold(14), color: AppColors.textPrimary)
    private let singleContainer = UIStackView.vertical(spacing: 8, alignment: .fill)
    private let comboContainer = UIStackView.vertical(spacing: 8, alignment: .fill)
    private let b1g1Container = UIStackView.vertical(spacing: 8, alignment: .fill)

    // Step 6 budget
    private let budgetTotalLabel = UILabel.make("R0", font: AppFonts.bold(15), color: AppColors.textPrimary, align: .right)
    private let budgetDailyLabel = UILabel.make("R0", font: AppFonts.bold(15), color: AppColors.textPrimary, align: .right)
    private let budgetDurationLabel = UILabel.make("-", font: AppFonts.bold(13), color: AppColors.textPrimary, align: .right, lines: 0)
    private let budgetProductsLabel = UILabel.make("R0", font: AppFonts.bold(15), color: AppColors.textPrimary, align: .right)
    private let budgetBreakdownLabel = UILabel.make("", font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 0)
    private let estimateCard = UIStackView.vertical(spacing: 0, alignment: .fill)

    // Step 7 review
    private let reviewCard = UIStackView.vertical(spacing: 0, alignment: .fill)

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
        formScroll.keyboardDismissMode = .interactive
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

        stepStacks = [buildTypeStep(), buildDetailsStep(), buildTargetingStep(), buildCreativeStep(),
                      buildProductsStep(), buildBudgetStep(), buildReviewStep()]
        for step in stepStacks {
            step.isLayoutMarginsRelativeArrangement = true
            step.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
            formStack.addArrangedSubview(step)
        }
        showStep(0)
    }

    override func loadData() {
        loadReference()
        loadCatalogue()
        if editPromotionId != nil { loadPromotionForEdit() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didWireMapScroll else { return }
        didWireMapScroll = true
        wireMapScrollBehavior()
    }

    // MARK: - Stepper (port of CreateTrader)

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
                circle.layer.borderWidth = 0
                title.textColor = AppColors.textPrimary
                title.font = AppFonts.regular(13)
            } else if i == currentStep {
                circle.backgroundColor = AppColors.purplePrimary
                circle.textColor = .white
                circle.text = "\(i + 1)"
                circle.layer.borderWidth = 0
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
        styleContinueButton()
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

    // MARK: - Bottom bar

    /// Matches Android btnContinue — 14sp label with 20dp horizontal padding.
    private func styleContinueButton() {
        continueButton.titleLabel?.font = AppFonts.bold(14)
        continueButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
    }

    private func updateContinueButtonTitle(for step: Int) {
        continueButton.setTitle(step == stepReview ? S.promoSubmit : S.continueButton, for: .normal)
    }

    // MARK: - Navigation

    @objc private func goBack() {
        if currentStep == 0 { navigationController?.popViewController(animated: true) }
        else { showStep(currentStep - 1) }
    }

    @objc private func goContinue() {
        guard validateStep(currentStep) else { return }
        if currentStep == stepReview { submit(status: "pending_approval") }
        else { showStep(currentStep + 1) }
    }

    private func showStep(_ index: Int) {
        currentStep = index
        for (i, step) in stepStacks.enumerated() { step.isHidden = i != index }
        updateContinueButtonTitle(for: index)
        if index == stepBudget { buildBudget() }
        else if index == stepReview { buildReview() }
        renderStepper()
        view.endEditing(true)
        formScroll.setContentOffset(.zero, animated: false)
        scrollStepperTo(index)
    }

    private func scrollStepperTo(_ index: Int) {
        guard stepTitles.indices.contains(index) else { return }
        let item = stepTitles[index]
        stepperScroll.layoutIfNeeded()
        let target = max(0, item.convert(item.bounds, to: stepperStack).minX - 40)
        stepperScroll.setContentOffset(CGPoint(x: min(target, max(0, stepperStack.bounds.width - stepperScroll.bounds.width)), y: 0), animated: true)
    }

    // MARK: - Validation

    private func validateStep(_ step: Int) -> Bool {
        switch step {
        case 0:
            if selectedTypeValue == nil { return fail("Please choose a campaign type.") }
            return true
        case 1:
            if text(nameField).isEmpty { return fail("Enter a campaign name.") }
            if selectedObjectiveValue == nil { return fail("Select a campaign objective.") }
            if startDate.isEmpty || endDate.isEmpty { return fail("Select start and end dates.") }
            if text(budgetField).isEmpty { return fail("Enter a budget.") }
            return true
        case stepTargeting:
            if pickedCoordinate == nil { return fail("Search an address or drop a pin on the map.") }
            if selectedSegmentIds.isEmpty { return fail("Select at least one trader segment.") }
            return true
        case stepProducts:
            if singleLines.isEmpty && comboDeals.isEmpty && b1g1Deals.isEmpty {
                return fail("Add at least one product to continue.")
            }
            return true
        default:
            return true
        }
    }

    @discardableResult
    private func fail(_ message: String) -> Bool { toast(message); return false }

    // MARK: - Step 1: Type

    private func buildTypeStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 4, alignment: .fill)
        stack.addArrangedSubview(UILabel.make(S.promoStepTypeTitle, font: AppFonts.bold(16), color: AppColors.topTitle, lines: 0))
        let sub = UILabel.make(S.promoStepTypeSub, font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 0)
        stack.addArrangedSubview(sub)
        stack.setCustomSpacing(16, after: sub)

        let grid = UIStackView.vertical(spacing: 10, alignment: .fill)
        var row: UIStackView?
        for (index, _) in typeValues.enumerated() {
            if index % 2 == 0 {
                row = UIStackView.horizontal(spacing: 10, alignment: .fill)
                row?.distribution = .fillEqually
                grid.addArrangedSubview(row!)
            }
            let card = typeCard(index)
            typeCards.append(card)
            row?.addArrangedSubview(card)
        }
        if typeValues.count % 2 == 1 { row?.addArrangedSubview(UIView()) }
        stack.addArrangedSubview(grid)
        return stack
    }

    private func typeCard(_ index: Int) -> UIView {
        let card = UIView()
        card.layer.cornerRadius = AppMetrics.radiusLG
        card.layer.borderWidth = 1
        card.layer.borderColor = AppColors.border.cgColor
        card.backgroundColor = AppColors.surface
        card.isUserInteractionEnabled = true
        card.tag = index
        card.forAutoLayout()
        card.heightAnchor.constraint(greaterThanOrEqualToConstant: 148).isActive = true

        let tile = StyleKit.iconTile(color: typeIconBgColors[index])
        tile.constrainSize(40)
        let icon = UIImageView(image: UIImage(systemName: typeIconSymbols[index]))
        icon.tintColor = typeIconTints[index]
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        tile.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22)
        ])

        let title = UILabel.make(typeLabels[index], font: AppFonts.bold(AppMetrics.textTitle),
                                 color: AppColors.topTitle, align: .center, lines: 2)
        title.tag = typeCardTitleTag
        let desc = UILabel.make(typeDescs[index], font: AppFonts.regular(AppMetrics.textLabel),
                                color: AppColors.textSecondary, align: .center, lines: 0)

        let inner = UIStackView.vertical(spacing: 0, alignment: .center)
        inner.forAutoLayout()
        inner.addArrangedSubview(tile)
        inner.setCustomSpacing(10, after: tile)
        inner.addArrangedSubview(title)
        inner.setCustomSpacing(4, after: title)
        inner.addArrangedSubview(desc)
        card.addSubview(inner)
        inner.pinEdges(to: card, insets: UIEdgeInsets(top: 18, left: 12, bottom: 18, right: 12))
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(typeTapped(_:))))
        return card
    }

    @objc private func typeTapped(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag else { return }
        if typeLocked { toast(S.promoTypeLocked); return }
        selectedTypeValue = typeValues[index]
        applyTypeSelection()
    }

    private func applyTypeSelection() {
        for (i, card) in typeCards.enumerated() {
            let selected = typeValues[i] == selectedTypeValue
            card.backgroundColor = selected ? AppColors.purpleLight : AppColors.surface
            card.layer.borderColor = (selected ? AppColors.purplePrimary : AppColors.border).cgColor
            card.layer.borderWidth = selected ? 1.5 : 1
            card.alpha = (typeLocked && !selected) ? 0.4 : 1
            (card.viewWithTag(typeCardTitleTag) as? UILabel)?.textColor = selected ? AppColors.purplePrimary : AppColors.topTitle
        }
    }

    // MARK: - Step 2: Details

    private func buildDetailsStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Campaign Details"))
        stack.addArrangedSubview(subtitle("Name your campaign and set the schedule."))
        stack.addArrangedSubview(fieldGroup("Campaign Name", nameField, placeholder: "e.g. Winter Mega Sale"))

        stack.addArrangedSubview(UILabel.make("Campaign Objective", font: AppFonts.regular(13), color: AppColors.textPrimary))
        configurePickerButton(objectiveButton, placeholder: "Select an objective")
        objectiveButton.addTarget(self, action: #selector(pickObjective), for: .touchUpInside)
        stack.addArrangedSubview(objectiveButton)

        let dateRow = UIStackView.horizontal(spacing: 12, alignment: .fill)
        dateRow.distribution = .fillEqually
        dateRow.addArrangedSubview(dateColumn("Start Date", startDateButton, isStart: true))
        dateRow.addArrangedSubview(dateColumn("End Date", endDateButton, isStart: false))
        stack.addArrangedSubview(dateRow)

        let budgetRow = UIStackView.horizontal(spacing: 12, alignment: .fill)
        budgetRow.distribution = .fillEqually
        budgetRow.addArrangedSubview(fieldGroup("Total Budget (R)", budgetField, placeholder: "0.00", keyboard: .decimalPad))
        budgetRow.addArrangedSubview(fieldGroup("Daily Budget (R)", dailyBudgetField, placeholder: "0.00", keyboard: .decimalPad))
        stack.addArrangedSubview(budgetRow)

        stack.addArrangedSubview(UILabel.make("Description (Optional)", font: AppFonts.regular(13), color: AppColors.textPrimary))
        descriptionView.font = AppFonts.regular(14)
        descriptionView.textColor = AppColors.textPrimary
        descriptionView.backgroundColor = AppColors.surface
        descriptionView.layer.cornerRadius = AppMetrics.radiusMD
        descriptionView.layer.borderWidth = 1
        descriptionView.layer.borderColor = AppColors.border.cgColor
        descriptionView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        descriptionView.constrainHeight(96)
        stack.addArrangedSubview(descriptionView)
        return stack
    }

    private func dateColumn(_ label: String, _ button: UIButton, isStart: Bool) -> UIStackView {
        configurePickerButton(button, placeholder: "Select")
        button.addAction(UIAction { [weak self] _ in self?.pickDate(isStart: isStart) }, for: .touchUpInside)
        let col = UIStackView.vertical(spacing: 5, alignment: .fill)
        col.addArrangedSubview(UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textPrimary))
        col.addArrangedSubview(button)
        return col
    }

    @objc private func pickObjective() {
        let sheet = UIAlertController(title: S.promoObjective, message: nil, preferredStyle: .actionSheet)
        for (i, label) in objectiveLabels.enumerated() {
            sheet.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.selectedObjectiveValue = self.objectiveValues[i]
                self.setPickerTitle(self.objectiveButton, label)
            })
        }
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = objectiveButton; pop.sourceRect = objectiveButton.bounds
        }
        present(sheet, animated: true)
    }

    private func pickDate(isStart: Bool) {
        let initial = parseApiDate(isStart ? startDate : endDate) ?? Date()
        let sheet = DatePickerSheet(initial: initial) { [weak self] date in
            guard let self = self else { return }
            let api = self.apiDateString(date)
            let shown = self.displayDate(api)
            if isStart {
                self.startDate = api
                self.setPickerTitle(self.startDateButton, shown)
            } else {
                self.endDate = api
                self.setPickerTitle(self.endDateButton, shown)
            }
        }
        present(sheet, animated: true)
    }

    // MARK: - Step 3: Targeting

    private func buildTargetingStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Targeting"))
        stack.addArrangedSubview(subtitle("Choose a location and the trader segments to reach."))
        stack.addArrangedSubview(fieldGroup("Target Area", addressField, placeholder: "Search for an area or address"))
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
        mapContainer.constrainHeight(300)
        mapView.forAutoLayout()
        mapContainer.addSubview(mapView)
        mapView.pinEdges(to: mapContainer)
        stack.addArrangedSubview(mapContainer)

        stack.addArrangedSubview(sectionTitle("Trader Segments"))
        let segField = tappableField()
        segField.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(pickSegments)))
        let segStack = UIStackView.vertical(spacing: 6, alignment: .fill)
        segStack.isLayoutMarginsRelativeArrangement = true
        segStack.layoutMargins = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        segStack.addArrangedSubview(segmentHint)
        segmentChipsScroll.showsHorizontalScrollIndicator = false
        segmentChips.forAutoLayout()
        segmentChipsScroll.addSubview(segmentChips)
        segmentChips.pinEdges(to: segmentChipsScroll)
        segmentChips.heightAnchor.constraint(equalTo: segmentChipsScroll.heightAnchor).isActive = true
        segmentChipsScroll.heightAnchor.constraint(equalToConstant: 30).isActive = true
        segmentChipsScroll.isHidden = true
        segStack.addArrangedSubview(segmentChipsScroll)
        segField.addSubview(segStack)
        segStack.forAutoLayout()
        segStack.pinEdges(to: segField)
        stack.addArrangedSubview(segField)
        return stack
    }

    @objc private func pickSegments() {
        guard !segments.isEmpty else { return }
        let options = segments.map { $0.name ?? "" }
        let preselected = Set(segments.enumerated()
            .filter { selectedSegmentIds.contains($0.element.id) }.map { $0.offset })
        let picker = MultiSelectViewController(title: "Trader Segments", options: options, selected: preselected) { [weak self] indices in
            guard let self = self else { return }
            self.selectedSegmentIds = indices.sorted().map { self.segments[$0].id }
            self.renderSegmentChips()
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }

    private func renderSegmentChips() {
        segmentChips.arrangedSubviews.forEach { $0.removeFromSuperview() }
        segmentHint.isHidden = !selectedSegmentIds.isEmpty
        segmentChipsScroll.isHidden = selectedSegmentIds.isEmpty
        for seg in segments where selectedSegmentIds.contains(seg.id) {
            segmentChips.addArrangedSubview(removableChip(seg.name ?? "") { [weak self] in
                self?.selectedSegmentIds.removeAll { $0 == seg.id }
                self?.renderSegmentChips()
            })
        }
    }

    // MARK: - Step 4: Creative

    private func buildCreativeStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Creative"))
        stack.addArrangedSubview(subtitle("Upload a banner image or a short video for your campaign."))

        tabImage.setTitle("Image", for: .normal)
        tabVideo.setTitle("Video", for: .normal)
        [tabImage, tabVideo].forEach { $0.titleLabel?.font = AppFonts.bold(14) }
        tabImage.addAction(UIAction { [weak self] _ in self?.selectCreativeTab(video: false) }, for: .touchUpInside)
        tabVideo.addAction(UIAction { [weak self] _ in self?.selectCreativeTab(video: true) }, for: .touchUpInside)
        let tabs = UIStackView.horizontal(spacing: 24, alignment: .center)
        tabs.addArrangedSubview(tabImage)
        tabs.addArrangedSubview(tabVideo)
        tabs.addArrangedSubview(UIView())
        stack.addArrangedSubview(tabs)

        // Image upload box
        styleUploadBox(imageUploadBox)
        imageUploadBox.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(pickBanner)))
        imagePreview.contentMode = .scaleAspectFit
        imagePreview.clipsToBounds = true
        imagePreview.isHidden = true
        let imageInner = UIStackView.vertical(spacing: 10, alignment: .center)
        imageInner.forAutoLayout()
        let imageIcon = UIImageView(image: UIImage(systemName: "photo.on.rectangle"))
        imageIcon.tintColor = AppColors.textTertiary
        imageIcon.contentMode = .scaleAspectFit
        imageIcon.constrainSize(36)
        imageInner.addArrangedSubview(imageIcon)
        imageInner.addArrangedSubview(imagePlaceholder)
        imageInner.addArrangedSubview(imagePreview)
        imagePreview.heightAnchor.constraint(equalToConstant: 140).isActive = true
        imagePreview.widthAnchor.constraint(equalTo: imageInner.widthAnchor).isActive = true
        imageUploadBox.addSubview(imageInner)
        imageInner.pinEdges(to: imageUploadBox, insets: UIEdgeInsets(top: 24, left: 16, bottom: 24, right: 16))
        stack.addArrangedSubview(imageUploadBox)

        // Video upload box
        styleUploadBox(videoUploadBox)
        videoUploadBox.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(pickVideo)))
        let videoInner = UIStackView.vertical(spacing: 10, alignment: .center)
        videoInner.forAutoLayout()
        let videoIcon = UIImageView(image: UIImage(systemName: "video.badge.plus"))
        videoIcon.tintColor = AppColors.textTertiary
        videoIcon.contentMode = .scaleAspectFit
        videoIcon.constrainSize(36)
        videoInner.addArrangedSubview(videoIcon)
        videoInner.addArrangedSubview(videoLabel)
        videoUploadBox.addSubview(videoInner)
        videoInner.pinEdges(to: videoUploadBox, insets: UIEdgeInsets(top: 24, left: 16, bottom: 24, right: 16))
        stack.addArrangedSubview(videoUploadBox)

        stack.addArrangedSubview(subtitle("Accepted: JPG, PNG, MP4 (Max 5MB)."))
        selectCreativeTab(video: false)
        return stack
    }

    private func styleUploadBox(_ box: UIView) {
        box.backgroundColor = AppColors.surfaceVariant
        box.layer.cornerRadius = AppMetrics.radiusMD
        box.layer.borderWidth = 1.5
        box.layer.borderColor = AppColors.border.cgColor
        box.isUserInteractionEnabled = true
    }

    private func selectCreativeTab(video: Bool) {
        pickingVideo = video
        tabImage.setTitleColor(video ? AppColors.textSecondary : AppColors.purplePrimary, for: .normal)
        tabVideo.setTitleColor(video ? AppColors.purplePrimary : AppColors.textSecondary, for: .normal)
        imageUploadBox.isHidden = video
        videoUploadBox.isHidden = !video
    }

    @objc private func pickBanner() {
        pickingVideo = false
        presentMediaSheet(images: true)
    }

    @objc private func pickVideo() {
        pickingVideo = true
        presentMediaSheet(images: false)
    }

    private func presentMediaSheet(images: Bool) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: images ? "Photo Library" : "Video Library", style: .default) { [weak self] _ in
            self?.presentPhotoLibrary(images: images)
        })
        sheet.addAction(UIAlertAction(title: "Choose File", style: .default) { [weak self] _ in
            self?.presentFilePicker(images: images)
        })
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        if let pop = sheet.popoverPresentationController {
            let anchor = images ? imageUploadBox : videoUploadBox
            pop.sourceView = anchor; pop.sourceRect = anchor.bounds
        }
        present(sheet, animated: true)
    }

    private func presentPhotoLibrary(images: Bool) {
        var config = PHPickerConfiguration()
        config.filter = images ? .images : .videos
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentFilePicker(images: Bool) {
        let types: [UTType] = images ? [.image] : [.movie, .video, .mpeg4Movie]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    // MARK: - Step 5: Products

    private func buildProductsStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Products"))
        stack.addArrangedSubview(subtitle("Add the products this campaign promotes."))

        stack.addArrangedSubview(productSection(header: singleHeader, container: singleContainer,
                                                addTitle: "+ Add Single Product", action: #selector(addSingle)))
        stack.addArrangedSubview(productSection(header: comboHeader, container: comboContainer,
                                                addTitle: "+ Add Combo Deal", action: #selector(addCombo)))
        stack.addArrangedSubview(productSection(header: b1g1Header, container: b1g1Container,
                                                addTitle: "+ Add Buy1Get1 Deal", action: #selector(addB1g1)))
        renderSingle(); renderCombo(); renderB1g1()
        return stack
    }

    private func productSection(header: UILabel, container: UIStackView, addTitle: String, action: Selector) -> UIView {
        let card = StyleKit.cardView()
        let addButton = UIButton(type: .system)
        addButton.setTitle(addTitle, for: .normal)
        addButton.setTitleColor(AppColors.purplePrimary, for: .normal)
        addButton.titleLabel?.font = AppFonts.bold(13)
        addButton.setContentHuggingPriority(.required, for: .horizontal)
        addButton.addTarget(self, action: action, for: .touchUpInside)
        let head = UIStackView.horizontal(spacing: 8, alignment: .center)
        head.addArrangedSubview(header)
        head.addArrangedSubview(UIView())
        head.addArrangedSubview(addButton)
        let stack = UIStackView.vertical(spacing: 8, alignment: .fill)
        stack.forAutoLayout()
        stack.addArrangedSubview(head)
        stack.addArrangedSubview(container)
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        return card
    }

    @objc private func addSingle() {
        guard ensureCatalogue() else { return }
        let picker = PromoProductPickerViewController(title: "Add Single Product",
                                                      hint: "Tap a product to add it to the campaign.",
                                                      catalogue: catalogue, multiSelect: false) { [weak self] selected in
            guard let self = self, let product = selected.first else { return }
            self.singleLines.append(ProductLine(product))
            self.renderSingle()
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }

    @objc private func addCombo() {
        guard ensureCatalogue() else { return }
        let picker = PromoProductPickerViewController(title: "Add Combo Deal",
                                                      hint: "Select several products for this combo deal.",
                                                      catalogue: catalogue, multiSelect: true) { [weak self] selected in
            guard let self = self, !selected.isEmpty else { return }
            let deal = ComboDeal()
            deal.lines = selected.map { ProductLine($0) }
            self.comboDeals.append(deal)
            self.renderCombo()
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }

    @objc private func addB1g1() {
        guard ensureCatalogue() else { return }
        let picker = PromoB1G1PickerViewController(catalogue: catalogue) { [weak self] buy, free in
            guard let self = self else { return }
            let deal = B1G1Deal()
            deal.buy = buy
            deal.free = free
            self.b1g1Deals.append(deal)
            self.renderB1g1()
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }

    private func ensureCatalogue() -> Bool {
        if catalogue.isEmpty { toast("No products in your catalogue yet."); return false }
        return true
    }

    private func renderSingle() {
        singleHeader.text = "Single Products (\(singleLines.count))"
        singleContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if singleLines.isEmpty { singleContainer.addArrangedSubview(emptyHint("No single products added yet.")); return }
        for line in singleLines {
            singleContainer.addArrangedSubview(lineRow(line) { [weak self] in
                self?.singleLines.removeAll { $0 === line }
                self?.renderSingle()
            })
        }
    }

    private func renderCombo() {
        comboHeader.text = "Combo Deals (\(comboDeals.count))"
        comboContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if comboDeals.isEmpty { comboContainer.addArrangedSubview(emptyHint("No combo deals yet.")); return }
        for (i, deal) in comboDeals.enumerated() {
            let group = dealGroup()
            group.addArrangedSubview(dealHeader(S.promoDeal(i + 1)) { [weak self] in
                self?.comboDeals.removeAll { $0 === deal }
                self?.renderCombo()
            })
            for line in deal.lines {
                group.addArrangedSubview(lineRow(line) { [weak self] in
                    deal.lines.removeAll { $0 === line }
                    if deal.lines.isEmpty { self?.comboDeals.removeAll { $0 === deal } }
                    self?.renderCombo()
                })
            }
            comboContainer.addArrangedSubview(group)
        }
    }

    private func renderB1g1() {
        b1g1Header.text = "Buy1Get1 Free Deals (\(b1g1Deals.count))"
        b1g1Container.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if b1g1Deals.isEmpty { b1g1Container.addArrangedSubview(emptyHint("No Buy1Get1 deals yet.")); return }
        for (i, deal) in b1g1Deals.enumerated() {
            let group = dealGroup()
            group.addArrangedSubview(dealHeader(S.promoDeal(i + 1)) { [weak self] in
                self?.b1g1Deals.removeAll { $0 === deal }
                self?.renderB1g1()
            })
            group.addArrangedSubview(UILabel.make(S.promoBuyProducts, font: AppFonts.bold(12), color: AppColors.textSecondary))
            for p in deal.buy { group.addArrangedSubview(simpleProductRow(p)) }
            group.addArrangedSubview(UILabel.make(S.promoFreeProducts, font: AppFonts.bold(12), color: AppColors.textSecondary))
            for p in deal.free { group.addArrangedSubview(simpleProductRow(p)) }
            group.addArrangedSubview(stockPriceRow(stock: deal.stock, price: deal.price,
                                                   onStock: { deal.stock = $0 }, onPrice: { deal.price = $0 }))
            b1g1Container.addArrangedSubview(group)
        }
    }

    // ---- Product row builders ----

    private func lineRow(_ line: ProductLine, onRemove: @escaping () -> Void) -> UIView {
        let group = UIStackView.vertical(spacing: 8, alignment: .fill)
        group.isLayoutMarginsRelativeArrangement = true
        group.layoutMargins = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        let wrap = UIView()
        wrap.backgroundColor = AppColors.surface
        wrap.layer.cornerRadius = AppMetrics.radiusMD
        wrap.layer.borderWidth = 1
        wrap.layer.borderColor = AppColors.border.cgColor

        let thumb = thumbView(line.product.imageUrl, size: 40)
        let name = UILabel.make(line.product.name, font: AppFonts.bold(14), color: AppColors.textPrimary, lines: 1)
        let sub = UILabel.make(productSubtitle(line.product), font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 1)
        let info = UIStackView.vertical(spacing: 2, alignment: .leading)
        info.addArrangedSubview(name)
        info.addArrangedSubview(sub)
        let del = removeButton(onRemove)
        let top = UIStackView.horizontal(spacing: 10, alignment: .center)
        top.addArrangedSubview(thumb)
        top.addArrangedSubview(info)
        top.addArrangedSubview(UIView())
        top.addArrangedSubview(del)

        group.addArrangedSubview(top)
        group.addArrangedSubview(stockPriceRow(stock: line.stock, price: line.price,
                                               onStock: { line.stock = $0 }, onPrice: { line.price = $0 }))
        wrap.addSubview(group)
        group.forAutoLayout()
        group.pinEdges(to: wrap)
        return wrap
    }

    private func simpleProductRow(_ p: PromoProduct) -> UIView {
        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.addArrangedSubview(thumbView(p.imageUrl, size: 28))
        row.addArrangedSubview(UILabel.make(p.name, font: AppFonts.regular(13), color: AppColors.textPrimary, lines: 1))
        row.addArrangedSubview(UIView())
        return row
    }

    private func stockPriceRow(stock: String, price: String,
                               onStock: @escaping (String) -> Void, onPrice: @escaping (String) -> Void) -> UIView {
        let stockField = numberField(placeholder: "Available stock", value: stock)
        stockField.addAction(UIAction { _ in onStock(stockField.text?.trimmingCharacters(in: .whitespaces) ?? "") }, for: .editingChanged)
        let priceField = numberField(placeholder: S.promoSellingPriceHint, value: price)
        priceField.addAction(UIAction { _ in onPrice(priceField.text?.trimmingCharacters(in: .whitespaces) ?? "") }, for: .editingChanged)
        let row = UIStackView.horizontal(spacing: 8, alignment: .fill)
        row.distribution = .fillEqually
        row.addArrangedSubview(stockField)
        row.addArrangedSubview(priceField)
        return row
    }

    private func numberField(placeholder: String, value: String) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.text = value
        field.font = AppFonts.regular(13)
        field.textColor = AppColors.textPrimary
        field.keyboardType = .decimalPad
        field.backgroundColor = AppColors.surfaceVariant
        field.layer.cornerRadius = AppMetrics.radiusSM
        field.layer.borderWidth = 1
        field.layer.borderColor = AppColors.border.cgColor
        field.constrainHeight(38)
        let pad = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
        field.leftView = pad; field.leftViewMode = .always
        return field
    }

    private func thumbView(_ url: String?, size: CGFloat) -> UIImageView {
        let thumb = UIImageView()
        thumb.contentMode = .scaleAspectFill
        thumb.clipsToBounds = true
        thumb.backgroundColor = AppColors.surfaceVariant
        thumb.layer.cornerRadius = AppMetrics.radiusSM
        thumb.constrainSize(size)
        if let url = url, let u = URL(string: url) {
            ImageLoader.load(u) { [weak thumb] image in thumb?.image = image }
        }
        return thumb
    }

    private func removeButton(_ onRemove: @escaping () -> Void) -> UIButton {
        let del = UIButton(type: .system)
        del.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        del.tintColor = AppColors.textTertiary
        del.constrainSize(22)
        del.setContentHuggingPriority(.required, for: .horizontal)
        del.addAction(UIAction { _ in onRemove() }, for: .touchUpInside)
        return del
    }

    private func dealGroup() -> UIStackView {
        let group = UIStackView.vertical(spacing: 6, alignment: .fill)
        group.isLayoutMarginsRelativeArrangement = true
        group.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        let bg = UIView()
        bg.backgroundColor = AppColors.surfaceVariant
        bg.layer.cornerRadius = AppMetrics.radiusMD
        bg.layer.borderWidth = 1
        bg.layer.borderColor = AppColors.border.cgColor
        group.insertSubview(bg, at: 0)
        bg.forAutoLayout()
        bg.pinEdges(to: group)
        return group
    }

    private func dealHeader(_ title: String, onRemove: @escaping () -> Void) -> UIView {
        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.addArrangedSubview(UILabel.make(title, font: AppFonts.bold(14), color: AppColors.textPrimary))
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(removeButton(onRemove))
        return row
    }

    private func emptyHint(_ text: String) -> UILabel {
        let l = UILabel.make(text, font: AppFonts.regular(13), color: AppColors.textSecondary, align: .center, lines: 0)
        l.setContentHuggingPriority(.defaultLow, for: .vertical)
        return l
    }

    private func productSubtitle(_ p: PromoProduct) -> String {
        [p.sku, p.categoryTitle, p.brandName].filter { !$0.isEmpty }.joined(separator: " • ")
    }

    // MARK: - Step 6: Budget

    private func buildBudgetStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Budget & Estimates"))
        stack.addArrangedSubview(subtitle("Review your spend and estimated performance."))

        let summary = StyleKit.cardView()
        let summaryStack = UIStackView.vertical(spacing: 10, alignment: .fill)
        summaryStack.forAutoLayout()
        summaryStack.addArrangedSubview(budgetRow("Total Budget", budgetTotalLabel))
        summaryStack.addArrangedSubview(budgetRow("Daily Budget", budgetDailyLabel))
        summaryStack.addArrangedSubview(budgetRow("Duration", budgetDurationLabel))
        summaryStack.addArrangedSubview(budgetRow("Products Cost", budgetProductsLabel))
        summaryStack.addArrangedSubview(budgetBreakdownLabel)
        summary.addSubview(summaryStack)
        summaryStack.pinEdges(to: summary, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        stack.addArrangedSubview(summary)

        stack.addArrangedSubview(UILabel.make("Estimated Performance", font: AppFonts.bold(15), color: AppColors.textPrimary))
        let estWrap = StyleKit.cardView()
        estimateCard.forAutoLayout()
        estimateCard.isLayoutMarginsRelativeArrangement = true
        estimateCard.layoutMargins = UIEdgeInsets(top: 4, left: 14, bottom: 14, right: 14)
        estWrap.addSubview(estimateCard)
        estimateCard.pinEdges(to: estWrap)
        stack.addArrangedSubview(estWrap)
        return stack
    }

    private func budgetRow(_ label: String, _ valueLabel: UILabel) -> UIStackView {
        let row = UIStackView.horizontal(spacing: 8, alignment: .firstBaseline)
        let l = UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textSecondary)
        row.addArrangedSubview(l)
        row.addArrangedSubview(valueLabel)
        valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        l.setContentHuggingPriority(.required, for: .horizontal)
        return row
    }

    private func buildBudget() {
        let total = parseDouble(text(budgetField))
        let daily = parseDouble(text(dailyBudgetField))
        let single = singleCost(), combo = comboCost(), b1g1 = b1g1Cost()
        let productsCost = single + combo + b1g1
        let days = durationDays()

        budgetTotalLabel.text = formatRand(total)
        budgetDailyLabel.text = formatRand(daily)
        budgetDurationLabel.text = (startDate.isEmpty ? "-" : "\(displayDate(startDate)) – \(displayDate(endDate))")
            + (days > 0 ? "  (\(days) days)" : "")
        budgetProductsLabel.text = formatRand(productsCost)
        budgetBreakdownLabel.text = "Single Products: \(formatRand(single))\nCombo Deals: \(formatRand(combo))\nBuy1Get1 Free Deals: \(formatRand(b1g1))"

        estimateCard.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let reachLo = (total * 10).rounded(), reachHi = (total * 14).rounded()
        let imprLo = reachLo * 5, imprHi = reachHi * 5
        let clickLo = (imprLo * 0.025).rounded(), clickHi = (imprHi * 0.03).rounded()
        let orderLo = (clickLo * 0.27).rounded(), orderHi = (clickHi * 0.27).rounded()
        let salesLo = (productsCost * 0.99).rounded(), salesHi = (productsCost * 1.386).rounded()
        addEstimate("Estimated Reach", "\(range(reachLo, reachHi)) Traders")
        addEstimate("Estimated Impressions", range(imprLo, imprHi))
        addEstimate("Estimated Clicks", range(clickLo, clickHi))
        addEstimate("Estimated CTR", "2.5% – 3.2%")
        addEstimate("Estimated Orders", range(orderLo, orderHi))
        addEstimate("Estimated Sales Impact", "\(formatRand(salesLo)) – \(formatRand(salesHi))")
    }

    private func addEstimate(_ label: String, _ value: String) {
        let row = UIStackView.horizontal(spacing: 8, alignment: .firstBaseline)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
        let l = UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textSecondary)
        let v = UILabel.make(value, font: AppFonts.bold(13), color: AppColors.textPrimary, align: .right, lines: 0)
        l.setContentHuggingPriority(.required, for: .horizontal)
        row.addArrangedSubview(l)
        row.addArrangedSubview(v)
        estimateCard.addArrangedSubview(row)
    }

    // MARK: - Step 7: Review

    private func buildReviewStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Review & Submit"))
        stack.addArrangedSubview(subtitle("Check the details before submitting for approval."))
        let card = StyleKit.cardView()
        reviewCard.forAutoLayout()
        reviewCard.isLayoutMarginsRelativeArrangement = true
        reviewCard.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        card.addSubview(reviewCard)
        reviewCard.pinEdges(to: card)
        stack.addArrangedSubview(card)

        let draft = UIButton(type: .system)
        draft.setTitle(S.promoSaveDraft, for: .normal)
        StyleKit.styleOutlinedButton(draft)
        draft.constrainHeight(46)
        draft.addAction(UIAction { [weak self] _ in self?.submit(status: "draft") }, for: .touchUpInside)
        stack.addArrangedSubview(draft)
        return stack
    }

    private func buildReview() {
        reviewCard.arrangedSubviews.forEach { $0.removeFromSuperview() }
        addReview("Type", typeLabel(selectedTypeValue))
        addReview("Objective", objectiveLabel(selectedObjectiveValue))
        addReview("Dates", startDate.isEmpty ? "-" : "\(displayDate(startDate)) – \(displayDate(endDate))")
        addReview("Budget", formatRand(parseDouble(text(budgetField))))
        addReview("Targeting", "\(selectedSegmentIds.count) segment(s)")
        addReview("Products", "\(singleLines.count) single · \(comboDeals.count) combo · \(b1g1Deals.count) B1G1")
        addReview("Products Cost", formatRand(singleCost() + comboCost() + b1g1Cost()))
    }

    private func addReview(_ label: String, _ value: String) {
        let row = UIStackView.horizontal(spacing: 8, alignment: .firstBaseline)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
        let l = UILabel.make(label, font: AppFonts.regular(14), color: AppColors.textSecondary)
        let v = UILabel.make(value, font: AppFonts.bold(14), color: AppColors.textPrimary, align: .right, lines: 0)
        l.setContentHuggingPriority(.required, for: .horizontal)
        row.addArrangedSubview(l)
        row.addArrangedSubview(v)
        reviewCard.addArrangedSubview(row)
    }

    // MARK: - Reference + catalogue + edit load

    private func loadReference() {
        ApiClient.shared.getReference { [weak self] result in
            guard let self = self, case .success(let data) = result else { return }
            self.segments = (data.traderTypes ?? []).sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
            self.renderSegmentChips()
        }
    }

    private func loadCatalogue() {
        ApiClient.shared.getProducts { [weak self] result in
            guard let self = self, case .success(let data) = result else { return }
            self.catalogue = (data.products ?? []).map { PromoProduct($0) }
        }
    }

    private func loadPromotionForEdit() {
        guard let id = editPromotionId else { return }
        ApiClient.shared.getPromotionById(id: id) { [weak self] result in
            guard let self = self, case .success(let data) = result, let p = data.promotion else { return }
            self.prefill(p)
        }
    }

    private func prefill(_ p: PromotionDetailData.Promotion) {
        if let type = p.campaignType, !type.isEmpty {
            selectedTypeValue = type
            typeLocked = true
            applyTypeSelection()
        }
        nameField.text = p.name
        descriptionView.text = p.promotionDescription
        budgetField.text = p.budget
        dailyBudgetField.text = p.dailyBudget
        if let objective = p.objective, !objective.isEmpty {
            selectedObjectiveValue = objective
            setPickerTitle(objectiveButton, objectiveLabel(objective))
        }
        if let s = p.startDate, !s.isEmpty { startDate = s; setPickerTitle(startDateButton, displayDate(s)) }
        if let e = p.endDate, !e.isEmpty { endDate = e; setPickerTitle(endDateButton, displayDate(e)) }

        if let address = p.address, !address.isEmpty { setAddressText(address) }
        if let placeId = p.placeId { pickedPlaceId = placeId }
        if let lat = Double(p.lat ?? ""), let lng = Double(p.lng ?? "") {
            placePin(at: CLLocationCoordinate2D(latitude: lat, longitude: lng), zoom: true)
        }
        parseSegments(p.traderSegments)
        renderSegmentChips()

        parseSelectedProducts(p.selectedProducts)
        renderSingle(); renderCombo(); renderB1g1()

        if let url = p.bannerFile?.bestUrl, !url.isEmpty {
            bannerExistingUrl = url
            imagePlaceholder.text = "Current banner — tap to replace"
            if let u = URL(string: url) {
                ImageLoader.load(u) { [weak self] image in
                    guard let self = self, let image = image else { return }
                    self.imagePreview.image = image
                    self.imagePreview.isHidden = false
                    self.imagePlaceholder.isHidden = true
                }
            }
        }
        if let url = p.videoFile?.bestUrl, !url.isEmpty {
            videoExisting = true
            videoLabel.text = S.promoVideoUploaded
            videoLabel.textColor = AppColors.success
        }
    }

    // ---- Defensive JSON parsing (shapes vary across server builds) ----

    private func parseSegments(_ raw: JSONValue?) {
        guard let array = raw?.unwrapped.arrayValue else { return }
        for el in array {
            let idString = el.stringValue ?? el.string("id")
            if let id = Int64(idString), !selectedSegmentIds.contains(id) { selectedSegmentIds.append(id) }
        }
    }

    private func parseSelectedProducts(_ raw: JSONValue?) {
        guard let root = raw?.unwrapped, root.objectValue != nil else { return }

        for el in root.array("single_products") where el.objectValue != nil {
            singleLines.append(lineFromObject(el))
        }
        for el in root.array("combo_deals") {
            let deal = ComboDeal()
            if el.objectValue != nil {
                for pe in el.array("products") where pe.objectValue != nil { deal.lines.append(lineFromObject(pe)) }
            } else if let bare = el.arrayValue {
                for pe in bare where pe.objectValue != nil { deal.lines.append(lineFromObject(pe)) }
            }
            if !deal.lines.isEmpty { comboDeals.append(deal) }
        }
        for el in root.array("buy1_get1_deals") where el.objectValue != nil {
            let deal = B1G1Deal()
            for be in el.array("buy_products") where be.objectValue != nil { deal.buy.append(PromoProduct(json: be)) }
            for fe in el.array("free_products") where fe.objectValue != nil { deal.free.append(PromoProduct(json: fe)) }
            deal.price = el.string("campaign_selling_price")
            deal.stock = el.string("available_stock")
            if !deal.buy.isEmpty || !deal.free.isEmpty { b1g1Deals.append(deal) }
        }
    }

    private func lineFromObject(_ o: JSONValue) -> ProductLine {
        let line = ProductLine(PromoProduct(json: o))
        let cp = o.string("campaign_selling_price"); if !cp.isEmpty { line.price = cp }
        let av = o.string("available_stock"); if !av.isEmpty { line.stock = av }
        return line
    }

    // MARK: - Submit

    private func submit(status: String) {
        var form: [String: String] = [:]
        if let id = editPromotionId { form["id"] = id }
        form["status"] = status
        form["campaign_type"] = selectedTypeValue ?? ""
        form["name"] = text(nameField)
        form["description"] = descriptionView.text ?? ""
        if let objective = selectedObjectiveValue { form["objective"] = objective }
        form["start_date"] = startDate
        form["end_date"] = endDate
        form["budget"] = text(budgetField)
        form["daily_budget"] = text(dailyBudgetField)
        form["products_cost"] = trimNumber(singleCost() + comboCost() + b1g1Cost())
        form["address"] = text(addressField)
        if !pickedPlaceId.isEmpty { form["place_id"] = pickedPlaceId }
        if let coord = pickedCoordinate {
            form["lat"] = String(coord.latitude)
            form["lng"] = String(coord.longitude)
        }
        form["trader_segments"] = jsonString(selectedSegmentIds.map(String.init)) ?? "[]"
        form["selected_products"] = jsonString(buildSelectedProducts()) ?? "{}"

        // Newly-picked media uploaded via upload-media after the record exists.
        var mediaFiles: [Http.FilePart] = []
        if let banner = bannerData {
            mediaFiles.append(Http.FilePart(field: "banner_file", fileName: "banner_file.jpg", mimeType: "image/jpeg", data: banner))
        }
        if let video = videoData {
            mediaFiles.append(Http.FilePart(field: "video_file", fileName: videoName ?? "video_file.mp4",
                                            mimeType: "video/mp4", data: video))
        }

        continueButton.isEnabled = false
        continueButton.setTitle(S.promoSubmitting, for: .normal)

        let editing = editPromotionId != nil
        let phase1: (Result<PromotionDetailData, ApiError>) -> Void = { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                let id = data.promotion?.id ?? self.editPromotionId
                if !mediaFiles.isEmpty, let id = id {
                    self.uploadMediaThenFinish(id: id, files: mediaFiles, editing: editing)
                } else {
                    self.finishSaved(editing: editing)
                }
            case .failure(let error):
                self.continueButton.isEnabled = true
                self.updateContinueButtonTitle(for: self.currentStep)
                self.toast(error.message)
            }
        }

        if editing {
            ApiClient.shared.updatePromotion(form: form, files: [], completion: phase1)
        } else {
            ApiClient.shared.createPromotion(form: form, files: [], completion: phase1)
        }
    }

    private func uploadMediaThenFinish(id: String, files: [Http.FilePart], editing: Bool) {
        ApiClient.shared.uploadPromotionMedia(id: id, files: files) { [weak self] result in
            guard let self = self else { return }
            if case .failure(let error) = result {
                // The campaign itself saved; only the media upload failed.
                self.toast(S.promoMediaFailed(error.message))
            }
            self.finishSaved(editing: editing)
        }
    }

    private func finishSaved(editing: Bool) {
        onSaved?(editing ? S.promoUpdatedMessage : S.promoCreatedMessage)
        navigationController?.popViewController(animated: true)
    }

    /// Lean selected_products payload grouped into single / combo / buy1get1.
    private func buildSelectedProducts() -> [String: Any] {
        var root: [String: Any] = [:]
        root["single_products"] = singleLines.map { lineMap($0) }
        root["combo_deals"] = comboDeals.map { deal -> [String: Any] in
            ["products": deal.lines.map { lineMap($0) }]
        }
        root["buy1_get1_deals"] = b1g1Deals.map { deal -> [String: Any] in
            [
                "buy_products": deal.buy.map { productIdMap($0) },
                "free_products": deal.free.map { productIdMap($0) },
                "campaign_selling_price": deal.price,
                "available_stock": deal.stock
            ]
        }
        return root
    }

    private func lineMap(_ l: ProductLine) -> [String: Any] {
        [
            "product_id": l.product.id,
            "campaign_selling_price": l.price,
            "available_stock": l.stock,
            "original_price": l.product.sellingPrice,
            "original_stock": l.product.stock
        ]
    }

    private func productIdMap(_ p: PromoProduct) -> [String: Any] {
        ["product_id": p.id, "original_price": p.sellingPrice, "original_stock": p.stock]
    }

    private func jsonString(_ object: Any) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: []) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Cost helpers

    private func singleCost() -> Double { singleLines.reduce(0) { $0 + lineValue($1) } }
    private func comboCost() -> Double { comboDeals.reduce(0) { $0 + $1.lines.reduce(0) { $0 + lineValue($1) } } }
    private func b1g1Cost() -> Double { b1g1Deals.reduce(0) { $0 + parseDouble($1.price) * parseDouble($1.stock) } }
    private func lineValue(_ l: ProductLine) -> Double { parseDouble(l.price) * parseDouble(l.stock) }

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
        pickedPlaceId = prediction.placeId ?? ""
        guard let placeId = prediction.placeId else { return }
        ApiClient.shared.getCoordinateFromPlaceId(placeId) { [weak self] result in
            guard let self = self, case .success(let data) = result,
                  let lat = data.latitude, let lng = data.longitude else { return }
            if let formatted = data.formattedAddress, !formatted.isEmpty { self.setAddressText(formatted) }
            self.placePin(at: CLLocationCoordinate2D(latitude: lat, longitude: lng), zoom: true)
        }
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
        pickedPlaceId = ""
        placePin(at: coordinate, zoom: false)
        reverseGeocode(coordinate)
    }

    func mapView(_ mapView: GMSMapView, didEndDragging marker: GMSMarker) {
        pickedCoordinate = marker.position
        pickedPlaceId = ""
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

    // MARK: - Media pickers (delegates)

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        let provider = result.itemProvider
        if pickingVideo {
            let movie = UTType.movie.identifier
            guard provider.hasItemConformingToTypeIdentifier(movie) else { toast("Could not read video."); return }
            provider.loadFileRepresentation(forTypeIdentifier: movie) { [weak self] url, _ in
                guard let self = self, let url = url, let data = try? Data(contentsOf: url) else {
                    DispatchQueue.main.async { self?.toast("Could not read video.") }
                    return
                }
                let name = url.lastPathComponent
                DispatchQueue.main.async { self.applyVideo(data: data, name: name) }
            }
        } else {
            guard provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let self = self, let image = object as? UIImage,
                      let data = Self.downscaledJpeg(image, maxDimension: 1440, quality: 0.7) else { return }
                DispatchQueue.main.async { self.applyBanner(data: data, image: image) }
            }
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let raw = try? Data(contentsOf: url) else { toast("Could not read file."); return }

        if pickingVideo {
            guard raw.count <= Self.maxUploadBytes else {
                toast("Video is too large. Please choose a file under 5 MB."); return
            }
            applyVideo(data: raw, name: url.lastPathComponent)
        } else if let image = UIImage(data: raw), let jpeg = Self.downscaledJpeg(image, maxDimension: 1440, quality: 0.7) {
            applyBanner(data: jpeg, image: image)
        } else {
            toast("Could not read image.")
        }
    }

    private func applyBanner(data: Data, image: UIImage) {
        bannerData = data
        imagePreview.image = image
        imagePreview.isHidden = false
        imagePlaceholder.isHidden = true
    }

    private func applyVideo(data: Data, name: String) {
        guard data.count <= Self.maxUploadBytes else {
            toast("Video is too large. Please choose a file under 5 MB."); return
        }
        videoData = data
        videoName = name
        videoLabel.text = name
        videoLabel.textColor = AppColors.success
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

    // MARK: - Shared view builders

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
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 34)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.regular(AppMetrics.textBody); return out
        }
        button.configuration = config
        button.contentHorizontalAlignment = .leading
        button.constrainHeight(48)

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

    // MARK: - Value helpers

    private func text(_ field: UITextField) -> String {
        field.text?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    private func typeLabel(_ value: String?) -> String {
        guard let value = value, let i = typeValues.firstIndex(of: value) else { return "-" }
        return typeLabels[i]
    }
    private func objectiveLabel(_ value: String?) -> String {
        guard let value = value, let i = objectiveValues.firstIndex(of: value) else { return "-" }
        return objectiveLabels[i]
    }

    private let apiDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private let displayDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "dd MMM yyyy"; return f
    }()

    private func apiDateString(_ date: Date) -> String { apiDateFormatter.string(from: date) }
    private func parseApiDate(_ value: String) -> Date? { value.isEmpty ? nil : apiDateFormatter.date(from: value) }
    private func displayDate(_ api: String) -> String {
        guard let d = apiDateFormatter.date(from: api) else { return api }
        return displayDateFormatter.string(from: d)
    }

    private func durationDays() -> Int {
        guard let s = parseApiDate(startDate), let e = parseApiDate(endDate) else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: s, to: e).day ?? 0
        return max(days + 1, 0)
    }

    private func range(_ lo: Double, _ hi: Double) -> String { "\(groupThousands(lo)) – \(groupThousands(hi))" }
    private func groupThousands(_ value: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = " "; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? String(Int(value))
    }
    private func formatRand(_ value: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = ","; f.maximumFractionDigits = 0
        return "R" + (f.string(from: NSNumber(value: value.rounded())) ?? String(Int(value)))
    }
    private func trimNumber(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
    private func parseDouble(_ value: String) -> Double {
        Double(value.trimmingCharacters(in: .whitespaces)) ?? 0
    }
}

// MARK: - Wizard value types

/// Lightweight product used inside the wizard — built from a catalogue row or from
/// a JSON object when prefilling an existing campaign.
struct PromoProduct {
    let id: String
    let name: String
    let sku: String
    let sellingPrice: String   // original price
    let stock: String          // original stock
    let imageUrl: String?
    let categoryTitle: String
    let brandName: String
    let barcode: String

    init(_ p: ProductsData.Product) {
        id = p.id ?? ""
        name = p.name ?? "Product"
        sku = p.sku ?? ""
        sellingPrice = p.sellingPrice ?? ""
        stock = p.stockValue ?? ""
        let img = p.listImageUrl ?? ""
        imageUrl = img.isEmpty ? nil : img
        categoryTitle = p.categoryTitle ?? ""
        brandName = p.brandName ?? ""
        barcode = p.barcode ?? ""
    }

    init(json o: JSONValue) {
        func first(_ values: String...) -> String { values.first { !$0.isEmpty } ?? "" }
        id = first(o.string("product_id"), o.string("id"))
        name = first(o.string("name"), o.string("product_name"), "Product")
        sku = o.string("sku")
        barcode = o.string("barcode")
        sellingPrice = first(o.string("original_price"), o.string("selling_price"), o.string("campaign_selling_price"))
        stock = first(o.string("original_stock"), o.string("available_stock"), o.string("stock"))
        let img = first(o.string("image_url"), o.string("primary_product_image_url"))
        imageUrl = img.isEmpty ? nil : img
        brandName = o.string("brand_name")
        categoryTitle = o.string("category_title")
    }

    func matches(_ query: String) -> Bool {
        let q = query.lowercased()
        return name.lowercased().contains(q) || sku.lowercased().contains(q)
            || barcode.lowercased().contains(q) || brandName.lowercased().contains(q)
            || categoryTitle.lowercased().contains(q)
    }
}

/// One promoted product with an editable campaign price + available stock (reference
/// type so edits in the rendered rows persist).
final class ProductLine {
    let product: PromoProduct
    var price: String
    var stock: String
    init(_ p: PromoProduct) {
        product = p
        price = p.sellingPrice
        stock = p.stock
    }
}

final class ComboDeal { var lines: [ProductLine] = [] }

final class B1G1Deal {
    var buy: [PromoProduct] = []
    var free: [PromoProduct] = []
    var price = ""
    var stock = ""
}

// MARK: - Date picker sheet

/// A compact bottom sheet with a wheel date picker and Done / Cancel.
private final class DatePickerSheet: UIViewController {
    private let onPick: (Date) -> Void
    private let datePicker = UIDatePicker()

    init(initial: Date, onPick: @escaping (Date) -> Void) {
        self.onPick = onPick
        super.init(nibName: nil, bundle: nil)
        datePicker.date = initial
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
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.forAutoLayout()

        let cancel = UIButton(type: .system)
        cancel.setTitle(S.cancel, for: .normal)
        cancel.setTitleColor(AppColors.textSecondary, for: .normal)
        cancel.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)
        let done = UIButton(type: .system)
        done.setTitle(S.promoDone, for: .normal)
        done.setTitleColor(AppColors.purplePrimary, for: .normal)
        done.titleLabel?.font = AppFonts.bold(15)
        done.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.dismiss(animated: true) { self.onPick(self.datePicker.date) }
        }, for: .touchUpInside)

        let bar = UIStackView.horizontal(spacing: 8, alignment: .center)
        bar.forAutoLayout()
        bar.addArrangedSubview(cancel)
        bar.addArrangedSubview(UIView())
        bar.addArrangedSubview(done)
        view.addSubview(bar)
        view.addSubview(datePicker)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            datePicker.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 8),
            datePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            datePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}
