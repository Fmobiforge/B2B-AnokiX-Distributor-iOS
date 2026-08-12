import UIKit

/// Products screen chrome — the iOS twin of include_products_kpis.xml +
/// include_products_filters.xml driven by ProductListSection on Android.
///
/// Holds the KPI cards, the stock tabs, keyword search and the category / brand /
/// status filter pills, and applies the whole selection locally to the product list
/// the API already returned (so a tab or pill never costs a round trip). Categories
/// and brands come from /api/common/base-info; until that lands the pickers fall back
/// to the values denormalised onto the products themselves.
///
/// Shared by the Products tab (ProductsTabViewController) and the drawer screen
/// (ProductsViewController).
final class ProductsChromeView: UIView {

    /// Fired whenever the tab, search text or a filter pill changes.
    var onFilterChanged: (() -> Void)?
    /// Presents the filter pickers — set to the owning view controller.
    weak var presenter: UIViewController?

    private enum Tab: Int, CaseIterable {
        case all, active, low, out

        var title: String {
            switch self {
            case .all: return "All Products"
            case .active: return "Active"
            case .low: return "Low Stock"
            case .out: return "Out of Stock"
            }
        }
    }

    // Filter state
    private var selectedTab: Tab = .all
    private var query = ""
    private var categoryId = ""
    private var brandName = ""
    private var status = ""

    // Data
    private var items: [ProductItem] = []
    private var summary: ProductsData.Summary?
    private var categories: [BaseInfoData.ProductCategory] = []
    private var brands: [BaseInfoData.Brand] = []

    // Views
    private let totalCard = ProductKpiCard(title: "Total Products", valueColor: AppColors.purplePrimary)
    private let activeCard = ProductKpiCard(title: "Active Products", valueColor: AppColors.success)
    private let outCard = ProductKpiCard(title: "Out of Stock", valueColor: AppColors.danger)
    private let lowCard = ProductKpiCard(title: "Low Stock", valueColor: AppColors.warning)
    private var tabViews: [ProductTabView] = []
    private let categoryPill = FilterPillButton(title: "All Categories")
    private let brandPill = FilterPillButton(title: "All Brands")
    private let statusPill = FilterPillButton(title: "All Status")

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        backgroundColor = AppColors.surface

        let kpiRow = UIStackView.horizontal(spacing: 8, alignment: .fill)
        [totalCard, activeCard, outCard, lowCard].forEach { kpiRow.addArrangedSubview($0) }
        let kpiScroll = horizontalScroll(containing: kpiRow)

        let tabRow = UIStackView.horizontal(spacing: 18, alignment: .fill)
        tabViews = Tab.allCases.map { tab in
            let view = ProductTabView(title: tab.title)
            view.onTap = { [weak self] in
                self?.selectedTab = tab
                self?.notifyChanged()
            }
            tabRow.addArrangedSubview(view)
            return view
        }
        let tabScroll = horizontalScroll(containing: tabRow)

        let divider = ListScreenLayout.hairline()

        let searchBar = SearchBarView(placeholder: "Search name, SKU or barcode…", height: 42)
        searchBar.onChange = { [weak self] text in
            self?.query = text.trimmingCharacters(in: .whitespaces)
            self?.notifyChanged()
        }

        categoryPill.addTarget(self, action: #selector(pickCategory), for: .touchUpInside)
        brandPill.addTarget(self, action: #selector(pickBrand), for: .touchUpInside)
        statusPill.addTarget(self, action: #selector(pickStatus), for: .touchUpInside)
        let pillRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        [categoryPill, brandPill, statusPill].forEach { pillRow.addArrangedSubview($0) }
        let pillScroll = horizontalScroll(containing: pillRow)

        let stack = UIStackView.vertical(spacing: 10, alignment: .fill)
        stack.addArrangedSubview(kpiScroll)
        stack.addArrangedSubview(tabScroll)
        stack.addArrangedSubview(divider)
        stack.addArrangedSubview(searchBar)
        stack.addArrangedSubview(pillScroll)
        stack.setCustomSpacing(12, after: kpiScroll)
        stack.setCustomSpacing(0, after: tabScroll)
        stack.forAutoLayout()
        addSubview(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))

        refreshChrome()
    }

    private func horizontalScroll(containing content: UIStackView) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.clipsToBounds = false
        content.forAutoLayout()
        scroll.addSubview(content)
        scroll.forAutoLayout()
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            content.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
        return scroll
    }

