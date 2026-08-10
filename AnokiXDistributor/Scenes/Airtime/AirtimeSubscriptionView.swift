import UIKit

/// Airtime & VAS › Subscription. Assigns a SIM to a subscription product; Limes replies with
/// the MSISDN, which is the number every later top-up is sold to. eSIMs carry no printed
/// serial, so switching eSIM on hides the ICCID block and sends `e_sim=1` instead.
final class AirtimeSubscriptionView: VasSectionView {

    private let productButton = UIButton(type: .system)
    private let esimSwitch = UISwitch()
    private let iccidField = UITextField()
    private var iccidBlock: UIStackView!
    private var createButton: UIButton!
    private let simListContainer = UIStackView.vertical(spacing: 0, alignment: .fill)

    private var products: [VasSubscriptionProductsData.Product] = []
    private var selectedProduct: VasSubscriptionProductsData.Product?
    private var subscriptions: [VasSubscriptionsData.Subscription] = []
    private var loaded = false

    override func build() {
        let (formCard, form) = makeCard(
            title: "Assign a SIM & subscription",
            body: "Pick a subscription product and hand in the SIM's ICCID. Limes assigns the "
                + "phone number (MSISDN) — that number, not the ICCID, is what you recharge "
                + "under Catalog & orders.")

        // The product list comes from the API, so the dropdown is wired by hand rather than
        // through labeledDropdown, which takes a fixed option list.
        styleDropdown(productButton)
        setDropdownTitle(productButton, "Select a product", chosen: false)
        productButton.addAction(UIAction { [weak self] _ in self?.pickProduct() }, for: .touchUpInside)
        let productStack = UIStackView.vertical(spacing: 6, alignment: .fill)
        productStack.addArrangedSubview(UILabel.make("Product", font: AppFonts.semibold(13), color: AppColors.textPrimary))
        productStack.addArrangedSubview(productButton)
        form.addArrangedSubview(productStack)

        esimSwitch.onTintColor = AppColors.success
        esimSwitch.setContentHuggingPriority(.required, for: .horizontal)
        esimSwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            // An eSIM has no ICCID to hand in — hide the field rather than ask for a serial
            // that does not exist.
            self.iccidBlock.isHidden = self.esimSwitch.isOn
        }, for: .valueChanged)
        let esimRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        esimRow.addArrangedSubview(UILabel.make("eSIM", font: AppFonts.semibold(13), color: AppColors.textPrimary))
        esimRow.addArrangedSubview(UIView())
        esimRow.addArrangedSubview(esimSwitch)
        form.addArrangedSubview(esimRow)

        iccidBlock = UIStackView.vertical(spacing: 6, alignment: .fill)
        iccidBlock.addArrangedSubview(labeledField("ICCID (SIM)", iccidField,
                                                   placeholder: "8927078220001234567", keyboard: .numberPad))
        iccidBlock.addArrangedSubview(UILabel.make(
            "The 19–20 digit serial printed on the SIM card — not a phone number.",
            font: AppFonts.regular(11), color: AppColors.textSecondary, lines: 0))
        form.addArrangedSubview(iccidBlock)

        createButton = primaryButton("Create subscription", color: AppColors.success) { [weak self] in
            self?.subscribe()
        }
        form.addArrangedSubview(createButton)
        stack.addArrangedSubview(formCard)

        let (simCard, simContent) = makeCard(title: "Activated SIMs")
        simContent.addArrangedSubview(simListContainer)
        stack.addArrangedSubview(simCard)
        rebuildSims()
    }

    override func onShown() {
        guard !loaded else { return }
        loaded = true
        loadProducts()
        loadSubscriptions()
    }

    // MARK: Products

    private func loadProducts() {
        ApiClient.shared.getVasSubscriptionProducts { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data):
                self.products = data.products
                // Default to the first product so the form is usable in one tap.
                if let first = self.products.first { self.select(first) }
            case .failure(let error):
                self.host?.vasShowError(error.message)
            }
        }
    }

    private func pickProduct() {
        guard !products.isEmpty else {
            // Nothing to choose from means the first fetch failed or is still running — the
            // operator tapped because they want options, so go and get them.
            loadProducts()
            return
        }
        presentOptions("Product", options: products.map(\.label)) { [weak self] index in
            guard let self else { return }
            self.select(self.products[index])
        }
    }

    private func select(_ product: VasSubscriptionProductsData.Product) {
        selectedProduct = product
        setDropdownTitle(productButton, product.label, chosen: true)
    }

    // MARK: Activated SIMs

    private func loadSubscriptions() {
        ApiClient.shared.getVasSubscriptions { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data): self.subscriptions = data.subscriptions
            case .failure: self.subscriptions = []
            }
            self.rebuildSims()
        }
    }

    private func rebuildSims() {
        simListContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if subscriptions.isEmpty {
            simListContainer.addArrangedSubview(centeredMessage("No SIMs activated yet."))
            return
        }
        for (i, sub) in subscriptions.enumerated() {
            simListContainer.addArrangedSubview(simRow(sub))
            if i < subscriptions.count - 1 { simListContainer.addArrangedSubview(hairline()) }
        }
    }

    /// A row leads with the MSISDN Limes assigned, because that number — not the ICCID — is
    /// what later top-ups are sold to.
    private func simRow(_ s: VasSubscriptionsData.Subscription) -> UIView {
        let hasNumber = !(s.msisdn ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        let title = UILabel.make(hasNumber ? VasFormat.msisdn(s.msisdn) : "Number pending",
                                 font: AppFonts.bold(14), color: AppColors.textPrimary, lines: 1)
        let pill = statusPill(VasFormat.limesStatusStyle(s.status))
        pill.setContentHuggingPriority(.required, for: .horizontal)
        let top = UIStackView.horizontal(spacing: 8, alignment: .center)
        top.addArrangedSubview(title)
        top.addArrangedSubview(UIView())
        top.addArrangedSubview(pill)

        let iccid = (s.iccid ?? "").isEmpty ? "eSIM" : "ICCID \(s.iccid ?? "")"
        let lines = UIStackView.vertical(spacing: 3, alignment: .fill)
        lines.addArrangedSubview(top)
        lines.addArrangedSubview(UILabel.make(iccid, font: AppFonts.regular(12), color: AppColors.textSecondary))
        return padded(lines, insets: UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0))
    }

    // MARK: Create

    private func subscribe() {
        guard let product = selectedProduct else {
            host?.vasShowAlert(title: "Check your details", message: "Please select a subscription product.")
            return
        }
        let eSim = esimSwitch.isOn
        let iccid = text(iccidField)
        if !eSim && !VasFormat.isValidIccid(iccid) {
            host?.vasShowAlert(title: "Check your details",
                               message: "Enter the SIM's ICCID (19–20 digits), or switch on eSIM.")
            return
        }

        createButton.isEnabled = false
        createButton.setTitle("Processing…", for: .normal)
        ApiClient.shared.subscribeVas(productId: product.id, iccid: iccid, eSim: eSim) { [weak self] result in
            guard let self else { return }
            self.createButton.isEnabled = true
            self.createButton.setTitle("Create subscription", for: .normal)
            switch result {
            case .success:
                self.host?.vasShowAlert(
                    title: "Subscription created",
                    message: "The SIM has been submitted for activation. The assigned number "
                        + "appears under Activated SIMs.")
                self.iccidField.text = ""
                self.loadSubscriptions()
            case .failure(let error):
                self.host?.vasShowError(error.message)
            }
        }
    }
}
