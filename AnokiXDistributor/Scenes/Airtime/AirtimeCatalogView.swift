import UIKit

/// Airtime & VAS › Catalog & orders. Flattens the VAS category tree to selectable leaves
/// (horizontal scroll, expandable to a grid), loads that category's products, and mirrors the
/// web portal's "Order summary" — recipient, optional custom amount for ad-hoc products,
/// reference, and a wallet-paid "Sell now".
final class AirtimeCatalogView: VasSectionView {

    private static let productLimit = 60

    private var categories: [VasCategoriesData.Node] = []
    private var products: [VasProductsData.Product] = []
    private var selectedCategory: VasCategoriesData.Node?
    private var selectedProduct: VasProductsData.Product?

    private var categoriesLoading = false
    private var productsLoading = false
    private var categoriesExpanded = false
    private var loaded = false
    /// Distributor VAS commission rate from api/common/vas/categories (e.g. 0.05 = 5%).
    private var commissionRate: Double = 0

    private var categoryToggle: UIButton!
    private let categoryListContainer = UIStackView.vertical(spacing: 12, alignment: .fill)
    private var poweredByLabel: UILabel!
    private let productListContainer = UIStackView.vertical(spacing: 12, alignment: .fill)

    private let recipientField = UITextField()
    private let customAmountField = UITextField()
    private let referenceField = UITextField()
    private var referenceCounter: UILabel!
    private var customAmountBlock: UIView!
    private var summaryProductNameLabel: UILabel!
    private var summaryProductAmountLabel: UILabel!
    private var summaryServiceFeeLabel: UILabel!
    private var summaryCommissionLabel: UILabel!
    private var summaryTotalLabel: UILabel!
    private var buyButton: UIButton!

    override func build() {
        stack.addArrangedSubview(buildCategoryCard())
        stack.addArrangedSubview(buildProductCard())
        stack.addArrangedSubview(buildOrderSummaryCard())
        rebuildCategories()
        rebuildProducts()
        rebuildOrderSummary()
    }

    override func onShown() {
        guard !loaded else { return }
        loaded = true
        loadCategories()
    }

    /// The distributor is now acting as a different customer (or none): the catalog is read on
    /// the customer's token, so what is on screen is dropped and re-read for the new one.
    func onCustomerChanged() {
        loaded = false
        categories = []
        products = []
        selectedCategory = nil
        selectedProduct = nil
        poweredByLabel.attributedText = nil
        customAmountField.text = ""
        rebuildCategories()
        rebuildProducts()
        rebuildOrderSummary()
        if !isHidden && !(host?.vasActingCustomerId ?? "").isEmpty { onShown() }
    }

    // MARK: Cards

