import UIKit

/// Port of PromotionsActivity. Live KPI summary + searchable/filterable campaign
/// list with a per-row View / Edit / Delete menu, plus a Create Promotion button.
final class PromotionsViewController: BaseSecondaryViewController {

    override var screenTitle: String { S.promotions }
    override var screenSubtitle: String? { S.promotionsSubtitle }

    private let statusLabels = ["All Status", "Active", "Pending Approval", "Scheduled", "Draft", "Rejected"]
    private let statusValues = ["", "active", "pending_approval", "scheduled", "draft", "rejected"]
    private let typeLabels = ["All Types", "Best Deal", "Can't Miss Deal", "Exclusive Deal",
                              "Featured Store", "Promotion", "Post", "Story"]
    private let typeValues = ["", "best_deal", "cant_miss_deal", "exclusive_deal",
                              "featured_store", "promotion", "post", "story"]

    // Full result set from one API call; all search/filter happens locally over this.
    private var allItems: [PromotionItem] = []
    private var statusFilter = ""
    private var typeFilter = ""
    private var search = ""

    // UI
    private let summaryScroll = UIScrollView()
    private let summaryRow = UIStackView.horizontal(spacing: 10, alignment: .fill)
    private let statusButton = UIButton(type: .system)
    private let typeButton = UIButton(type: .system)
    private let listStack = UIStackView.vertical(spacing: 12, alignment: .fill)
    private let emptyLabel = UILabel.make("No campaigns yet. Tap Create Promotion to launch your first one.",
                                          font: AppFonts.regular(14), color: AppColors.textSecondary, align: .center)
    private var pendingSuccessBanner: String?

    // MARK: - Setup

