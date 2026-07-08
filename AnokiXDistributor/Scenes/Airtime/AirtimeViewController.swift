import UIKit

/// Airtime & VAS (Limes, live) — UIKit port of the Android `AirtimeActivity`.
/// Flattens the VAS category tree to selectable leaves (horizontal scroll, expandable to a
/// grid), loads that category's products, and mirrors the web portal's "Order summary" —
/// recipient, optional custom amount for ad-hoc products, reference, and a wallet-paid
/// "Sell now". KPI summary + recent transactions come from `api/common/vas/transactions`.
final class AirtimeViewController: BaseSecondaryViewController {

    override var screenTitle: String { "Airtime & VAS" }
    override var screenSubtitle: String? { "Sell airtime, data and digital services · Powered by Limes" }

    private static let productLimit = 60
    private static let txnPerPage = 20

    // MARK: State

    private var categories: [VasCategoriesData.Node] = []
    private var products: [VasProductsData.Product] = []
    private var transactions: [VasTransactionsData.Transaction] = []
    private var summary: VasTransactionsData.Summary?

    private var selectedCategory: VasCategoriesData.Node?
    private var selectedProduct: VasProductsData.Product?

    private var categoriesLoading = false
    private var productsLoading = false
    private var categoriesExpanded = false
    /// Distributor VAS commission rate from api/common/vas/categories (e.g. 0.05 = 5%).
    private var commissionRate: Double = 0

    // MARK: Views rebuilt on data changes

    private var stack: UIStackView!
    private var kpiContainer = UIStackView.vertical(spacing: 12, alignment: .fill)
    private var categoryToggle: UIButton!
    private var categoryListContainer = UIStackView.vertical(spacing: 12, alignment: .fill)
    private var poweredByLabel: UILabel!
    private var productListContainer = UIStackView.vertical(spacing: 12, alignment: .fill)
    private var txnBody = UIStackView.vertical(spacing: 0, alignment: .fill)

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

    // MARK: Setup

    override func setupContent(in container: UIView) {
        stack = makeScrollStack(in: container)
        stack.addArrangedSubview(kpiContainer)
        stack.addArrangedSubview(buildCategoryCard())
        stack.addArrangedSubview(buildProductCard())
        stack.addArrangedSubview(buildOrderSummaryCard())
        stack.addArrangedSubview(buildTransactionsCard())

        rebuildKpis()
        rebuildCategories()
        rebuildProducts()
        rebuildOrderSummary()
        rebuildTransactions()
    }

    override func loadData() {
        loadTransactions()
        loadCategories()
    }

    // MARK: Card builders

    private func makeCard() -> (card: UIView, body: UIStackView) {
        let card = StyleKit.cardView()
        let body = UIStackView.vertical(spacing: 12, alignment: .fill)
        body.forAutoLayout()
        card.addSubview(body)
        body.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return (card, body)
    }

