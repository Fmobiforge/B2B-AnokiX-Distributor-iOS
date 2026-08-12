import UIKit
import PhotosUI
import UniformTypeIdentifiers

/// Five-step "Create New Product" wizard wired to /api/distributor/products/create
/// (and …/update when opened with an existing product, …/delete from the nav bar).
///
/// Steps: 1 Basic Information · 2 Packaging · 3 Images & Documents ·
///        4 Pricing & Inventory · 5 Review & Submit. Mirrors the Android
///        CreateProductActivity and the iOS Create Trader wizard.
final class CreateProductViewController: BaseSecondaryViewController,
        PHPickerViewControllerDelegate, UIDocumentPickerDelegate, UITextFieldDelegate {

    /// Set to edit an existing product (loads get-by-id, switches to update/delete).
    var productId: String?
    /// Called after a successful create/update/delete so the list can refresh.
    var onSaved: (() -> Void)?

    override var screenTitle: String { productId == nil ? "Create New Product" : "Edit Product" }
    // When editing, show a trash action in the title bar (mirrors Android's header delete).
    override var trailingIcon: String? { productId == nil ? nil : "ic_delete" }
    override func trailingTapped() { confirmDelete() }

    // Measurement type → (dim_type value, weight unit, dimension unit)
    private let dimTypeValues = ["kilo_centi", "pound_inch"]
    private let weightUnits = ["kg", "lb"]
    private let dimUnits = ["cm", "in"]
    private let maxAdditionalImages = 5
    private let maxUploadBytes = 5 * 1024 * 1024

    // Stepper
    private let stepKeys = ["Basic Information", "Packaging", "Images & Documents",
                            "Pricing & Inventory", "Review & Submit"]
    private let stepReview = 4
    private let stepperScroll = UIScrollView()
    private let stepperStack = UIStackView.horizontal(spacing: 0, alignment: .center)
    private var stepCircles: [UILabel] = []
    private var stepTitles: [UILabel] = []
    private var currentStep = 0

    private let formScroll = UIScrollView()
    private let continueButton = UIButton(type: .system)
    private var stepStacks: [UIStackView] = []

    // Fields
    private let nameField = UITextField()
    private let barcodeField = UITextField()
    private let skuField = UITextField()
    private let descriptionView = UITextView()
    private let brandButton = UIButton(type: .system)
    private let categoryButton = UIButton(type: .system)
    private let subCategoryButton = UIButton(type: .system)
    private let unitButton = UIButton(type: .system)
    private let measurementButton = UIButton(type: .system)
    private let unitsPerCaseField = UITextField()
    private let weightField = UITextField()
    private let weightUnitLabel = UILabel()
    private let dimLField = UITextField()
    private let dimWField = UITextField()
    private let dimHField = UITextField()
    private let dimUnitLabel = UILabel()
    private let sellingPriceField = UITextField()
    private let costPriceField = UITextField()
    private let stockField = UITextField()
    private let reorderField = UITextField()
    private let promoPriceField = UITextField()
    private let promoStartField = UITextField()
    private let promoEndField = UITextField()
    private let promoStartPicker = UIDatePicker()
    private let promoEndPicker = UIDatePicker()
    private let promoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private let availableSwitch = UISwitch()
    private let reviewStack = UIStackView.vertical(spacing: 0, alignment: .fill)

    // Selections
    private var selectedBrandId: Int64?
    private var selectedParentCategoryId: Int64?
    private var selectedSubCategoryId: Int64?
    private var selectedUnitId: String?
    private var measurementIndex = 0

    // Base info
    private var brands: [BaseInfoData.Brand] = []
    private var allCategories: [BaseInfoData.ProductCategory] = []
    private var parentCategories: [BaseInfoData.ProductCategory] = []
    private var subCategories: [BaseInfoData.ProductCategory] = []
    private var units: [BaseInfoData.ProductUnit] = []

    // Images / files
    private enum ImageTarget { case primary, additional }
    private var pendingImageTarget: ImageTarget = .primary
    private var primaryImageData: Data?
    private var primaryProvided = false       // true when an existing image is kept on edit
    private let primaryImageView = UIImageView()
    private let primaryPlaceholder = UILabel()
    private var newAdditionalImages: [Data] = []
    private var existingAdditional: [(id: String, url: String)] = []
    private var removeAdditionalIds: [String] = []
    private let additionalChips = UIStackView.vertical(spacing: 8, alignment: .fill)
    private var datasheet: (data: Data, name: String, mime: String)?
    private let datasheetLabel = UILabel()

    // MARK: - Setup

    override func setupContent(in container: UIView) {
        buildStepper(in: container)
        let divider = ListScreenLayout.hairline()
        divider.forAutoLayout()
        container.addSubview(divider)

        let bottomBar = buildBottomBar()
        container.addSubview(bottomBar)

        formScroll.alwaysBounceVertical = true
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

        stepStacks = [buildBasicStep(), buildPackagingStep(), buildImagesStep(),
                      buildPricingStep(), buildReviewStep()]
        for step in stepStacks {
            step.isLayoutMarginsRelativeArrangement = true
            step.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
            formStack.addArrangedSubview(step)
        }
        showStep(0)
    }

    override func loadData() {
        applyMeasurement(0)
        loadBaseInfo()
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

        StyleKit.stylePrimaryButton(continueButton)
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
        if currentStep == 0 { navigationController?.popViewController(animated: true) }
        else { showStep(currentStep - 1) }
    }

    @objc private func goContinue() {
        guard validateStep(currentStep) else { return }
        if currentStep == stepReview { submit() }
        else { showStep(currentStep + 1) }
    }

    private func showStep(_ index: Int) {
        currentStep = index
        for (i, step) in stepStacks.enumerated() { step.isHidden = i != index }
        continueButton.setTitle(index == stepReview ? "Submit" : "Continue", for: .normal)
        if index == stepReview { buildReview() }
        renderStepper()
        view.endEditing(true)
        formScroll.setContentOffset(.zero, animated: false)
        scrollStepperToCurrent()
    }

    /// Keep the active step's number + title in view as the user advances (mirrors the
    /// Android stepper's smoothScrollTo).
    private func scrollStepperToCurrent() {
        guard currentStep < stepCircles.count else { return }
        DispatchQueue.main.async {
            self.stepperStack.layoutIfNeeded()
            let circleRect = self.stepCircles[self.currentStep]
                .convert(self.stepCircles[self.currentStep].bounds, to: self.stepperScroll)
            let titleRect = self.stepTitles[self.currentStep]
                .convert(self.stepTitles[self.currentStep].bounds, to: self.stepperScroll)
            let target = circleRect.union(titleRect).insetBy(dx: -24, dy: 0)
            self.stepperScroll.scrollRectToVisible(target, animated: true)
        }
    }

    // MARK: - Validation

    private func validateStep(_ step: Int) -> Bool {
        switch step {
        case 0:
            if text(nameField).isEmpty { return fail("Please enter the product name.") }
            if selectedBrandId == nil { return fail("Please select a brand.") }
            if selectedParentCategoryId == nil { return fail("Please select a category.") }
            if selectedSubCategoryId == nil { return fail("Please select a sub category.") }
            if text(barcodeField).isEmpty { return fail("Please enter the barcode.") }
            if text(skuField).isEmpty { return fail("Please enter the SKU.") }
            return true
        case 1:
            if selectedUnitId == nil { return fail("Please select a unit type.") }
            if text(weightField).isEmpty { return fail("Please enter the weight.") }
            if text(dimLField).isEmpty || text(dimWField).isEmpty || text(dimHField).isEmpty {
                return fail("Please enter the dimensions.")
            }
            return true
        case 2:
            if primaryImageData == nil && !primaryProvided { return fail("Please upload a primary product image.") }
            return true
        case 3:
            if text(sellingPriceField).isEmpty { return fail("Please enter the selling price.") }
            if text(stockField).isEmpty { return fail("Please enter the stock quantity.") }
            if text(reorderField).isEmpty { return fail("Please enter the reorder level.") }
            return true
        default:
            return true
        }
    }

    @discardableResult
    private func fail(_ message: String) -> Bool {
        toast(message)
        return false
    }

    // MARK: - Step builders

    private func buildBasicStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 14, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Basic Information"))
        stack.addArrangedSubview(hPair(
            fieldGroup("Product Name *", nameField, placeholder: "Enter product name"),
            pickerGroup("Brand *", brandButton, placeholder: "Select brand", action: #selector(pickBrand))))
        stack.addArrangedSubview(hPair(
            pickerGroup("Category *", categoryButton, placeholder: "Select category", action: #selector(pickCategory)),
            pickerGroup("Sub Category *", subCategoryButton, placeholder: "Select sub category", action: #selector(pickSubCategory))))
        stack.addArrangedSubview(hPair(
            fieldGroup("Barcode *", barcodeField, placeholder: "Enter barcode", keyboard: .numberPad),
            fieldGroup("SKU *", skuField, placeholder: "Enter SKU")))

        let descLabel = UILabel.make("Description", font: AppFonts.regular(13), color: AppColors.textPrimary)
        descriptionView.font = AppFonts.regular(13)
        descriptionView.textColor = AppColors.textPrimary
        descriptionView.backgroundColor = AppColors.surface
        descriptionView.layer.cornerRadius = AppMetrics.radiusMD
        descriptionView.layer.borderWidth = 1
        descriptionView.layer.borderColor = AppColors.border.cgColor
        descriptionView.constrainHeight(100)
        descriptionView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        let descGroup = UIStackView.vertical(spacing: 5, alignment: .fill)
        descGroup.addArrangedSubview(descLabel)
        descGroup.addArrangedSubview(descriptionView)
        stack.addArrangedSubview(descGroup)
        return stack
    }

    private func buildPackagingStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 14, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Packaging"))
        stack.addArrangedSubview(hPair(
            pickerGroup("Unit Type *", unitButton, placeholder: "Select unit type", action: #selector(pickUnit)),
            fieldGroup("Units Per Case", unitsPerCaseField, placeholder: "e.g. 12", keyboard: .numberPad)))
        stack.addArrangedSubview(pickerGroup("Measurements Type *", measurementButton,
                                             placeholder: "Kilograms / Centimeters", action: #selector(pickMeasurement)))

        // Weight + unit
        StyleKit.styleInput(weightField); weightField.placeholder = "0.0"; weightField.keyboardType = .decimalPad
        styleUnitBox(weightUnitLabel)
        let weightRow = UIStackView.horizontal(spacing: 8, alignment: .fill)
        weightRow.addArrangedSubview(weightField)
        weightRow.addArrangedSubview(weightUnitLabel)
        weightUnitLabel.widthAnchor.constraint(equalToConstant: 56).isActive = true
        let weightGroup = UIStackView.vertical(spacing: 5, alignment: .fill)
        weightGroup.addArrangedSubview(UILabel.make("Weight *", font: AppFonts.regular(13), color: AppColors.textPrimary))
        weightGroup.addArrangedSubview(weightRow)
        stack.addArrangedSubview(weightGroup)

        // Dimensions
        for f in [dimLField, dimWField, dimHField] {
            StyleKit.styleInput(f); f.keyboardType = .decimalPad; f.textAlignment = .center
        }
        dimLField.placeholder = "L"; dimWField.placeholder = "W"; dimHField.placeholder = "H"
        styleUnitBox(dimUnitLabel)
        let dimRow = UIStackView.horizontal(spacing: 6, alignment: .fill)
        dimRow.distribution = .fill
        dimRow.addArrangedSubview(dimLField)
        dimRow.addArrangedSubview(dimX())
        dimRow.addArrangedSubview(dimWField)
        dimRow.addArrangedSubview(dimX())
        dimRow.addArrangedSubview(dimHField)
        dimRow.addArrangedSubview(dimUnitLabel)
        dimLField.widthAnchor.constraint(equalTo: dimWField.widthAnchor).isActive = true
        dimWField.widthAnchor.constraint(equalTo: dimHField.widthAnchor).isActive = true
        dimUnitLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true
        let dimGroup = UIStackView.vertical(spacing: 5, alignment: .fill)
        dimGroup.addArrangedSubview(UILabel.make("Dimensions (L x W x H) *", font: AppFonts.regular(13), color: AppColors.textPrimary))
        dimGroup.addArrangedSubview(dimRow)
        stack.addArrangedSubview(dimGroup)
        return stack
    }

    private func buildImagesStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 14, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Images & Documents"))

        // Primary image
        stack.addArrangedSubview(UILabel.make("Primary Product Image *", font: AppFonts.regular(13), color: AppColors.textPrimary))
        let primaryBox = UIView()
        primaryBox.backgroundColor = AppColors.surfaceVariant
        primaryBox.layer.cornerRadius = AppMetrics.radiusMD
        primaryBox.layer.borderWidth = 1.5
        primaryBox.layer.borderColor = AppColors.purpleTextLight.cgColor
        primaryBox.constrainHeight(150)
        primaryBox.isUserInteractionEnabled = true
        primaryBox.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(pickPrimaryImage)))
        primaryPlaceholder.text = "Tap to upload  ·  PNG, JPG up to 5MB"
        primaryPlaceholder.font = AppFonts.regular(13)
        primaryPlaceholder.textColor = AppColors.textSecondary
        primaryPlaceholder.forAutoLayout()
        primaryBox.addSubview(primaryPlaceholder)
        primaryImageView.contentMode = .scaleAspectFill
        primaryImageView.clipsToBounds = true
        primaryImageView.layer.cornerRadius = AppMetrics.radiusMD
        primaryImageView.isHidden = true
        primaryImageView.forAutoLayout()
        primaryBox.addSubview(primaryImageView)
        NSLayoutConstraint.activate([
            primaryPlaceholder.centerXAnchor.constraint(equalTo: primaryBox.centerXAnchor),
            primaryPlaceholder.centerYAnchor.constraint(equalTo: primaryBox.centerYAnchor),
            primaryImageView.topAnchor.constraint(equalTo: primaryBox.topAnchor, constant: 6),
            primaryImageView.bottomAnchor.constraint(equalTo: primaryBox.bottomAnchor, constant: -6),
            primaryImageView.leadingAnchor.constraint(equalTo: primaryBox.leadingAnchor, constant: 6),
            primaryImageView.trailingAnchor.constraint(equalTo: primaryBox.trailingAnchor, constant: -6)
        ])
        stack.addArrangedSubview(primaryBox)

        // Additional images
        stack.addArrangedSubview(UILabel.make("Additional Images (max 5)", font: AppFonts.bold(13), color: AppColors.textPrimary))
        stack.addArrangedSubview(additionalChips)
        let addMore = UIButton(type: .system)
        configurePickerButton(addMore, placeholder: "+ Add image")
        addMore.addTarget(self, action: #selector(pickAdditionalImage), for: .touchUpInside)
        stack.addArrangedSubview(addMore)

        // Datasheet
        stack.addArrangedSubview(UILabel.make("Product Datasheet (Optional)", font: AppFonts.bold(13), color: AppColors.textPrimary))
        datasheetLabel.text = "Tap to upload file  ·  PDF, DOC, XLS up to 10MB"
        datasheetLabel.font = AppFonts.regular(12)
        datasheetLabel.textColor = AppColors.info
        datasheetLabel.numberOfLines = 0
        let datasheetBox = UIView()
        datasheetBox.backgroundColor = AppColors.surfaceVariant
        datasheetBox.layer.cornerRadius = AppMetrics.radiusMD
        datasheetBox.layer.borderWidth = 1.5
        datasheetBox.layer.borderColor = AppColors.purpleTextLight.cgColor
        datasheetBox.isUserInteractionEnabled = true
        datasheetBox.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(pickDatasheet)))
        datasheetLabel.forAutoLayout()
        datasheetBox.addSubview(datasheetLabel)
        datasheetLabel.pinEdges(to: datasheetBox, insets: UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12))
        stack.addArrangedSubview(datasheetBox)
        renderAdditionalChips()
        return stack
    }

    private func buildPricingStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 14, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Pricing & Inventory"))
        stack.addArrangedSubview(hPair(
            fieldGroup("Selling Price (R) *", sellingPriceField, placeholder: "0.00", keyboard: .decimalPad),
            fieldGroup("Cost Price (R)", costPriceField, placeholder: "0.00", keyboard: .decimalPad)))
        stack.addArrangedSubview(hPair(
            fieldGroup("Stock Quantity *", stockField, placeholder: "0", keyboard: .numberPad),
            fieldGroup("Reorder Level *", reorderField, placeholder: "0", keyboard: .numberPad)))
        stack.addArrangedSubview(fieldGroup("Promotion Price (R)", promoPriceField, placeholder: "0.00", keyboard: .decimalPad))
        let promoDateRow = hPair(
            fieldGroup("Promotion Start Date", promoStartField, placeholder: "YYYY-MM-DD"),
            fieldGroup("Promotion End Date", promoEndField, placeholder: "YYYY-MM-DD"))
        attachDatePicker(to: promoStartField, picker: promoStartPicker)
        attachDatePicker(to: promoEndField, picker: promoEndPicker)
        stack.addArrangedSubview(promoDateRow)

        let availLabel = UILabel.make("Available For Ordering", font: AppFonts.bold(15), color: AppColors.purpleDark)
        availableSwitch.isOn = true
        availableSwitch.onTintColor = AppColors.purplePrimary
        let availRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        availRow.addArrangedSubview(availLabel)
        availRow.addArrangedSubview(UIView())
        availRow.addArrangedSubview(availableSwitch)
        stack.addArrangedSubview(availRow)
        return stack
    }

    private func buildReviewStep() -> UIStackView {
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(sectionTitle("Review & Submit"))
        stack.addArrangedSubview(subtitle("Review your product details below, then submit for approval."))
        let card = UIView()
        card.backgroundColor = AppColors.surface
        card.layer.cornerRadius = AppMetrics.radiusMD
        card.layer.borderWidth = 1
        card.layer.borderColor = AppColors.border.cgColor
        reviewStack.isLayoutMarginsRelativeArrangement = true
        reviewStack.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        reviewStack.forAutoLayout()
        card.addSubview(reviewStack)
        reviewStack.pinEdges(to: card)
        stack.addArrangedSubview(card)
        // Delete now lives in the title bar (see trailingIcon / trailingTapped).
        return stack
    }

    private func buildReview() {
        reviewStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        addReviewRow("Product Name", text(nameField))
        addReviewRow("Brand", selectedBrandId.flatMap { brandName($0) } ?? "")
        addReviewRow("Category", selectedSubCategoryId.flatMap { categoryName($0) } ?? "")
        addReviewRow("Barcode", text(barcodeField))
        addReviewRow("Selling Price", "R" + text(sellingPriceField))
        addReviewRow("Stock Quantity", text(stockField))
    }

    private func addReviewRow(_ label: String, _ value: String) {
        let left = UILabel.make(label, font: AppFonts.regular(14), color: AppColors.textSecondary)
        let right = UILabel.make(value, font: AppFonts.bold(14), color: AppColors.purpleDark, align: .right, lines: 0)
        right.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = UIStackView.horizontal(spacing: 8, alignment: .top)
        row.addArrangedSubview(left)
        row.addArrangedSubview(right)
        left.setContentHuggingPriority(.required, for: .horizontal)
        reviewStack.addArrangedSubview(row)
    }

    // MARK: - Pickers (selection lists)

    @objc private func pickBrand() {
        presentChoices("Brand", brands.map { $0.name ?? "" }) { [weak self] index in
            guard let self = self else { return }
            self.selectedBrandId = self.brands[index].id
            self.setPickerTitle(self.brandButton, self.brands[index].name ?? "")
        }
    }

    @objc private func pickCategory() {
        presentChoices("Category", parentCategories.map { $0.title ?? "" }) { [weak self] index in
            guard let self = self else { return }
            let cat = self.parentCategories[index]
            self.selectedParentCategoryId = cat.id
            self.setPickerTitle(self.categoryButton, cat.title ?? "")
            self.selectedSubCategoryId = nil
            self.setPickerTitle(self.subCategoryButton, "Select sub category")
            self.subCategoryButton.configuration?.baseForegroundColor = AppColors.textSecondary
            self.rebuildSubCategories()
        }
    }

    @objc private func pickSubCategory() {
        guard selectedParentCategoryId != nil else { toast("Please select a category."); return }
        presentChoices("Sub Category", subCategories.map { $0.title ?? "" }) { [weak self] index in
            guard let self = self else { return }
            self.selectedSubCategoryId = self.subCategories[index].id
            self.setPickerTitle(self.subCategoryButton, self.subCategories[index].title ?? "")
        }
    }

    @objc private func pickUnit() {
        presentChoices("Unit Type", units.map { $0.name ?? "" }) { [weak self] index in
            guard let self = self else { return }
            self.selectedUnitId = self.units[index].id
            self.setPickerTitle(self.unitButton, self.units[index].name ?? "")
        }
    }

    @objc private func pickMeasurement() {
        presentChoices("Measurements Type", ["Kilograms / Centimeters", "Pounds / Inches"]) { [weak self] index in
            self?.applyMeasurement(index)
        }
    }

    private func applyMeasurement(_ index: Int) {
        measurementIndex = index
        setPickerTitle(measurementButton, index == 0 ? "Kilograms / Centimeters" : "Pounds / Inches")
        weightUnitLabel.text = weightUnits[index]
        dimUnitLabel.text = dimUnits[index]
    }

    private func rebuildSubCategories() {
        subCategories = allCategories.filter { $0.parentId == selectedParentCategoryId }
    }

    private func presentChoices(_ title: String, _ options: [String], onPick: @escaping (Int) -> Void) {
        guard !options.isEmpty else { return }
        let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for (i, option) in options.enumerated() {
            sheet.addAction(UIAlertAction(title: option, style: .default) { _ in onPick(i) })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController { pop.sourceView = view; pop.sourceRect = view.bounds }
        present(sheet, animated: true)
    }

    // MARK: - Promotion date pickers

    /// Make a promotion date field pick-only via a wheel UIDatePicker (mirrors the
    /// Android DatePickerDialog) with a Clear / Done toolbar. Value is stored as
    /// yyyy-MM-dd, the format the API expects.
    private func attachDatePicker(to field: UITextField, picker: UIDatePicker) {
        picker.datePickerMode = .date
        if #available(iOS 13.4, *) { picker.preferredDatePickerStyle = .wheels }
        field.inputView = picker
        field.tintColor = .clear        // pick-only — hide the text caret
        field.delegate = self

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let clear = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearPromoDate))
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(commitPromoDate))
        toolbar.setItems([clear, spacer, done], animated: false)
        field.inputAccessoryView = toolbar
    }

    @objc private func commitPromoDate() {
        if promoStartField.isFirstResponder {
            promoStartField.text = promoDateFormatter.string(from: promoStartPicker.date)
        } else if promoEndField.isFirstResponder {
            promoEndField.text = promoDateFormatter.string(from: promoEndPicker.date)
        }
        view.endEditing(true)
    }

    @objc private func clearPromoDate() {
        if promoStartField.isFirstResponder { promoStartField.text = "" }
        else if promoEndField.isFirstResponder { promoEndField.text = "" }
        view.endEditing(true)
    }

    /// Shows a promotion date returned by the API on its field and syncs the wheel to it.
    /// Tolerates a trailing time component and skips the "0000-00-00" placeholder the
    /// backend uses when no promotion window is set.
    private func applyPromoDate(_ apiDate: String?, to field: UITextField, picker: UIDatePicker) {
        let value = (apiDate ?? "").trimmingCharacters(in: .whitespaces)
        guard let datePart = value.split(separator: " ").first.map(String.init),
              let date = promoDateFormatter.date(from: datePart),
              !datePart.hasPrefix("0000") else { return }
        field.text = datePart
        picker.date = date
    }

    /// Sync the wheel to the value already in the field (e.g. when editing a product).
    func textFieldDidBeginEditing(_ textField: UITextField) {
        let picker: UIDatePicker?
        if textField == promoStartField { picker = promoStartPicker }
        else if textField == promoEndField { picker = promoEndPicker }
        else { picker = nil }
        guard let picker = picker else { return }
        if let text = textField.text, let date = promoDateFormatter.date(from: text) {
            picker.date = date
        }
    }

    // MARK: - Image / file pickers

    @objc private func pickPrimaryImage() { pendingImageTarget = .primary; presentPhotoPicker() }
    @objc private func pickAdditionalImage() {
        if existingAdditional.count + newAdditionalImages.count >= maxAdditionalImages {
            toast("You can upload up to 5 additional images."); return
        }
        pendingImageTarget = .additional
        presentPhotoPicker()
    }

    private func presentPhotoPicker() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self = self, let image = object as? UIImage,
                  let data = Self.downscaledJpeg(image, maxDimension: 1280, quality: 0.5) else { return }
            DispatchQueue.main.async {
                if self.pendingImageTarget == .primary {
                    self.primaryImageData = data
                    self.primaryImageView.image = UIImage(data: data)
                    self.primaryImageView.isHidden = false
                    self.primaryPlaceholder.isHidden = true
                } else {
                    self.newAdditionalImages.append(data)
                    self.renderAdditionalChips()
                }
            }
        }
    }

    @objc private func pickDatasheet() {
        let types: [UTType] = [.pdf, .spreadsheet, .image,
                               UTType(filenameExtension: "doc") ?? .data,
                               UTType(filenameExtension: "docx") ?? .data,
                               UTType(filenameExtension: "xls") ?? .data,
                               UTType(filenameExtension: "xlsx") ?? .data]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = self
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { toast("Could not read file"); return }
        guard data.count <= maxUploadBytes else { toast("File is too large. Please choose a file under 5 MB."); return }
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        datasheet = (data, url.lastPathComponent, mime)
        datasheetLabel.text = url.lastPathComponent
        datasheetLabel.textColor = AppColors.success
    }

    private func renderAdditionalChips() {
        additionalChips.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, existing) in existingAdditional.enumerated() {
            let id = existing.id
            additionalChips.addArrangedSubview(imageChip(url: existing.url, image: nil,
                                                         title: "Saved image \(i + 1)") { [weak self] in
                guard let self = self else { return }
                self.existingAdditional.removeAll { $0.id == id }
                self.removeAdditionalIds.append(id)
                self.renderAdditionalChips()
            })
        }
        for (i, data) in newAdditionalImages.enumerated() {
            additionalChips.addArrangedSubview(imageChip(url: nil, image: UIImage(data: data),
                                                         title: "New image \(i + 1)") { [weak self] in
                guard let self = self, i < self.newAdditionalImages.count else { return }
                self.newAdditionalImages.remove(at: i)
                self.renderAdditionalChips()
            })
        }
    }

    /// One additional-image row: a thumbnail (loaded from `url` for saved images, or
    /// built from `image` data for newly picked ones), a caption, and a remove button.
    private func imageChip(url: String?, image: UIImage?, title: String,
                           onRemove: @escaping () -> Void) -> UIView {
        let chip = UIView()
        chip.backgroundColor = AppColors.surfaceVariant
        chip.layer.cornerRadius = AppMetrics.radiusSM
        chip.layer.borderWidth = 1
        chip.layer.borderColor = AppColors.border.cgColor

        let thumb = UIImageView()
        thumb.contentMode = .scaleAspectFill
        thumb.clipsToBounds = true
        thumb.backgroundColor = AppColors.surface
        thumb.layer.cornerRadius = AppMetrics.radiusSM
        thumb.constrainSize(44)
        if let image = image {
            thumb.image = image
        } else if let url = url, let u = URL(string: url) {
            ImageLoader.load(u) { [weak thumb] loaded in thumb?.image = loaded }
        }

        let label = UILabel.make(title, font: AppFonts.regular(13), color: AppColors.textPrimary)

        let remove = UIButton(type: .system)
        remove.setImage(UIImage(systemName: "trash"), for: .normal)
        remove.tintColor = AppColors.danger
        remove.constrainSize(22)
        remove.addAction(UIAction { _ in onRemove() }, for: .touchUpInside)

        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 12)
        row.forAutoLayout()
        row.addArrangedSubview(thumb)
        row.addArrangedSubview(label)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(remove)
        chip.addSubview(row)
        row.pinEdges(to: chip)
        return chip
    }

    // MARK: - Base info / edit load

    private func loadBaseInfo() {
        ApiClient.shared.getBaseInfo { [weak self] result in
            guard let self = self, case .success(let data) = result else { return }
            self.brands = data.brands ?? []
            self.units = data.productUnits ?? []
            self.allCategories = data.productCategories ?? []
            self.parentCategories = self.allCategories.filter { $0.parentId == nil }
            if self.productId != nil { self.loadProductForEdit() }
        }
    }

    private func loadProductForEdit() {
        guard let id = productId else { return }
        ApiClient.shared.getProductById(id: id) { [weak self] result in
            guard let self = self, case .success(let data) = result, let p = data.product else { return }
            self.prefill(p)
        }
    }

    private func prefill(_ p: ProductDetailData.Product) {
        nameField.text = p.name
        barcodeField.text = p.barcode
        skuField.text = p.sku
        descriptionView.text = p.productDescription
        unitsPerCaseField.text = p.unitsPerCase
        weightField.text = p.dimWeight ?? p.weight
        dimLField.text = p.dimLength
        dimWField.text = p.dimWidth
        dimHField.text = p.dimHeight
        sellingPriceField.text = p.sellingPrice
        costPriceField.text = p.costPrice
        stockField.text = p.stockQuantity ?? p.stock
        reorderField.text = p.reorderLevel
        promoPriceField.text = p.promotionPrice
        applyPromoDate(p.promotionStartDate, to: promoStartField, picker: promoStartPicker)
        applyPromoDate(p.promotionEndDate, to: promoEndField, picker: promoEndPicker)

        if let b = Int64(p.brandId ?? "") { selectedBrandId = b; setPickerTitle(brandButton, brandName(b)) }
        if let pc = Int64(p.parentCategoryId ?? "") {
            selectedParentCategoryId = pc
            setPickerTitle(categoryButton, categoryName(pc))
            rebuildSubCategories()
        }
        if let c = Int64(p.categoryId ?? "") { selectedSubCategoryId = c; setPickerTitle(subCategoryButton, categoryName(c)) }
        if let u = p.unitId { selectedUnitId = u; setPickerTitle(unitButton, unitName(u)) }
        applyMeasurement((p.dimType ?? p.measurementsType) == "pound_inch" ? 1 : 0)
        availableSwitch.isOn = (p.availableForOrdering ?? "1") != "0"

        if let img = p.primaryProductImageUrl ?? p.imageUrl, !img.isEmpty {
            primaryProvided = true
            primaryPlaceholder.text = "Current image — tap to replace"
            if let url = URL(string: img) {
                ImageLoader.load(url) { [weak self] image in
                    guard let self = self, let image = image else { return }
                    self.primaryImageView.image = image
                    self.primaryImageView.isHidden = false
                    self.primaryPlaceholder.isHidden = true
                }
            }
        }
        existingAdditional = (p.additionalImages ?? []).compactMap { ai in
            guard let id = ai.id, let url = ai.fileUrl else { return nil }
            return (id: id, url: url)
        }
        renderAdditionalChips()
    }

    // MARK: - Submit

    private func submit() {
        var form: [String: String] = [:]
        if let id = productId { form["id"] = id }
        form["name"] = text(nameField)
        if let b = selectedBrandId { form["brand_id"] = String(b) }
        if let pc = selectedParentCategoryId { form["parent_category_id"] = String(pc) }
        if let c = selectedSubCategoryId { form["category_id"] = String(c) }
        form["barcode"] = text(barcodeField)
        form["sku"] = text(skuField)
        form["description"] = descriptionView.text ?? ""
        if let u = selectedUnitId { form["unit_id"] = u }
        form["units_per_case"] = text(unitsPerCaseField)
        form["dim_type"] = dimTypeValues[measurementIndex]
        form["measurements_type"] = dimTypeValues[measurementIndex]
        form["dim_weight"] = text(weightField)
        form["weight"] = text(weightField)
        form["dim_length"] = text(dimLField)
        form["dim_width"] = text(dimWField)
        form["dim_height"] = text(dimHField)
        form["selling_price"] = text(sellingPriceField)
        form["cost_price"] = text(costPriceField)
        form["stock"] = text(stockField)
        form["reorder_level"] = text(reorderField)
        form["promotion_price"] = text(promoPriceField)
        form["promotion_start_date"] = text(promoStartField)
        form["promotion_end_date"] = text(promoEndField)
        form["available_for_ordering"] = availableSwitch.isOn ? "1" : "0"
        if !removeAdditionalIds.isEmpty {
            form["remove_additional_image_ids"] = removeAdditionalIds.joined(separator: ",")
        }

        var files: [Http.FilePart] = []
        if let data = primaryImageData {
            files.append(Http.FilePart(field: "image", fileName: "image.jpg", mimeType: "image/jpeg", data: data))
        }
        for (i, data) in newAdditionalImages.enumerated() {
            files.append(Http.FilePart(field: "additional_image_\(i)", fileName: "additional_\(i).jpg",
                                       mimeType: "image/jpeg", data: data))
        }
        if let sheet = datasheet {
            files.append(Http.FilePart(field: "datasheet", fileName: sheet.name, mimeType: sheet.mime, data: sheet.data))
        }

        continueButton.isEnabled = false
        continueButton.setTitle("Submitting…", for: .normal)
        let handler: (Result<ProductDetailData, ApiError>) -> Void = { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.onSaved?()
                self.popToProductList()
            case .failure(let error):
                self.continueButton.isEnabled = true
                self.continueButton.setTitle("Submit", for: .normal)
                self.toast(error.message)
            }
        }
        if productId == nil {
            ApiClient.shared.createProduct(form: form, files: files, completion: handler)
        } else {
            ApiClient.shared.updateProduct(form: form, files: files, completion: handler)
        }
    }

    @objc private func confirmDelete() {
        guard let id = productId else { return }
        let alert = UIAlertController(title: "Delete product?",
                                      message: "This will permanently remove the product. This cannot be undone.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            ApiClient.shared.deleteProduct(id: id) { result in
                guard let self = self else { return }
                switch result {
                case .success:
                    self.onSaved?()
                    self.popToProductList()
                case .failure(let error):
                    self.toast(error.message)
                }
            }
        })
        present(alert, animated: true)
    }

    /// Pop the wizard (and the options screen) back to the products list.
    private func popToProductList() {
        guard let nav = navigationController else { return }
        let remaining = nav.viewControllers.filter {
            !($0 is CreateProductViewController) && !($0 is AddProductOptionsViewController)
        }
        if remaining.isEmpty {
            nav.popViewController(animated: true)
        } else {
            nav.setViewControllers(remaining, animated: true)
        }
    }

    // MARK: - Helpers

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

    private func brandName(_ id: Int64) -> String { brands.first { $0.id == id }?.name ?? "" }
    private func categoryName(_ id: Int64) -> String { allCategories.first { $0.id == id }?.title ?? "" }
    private func unitName(_ id: String) -> String { units.first { $0.id == id }?.name ?? "" }

    private func text(_ field: UITextField) -> String {
        field.text?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    // MARK: - UI builders

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
        let title = UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textPrimary)
        let stack = UIStackView.vertical(spacing: 5, alignment: .fill)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(field)
        return stack
    }

    private func pickerGroup(_ label: String, _ button: UIButton, placeholder: String,
                             action: Selector) -> UIStackView {
        configurePickerButton(button, placeholder: placeholder)
        button.addTarget(self, action: action, for: .touchUpInside)
        let title = UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textPrimary)
        let stack = UIStackView.vertical(spacing: 5, alignment: .fill)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(button)
        return stack
    }

    private func hPair(_ a: UIView, _ b: UIView) -> UIStackView {
        let row = UIStackView.horizontal(spacing: 12, alignment: .top)
        row.distribution = .fillEqually
        row.addArrangedSubview(a)
        row.addArrangedSubview(b)
        return row
    }

    private func dimX() -> UILabel {
        UILabel.make("x", font: AppFonts.regular(13), color: AppColors.textSecondary, align: .center)
    }

    private func styleUnitBox(_ label: UILabel) {
        label.text = "kg"
        label.font = AppFonts.regular(13)
        label.textColor = AppColors.textSecondary
        label.textAlignment = .center
        label.backgroundColor = AppColors.surface
        label.layer.cornerRadius = AppMetrics.radiusMD
        label.layer.borderWidth = 1
        label.layer.borderColor = AppColors.border.cgColor
        label.constrainHeight(48)
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

        // A small chevron pinned to the right edge. (Using the configuration's own
        // image places it right after the title and scales it with the body font —
        // too large and mis-positioned, as seen in the design review.)
        let chevron = UIImageView(image: UIImage(systemName: "chevron.down",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
        chevron.tintColor = AppColors.textSecondary
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
}
