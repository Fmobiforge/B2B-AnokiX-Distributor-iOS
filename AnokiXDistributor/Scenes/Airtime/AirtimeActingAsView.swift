import UIKit

/// The "Acting as" bar shared by Subscription, Catalog & orders and Dynamic services — the
/// UIKit twin of Android's `ActingAsSelector`.
///
/// Limes issues its token per customer, so those three tabs cannot call anything until the
/// distributor has picked one of their onboarded customers and `select-customer` has come back
/// approved. Only customers with status `ACT` are offered — Limes refuses to authenticate as
/// anyone else — and the approved `customer_id` then travels with every request those tabs make.
final class AirtimeActingAsView: VasSectionView {

    private static let limit = 500

    /// Fires when the approved customer changes (including back to none).
    var onChange: ((VasSelectCustomerData.Customer?) -> Void)?

    private let pickerButton = UIButton(type: .system)
    private let noteLabel = UILabel.make("", font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 0)
    private var chip: PaddingLabel!
    private var pickerStack: UIStackView!
    private var emptyStack: UIStackView!
    private let spinner = UIActivityIndicatorView(style: .medium)

    private var customers: [VasCustomersData.Customer] = []
    private var approved: VasSelectCustomerData.Customer?
    private var customersLoaded = false
    private var busy = false

    // MARK: State

    /// The approved customer's id, or "" while no customer has been authenticated.
    var customerId: String { approved?.id ?? "" }

    var hasCustomer: Bool { !customerId.isEmpty }

    /// Shown with the three customer-scoped tabs; hidden everywhere else.
    func setVisible(_ visible: Bool) {
        isHidden = !visible
        if visible && !customersLoaded { loadCustomers(openPicker: false) }
    }

    /// A customer was just onboarded, so the picker list is stale. The new customer is not
    /// active on Limes yet, but the operator will expect to find them once they are.
    func reloadCustomers() {
        customersLoaded = false
        if !isHidden { loadCustomers(openPicker: false) }
    }

    // MARK: Build

    override func build() {
        let (cardView, content) = makeCard(title: nil)

        chip = statusPill((label: "", fg: AppColors.success, bg: AppColors.successBg))
        chip.isHidden = true
        chip.setContentHuggingPriority(.required, for: .horizontal)
        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        header.addArrangedSubview(UILabel.make("Acting as", font: AppFonts.bold(14), color: AppColors.textPrimary))
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(chip)
        content.addArrangedSubview(header)

        styleDropdown(pickerButton)
        setDropdownTitle(pickerButton, "Select a customer", chosen: false)
        pickerButton.addAction(UIAction { [weak self] _ in self?.showPicker() }, for: .touchUpInside)

        spinner.hidesWhenStopped = true
        spinner.color = AppColors.purplePrimary
        // The dropdown takes the slack; the spinner keeps its intrinsic width beside it.
        spinner.setContentHuggingPriority(.required, for: .horizontal)
        pickerButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let pickerRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        pickerRow.addArrangedSubview(pickerButton)
        pickerRow.addArrangedSubview(spinner)

        noteLabel.text = Self.note
        pickerStack = UIStackView.vertical(spacing: 8, alignment: .fill)
        pickerStack.addArrangedSubview(pickerRow)
        pickerStack.addArrangedSubview(noteLabel)
        content.addArrangedSubview(pickerStack)

        // No customers at all: onboarding is the only way forward, so link straight to it.
        emptyStack = UIStackView.vertical(spacing: 6, alignment: .leading)
        emptyStack.addArrangedSubview(UILabel.make("No customers yet.", font: AppFonts.bold(13), color: AppColors.textPrimary))
        emptyStack.addArrangedSubview(UILabel.make(
            "Limes issues its token per customer, so onboard someone before selling to them.",
            font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 0))
        let onboard = outlinedButton("Onboard a customer") { [weak self] in
            self?.host?.vasOpenOnboardTab()
        }
        onboard.configuration?.baseForegroundColor = AppColors.success
        emptyStack.addArrangedSubview(onboard)
        emptyStack.isHidden = true
        content.addArrangedSubview(emptyStack)

        stack.addArrangedSubview(cardView)
    }

    private static let note = "Pick a customer — their Limes token is what these calls use."

    // MARK: Customers