    // MARK: Data in

    func setProducts(_ items: [ProductItem], summary: ProductsData.Summary?) {
        self.items = items
        self.summary = summary
        refreshChrome()
    }

    func setBaseInfo(_ data: BaseInfoData?) {
        categories = data?.productCategories ?? []
        brands = data?.brands ?? []
    }

    // MARK: Filtering

    /// The products that survive the current tab + search + filter selection.
    var filteredItems: [ProductItem] {
        items.filter { item in
            matchesTab(item) && matchesQuery(item) && matchesCategory(item)
                && matchesBrand(item) && matchesStatus(item)
        }
    }

    private func matchesTab(_ item: ProductItem) -> Bool {
        switch selectedTab {
        case .all: return true
        case .active: return item.isActive
        case .low: return item.isLowStock
        case .out: return item.isOutOfStock
        }
    }

    private func matchesQuery(_ item: ProductItem) -> Bool {
        guard !query.isEmpty else { return true }
        return [item.name, item.sku, item.barcode, item.category, item.brand]
            .contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private func matchesCategory(_ item: ProductItem) -> Bool {
        // A parent category also matches every product filed under one of its children.
        categoryId.isEmpty || categoryId == item.categoryId || categoryId == item.parentCategoryId
    }

    private func matchesBrand(_ item: ProductItem) -> Bool {
        brandName.isEmpty || brandName.caseInsensitiveCompare(item.brand) == .orderedSame
    }

    private func matchesStatus(_ item: ProductItem) -> Bool {
        status.isEmpty || status.caseInsensitiveCompare(item.status) == .orderedSame
    }

    private func notifyChanged() {
        refreshChrome()
        onFilterChanged?()
    }

    // MARK: Chrome binding

    private func refreshChrome() {
        let total = summary?.totalProducts?.value ?? items.count
        let active = summary?.activeProducts?.value ?? count(.active)
        let out = summary?.outOfStock?.value ?? count(.out)
        let low = summary?.lowStock?.value ?? count(.low)

        totalCard.set(value: total, subtitle: totalTrendLabel())
        activeCard.set(value: active, subtitle: percentLabel(active, of: total))
        outCard.set(value: out, subtitle: percentLabel(out, of: total))
        lowCard.set(value: low, subtitle: percentLabel(low, of: total))

        for (index, tab) in Tab.allCases.enumerated() {
            tabViews[index].set(title: "\(tab.title) (\(count(tab)))", selected: tab == selectedTab)
        }
    }

    private func totalTrendLabel() -> String {
        guard let metric = summary?.totalProducts, let label = metric.compareLabel else { return "" }
        let change = metric.changePercent ?? 0
        return String(format: "%+.0f%% %@", change, label)
    }

    private func percentLabel(_ value: Int, of total: Int) -> String {
        let percent = total > 0 ? Int((Double(value) / Double(total) * 100).rounded()) : 0
        return "\(percent)% of total"
    }

    private func count(_ tab: Tab) -> Int {
        switch tab {
        case .all: return items.count
        case .active: return items.filter { $0.isActive }.count
        case .low: return items.filter { $0.isLowStock }.count
        case .out: return items.filter { $0.isOutOfStock }.count
        }
    }

    // MARK: Pickers

    /// Category sheet: parent categories with their children indented underneath,
    /// mirroring the web filter.
    @objc private func pickCategory() {
        var labels = ["All Categories"]
        var ids = [""]

        if !categories.isEmpty {
            for parent in categories where (parent.parentId ?? 0) == 0 {
                labels.append(parent.title ?? "")
                ids.append(String(parent.id))
                for child in categories where child.parentId == parent.id {
                    labels.append("— \(child.title ?? "")")
                    ids.append(String(child.id))
                }
            }
        } else {
            var seen = Set<String>()
            for item in items where !item.categoryId.isEmpty && !item.category.isEmpty {
                if seen.insert(item.categoryId).inserted {
                    labels.append(item.category)
                    ids.append(item.categoryId)
                }
            }
        }

        presentPicker(title: "Category", options: labels) { [weak self] index in
            guard let self = self else { return }
            self.categoryId = ids[index]
            self.categoryPill.setTitle(labels[index].replacingOccurrences(of: "— ", with: ""))
            self.notifyChanged()
        }
    }

    @objc private func pickBrand() {
        var labels = ["All Brands"]
        if !brands.isEmpty {
            for brand in brands {
                if let name = brand.name, !name.isEmpty, !labels.contains(name) { labels.append(name) }
            }
        } else {
            for item in items where !item.brand.isEmpty && !labels.contains(item.brand) {
                labels.append(item.brand)
            }
        }

        presentPicker(title: "Brand", options: labels) { [weak self] index in
            guard let self = self else { return }
            self.brandName = index == 0 ? "" : labels[index]
            self.brandPill.setTitle(labels[index])
            self.notifyChanged()
        }
    }

    @objc private func pickStatus() {
        // The API documents Active / Pending / InActive; anything else a product carries
        // is appended below so the filter always covers the data on screen.
        var labels = ["All Status", "Active", "Pending", "Inactive"]
        for item in items where !item.status.isEmpty && !labels.contains(item.status) {
            labels.append(item.status)
        }

        presentPicker(title: "Status", options: labels) { [weak self] index in
            guard let self = self else { return }
            self.status = index == 0 ? "" : labels[index]
            self.statusPill.setTitle(labels[index])
            self.notifyChanged()
        }
    }

    private func presentPicker(title: String, options: [String], onPick: @escaping (Int) -> Void) {
        guard let presenter = presenter, options.count > 1 else { return }
        let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for (index, option) in options.enumerated() {
            sheet.addAction(UIAlertAction(title: option, style: .default) { _ in onPick(index) })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = self
        sheet.popoverPresentationController?.sourceRect = bounds
        presenter.present(sheet, animated: true)
    }
}

/// One KPI card (label, value, sub-caption) — bg_stat_card + ProductKpi* styles.
final class ProductKpiCard: UIView {

    private let valueLabel = UILabel()
    private let subtitleLabel = UILabel()

    init(title: String, valueColor: UIColor) {
        super.init(frame: .zero)
        StyleKit.styleCard(self)

        let titleLabel = UILabel.make(title, font: AppFonts.light(AppMetrics.textLabel),
                                      color: AppColors.textSecondary, lines: 1)
        valueLabel.font = AppFonts.bold(AppMetrics.textStatValue)
        valueLabel.textColor = valueColor
        valueLabel.text = "0"
        subtitleLabel.font = AppFonts.regular(AppMetrics.textMicro)
        subtitleLabel.textColor = AppColors.textTertiary

        let stack = UIStackView.vertical(spacing: 2, alignment: .leading)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.setCustomSpacing(4, after: titleLabel)
        stack.forAutoLayout()
        addSubview(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10))
        widthAnchor.constraint(equalToConstant: 132).isActive = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func set(value: Int, subtitle: String) {
        valueLabel.text = "\(value)"
        subtitleLabel.text = subtitle
    }
}

/// One stock tab (label + purple underline) — ProductTab / ProductTabIndicator styles.
final class ProductTabView: UIView {

    var onTap: (() -> Void)?

    private let label = UILabel()
    private let indicator = UIView()

    init(title: String) {
        super.init(frame: .zero)
        label.text = title
        label.font = AppFonts.bold(AppMetrics.textBodySM)
        label.textColor = AppColors.textSecondary

        indicator.backgroundColor = AppColors.purplePrimary
        indicator.layer.cornerRadius = 1
        indicator.isHidden = true
        indicator.constrainHeight(2)

        let stack = UIStackView.vertical(spacing: 6, alignment: .fill)
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(indicator)
        stack.forAutoLayout()
        stack.isUserInteractionEnabled = false
        addSubview(stack)
        stack.pinEdges(to: self)

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped() { onTap?() }

    func set(title: String, selected: Bool) {
        label.text = title
        label.textColor = selected ? AppColors.purplePrimary : AppColors.textSecondary
        indicator.isHidden = !selected
    }
}