    override func setupContent(in container: UIView) {
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = false
        scroll.backgroundColor = AppColors.background
        scroll.forAutoLayout()
        container.addSubview(scroll)

        let stack = UIStackView.vertical(spacing: 16, alignment: .fill)
        stack.forAutoLayout()
        scroll.addSubview(stack)

        // Summary KPI cards (horizontally scrollable).
        summaryScroll.showsHorizontalScrollIndicator = false
        summaryRow.forAutoLayout()
        summaryScroll.addSubview(summaryRow)
        NSLayoutConstraint.activate([
            summaryRow.topAnchor.constraint(equalTo: summaryScroll.contentLayoutGuide.topAnchor),
            summaryRow.bottomAnchor.constraint(equalTo: summaryScroll.contentLayoutGuide.bottomAnchor),
            summaryRow.leadingAnchor.constraint(equalTo: summaryScroll.contentLayoutGuide.leadingAnchor),
            summaryRow.trailingAnchor.constraint(equalTo: summaryScroll.contentLayoutGuide.trailingAnchor),
            summaryRow.heightAnchor.constraint(equalTo: summaryScroll.frameLayoutGuide.heightAnchor)
        ])
        summaryScroll.isHidden = true
        // Below required so it yields to the stack's collapse constraint when hidden.
        let summaryHeight = summaryScroll.heightAnchor.constraint(equalToConstant: 96)
        summaryHeight.priority = .defaultHigh
        summaryHeight.isActive = true
        stack.addArrangedSubview(summaryScroll)

        // Search + filters.
        let searchBar = SearchBarView(placeholder: "Search campaigns…")
        searchBar.onChange = { [weak self] text in self?.search = text; self?.applyFilter() }
        stack.addArrangedSubview(searchBar)

        configureFilterButton(statusButton, title: statusLabels[0])
        statusButton.addTarget(self, action: #selector(pickStatus), for: .touchUpInside)
        configureFilterButton(typeButton, title: typeLabels[0])
        typeButton.addTarget(self, action: #selector(pickType), for: .touchUpInside)
        let filterRow = UIStackView.horizontal(spacing: 10, alignment: .fill)
        filterRow.distribution = .fillEqually
        filterRow.addArrangedSubview(statusButton)
        filterRow.addArrangedSubview(typeButton)
        stack.addArrangedSubview(filterRow)

        emptyLabel.isHidden = true
        stack.addArrangedSubview(emptyLabel)
        stack.addArrangedSubview(listStack)

        // Fixed Create button.
        let create = UIButton(type: .system)
        StyleKit.stylePrimaryButton(create)
        create.setTitle(S.createPromotion, for: .normal)
        create.setImage(UIImage(systemName: "plus"), for: .normal)
        create.tintColor = .white
        create.addTarget(self, action: #selector(createTapped), for: .touchUpInside)
        create.forAutoLayout()
        container.addSubview(create)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: container.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: create.topAnchor, constant: -10),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),

            create.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            create.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            create.bottomAnchor.constraint(equalTo: container.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            create.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    override func loadData() {
        // One fetch (all types); status/type/search filtering is done locally.
        ApiClient.shared.getPromotions(campaignType: "") { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                self.renderSummary(data.summary?.summaryCards ?? [])
                self.allItems = ApiMapper.toPromotionItems(data)
                self.applyFilter()
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let message = pendingSuccessBanner {
            pendingSuccessBanner = nil
            successBanner(message)
        }
    }

    // MARK: - Summary cards

    private func renderSummary(_ cards: [PromotionsData.SummaryCard]) {
        summaryRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        summaryScroll.isHidden = cards.isEmpty
        for card in cards {
            summaryRow.addArrangedSubview(makeSummaryCard(card))
        }
    }

    private func makeSummaryCard(_ c: PromotionsData.SummaryCard) -> UIView {
        let card = StyleKit.cardView()
        let label = UILabel.make(c.label ?? "", font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 2)
        let value = UILabel.make(c.formattedValue ?? "—", font: AppFonts.bold(18), color: AppColors.textPrimary)

        let trend = UILabel.make(c.trend?.label, font: AppFonts.bold(11),
                                 color: ("down" == c.trend?.direction) ? AppColors.danger : AppColors.success, lines: 1)
        let stack = UIStackView.vertical(spacing: 6, alignment: .leading)
        stack.forAutoLayout()
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(value)
        stack.addArrangedSubview(trend)
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14))
        card.widthAnchor.constraint(equalToConstant: 170).isActive = true
        return card
    }

    // MARK: - Local search + filter

    private func applyFilter() {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = allItems.filter { item in
            if !statusFilter.isEmpty && statusFilter.caseInsensitiveCompare(item.status) != .orderedSame { return false }
            if !typeFilter.isEmpty && typeFilter.caseInsensitiveCompare(item.campaignType) != .orderedSame { return false }
            if !q.isEmpty && !item.name.lowercased().contains(q) { return false }
            return true
        }
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        emptyLabel.isHidden = !filtered.isEmpty
        for item in filtered {
            listStack.addArrangedSubview(makeCard(item))
        }
    }

    // MARK: - Promotion card

    private func makeCard(_ promo: PromotionItem) -> UIView {
        let card = StyleKit.cardView()

        // We will not use banner for now 
        /*let banner = UIView()
        banner.backgroundColor = bannerColor(promo.campaignType)
        banner.layer.cornerRadius = AppMetrics.radiusMD
        banner.constrainHeight(72)
        let bannerLabel = UILabel.make(promo.typeLabel.isEmpty ? "Campaign" : promo.typeLabel.uppercased(),
                                       font: AppFonts.bold(16), color: .white, align: .center, lines: 2)
        bannerLabel.forAutoLayout()
        banner.addSubview(bannerLabel)
        bannerLabel.pinEdges(to: banner, insets: UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))*/

        let title = UILabel.make(promo.name, font: AppFonts.bold(15), color: AppColors.textPrimary, lines: 2)
        let status = StyleKit.badgeLabel()
        StyleKit.applyStatusBadge(status, status: promo.statusLabel.isEmpty ? "—" : promo.statusLabel)
        status.setContentHuggingPriority(.required, for: .horizontal)
        status.setContentCompressionResistancePriority(.required, for: .horizontal)

        let menu = UIButton(type: .system)
        menu.setImage(AppIcons.symbol("ic_more_vert"), for: .normal)
        menu.tintColor = AppColors.textSecondary
        menu.constrainSize(28)
        menu.setContentHuggingPriority(.required, for: .horizontal)
        menu.addAction(UIAction { [weak self] _ in self?.showRowMenu(for: promo, anchor: menu) }, for: .touchUpInside)

        let titleRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        titleRow.addArrangedSubview(title)
        titleRow.addArrangedSubview(UIView())
        titleRow.addArrangedSubview(status)
        //titleRow.addArrangedSubview(menu)

        let dateLabel = UILabel.make(promo.dateRange, font: AppFonts.regular(12), color: AppColors.textSecondary)

        let metricsGroup = UIStackView.horizontal(spacing: 10, alignment: .fill)
        metricsGroup.distribution = .fillEqually
        metricsGroup.addArrangedSubview(metric("Budget", promo.budget))
        metricsGroup.addArrangedSubview(metric("Reach", promo.reach))
        metricsGroup.addArrangedSubview(metric("Clicks", promo.clicks))
        metricsGroup.addArrangedSubview(metric("CTR", promo.ctr))
        metricsGroup.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let metrics = UIStackView.horizontal(spacing: 10, alignment: .fill)
        metrics.addArrangedSubview(metricsGroup)
        metrics.addArrangedSubview(menu)

        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.forAutoLayout()
        [/*banner, */titleRow, dateLabel, metrics].forEach { stack.addArrangedSubview($0) }
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        return card
    }

    private func metric(_ title: String, _ value: String) -> UIView {
        let stack = UIStackView.vertical(spacing: 2, alignment: .leading)
        stack.addArrangedSubview(UILabel.make(value.isEmpty ? "—" : value, font: AppFonts.bold(15), color: AppColors.textPrimary, lines: 1))
        stack.addArrangedSubview(UILabel.make(title, font: AppFonts.regular(10), color: AppColors.textSecondary))
        return stack
    }

    private func bannerColor(_ campaignType: String) -> UIColor {
        switch campaignType {
        case "best_deal": return AppColors.purpleDark
        case "cant_miss_deal": return AppColors.purplePrimary
        case "exclusive_deal": return AppColors.info
        case "featured_store": return AppColors.success
        case "promotion": return AppColors.warning
        case "post": return AppColors.statExpiring
        case "story": return AppColors.danger
        default: return AppColors.purplePrimary
        }
    }

    // MARK: - Row menu: View Details / Edit / Delete

    private func showRowMenu(for item: PromotionItem, anchor: UIView) {
        let sheet = UIAlertController(title: item.name, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: S.promoViewDetails, style: .default) { [weak self] _ in self?.showDetails(item) })
        sheet.addAction(UIAlertAction(title: S.promoEdit, style: .default) { [weak self] _ in self?.openEditor(item) })
        sheet.addAction(UIAlertAction(title: S.promoDelete, style: .destructive) { [weak self] _ in self?.confirmDelete(item) })
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = anchor
            pop.sourceRect = anchor.bounds
        }
        present(sheet, animated: true)
    }