    private func loadCustomers(openPicker: Bool) {
        guard !busy else { return }
        busy = true
        customersLoaded = true
        setLoading(true, note: "Loading your active customers…")

        ApiClient.shared.getVasCustomers(search: "", limit: Self.limit, activeOnly: true) { [weak self] result in
            guard let self else { return }
            self.busy = false
            self.setLoading(false)
            switch result {
            case .success(let data):
                // The endpoint is asked for active customers only; the filter is repeated here
                // so a server that ignores the flag cannot offer a customer Limes would refuse
                // to authenticate as.
                self.customers = data.customers.filter { Self.isActive($0.status) }
                // A customer that is no longer active must not stay selected.
                if let approved = self.approved,
                   !self.customers.contains(where: { $0.id == approved.id }) {
                    self.clearSelection()
                }
                self.render()
                if openPicker { self.showPicker() }
            case .failure(let error):
                self.customersLoaded = false
                self.render()
                self.host?.vasShowError(error.message)
            }
        }
    }

    private static func isActive(_ status: String?) -> Bool {
        let s = (status ?? "").trimmingCharacters(in: .whitespaces).uppercased()
        return s == "ACT" || s == "ACTIVE"
    }

    private func showPicker() {
        guard !busy else { return }
        guard !customers.isEmpty else {
            // Either the list has never loaded or it failed — the operator tapped because they
            // want the options, so go and fetch them and open the picker on the way back.
            loadCustomers(openPicker: true)
            return
        }
        presentOptions("Choose a customer", options: customers.map(Self.optionLabel)) { [weak self] index in
            guard let self else { return }
            self.select(self.customers[index])
        }
    }

    /// "Mr Tam Ho · 023 123 1132" — name plus the number, as on the web portal.
    private static func optionLabel(_ c: VasCustomersData.Customer) -> String {
        let phone = VasFormat.msisdn(c.phone)
        return phone.isEmpty ? c.displayName : "\(c.displayName) · \(phone)"
    }

    // MARK: select-customer

    private func select(_ customer: VasCustomersData.Customer) {
        guard !busy else { return }
        busy = true
        // Show the pick immediately, then say what is happening — the call is a round trip to
        // Limes and the operator should see which name they chose while it runs.
        setDropdownTitle(pickerButton, Self.optionLabel(customer), chosen: true)
        chip.isHidden = true
        setLoading(true, note: "Authenticating with Limes…")

        ApiClient.shared.selectVasCustomer(customerId: customer.id) { [weak self] result in
            guard let self else { return }
            self.busy = false
            self.setLoading(false)
            switch result {
            case .success(let data):
                guard data.authenticated else {
                    // Approval is what unlocks the tabs; anything else leaves them shut.
                    self.clearSelection()
                    self.render()
                    self.host?.vasShowError("Limes could not authenticate as this customer. "
                                            + "Make sure their account is active, then try again.")
                    return
                }
                if let c = data.customer, !c.id.isEmpty {
                    self.approved = c
                } else {
                    self.approved = Self.fallback(from: customer)
                }
                self.chip.text = data.subjectLabel
                self.chip.isHidden = data.subjectLabel.isEmpty
                self.render()
                self.onChange?(self.approved)
            case .failure(let error):
                self.clearSelection()
                self.render()
                self.host?.vasShowError(error.message)
            }
        }
    }

    /// Stands in when the response omits the customer block — the picked row is what we know.
    private static func fallback(from c: VasCustomersData.Customer) -> VasSelectCustomerData.Customer {
        VasSelectCustomerData.Customer(id: c.id, firstname: c.firstname, lastname: c.lastname,
                                       email: c.email, phone: c.phone, status: c.status,
                                       limesAccountId: c.limesAccountId)
    }

    private func clearSelection() {
        let had = approved != nil
        approved = nil
        chip.isHidden = true
        setDropdownTitle(pickerButton, "Select a customer", chosen: false)
        if had { onChange?(nil) }
    }

    // MARK: Rendering

    private func render() {
        let none = customers.isEmpty && approved == nil
        pickerStack.isHidden = none
        emptyStack.isHidden = !none
        noteLabel.isHidden = approved != nil
        noteLabel.text = Self.note
    }

    private func setLoading(_ active: Bool, note: String? = nil) {
        active ? spinner.startAnimating() : spinner.stopAnimating()
        pickerButton.isEnabled = !active
        if active, let note {
            noteLabel.isHidden = false
            noteLabel.text = note
        }
    }
}
