import UIKit

/// Dashboard tab — header + scroll stack are in Main.storyboard; KPI sections are filled in code.
final class DashboardViewController: BaseMainViewController {

    @IBOutlet private weak var menuButton: UIButton!
    @IBOutlet private weak var welcomeLabel: UILabel!
    @IBOutlet private weak var dashboardSubtitleLabel: UILabel!
    @IBOutlet private weak var notificationsButton: UIButton!
    @IBOutlet private weak var avatarLabel: UILabel!
    @IBOutlet private weak var contentStackView: UIStackView!

    private var stack: UIStackView { contentStackView }

    /// Distributor company logo (from login `portal_info`) shown over the initials avatar
    /// when a valid URL is available; hidden otherwise so the initials show through.
    private lazy var avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 18
        iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    override func configureStoryboardChrome() {
        welcomeLabel.font = AppFonts.bold(AppMetrics.textTitle)
        welcomeLabel.textColor = AppColors.textPrimary
        dashboardSubtitleLabel.text = S.dashboardSubtitle
        dashboardSubtitleLabel.font = AppFonts.light(AppMetrics.textBodySM)
        dashboardSubtitleLabel.textColor = AppColors.textSecondary
        avatarLabel.layer.cornerRadius = 18
        avatarLabel.layer.masksToBounds = true
        avatarLabel.backgroundColor = AppColors.purpleLight
        avatarLabel.textColor = AppColors.purplePrimary
        avatarLabel.font = AppFonts.bold(14)
        if avatarImageView.superview == nil {
            avatarLabel.isUserInteractionEnabled = true
            avatarLabel.addSubview(avatarImageView)
            NSLayoutConstraint.activate([
                avatarImageView.leadingAnchor.constraint(equalTo: avatarLabel.leadingAnchor),
                avatarImageView.trailingAnchor.constraint(equalTo: avatarLabel.trailingAnchor),
                avatarImageView.topAnchor.constraint(equalTo: avatarLabel.topAnchor),
                avatarImageView.bottomAnchor.constraint(equalTo: avatarLabel.bottomAnchor)
            ])
        }
        menuButton.tintColor = AppColors.textPrimary
        notificationsButton.tintColor = AppColors.textPrimary
        addNotificationBadge(to: notificationsButton)
        refreshWelcome()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshWelcome()
        refreshNotificationBadge(on: notificationsButton)
    }

    private func refreshWelcome() {
        welcomeLabel.text = S.welcomeBack(SessionManager.shared.firstName)
        avatarLabel.text = SessionManager.shared.initials
        bindAvatarLogo()
    }