    /// Quick read-only summary built from the list row (no extra fetch).
    private func showDetails(_ item: PromotionItem) {
        var lines: [String] = []
        func add(_ label: String, _ value: String) {
            if !value.isEmpty { lines.append("\(label): \(value)") }
        }
        add("Type", item.typeLabel)
        add("Status", item.statusLabel)
        add("Duration", item.dateRange)
        add("Budget", item.budget)
        add("Reach", item.reach)
        add("Clicks", item.clicks)
        add("CTR", item.ctr)
        let alert = UIAlertController(title: item.name, message: lines.joined(separator: "\n"),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.promoEdit, style: .default) { [weak self] _ in self?.openEditor(item) })
        alert.addAction(UIAlertAction(title: S.promoClose, style: .cancel))
        present(alert, animated: true)
    }

    private func confirmDelete(_ item: PromotionItem) {
        let alert = UIAlertController(title: "Delete campaign?",
                                      message: "“\(item.name)” will be permanently removed.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: S.promoDelete, style: .destructive) { [weak self] _ in
            self?.deletePromotion(item)
        })
        present(alert, animated: true)
    }

    private func deletePromotion(_ item: PromotionItem) {
        ApiClient.shared.deletePromotion(id: item.id) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.successBanner(S.promoDeletedMessage)
                self.loadData()
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    // MARK: - Create / Edit

    @objc private func createTapped() {
        let wizard = CreatePromotionViewController()
        wizard.onSaved = { [weak self] message in
            self?.loadData()
            self?.pendingSuccessBanner = message
        }
        navigationController?.pushViewController(wizard, animated: true)
    }

    private func openEditor(_ item: PromotionItem) {
        let wizard = CreatePromotionViewController(promotionId: item.id)
        wizard.onSaved = { [weak self] message in
            self?.loadData()
            self?.pendingSuccessBanner = message
        }
        navigationController?.pushViewController(wizard, animated: true)
    }

    // MARK: - Filters

    @objc private func pickStatus() {
        pick(labels: statusLabels) { [weak self] index in
            guard let self = self else { return }
            self.statusFilter = self.statusValues[index]
            self.setFilterTitle(self.statusButton, self.statusLabels[index])
            self.applyFilter()
        }
    }

    @objc private func pickType() {
        pick(labels: typeLabels) { [weak self] index in
            guard let self = self else { return }
            self.typeFilter = self.typeValues[index]
            self.setFilterTitle(self.typeButton, self.typeLabels[index])
            self.applyFilter()
        }
    }

    private func pick(labels: [String], onPick: @escaping (Int) -> Void) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for (i, label) in labels.enumerated() {
            sheet.addAction(UIAlertAction(title: label, style: .default) { _ in onPick(i) })
        }
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(sheet, animated: true)
    }

    private func configureFilterButton(_ button: UIButton, title: String) {
        var config = UIButton.Configuration.bordered()
        config.baseForegroundColor = AppColors.textPrimary
        config.background.strokeColor = AppColors.border
        config.background.backgroundColor = AppColors.surface
        config.cornerStyle = .medium
        config.title = title
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 34)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.regular(13); return out
        }
        button.configuration = config
        button.contentHorizontalAlignment = .leading

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

    private func setFilterTitle(_ button: UIButton, _ title: String) {
        guard var config = button.configuration else { return }
        config.title = title
        button.configuration = config
    }
}
