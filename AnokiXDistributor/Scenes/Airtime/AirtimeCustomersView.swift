import UIKit

/// Airtime & VAS › Customers. The end-customers this distributor has onboarded, with the
/// Limes account number to quote when activating their SIM on the Subscription tab.
final class AirtimeCustomersView: VasSectionView {

    private static let limit = 500

    private let searchBar = SearchBarView(placeholder: "Search name, ID, phone, email or account no.")
    private let listContainer = UIStackView.vertical(spacing: 0, alignment: .fill)
    private var countLabel: UILabel!

    private var customers: [VasCustomersData.Customer] = []
    private var loading = false
    private var loaded = false

    override func build() {
        let (cardView, content) = makeCard(
            title: "Onboarded customers",
            body: "Customers you've registered with Limes. Use the account number when "
                + "activating their SIM on the Subscription tab.")

        searchBar.textField.returnKeyType = .search
        searchBar.textField.addAction(UIAction { [weak self] _ in self?.load() }, for: .editingDidEndOnExit)
        content.addArrangedSubview(searchBar)

        countLabel = UILabel.make("", font: AppFonts.regular(12), color: AppColors.textSecondary)
        // Search runs the keyword; Refresh re-reads the list as it is — clearing the keyword is
        // the operator's call, exactly as on the web portal.
        let search = pillButton("Search", icon: "magnifyingglass")
        let refresh = pillButton("Refresh", icon: "arrow.clockwise")

        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        header.addArrangedSubview(countLabel)
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(search)
        header.addArrangedSubview(refresh)
        content.addArrangedSubview(header)
        content.addArrangedSubview(listContainer)

        stack.addArrangedSubview(cardView)
        rebuildList()
    }

    /// Small outlined pill — the shape both list actions share.
    private func pillButton(_ title: String, icon: String) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.title = title
        config.image = UIImage(systemName: icon)
        config.imagePadding = 6
        config.baseForegroundColor = AppColors.purplePrimary
        config.background.strokeColor = AppColors.border
        config.background.strokeWidth = 1
        config.background.cornerRadius = AppMetrics.radiusMD
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var out = $0; out.font = AppFonts.bold(12); return out
        }
        button.configuration = config
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.addAction(UIAction { [weak self] _ in self?.load() }, for: .touchUpInside)
        return button
    }

    /// Loads once when the tab is first opened; later visits reuse what is on screen.
    override func onShown() {
        if !loaded { load() }
    }

    /// Forces a reload — used after an onboard so the new customer appears straight away.
    func reload() {
        loaded = false
        load()
    }

    private func load() {
        loaded = true
        loading = true
        rebuildList()
        ApiClient.shared.getVasCustomers(search: text(searchBar.textField), limit: Self.limit) { [weak self] result in
            guard let self else { return }
            self.loading = false
            switch result {
            case .success(let data):
                self.customers = data.customers
            case .failure(let error):
                self.customers = []
                self.host?.vasShowError(error.message)
            }
            self.rebuildList()
        }
    }

    private func rebuildList() {
        listContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        countLabel.text = customers.isEmpty
            ? ""
            : "\(customers.count) customer\(customers.count == 1 ? "" : "s")"

        if loading {
            listContainer.addArrangedSubview(loadingIndicator())
            return
        }
        if customers.isEmpty {
            // "Nothing matched" and "nobody onboarded yet" are different problems and read as
            // such — a keyword that finds nothing is not an empty account.
            listContainer.addArrangedSubview(centeredMessage(
                text(searchBar.textField).isEmpty
                    ? "No customers onboarded yet. Add one on the Onboard customer tab."
                    : "No customers match that search."))
            return
        }
        for (i, customer) in customers.enumerated() {
            listContainer.addArrangedSubview(row(customer))
            if i < customers.count - 1 { listContainer.addArrangedSubview(hairline()) }
        }
    }

    private func row(_ c: VasCustomersData.Customer) -> UIView {
        let name = UILabel.make(c.displayName, font: AppFonts.bold(14), color: AppColors.textPrimary, lines: 1)
        let pill = statusPill(VasFormat.limesStatusStyle(c.status))
        pill.setContentHuggingPriority(.required, for: .horizontal)
        let top = UIStackView.horizontal(spacing: 8, alignment: .center)
        top.addArrangedSubview(name)
        top.addArrangedSubview(UIView())
        top.addArrangedSubview(pill)

        var meta: [String] = []
        if let id = c.idNumber, !id.isEmpty { meta.append(id) }
        let phone = VasFormat.msisdn(c.phone)
        if !phone.isEmpty { meta.append(phone) }

        let lines = UIStackView.vertical(spacing: 3, alignment: .fill)
        lines.addArrangedSubview(top)
        lines.addArrangedSubview(UILabel.make(meta.isEmpty ? "—" : meta.joined(separator: " · "),
                                              font: AppFonts.regular(12), color: AppColors.textSecondary))
        if let email = c.email, !email.isEmpty {
            lines.addArrangedSubview(UILabel.make(email, font: AppFonts.regular(12),
                                                  color: AppColors.textSecondary, lines: 1))
        }
        if let account = c.limesAccountId, !account.isEmpty {
            lines.addArrangedSubview(UILabel.make("Account no. \(account)", font: AppFonts.regular(12),
                                                  color: AppColors.purplePrimary))
        }
        return padded(lines, insets: UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0))
    }
}
