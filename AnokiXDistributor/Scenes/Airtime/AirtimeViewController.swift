import UIKit

/// Airtime & VAS (Limes, live) — UIKit twin of the Android `AirtimeActivity`. Mirrors the web
/// portal: a KPI strip and an explainer that always stay on screen, then one of six sections
/// at a time —
/// 1. **Onboard customer** — register an end-customer in the Limes CRM
/// 2. **Customers** — who you have onboarded, with their Limes account no.
/// 3. **Subscription** — assign a SIM; Limes hands back the phone number
/// 4. **Catalog & orders** — sell a catalog product to a number
/// 5. **Dynamic services** — compose an exact-value bundle
/// 6. **Recent transactions** — the VAS history + KPI figures
///
/// Only onboarding + subscription need each other; airtime and data top-ups go straight to
/// any number that is already active on the network.
final class AirtimeViewController: BaseSecondaryViewController {

    override var screenTitle: String { "Airtime & VAS" }
    override var screenSubtitle: String? { "Sell airtime, data and digital services · Powered by Limes" }

    private static let txnPerPage = 20

    private static let howItWorks =
        "<b>How this page works:</b> <b>Onboard customer</b> → activate their SIM under "
        + "<b>Subscription</b> (you hand in the SIM's <b>ICCID</b>; Limes hands back the "
        + "<b>phone number</b>) → then sell airtime, data & bundles to that number under "
        + "<b>Catalog & orders</b> or <b>Dynamic services</b>, and track it all under "
        + "<b>Recent transactions</b>. Airtime & data top-ups go straight to any <b>active</b> "
        + "number — onboarding is only needed when signing a customer up to a SIM subscription."

    private static let tabTitles = [
        "Onboard customer", "Customers", "Subscription",
        "Catalog & orders", "Dynamic services", "Recent transactions"
    ]

    // MARK: State

    private var summary: VasTransactionsData.Summary?
    private var currentTab = 0

    // MARK: Views

    private var stack: UIStackView!
    private let kpiContainer = UIStackView.vertical(spacing: 12, alignment: .fill)
    private var tabButtons: [UIButton] = []

    private let onboardView = AirtimeOnboardView()
    private let customersView = AirtimeCustomersView()
    private let subscriptionView = AirtimeSubscriptionView()
    private let catalogView = AirtimeCatalogView()
    private let dynamicView = AirtimeDynamicServicesView()
    private let transactionsView = AirtimeTransactionsView()
    private var sections: [VasSectionView] { [onboardView, customersView, subscriptionView,
                                              catalogView, dynamicView, transactionsView] }

    // MARK: Setup

    override func setupContent(in container: UIView) {
        stack = makeScrollStack(in: container)
        stack.addArrangedSubview(kpiContainer)
        stack.addArrangedSubview(VasSectionView.infoBanner(NSAttributedString.vasExplainer(Self.howItWorks)))
        stack.addArrangedSubview(buildTabStrip())

        for section in sections {
            section.host = self
            stack.addArrangedSubview(section)
        }

        rebuildKpis()
        selectTab(0)
    }

    override func loadData() {
        loadTransactions()
    }

    /// The pill tab bar. It lives in a horizontal scroll view because six labels never fit
    /// across a phone, and each pill is a plain button so the selected state is a style swap.
    private func buildTabStrip() -> UIView {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        let row = UIStackView.horizontal(spacing: 8, alignment: .fill)
        row.forAutoLayout()

        // Titles are applied in selectTab as attributed strings, which also carry the
        // selected/unselected colour, so nothing here sets a plain title to fight with.
        for index in Self.tabTitles.indices {
            let button = UIButton(type: .system)
            var config = UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16)
            config.background.cornerRadius = AppMetrics.radiusMD
            config.background.strokeWidth = 1
            button.configuration = config
            button.addAction(UIAction { [weak self] _ in self?.selectTab(index) }, for: .touchUpInside)
            row.addArrangedSubview(button)
            tabButtons.append(button)
        }

        scroll.addSubview(row)
        row.pinEdges(to: scroll)
        row.heightAnchor.constraint(equalTo: scroll.heightAnchor).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return scroll
    }

    private func selectTab(_ index: Int) {
        currentTab = index
        for (i, button) in tabButtons.enumerated() {
            let selected = i == index
            var config = button.configuration
            config?.background.backgroundColor = selected ? AppColors.successBg : AppColors.surface
            config?.background.strokeColor = selected ? AppColors.success : AppColors.border
            config?.attributedTitle = AttributedString(Self.tabTitles[i], attributes: AttributeContainer([
                .font: AppFonts.bold(13),
                .foregroundColor: selected ? AppColors.success : AppColors.textSecondary
            ]))
            button.configuration = config
        }
        for (i, section) in sections.enumerated() {
            section.isHidden = i != index
        }
        // Sections fetch their own data the first time they are opened, so switching tabs
        // never costs a request the operator did not ask for.
        sections[index].onShown()
    }

    // MARK: KPI

    private func rebuildKpis() {
        kpiContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let s = summary
        let cards = [
            KpiCardView(title: "VAS sales · today", value: VasFormat.money(s?.salesToday ?? 0),
                        icon: "ic_check_circle", iconBg: AppColors.successBg, valueColor: AppColors.success, tint: AppColors.success),
            KpiCardView(title: "Transactions · today", value: String(Int(s?.countToday ?? 0)),
                        icon: "ic_orders", iconBg: AppColors.infoBg, valueColor: AppColors.textPrimary, tint: AppColors.info),
            KpiCardView(title: "Commission · month", value: VasFormat.money(s?.commissionMonth ?? 0),
                        icon: "ic_finances", iconBg: AppColors.warningBg, valueColor: AppColors.success, tint: AppColors.warning),
            KpiCardView(title: "Wallet balance", value: VasFormat.money(s?.walletBalance ?? 0),
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

    // MARK: Transactions + KPI summary

    private func loadTransactions() {
        ApiClient.shared.getVasTransactions(page: 1, perPage: Self.txnPerPage) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data):
                self.summary = data.summary
                self.transactionsView.setTransactions(data.transactions)
                self.rebuildKpis()
            case .failure:
                self.transactionsView.setTransactions([])
            }
        }
    }
}

// MARK: - VasSectionHost

extension AirtimeViewController: VasSectionHost {

    func vasPresent(_ viewController: UIViewController) {
        present(viewController, animated: true)
    }

    /// Limes' failure replies are long and multi-line (they name the reason, e.g. "not an
    /// active subscriber"), and an alert scrolls them, so the whole text is shown verbatim.
    func vasShowError(_ message: String) {
        vasShowAlert(title: "Something went wrong", message: message)
    }

    func vasShowAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Close", style: .default))
        present(alert, animated: true)
    }

    func vasRefreshTransactions() {
        loadTransactions()
    }

    func vasCustomerOnboarded() {
        customersView.reload()
    }
}