    private func buildCategoryCard() -> UIView {
        let (card, body) = makeCard()
        let title = UILabel.make("1. Choose a category", font: AppFonts.bold(15), color: AppColors.textPrimary)
        categoryToggle = UIButton(type: .system)
        categoryToggle.setTitle("View all", for: .normal)
        categoryToggle.setTitleColor(AppColors.purplePrimary, for: .normal)
        categoryToggle.titleLabel?.font = AppFonts.semibold(13)
        categoryToggle.setContentHuggingPriority(.required, for: .horizontal)
        categoryToggle.addTarget(self, action: #selector(toggleCategories), for: .touchUpInside)
        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        header.addArrangedSubview(title)
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(categoryToggle)
        body.addArrangedSubview(header)
        body.addArrangedSubview(categoryListContainer)
        return card
    }

    private func buildProductCard() -> UIView {
        let (card, body) = makeCard()
        let title = UILabel.make("2. Select a product", font: AppFonts.bold(15), color: AppColors.textPrimary)
        poweredByLabel = UILabel.make("", font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 0)
        body.addArrangedSubview(title)
        body.addArrangedSubview(poweredByLabel)
        body.addArrangedSubview(productListContainer)
        return card
    }

    private func buildOrderSummaryCard() -> UIView {
        let (card, body) = makeCard()
        body.spacing = 14
        body.addArrangedSubview(UILabel.make("Order summary", font: AppFonts.bold(15), color: AppColors.textPrimary))

        StyleKit.styleInput(recipientField)
        recipientField.placeholder = "082 123 4567"
        recipientField.keyboardType = .phonePad
        recipientField.addTarget(self, action: #selector(fieldsChanged), for: .editingChanged)
        body.addArrangedSubview(labeledField("Recipient", field: recipientField))

        StyleKit.styleInput(customAmountField)
        customAmountField.placeholder = "R e.g. 20"
        customAmountField.keyboardType = .decimalPad
        customAmountField.addTarget(self, action: #selector(fieldsChanged), for: .editingChanged)
        customAmountBlock = labeledField("Custom amount (R)", field: customAmountField)
        customAmountBlock.isHidden = true
        body.addArrangedSubview(customAmountBlock)

        StyleKit.styleInput(referenceField)
        referenceField.placeholder = "e.g. invoice, customer name"
        referenceField.addTarget(self, action: #selector(referenceChanged), for: .editingChanged)
        referenceCounter = UILabel.make("0/30", font: AppFonts.regular(11), color: AppColors.textTertiary, align: .right)
        let refStack = UIStackView.vertical(spacing: 6, alignment: .fill)
        refStack.addArrangedSubview(UILabel.make("Optional reference", font: AppFonts.semibold(13), color: AppColors.textPrimary))
        refStack.addArrangedSubview(referenceField)
        refStack.addArrangedSubview(referenceCounter)
        body.addArrangedSubview(refStack)

        summaryProductNameLabel = UILabel.make("No product selected", font: AppFonts.regular(14), color: AppColors.textSecondary, lines: 1)
        summaryProductAmountLabel = UILabel.make("", font: AppFonts.regular(14), color: AppColors.textPrimary)
        body.addArrangedSubview(summaryRow(summaryProductNameLabel, summaryProductAmountLabel))

        summaryServiceFeeLabel = UILabel.make(Self.money(0), font: AppFonts.regular(14), color: AppColors.textPrimary)
        body.addArrangedSubview(summaryRow(UILabel.make("Service fee", font: AppFonts.regular(14), color: AppColors.textSecondary), summaryServiceFeeLabel))

        summaryCommissionLabel = UILabel.make(Self.money(0), font: AppFonts.regular(14), color: AppColors.success)
        body.addArrangedSubview(summaryRow(UILabel.make("Your commission (est.)", font: AppFonts.regular(14), color: AppColors.textSecondary), summaryCommissionLabel))

        body.addArrangedSubview(hairline())

        summaryTotalLabel = UILabel.make(Self.money(0), font: AppFonts.bold(20), color: AppColors.purplePrimary)
        body.addArrangedSubview(summaryRow(UILabel.make("Total", font: AppFonts.bold(16), color: AppColors.textPrimary), summaryTotalLabel))

        buyButton = UIButton(type: .system)
        StyleKit.stylePrimaryButton(buyButton)
        buyButton.setTitle("Sell now", for: .normal)
        buyButton.addTarget(self, action: #selector(buyTapped), for: .touchUpInside)
        body.addArrangedSubview(buyButton)

        body.addArrangedSubview(UILabel.make(
            "Paid from your anokiX wallet. Change how you pay in Settings → Preferences.",
            font: AppFonts.regular(11), color: AppColors.textTertiary, lines: 0))
        return card
    }

    private func buildTransactionsCard() -> UIView {
        let (card, body) = makeCard()
        body.addArrangedSubview(UILabel.make("Recent VAS transactions", font: AppFonts.bold(15), color: AppColors.textPrimary))
        body.addArrangedSubview(txnBody)
        return card
    }

    // MARK: Small view helpers

    private func labeledField(_ title: String, field: UITextField) -> UIStackView {
        let s = UIStackView.vertical(spacing: 6, alignment: .fill)
        s.addArrangedSubview(UILabel.make(title, font: AppFonts.semibold(13), color: AppColors.textPrimary))
        s.addArrangedSubview(field)
        return s
    }

    private func summaryRow(_ left: UILabel, _ right: UILabel) -> UIStackView {
        left.setContentHuggingPriority(.defaultLow, for: .horizontal)
        right.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.addArrangedSubview(left)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(right)
        return row
    }

    private func hairline() -> UIView {
        let line = UIView()
        line.backgroundColor = AppColors.border
        line.constrainHeight(1)
        return line
    }

    private func padded(_ view: UIView, insets: UIEdgeInsets) -> UIView {
        let wrap = UIView()
        view.forAutoLayout()
        wrap.addSubview(view)
        view.pinEdges(to: wrap, insets: insets)
        return wrap
    }

    private func centeredMessage(_ text: String) -> UIView {
        let label = UILabel.make(text, font: AppFonts.regular(13), color: AppColors.textSecondary, align: .center, lines: 0)
        return padded(label, insets: UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 0))
    }

    private func loadingIndicator() -> UIView {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = AppColors.purplePrimary
        spinner.startAnimating()
        spinner.forAutoLayout()
        let wrap = UIView()
        wrap.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: wrap.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 18),
            spinner.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -18)
        ])
        return wrap
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

    // MARK: KPI

    private func rebuildKpis() {
        kpiContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let s = summary
        let cards = [
            KpiCardView(title: "VAS sales · today", value: Self.money(s?.salesToday ?? 0),
                        icon: "ic_check_circle", iconBg: AppColors.successBg, valueColor: AppColors.success, tint: AppColors.success),
            KpiCardView(title: "Transactions · today", value: String(Int(s?.countToday ?? 0)),
                        icon: "ic_orders", iconBg: AppColors.infoBg, valueColor: AppColors.textPrimary, tint: AppColors.info),
            KpiCardView(title: "Commission · month", value: Self.money(s?.commissionMonth ?? 0),
                        icon: "ic_finances", iconBg: AppColors.warningBg, valueColor: AppColors.success, tint: AppColors.warning),
            KpiCardView(title: "Wallet balance", value: Self.money(s?.walletBalance ?? 0),
                        icon: "ic_wallet", iconBg: AppColors.purpleLight, valueColor: AppColors.purplePrimary, tint: AppColors.purplePrimary)
        ]
        kpiContainer.addArrangedSubview(kpiRow(cards[0], cards[1]))
        kpiContainer.addArrangedSubview(kpiRow(cards[2], cards[3]))
    }

    private func kpiRow(_ a: UIView, _ b: UIView) -> UIStackView {
        let row = UIStackView.horizontal(spacing: 12, alignment: .fill)
        row.distribution = .fillEqually
        row.addArrangedSubview(a)
        row.addArrangedSubview(b)
        return row
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
        let card = TapCard()
        card.backgroundColor = AppColors.surface
        card.layer.cornerRadius = 14
        card.layer.borderWidth = selected ? 2 : 1
        card.layer.borderColor = (selected ? AppColors.success : AppColors.border).cgColor
        card.onTap = { [weak self] in self?.selectCategory(node) }

        let tile = StyleKit.iconTile(color: AppColors.purpleLight)
        tile.constrainSize(36)
        let icon = UIImageView(image: UIImage(systemName: Self.icon(for: node.id, node.name)))
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
        let count = UILabel.make(bundleCount(node.productCount), font: AppFonts.regular(11), color: AppColors.textSecondary)

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

    @objc private func toggleCategories() {
        categoriesExpanded.toggle()
        rebuildCategories()
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
        let cards = products.map { productCardView($0) }
        productListContainer.addArrangedSubview(gridRows(cards, columns: 2, spacing: 12))
    }

    private func productCardView(_ product: VasProductsData.Product) -> UIView {
        let selected = product.id == selectedProduct?.id
        let adHoc = product.isAdHoc
        let card = TapCard()
        card.backgroundColor = AppColors.surface
        card.layer.cornerRadius = 12
        card.layer.borderWidth = selected ? 2 : 1
        card.layer.borderColor = (selected ? AppColors.success : AppColors.border).cgColor
        card.onTap = { [weak self] in self?.selectProduct(product) }

        let title = UILabel.make(adHoc ? "Custom" : (product.name ?? "—"),
                                 font: AppFonts.bold(14), color: AppColors.textPrimary, lines: 2)
        let subtitle = UILabel.make(adHoc ? (product.name ?? "") : Self.money(product.price),
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

    // MARK: Order summary

    /// The amount that will be charged: ad-hoc → custom input; fixed → the product price.
    private func currentAmount() -> Double {
        guard let p = selectedProduct else { return 0 }
        if p.isAdHoc {
            let raw = (customAmountField.text ?? "").trimmingCharacters(in: .whitespaces)
            return Double(raw) ?? 0
        }
        return p.price
    }

    private func rebuildOrderSummary() {
        let amount = currentAmount()
        let serviceFee = 0.0
        let total = amount + serviceFee

        if let p = selectedProduct {
            summaryProductNameLabel.text = p.name ?? "—"
            summaryProductNameLabel.textColor = AppColors.textPrimary
            summaryProductAmountLabel.text = Self.money(amount)
        } else {
            summaryProductNameLabel.text = "No product selected"
            summaryProductNameLabel.textColor = AppColors.textSecondary
            summaryProductAmountLabel.text = ""
        }
        summaryServiceFeeLabel.text = Self.money(serviceFee)
        // Distributor's estimated earning — informational, not added to the wallet-paid total.
        summaryCommissionLabel.text = Self.money(amount * commissionRate)
        summaryTotalLabel.text = Self.money(total)
        customAmountBlock.isHidden = !(selectedProduct?.isAdHoc ?? false)
    }

    @objc private func fieldsChanged() { rebuildOrderSummary() }

    @objc private func referenceChanged() {
        if let t = referenceField.text, t.count > 30 { referenceField.text = String(t.prefix(30)) }
        referenceCounter.text = "\(referenceField.text?.count ?? 0)/30"
    }

    // MARK: Transactions

    private func rebuildTransactions() {
        txnBody.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if transactions.isEmpty {
            txnBody.addArrangedSubview(centeredMessage("No transactions yet."))
            return
        }
        for (i, t) in transactions.enumerated() {
            txnBody.addArrangedSubview(transactionRow(t))
            if i < transactions.count - 1 { txnBody.addArrangedSubview(hairline()) }
        }
    }

    private func transactionRow(_ t: VasTransactionsData.Transaction) -> UIView {
        let title = UILabel.make(t.name ?? "—", font: AppFonts.semibold(14), color: AppColors.textPrimary, lines: 1)
        let meta = UILabel.make("\(Self.formatNumber(t.msisdn)) · \(Self.formatTime(t.createdAt))",
                                font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 1)
        let left = UIStackView.vertical(spacing: 3, alignment: .leading)
        left.setContentHuggingPriority(.defaultLow, for: .horizontal)
        [title, meta].forEach { left.addArrangedSubview($0) }

        let amount = UILabel.make(Self.money(t.amount), font: AppFonts.bold(14), color: AppColors.textPrimary)
        let pill = statusPill(t.status)
        let right = UIStackView.vertical(spacing: 4, alignment: .trailing)
        right.setContentHuggingPriority(.required, for: .horizontal)
        [amount, pill].forEach { right.addArrangedSubview($0) }

        let row = UIStackView.horizontal(spacing: 10, alignment: .top)
        row.addArrangedSubview(left)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(right)
        return padded(row, insets: UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0))
    }

    private func statusPill(_ status: String?) -> UIView {
        let style = Self.statusStyle(status)
        let pill = StyleKit.badgeLabel()
        pill.text = style.label
        pill.textColor = style.fg
        pill.backgroundColor = style.bg
        pill.font = AppFonts.semibold(AppMetrics.textLabel)
        return pill
    }

    // MARK: Networking

    private func loadTransactions() {
        ApiClient.shared.getVasTransactions(page: 1, perPage: Self.txnPerPage) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data):
                self.transactions = data.transactions
                self.summary = data.summary
                self.rebuildKpis()
                self.rebuildTransactions()
            case .failure:
                self.transactions = []
                self.rebuildTransactions()
            }
        }
    }