    private func bindAvatarLogo() {
        let urlString = SessionManager.shared.companyLogoUrl
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            avatarImageView.isHidden = true
            return
        }
        ImageLoader.load(url) { [weak self] image in
            guard let self = self else { return }
            if let image = image {
                self.avatarImageView.image = image
                self.avatarImageView.isHidden = false
            } else {
                self.avatarImageView.isHidden = true
            }
        }
    }

    @IBAction private func menuTapped(_ sender: UIButton) { openDrawer() }
    @IBAction private func notificationsTapped(_ sender: UIButton) { openNotifications() }

    private var currencySymbol = "R"

    private var wallet: WalletData?
    private weak var walletCard: UIControl?
    private weak var walletBalanceLabel: UILabel?

    override func loadData() {
        // Render a light skeleton, then replace everything with the live dashboard payload.
        renderAll(nil)
        ApiClient.shared.getDashboard { [weak self] result in
            guard let self = self, case .success(let data) = result else { return }
            self.renderAll(data.dashboard)
        }
        loadWallet()
    }

    private func loadWallet() {
        ApiClient.shared.getWallet { [weak self] result in
            guard let self = self, case .success(let data) = result else { return }
            self.wallet = data
            self.applyWallet()
        }
    }

    /// Rebuilds the whole dashboard from the (fixed-structure) API payload. Passing `nil`
    /// renders the placeholder skeleton shown before the first response arrives.
    private func renderAll(_ d: DashboardData.Dashboard?) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let symbol = d?.meta?.currency?.symbol, !symbol.isEmpty { currencySymbol = symbol }

        renderWalletCard()

        let summary = d?.summaryCards ?? MockData.fallbackSummaryCards
        renderSummaryCards(summary)

        addSectionTitle(S.overview)
        if let overview = d?.overview, !overview.isEmpty {
            renderKpis(titles: overview.map { $0.label ?? "" },
                       values: overview.map { String($0.value ?? 0) })
        } else {
            renderKpis(titles: MockData.kpiTitles, values: MockData.kpiValues)
        }

        let rev = d?.revenueOverview
        renderRevenue(total: rev?.formattedTotal ?? "R1,245,600.00",
                      trendLabel: rev?.trend?.label ?? "↑ 18.6% from previous period",
                      compare: d?.meta?.comparePeriodLabel ?? "vs previous period",
                      values: rev?.chart?.values ?? [12, 18, 14, 22, 19, 27, 24],
                      labels: rev?.chart?.labels ?? [])

        let catData = d?.topSellingCategories
        let cats = catData?.items?.map {
            CategoryRow(name: $0.name ?? "", amount: $0.formattedAmount ?? "",
                        percentage: $0.percentage ?? 0, color: AppColors.fromHex($0.color))
        } ?? MockData.fallbackCategories
        let centerMain = compactCurrency(catData?.total ?? cats.reduce(0) { $0 + $1.percentage })
        renderCategories(cats, centerMain: catData == nil ? nil : centerMain)

        let orders = d?.recentOrders?.items?.map {
            RecentOrderRow(orderId: $0.orderId ?? "", trader: $0.trader ?? "",
                           amount: $0.formattedAmount ?? "", date: Self.friendlyOrderDate($0),
                           statusLabel: $0.statusLabel ?? "", statusColor: AppColors.fromHex($0.statusColor))
        } ?? MockData.orders().prefix(5).map {
            RecentOrderRow(orderId: $0.orderId, trader: $0.traderName, amount: $0.amount,
                           date: $0.time, statusLabel: $0.status.capitalized, statusColor: AppColors.purplePrimary)
        }
        renderRecentOrders(orders)
    }

    private func addSectionTitle(_ text: String) {
        let label = UILabel.make(text, font: AppFonts.bold(15), color: AppColors.textPrimary)
        stack.addArrangedSubview(label)
    }

    // MARK: Wallet

    /// The tappable wallet balance card, always the first item in the stack. Hidden until
    /// the (separately loaded) wallet balance arrives.
    private func renderWalletCard() {
        let card = UIControl()
        StyleKit.styleCard(card)
        card.addTarget(self, action: #selector(walletCardTapped), for: .touchUpInside)

        let tile = UIView()
        tile.backgroundColor = AppColors.purplePrimary
        tile.layer.cornerRadius = AppMetrics.radiusLG
        tile.constrainSize(42)
        let icon = UIImageView(image: UIImage(systemName: "creditcard.fill"))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        tile.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 21),
            icon.heightAnchor.constraint(equalToConstant: 21)
        ])

        let caption = UILabel.make("Wallet Balance", font: AppFonts.regular(12), color: AppColors.textSecondary)
        let balance = UILabel.make("—", font: AppFonts.bold(20), color: AppColors.textPrimary)
        let middle = UIStackView.vertical(spacing: 1, alignment: .leading)
        middle.addArrangedSubview(caption)
        middle.addArrangedSubview(balance)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.down"))
        chevron.tintColor = AppColors.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.constrainSize(16)
        let poweredBy = UILabel.make("anokiX · IMB", font: AppFonts.light(10), color: AppColors.textTertiary)
        let right = UIStackView.vertical(spacing: 6, alignment: .trailing)
        right.addArrangedSubview(chevron)
        right.addArrangedSubview(poweredBy)

        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.isUserInteractionEnabled = false
        row.addArrangedSubview(tile)
        row.addArrangedSubview(middle)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(right)
        row.forAutoLayout()
        card.addSubview(row)
        row.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))

        stack.insertArrangedSubview(card, at: 0)
        walletCard = card
        walletBalanceLabel = balance
        applyWallet()
    }

    private func applyWallet() {
        guard let available = wallet?.balance?.available else {
            walletCard?.isHidden = true
            return
        }
        walletBalanceLabel?.text = formatMoney(available)
        walletCard?.isHidden = false
    }

    @objc private func walletCardTapped() {
        guard let wallet = wallet else { return }
        let vc = WalletDetailViewController(wallet: wallet, currencySymbol: currencySymbol) { [weak self] updated in
            self?.wallet = updated
            self?.applyWallet()
        }
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        present(vc, animated: true)
    }

    private func formatMoney(_ value: Double) -> String {
        WalletFormat.money(currencySymbol, value)
    }

    /// Recent-order timestamp: the API's `formattedDate` is a broken epoch, so format the
    /// raw `date` ("dd/MM/yyyy HH:mm:ss") into a readable label.
    static func friendlyOrderDate(_ order: DashboardData.RecentOrder) -> String {
        if let raw = order.date, !raw.isEmpty {
            let input = DateFormatter()
            input.dateFormat = "dd/MM/yyyy HH:mm:ss"
            input.locale = Locale(identifier: "en_US_POSIX")
            if let date = input.date(from: raw) {
                let out = DateFormatter()
                out.dateFormat = "dd MMM yyyy, HH:mm"
                out.locale = Locale(identifier: "en_US_POSIX")
                return out.string(from: date)
            }
            return raw
        }
        return order.formattedDate ?? ""
    }

    // MARK: Summary KPI cards (top, horizontally scrollable)

    private func renderSummaryCards(_ cards: [DashboardData.SummaryCard]) {
        let row = UIStackView.horizontal(spacing: 10, alignment: .fill)
        cards.forEach { row.addArrangedSubview(makeSummaryCard($0)) }
        row.forAutoLayout()

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.forAutoLayout()
        scroll.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            scroll.heightAnchor.constraint(equalTo: row.heightAnchor)
        ])
        stack.addArrangedSubview(scroll)
    }

    private func makeSummaryCard(_ c: DashboardData.SummaryCard) -> UIView {
        let card = UIView()
        StyleKit.styleCard(card)
        let accent = accentColor(c.color)

        let label = UILabel.make(c.label ?? "", font: AppFonts.regular(12), color: AppColors.textSecondary)
        let tile = StyleKit.iconTile(color: accent.withAlphaComponent(0.13))
        tile.constrainSize(30)
        let icon = UIImageView(image: AppIcons.symbol(iconKey(c.key)))
        icon.tintColor = accent
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        tile.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16)
        ])
        let topRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        topRow.addArrangedSubview(label)
        topRow.addArrangedSubview(UIView())
        topRow.addArrangedSubview(tile)

        let value = UILabel.make(c.formattedValue ?? "", font: AppFonts.bold(18), color: AppColors.textPrimary)

        let up = (c.trend?.direction ?? "up") != "down"
        let trendColor = up ? AppColors.success : AppColors.danger
        let trend = PaddingLabel(insets: UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
        trend.text = c.trend?.label
        trend.font = AppFonts.bold(11)
        trend.textColor = trendColor
        trend.backgroundColor = trendColor.withAlphaComponent(0.12)
        trend.layer.cornerRadius = AppMetrics.radiusSM
        trend.layer.masksToBounds = true
        let trendRow = UIStackView.horizontal(spacing: 0, alignment: .center)
        trendRow.addArrangedSubview(trend)
        trendRow.addArrangedSubview(UIView())

        let spark = SparklineView()
        spark.backgroundColor = .clear
        spark.lineColor = accent
        spark.values = c.sparkline ?? []
        spark.constrainHeight(40)

        let body = UIStackView.vertical(spacing: 10, alignment: .fill)
        [topRow, value, trendRow, spark].forEach { body.addArrangedSubview($0) }
        body.forAutoLayout()
        card.addSubview(body)
        body.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        card.widthAnchor.constraint(equalToConstant: 168).isActive = true
        return card
    }

    private func iconKey(_ key: String?) -> String {
        switch key {
        case "total_orders": return "ic_orders"
        case "active_traders": return "ic_traders"
        case "products_sold": return "ic_package"
        default: return "ic_wallet"
        }
    }

    private func accentColor(_ name: String?) -> UIColor {
        switch name {
        case "blue": return AppColors.info
        case "green": return AppColors.success
        case "orange": return AppColors.warning
        default: return AppColors.purplePrimary
        }
    }

    private func compactCurrency(_ value: Double) -> String {
        let abs = Swift.abs(value)
        if abs >= 1_000_000 { return String(format: "%@%.1fM", currencySymbol, value / 1_000_000) }
        if abs >= 1_000 { return String(format: "%@%.0fK", currencySymbol, value / 1_000) }
        return String(format: "%@%.0f", currencySymbol, value)
    }

    // MARK: Sections

    private func renderKpis(titles: [String], values: [String]) {
        let count = min(titles.count, values.count, 4)
        var cards: [KpiCardView] = []
        for i in 0..<count {
            cards.append(KpiCardView(title: titles[i], value: values[i],
                                     icon: MockData.kpiIcons[i % MockData.kpiIcons.count],
                                     iconBg: MockData.kpiIconBackgrounds[i % 4],
                                     valueColor: MockData.kpiValueColors[i % 4],
                                     tint: MockData.kpiIconTints[i % 4]))
        }
        var rows: [UIStackView] = []
        for pair in stride(from: 0, to: cards.count, by: 2) {
            let row = UIStackView.horizontal(spacing: 12, alignment: .fill)
            row.distribution = .fillEqually
            row.addArrangedSubview(cards[pair])
            if pair + 1 < cards.count { row.addArrangedSubview(cards[pair + 1]) }
            else { row.addArrangedSubview(UIView()) }
            rows.append(row)
        }
        rows.forEach { stack.addArrangedSubview($0) }
    }

    private func renderRevenue(total: String, trendLabel: String, compare: String,
                               values: [Double], labels: [String]) {
        let card = UIView()
        StyleKit.styleCard(card)
        let titleLabel = UILabel.title(S.revenueOverview)
        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        header.addArrangedSubview(titleLabel)
        header.addArrangedSubview(UIView())

        let totalLabel = UILabel.make(total, font: AppFonts.bold(AppMetrics.textKpiValue), color: AppColors.textPrimary)
        let up = !trendLabel.contains("↓")
        let trendBadge = PaddingLabel(insets: UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
        trendBadge.text = trendLabel
        trendBadge.font = AppFonts.bold(11)
        trendBadge.textColor = up ? AppColors.success : AppColors.danger
        trendBadge.backgroundColor = (up ? AppColors.success : AppColors.danger).withAlphaComponent(0.12)
        trendBadge.layer.cornerRadius = AppMetrics.radiusSM
        trendBadge.layer.masksToBounds = true

        let amountRow = UIStackView.horizontal(spacing: 10, alignment: .center)
        amountRow.addArrangedSubview(totalLabel)
        amountRow.addArrangedSubview(trendBadge)
        amountRow.addArrangedSubview(UIView())

        let compareLabel = UILabel.make(compare, font: AppFonts.light(AppMetrics.textLabel), color: AppColors.textSecondary)
        let chart = RevenueChartView()
        chart.backgroundColor = .clear
        chart.currencySymbol = currencySymbol
        chart.values = values
        chart.labels = labels
        chart.constrainHeight(170)

        let body = UIStackView.vertical(spacing: 10, alignment: .fill)
        [header, amountRow, compareLabel, chart].forEach { body.addArrangedSubview($0) }
        body.forAutoLayout()
        card.addSubview(body)
        body.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        stack.addArrangedSubview(card)
    }

    private func renderCategories(_ items: [CategoryRow], centerMain: String?) {
        let card = SectionCard(title: "Top Selling Categories")

        let donut = DonutChartView()
        donut.strokeWidth = 15
        donut.setData(values: items.map { CGFloat(max(0.0001, $0.percentage)) },
                      colors: items.map { $0.color })
        donut.setCenterText(main: centerMain, sub: centerMain == nil ? nil : "Total")
        donut.forAutoLayout()
        NSLayoutConstraint.activate([
            donut.widthAnchor.constraint(equalToConstant: 128),
            donut.heightAnchor.constraint(equalToConstant: 128)
        ])

        let legend = UIStackView.vertical(spacing: 4, alignment: .fill)
        for item in items {
            let dot = UIView()
            dot.backgroundColor = item.color
            dot.layer.cornerRadius = 4.5
            dot.forAutoLayout()
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 9),
                dot.heightAnchor.constraint(equalToConstant: 9)
            ])
            let name = UILabel.make(item.name, font: AppFonts.regular(12), color: AppColors.textSecondary)
            let amount = UILabel.make(item.amount, font: AppFonts.bold(12), color: AppColors.textPrimary)
            amount.setContentHuggingPriority(.required, for: .horizontal)
            let row = UIStackView.horizontal(spacing: 8, alignment: .center)
            row.addArrangedSubview(dot)
            row.addArrangedSubview(name)
            row.addArrangedSubview(UIView())
            row.addArrangedSubview(amount)
            legend.addArrangedSubview(row)
        }

        let content = UIStackView.horizontal(spacing: 14, alignment: .center)
        content.addArrangedSubview(donut)
        content.addArrangedSubview(legend)
        card.body.addArrangedSubview(content)
        stack.addArrangedSubview(card)
    }

    private func renderRecentOrders(_ orders: [RecentOrderRow]) {
        let card = SectionCard(title: S.recentOrders, actionTitle: S.viewAll) { [weak self] in
            (self?.tabBarController as? MainTabBarController)?.selectTab(forKey: "orders")
        }
        for order in orders {
            let title = UILabel.make(order.orderId, font: AppFonts.bold(13), color: AppColors.textPrimary)
            let sub = UILabel.make(order.trader, font: AppFonts.regular(12), color: AppColors.textSecondary)
            let date = UILabel.make(order.date, font: AppFonts.light(10), color: AppColors.textTertiary)
            let left = UIStackView.vertical(spacing: 2, alignment: .leading)
            [title, sub, date].forEach { left.addArrangedSubview($0) }

            let amount = UILabel.make(order.amount, font: AppFonts.bold(13), color: AppColors.textPrimary)
            amount.setContentHuggingPriority(.required, for: .horizontal)
            let status = PaddingLabel(insets: UIEdgeInsets(top: 3, left: 10, bottom: 3, right: 10))
            status.text = order.statusLabel
            status.font = AppFonts.bold(10)
            status.textColor = order.statusColor
            status.backgroundColor = order.statusColor.withAlphaComponent(0.12)
            status.layer.cornerRadius = AppMetrics.radiusSM
            status.layer.masksToBounds = true
            let right = UIStackView.vertical(spacing: 6, alignment: .trailing)
            right.addArrangedSubview(amount)
            right.addArrangedSubview(status)

            let row = UIStackView.horizontal(spacing: 8, alignment: .center)
            row.addArrangedSubview(left)
            row.addArrangedSubview(UIView())
            row.addArrangedSubview(right)
            card.body.addArrangedSubview(row)
        }
        stack.addArrangedSubview(card)
    }
}

struct CategoryRow {
    let name: String
    let amount: String
    let percentage: Double
    let color: UIColor
}

struct RecentOrderRow {
    let orderId: String
    let trader: String
    let amount: String
    let date: String
    let statusLabel: String
    let statusColor: UIColor
}

extension MockData {
    static var fallbackCategories: [CategoryRow] {
        [
            CategoryRow(name: "Airtime & Data", amount: "R86,200", percentage: 72, color: AppColors.purplePrimary),
            CategoryRow(name: "Electricity", amount: "R52,400", percentage: 54, color: AppColors.info),
            CategoryRow(name: "Groceries", amount: "R38,900", percentage: 40, color: AppColors.success),
            CategoryRow(name: "Beverages", amount: "R21,300", percentage: 24, color: AppColors.warning)
        ]
    }
}
