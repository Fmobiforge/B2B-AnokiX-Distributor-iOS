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
    }

    @IBAction private func menuTapped(_ sender: UIButton) { openDrawer() }
    @IBAction private func notificationsTapped(_ sender: UIButton) { openNotifications() }

    override func loadData() {
        renderKpis(titles: MockData.kpiTitles, values: MockData.kpiValues)
        renderRevenue(total: "R248,560", trendLabel: "↑ 12.5% vs last week",
                      values: [12, 18, 14, 22, 19, 27, 24])
        renderCategories(MockData.fallbackCategories)
        renderRecentOrders(Array(MockData.orders().prefix(3)))

        ApiClient.shared.getDashboard { [weak self] result in
            guard let self = self, case .success(let data) = result, let d = data.dashboard else { return }
            self.stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

            if let overview = d.overview, !overview.isEmpty {
                self.renderKpis(titles: overview.map { $0.label ?? "" },
                                values: overview.map { String($0.value ?? 0) })
            } else {
                self.renderKpis(titles: MockData.kpiTitles, values: MockData.kpiValues)
            }
            if let rev = d.revenueOverview {
                self.renderRevenue(total: rev.formattedTotal ?? "—",
                                   trendLabel: rev.trend?.label ?? "",
                                   values: rev.chart?.values ?? [12, 18, 14, 22, 19, 27, 24])
            }
            let cats = d.topSellingCategories?.items?.map {
                CategoryRow(name: $0.name ?? "", amount: $0.formattedAmount ?? "",
                            percentage: $0.percentage ?? 0, color: AppColors.fromHex($0.color))
            } ?? MockData.fallbackCategories
            self.renderCategories(cats)

            let orders = d.recentOrders?.items?.map {
                OrderItem(orderId: $0.orderId ?? "", traderName: $0.trader ?? "", initials: "",
                          location: "", amount: $0.formattedAmount ?? "", payment: "",
                          time: $0.formattedDate ?? "", status: ($0.statusLabel ?? "").lowercased())
            } ?? Array(MockData.orders().prefix(3))
            self.renderRecentOrders(orders)
        }
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

    private func renderRevenue(total: String, trendLabel: String, values: [Double]) {
        let card = UIView()
        StyleKit.styleCard(card)
        let titleLabel = UILabel.title(S.revenueOverview)
        let periodPill = makePeriodPill("This week")
        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        header.addArrangedSubview(titleLabel)
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(periodPill)

        let totalLabel = UILabel.make(total, font: AppFonts.bold(AppMetrics.textKpiValue), color: AppColors.textPrimary)
        let trendBadge = PaddingLabel(insets: UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
        trendBadge.text = trendLabel
        trendBadge.font = AppFonts.bold(11)
        trendBadge.textColor = AppColors.success
        trendBadge.backgroundColor = AppColors.successBg
        trendBadge.layer.cornerRadius = AppMetrics.radiusSM
        trendBadge.layer.masksToBounds = true

        let amountRow = UIStackView.horizontal(spacing: 10, alignment: .center)
        amountRow.addArrangedSubview(totalLabel)
        amountRow.addArrangedSubview(trendBadge)
        amountRow.addArrangedSubview(UIView())

        let compare = UILabel.make("vs 1 Jun – 7 Jun 2026", font: AppFonts.light(AppMetrics.textLabel), color: AppColors.textSecondary)
        let spark = SparklineView()
        spark.backgroundColor = .clear
        spark.constrainHeight(90)
        spark.values = values

        let body = UIStackView.vertical(spacing: 10, alignment: .fill)
        [header, amountRow, compare, spark].forEach { body.addArrangedSubview($0) }
        body.forAutoLayout()
        card.addSubview(body)
        body.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        stack.addArrangedSubview(card)
    }

    private func makePeriodPill(_ title: String) -> UIView {
        let pill = UIControl()
        pill.backgroundColor = AppColors.purpleLight
        pill.layer.cornerRadius = 16
        let label = UILabel.make(title, font: AppFonts.regular(AppMetrics.textBodySM), color: AppColors.purplePrimary)
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = AppColors.purplePrimary
        chevron.contentMode = .scaleAspectFit
        let row = UIStackView.horizontal(spacing: 4, alignment: .center)
        row.isUserInteractionEnabled = false
        row.addArrangedSubview(label)
        row.addArrangedSubview(chevron)
        row.forAutoLayout()
        pill.addSubview(row)
        NSLayoutConstraint.activate([
            chevron.widthAnchor.constraint(equalToConstant: 14),
            pill.heightAnchor.constraint(equalToConstant: 32),
            row.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -10),
            row.centerYAnchor.constraint(equalTo: pill.centerYAnchor)
        ])
        return pill
    }

    private func renderCategories(_ items: [CategoryRow]) {
        let card = SectionCard(title: "Top Selling Categories")
        for item in items {
            let name = UILabel.make(item.name, font: AppFonts.medium(13), color: AppColors.textPrimary)
            let amount = UILabel.make(item.amount, font: AppFonts.bold(13), color: AppColors.textPrimary)
            amount.setContentHuggingPriority(.required, for: .horizontal)
            let topRow = UIStackView.horizontal(spacing: 8, alignment: .center)
            topRow.addArrangedSubview(name)
            topRow.addArrangedSubview(UIView())
            topRow.addArrangedSubview(amount)

            let track = UIView()
            track.backgroundColor = AppColors.borderLight
            track.layer.cornerRadius = 3
            track.constrainHeight(6)
            let fill = UIView()
            fill.backgroundColor = item.color
            fill.layer.cornerRadius = 3
            fill.forAutoLayout()
            track.addSubview(fill)
            NSLayoutConstraint.activate([
                fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
                fill.topAnchor.constraint(equalTo: track.topAnchor),
                fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
                fill.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: max(0.02, min(1, item.percentage / 100)))
            ])

            let row = UIStackView.vertical(spacing: 6, alignment: .fill)
            row.addArrangedSubview(topRow)
            row.addArrangedSubview(track)
            card.body.addArrangedSubview(row)
        }
        stack.addArrangedSubview(card)
    }

    private func renderRecentOrders(_ orders: [OrderItem]) {
        let card = SectionCard(title: S.recentOrders, actionTitle: S.viewAll) { [weak self] in
            (self?.tabBarController as? MainTabBarController)?.selectTab(forKey: "orders")
        }
        for order in orders {
            let title = UILabel.make(order.orderId, font: AppFonts.bold(13), color: AppColors.textPrimary)
            let sub = UILabel.make(order.traderName, font: AppFonts.regular(12), color: AppColors.textSecondary)
            let left = UIStackView.vertical(spacing: 2, alignment: .leading)
            left.addArrangedSubview(title)
            left.addArrangedSubview(sub)

            let amount = UILabel.make(order.amount, font: AppFonts.bold(13), color: AppColors.textPrimary)
            amount.setContentHuggingPriority(.required, for: .horizontal)

            let row = UIStackView.horizontal(spacing: 8, alignment: .center)
            row.addArrangedSubview(left)
            row.addArrangedSubview(UIView())
            row.addArrangedSubview(amount)
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