    private func loadCategories() {
        categoriesLoading = true
        rebuildCategories()
        ApiClient.shared.getVasCategories { [weak self] result in
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
            case .failure(let err):
                self.categories = []
                self.rebuildCategories()
                self.toast(err.message)
            }
        }
    }

    private func loadProducts(_ categoryId: String) {
        productsLoading = true
        products = []
        rebuildProducts()
        ApiClient.shared.getVasProducts(category: categoryId, page: 1, limit: Self.productLimit) { [weak self] result in
            guard let self else { return }
            self.productsLoading = false
            switch result {
            case .success(let data):
                self.products = data.products
            case .failure(let err):
                self.products = []
                self.toast(err.message)
            }
            self.rebuildProducts()
        }
    }

    // MARK: Purchase flow

    @objc private func buyTapped() {
        guard validate(), let category = selectedCategory, let product = selectedProduct else { return }
        let msisdn = (recipientField.text ?? "").trimmingCharacters(in: .whitespaces)
        let amount = currentAmount()

        buyButton.isEnabled = false
        buyButton.setTitle("Processing…", for: .normal)
        ApiClient.shared.purchaseVas(productId: product.id, msisdn: msisdn, amount: amount,
                                     sku: product.sku ?? "", name: product.name ?? "",
                                     category: category.name) { [weak self] result in
            guard let self else { return }
            self.buyButton.isEnabled = true
            self.buyButton.setTitle("Sell now", for: .normal)
            switch result {
            case .success:
                self.onPurchaseComplete()
            case .failure(let err):
                self.alert(title: "Sell now", message: err.message)
            }
        }
    }

    private func onPurchaseComplete() {
        alert(title: "Sale successful",
              message: "Your VAS sale has been submitted. Check Recent VAS transactions for the outcome.")
        selectedProduct = nil
        customAmountField.text = ""
        referenceField.text = ""
        referenceCounter.text = "0/30"
        rebuildProducts()
        rebuildOrderSummary()
        loadTransactions()
    }

    /// Validate the order; on the first problem, prompt and return false.
    private func validate() -> Bool {
        guard selectedProduct != nil else {
            alert(title: "Check your details", message: "Please select a product first."); return false
        }
        let msisdn = (recipientField.text ?? "").trimmingCharacters(in: .whitespaces)
        if msisdn.isEmpty {
            alert(title: "Check your details", message: "Please enter the recipient's mobile number."); return false
        }
        if !Self.isValidMsisdn(msisdn) {
            alert(title: "Check your details", message: "Enter a valid mobile number, e.g. 082 123 4567."); return false
        }
        if currentAmount() <= 0 {
            alert(title: "Check your details", message: "Please enter a valid amount greater than R0.00."); return false
        }
        return true
    }

    private func alert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    // MARK: Formatting helpers

    private func bundleCount(_ n: Int) -> String { "\(n) \(n == 1 ? "bundle" : "bundles")" }

    private static let moneyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "\u{00A0}"
        f.decimalSeparator = ","
        f.groupingSize = 3
        f.usesGroupingSeparator = true
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    /// South-African money, e.g. "R 5 050,00" — space-grouped thousands, comma decimal.
    static func money(_ value: Double) -> String {
        "R " + (moneyFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value))
    }

    static func money(_ value: String?) -> String {
        money(Double((value ?? "").trimmingCharacters(in: .whitespaces)) ?? 0)
    }

    /// SA mobile number: 10 digits (0xxxxxxxxx) or 11 digits (27xxxxxxxxx).
    static func isValidMsisdn(_ raw: String) -> Bool {
        let digits = raw.filter(\.isNumber)
        return (digits.count == 10 && digits.hasPrefix("0"))
            || (digits.count == 11 && digits.hasPrefix("27"))
    }

    /// 27821234567 / 0821234567 → "082 123 4567" when it resolves to a 10-digit local number.
    static func formatNumber(_ msisdn: String?) -> String {
        guard let msisdn else { return "" }
        var digits = msisdn.filter(\.isNumber)
        if digits.hasPrefix("27") && digits.count == 11 {
            digits = "0" + digits.dropFirst(2)
        }
        if digits.count == 10 {
            let a = digits.prefix(3)
            let b = digits.dropFirst(3).prefix(3)
            let c = digits.dropFirst(6)
            return "\(a) \(b) \(c)"
        }
        return msisdn
    }

    private static let txnInFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy HH:mm:ss"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()
    private static let txnTimeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()

    static func formatTime(_ createdAt: String?) -> String {
        guard let createdAt else { return "" }
        if let d = txnInFmt.date(from: createdAt) { return txnTimeFmt.string(from: d) }
        return createdAt
    }

    /// Status pill label + colours, mirroring the Android `styleStatus`.
    static func statusStyle(_ status: String?) -> (label: String, fg: UIColor, bg: UIColor) {
        let s = (status ?? "").lowercased()
        if s.contains("fail") || s.contains("error") || s.contains("declin") {
            return ("Failed", AppColors.danger, AppColors.dangerBg)
        }
        if s.contains("success") || s.contains("complete") || s.contains("paid") {
            return ("Success", AppColors.success, AppColors.successBg)
        }
        let raw = status ?? ""
        let label = raw.isEmpty ? "Pending" : raw.prefix(1).uppercased() + raw.dropFirst()
        return (label, AppColors.purplePrimary, AppColors.purpleLight)
    }

    /// Category id/name → an SF Symbol, mirroring the Android `VasIcons`.
    static func icon(for id: String?, _ name: String?) -> String {
        let key = ((id ?? "") + " " + (name ?? "")).lowercased()
        if key.contains("whatsapp") || key.contains("sms") || key.contains("message") { return "message.fill" }
        if key.contains("data") || key.contains("fwa") || key.contains("wifi") { return "wifi" }
        if key.contains("voice") || key.contains("airtime") || key.contains("call") { return "phone.fill" }
        if key.contains("service") || key.contains("fee") || key.contains("wallet") { return "creditcard.fill" }
        let bundleKeys = ["combo", "bundle", "subscription", "package", "gsm", "flte",
                          "supplementary", "choose", "recharge", "convert", "day", "week"]
        if bundleKeys.contains(where: { key.contains($0) }) { return "square.grid.2x2.fill" }
        return "antenna.radiowaves.left.and.right"
    }
}

/// A tappable card container — UIControl so the whole card fires one action; content
/// stacks set `isUserInteractionEnabled = false` so hit-testing resolves to the control.
private final class TapCard: UIControl {
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handleTap() { onTap?() }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }
}