    private func buildCategoryCard() -> UIView {
        let (cardView, content) = makeCard(title: nil)
        categoryToggle = UIButton(type: .system)
        categoryToggle.setTitle("View all", for: .normal)
        categoryToggle.setTitleColor(AppColors.success, for: .normal)
        categoryToggle.titleLabel?.font = AppFonts.semibold(13)
        categoryToggle.setContentHuggingPriority(.required, for: .horizontal)
        categoryToggle.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.categoriesExpanded.toggle()
            self.rebuildCategories()
        }, for: .touchUpInside)

        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        header.addArrangedSubview(UILabel.make("1. Choose a category", font: AppFonts.bold(15), color: AppColors.textPrimary))
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(categoryToggle)
        content.addArrangedSubview(header)
        content.addArrangedSubview(categoryListContainer)
        return cardView
    }

    private func buildProductCard() -> UIView {
        let (cardView, content) = makeCard(title: "2. Select a product")
        poweredByLabel = UILabel.make("", font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 0)
        content.addArrangedSubview(poweredByLabel)
        content.addArrangedSubview(productListContainer)
        return cardView
    }

    private func buildOrderSummaryCard() -> UIView {
        let (cardView, content) = makeCard(title: "Order summary")
        content.spacing = 14

        recipientField.addAction(UIAction { [weak self] _ in self?.rebuildOrderSummary() }, for: .editingChanged)
        content.addArrangedSubview(labeledField("Recipient number", recipientField,
                                                placeholder: "082 123 4567", keyboard: .phonePad))

        customAmountField.addAction(UIAction { [weak self] _ in self?.rebuildOrderSummary() }, for: .editingChanged)
        customAmountBlock = labeledField("Custom amount (R)", customAmountField,
                                         placeholder: "R e.g. 20", keyboard: .decimalPad)
        customAmountBlock.isHidden = true
        content.addArrangedSubview(customAmountBlock)

        referenceField.addAction(UIAction { [weak self] _ in self?.referenceChanged() }, for: .editingChanged)
        referenceCounter = UILabel.make("0/30", font: AppFonts.regular(11), color: AppColors.textTertiary, align: .right)
        let refStack = labeledField("Optional reference", referenceField, placeholder: "e.g. invoice, customer name")
        refStack.addArrangedSubview(referenceCounter)
        content.addArrangedSubview(refStack)

        summaryProductNameLabel = UILabel.make("No product selected", font: AppFonts.regular(14), color: AppColors.textSecondary, lines: 1)
        summaryProductAmountLabel = UILabel.make("", font: AppFonts.regular(14), color: AppColors.textPrimary)
        content.addArrangedSubview(summaryRow(summaryProductNameLabel, summaryProductAmountLabel))

        summaryServiceFeeLabel = UILabel.make(VasFormat.money(0), font: AppFonts.regular(14), color: AppColors.textPrimary)
        content.addArrangedSubview(summaryRow(
            UILabel.make("Service fee", font: AppFonts.regular(14), color: AppColors.textSecondary),
            summaryServiceFeeLabel))

        summaryCommissionLabel = UILabel.make(VasFormat.money(0), font: AppFonts.regular(14), color: AppColors.success)
        content.addArrangedSubview(summaryRow(
            UILabel.make("Your commission (est.)", font: AppFonts.regular(14), color: AppColors.textSecondary),
            summaryCommissionLabel))

        content.addArrangedSubview(hairline())

        summaryTotalLabel = UILabel.make(VasFormat.money(0), font: AppFonts.bold(20), color: AppColors.purplePrimary)
        content.addArrangedSubview(summaryRow(
            UILabel.make("Total", font: AppFonts.bold(16), color: AppColors.textPrimary),
            summaryTotalLabel))

        buyButton = primaryButton("Sell now") { [weak self] in self?.buyTapped() }
        content.addArrangedSubview(buyButton)
        content.addArrangedSubview(UILabel.make(
            "Paid from your anokiX wallet. Change how you pay in Settings → Preferences.",
            font: AppFonts.regular(11), color: AppColors.textTertiary, lines: 0))
        return cardView
    }

    // MARK: Categories

    private func rebuildCategories() {
        categoryListContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        categoryToggle.isHidden = categories.count <= 1
        categoryToggle.setTitle(categoriesExpanded ? "Show less" : "View all", for: .normal)

        if categoriesLoading {
            categoryListContainer.addArrangedSubview(loadingIndicator())
            return
        }
        if categories.isEmpty {
            categoryListContainer.addArrangedSubview(centeredMessage("No categories available."))
            return
        }
        if categoriesExpanded {
            let cards = categories.map { categoryCardView($0, fixedWidth: false) }
            categoryListContainer.addArrangedSubview(gridRows(cards, columns: 3, spacing: 12))
        } else {
            let scroll = UIScrollView()
            scroll.showsHorizontalScrollIndicator = false
            let row = UIStackView.horizontal(spacing: 12, alignment: .fill)
            row.forAutoLayout()
            categories.forEach { row.addArrangedSubview(categoryCardView($0, fixedWidth: true)) }
            scroll.addSubview(row)
            row.pinEdges(to: scroll)
            scroll.heightAnchor.constraint(equalToConstant: 128).isActive = true
            row.heightAnchor.constraint(equalTo: scroll.heightAnchor).isActive = true
            categoryListContainer.addArrangedSubview(scroll)
        }
    }

    private func categoryCardView(_ node: VasCategoriesData.Node, fixedWidth: Bool) -> UIView {
        let selected = node.id == selectedCategory?.id
        let card = VasTapCard()
        card.backgroundColor = AppColors.surface
        card.layer.cornerRadius = 14
        card.layer.borderWidth = selected ? 2 : 1
        card.layer.borderColor = (selected ? AppColors.success : AppColors.border).cgColor
        card.onTap = { [weak self] in self?.selectCategory(node) }

        let tile = StyleKit.iconTile(color: AppColors.purpleLight)
        tile.constrainSize(36)
        let icon = UIImageView(image: UIImage(systemName: VasFormat.categoryIcon(id: node.id, name: node.name)))
        icon.tintColor = AppColors.purplePrimary
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        tile.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18)
        ])
        let name = UILabel.make(node.name, font: AppFonts.semibold(13), color: AppColors.textPrimary, lines: 2)
        let count = UILabel.make("\(node.productCount) \(node.productCount == 1 ? "bundle" : "bundles")",
                                 font: AppFonts.regular(11), color: AppColors.textSecondary)

        let inner = UIStackView.vertical(spacing: 8, alignment: .leading)
        inner.isUserInteractionEnabled = false
        inner.forAutoLayout()
        // Trailing spacer absorbs slack when the card is stretched to the row's fixed height,
        // keeping the icon/name/count top-aligned rather than spreading them apart.
        [tile, name, count, UIView()].forEach { inner.addArrangedSubview($0) }
        card.addSubview(inner)
        inner.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        if fixedWidth { card.widthAnchor.constraint(equalToConstant: 128).isActive = true }
        return card
    }

    private func selectCategory(_ node: VasCategoriesData.Node) {
        selectedCategory = node
        selectedProduct = nil
        poweredByLabel.attributedText = poweredByText(node.name)
        rebuildCategories()
        rebuildOrderSummary()
        loadProducts(node.id)
    }

    private func poweredByText(_ categoryName: String) -> NSAttributedString {
        let s = NSMutableAttributedString()
        s.append(NSAttributedString(string: categoryName, attributes: [
            .font: AppFonts.bold(12), .foregroundColor: AppColors.textPrimary]))
        s.append(NSAttributedString(string: " powered by ", attributes: [
            .font: AppFonts.regular(12), .foregroundColor: AppColors.textSecondary]))
        s.append(NSAttributedString(string: "Limes", attributes: [
            .font: AppFonts.bold(12), .foregroundColor: AppColors.success]))
        return s
    }

    // MARK: Products

    private func rebuildProducts() {
        productListContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if productsLoading {
            productListContainer.addArrangedSubview(loadingIndicator())
            return
        }
        if products.isEmpty {
            productListContainer.addArrangedSubview(centeredMessage("No products available for this category."))
            return
        }
        productListContainer.addArrangedSubview(gridRows(products.map { productCardView($0) }, columns: 2, spacing: 12))
    }

    private func productCardView(_ product: VasProductsData.Product) -> UIView {
        let selected = product.id == selectedProduct?.id
        let adHoc = product.isAdHoc
        let card = VasTapCard()
        card.backgroundColor = AppColors.surface
        card.layer.cornerRadius = 12
        card.layer.borderWidth = selected ? 2 : 1
        card.layer.borderColor = (selected ? AppColors.success : AppColors.border).cgColor
        card.onTap = { [weak self] in self?.selectProduct(product) }

        let title = UILabel.make(adHoc ? "Custom" : (product.name ?? "—"),
                                 font: AppFonts.bold(14), color: AppColors.textPrimary, lines: 2)
        let subtitle = UILabel.make(adHoc ? (product.name ?? "") : VasFormat.money(product.price),
                                    font: adHoc ? AppFonts.regular(12) : AppFonts.semibold(12),
                                    color: adHoc ? AppColors.textSecondary : AppColors.purplePrimary, lines: 2)
        let text = UIStackView.vertical(spacing: 4, alignment: .leading)
        text.setContentHuggingPriority(.defaultLow, for: .horizontal)
        [title, subtitle].forEach { text.addArrangedSubview($0) }

        let row = UIStackView.horizontal(spacing: 8, alignment: .top)
        row.isUserInteractionEnabled = false
        row.forAutoLayout()
        row.addArrangedSubview(text)
        if selected {
            let check = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
            check.tintColor = AppColors.success
            check.contentMode = .scaleAspectFit
            check.setContentHuggingPriority(.required, for: .horizontal)
            check.forAutoLayout()
            check.widthAnchor.constraint(equalToConstant: 18).isActive = true
            check.heightAnchor.constraint(equalToConstant: 18).isActive = true
            row.addArrangedSubview(check)
        }
        card.addSubview(row)
        row.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        card.heightAnchor.constraint(greaterThanOrEqualToConstant: 64).isActive = true
        return card
    }

    private func selectProduct(_ product: VasProductsData.Product) {
        selectedProduct = product
        if !product.isAdHoc { customAmountField.text = "" }
        rebuildProducts()
        rebuildOrderSummary()
    }

    /// Equal-width grid of `views` laid out in `columns` per row (last row filler-padded).
    private func gridRows(_ views: [UIView], columns: Int, spacing: CGFloat) -> UIStackView {
        let container = UIStackView.vertical(spacing: spacing, alignment: .fill)
        var index = 0
        while index < views.count {
            let row = UIStackView.horizontal(spacing: spacing, alignment: .fill)
            row.distribution = .fillEqually
            for _ in 0..<columns {
                if index < views.count {
                    row.addArrangedSubview(views[index]); index += 1
                } else {
                    row.addArrangedSubview(UIView())
                }
            }
            container.addArrangedSubview(row)
        }
        return container
    }

    // MARK: Order summary

    /// The amount that will be charged: ad-hoc → custom input; fixed → the product price.
    private func currentAmount() -> Double {
        guard let p = selectedProduct else { return 0 }
        return p.isAdHoc ? VasFormat.parse(customAmountField.text) : p.price
    }

    private func rebuildOrderSummary() {
        let amount = currentAmount()
        let serviceFee = 0.0 // No per-product fee in the VAS feed — wallet-paid at face value.

        if let p = selectedProduct {
            summaryProductNameLabel.text = p.name ?? "—"
            summaryProductNameLabel.textColor = AppColors.textPrimary
            summaryProductAmountLabel.text = VasFormat.money(amount)
        } else {
            summaryProductNameLabel.text = "No product selected"
            summaryProductNameLabel.textColor = AppColors.textSecondary
            summaryProductAmountLabel.text = ""
        }
        summaryServiceFeeLabel.text = VasFormat.money(serviceFee)
        // Distributor's estimated earning — informational, not added to the wallet-paid total.
        summaryCommissionLabel.text = VasFormat.money(amount * commissionRate)
        summaryTotalLabel.text = VasFormat.money(amount + serviceFee)
        customAmountBlock.isHidden = !(selectedProduct?.isAdHoc ?? false)
    }

    private func referenceChanged() {
        if let t = referenceField.text, t.count > 30 { referenceField.text = String(t.prefix(30)) }
        referenceCounter.text = "\(referenceField.text?.count ?? 0)/30"
    }

    // MARK: Networking

    private func loadCategories() {
        categoriesLoading = true
        rebuildCategories()
        ApiClient.shared.getVasCategories(customerId: host?.vasActingCustomerId ?? "") { [weak self] result in
            guard let self else { return }
            self.categoriesLoading = false
            switch result {
            case .success(let data):
                self.commissionRate = data.commissionRate
                self.categories = data.leaves
                if let first = self.categories.first {
                    self.selectCategory(first)
                } else {
                    self.rebuildCategories()
                }
            case .failure(let error):
                self.categories = []
                self.rebuildCategories()
                self.host?.vasShowError(error.message)
            }
        }
    }

    private func loadProducts(_ categoryId: String) {
        productsLoading = true
        products = []
        rebuildProducts()
        ApiClient.shared.getVasProducts(category: categoryId, page: 1, limit: Self.productLimit,
                                        customerId: host?.vasActingCustomerId ?? "") { [weak self] result in
            guard let self else { return }
            self.productsLoading = false
            switch result {
            case .success(let data): self.products = data.products
            case .failure(let error):
                self.products = []
                self.host?.vasShowError(error.message)
            }
            self.rebuildProducts()
        }
    }

    // MARK: Purchase

    private func buyTapped() {
        guard validate(), let category = selectedCategory, let product = selectedProduct else { return }
        let customerId = host?.vasActingCustomerId ?? ""
        guard !customerId.isEmpty else {
            _ = fail("Choose the customer you are acting for first.")
            return
        }
        let msisdn = text(recipientField)
        let amount = currentAmount()

        buyButton.isEnabled = false
        buyButton.setTitle("Processing…", for: .normal)
        ApiClient.shared.purchaseVas(productId: product.id, msisdn: msisdn, amount: amount,
                                     sku: product.sku ?? "", name: product.name ?? "",
                                     category: category.name,
                                     customerId: customerId) { [weak self] result in
            guard let self else { return }
            self.buyButton.isEnabled = true
            self.buyButton.setTitle("Sell now", for: .normal)
            switch result {
            case .success:
                self.onPurchaseComplete()
            case .failure(let error):
                self.host?.vasShowError(error.message)
            }
        }
    }

    private func onPurchaseComplete() {
        host?.vasShowAlert(title: "Sale successful",
                           message: "Your VAS sale has been submitted. Check Recent transactions for the outcome.")
        selectedProduct = nil
        customAmountField.text = ""
        referenceField.text = ""
        referenceCounter.text = "0/30"
        rebuildProducts()
        rebuildOrderSummary()
        host?.vasRefreshTransactions()
    }

    /// Validate the order; on the first problem, prompt and return false.
    private func validate() -> Bool {
        guard selectedProduct != nil else { return fail("Please select a product first.") }
        let msisdn = text(recipientField)
        if msisdn.isEmpty { return fail("Please enter the recipient's mobile number.") }
        if !VasFormat.isValidMsisdn(msisdn) { return fail("Enter a valid mobile number, e.g. 082 123 4567.") }
        if currentAmount() <= 0 { return fail("Please enter a valid amount greater than R0.00.") }
        return true
    }

    private func fail(_ message: String) -> Bool {
        host?.vasShowAlert(title: "Check your details", message: message)
        return false
    }
}
