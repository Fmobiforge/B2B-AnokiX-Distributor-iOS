import UIKit

/// Inventory management (New-Design/Inventory/1.Inventory-page.png): KPI cards, the stock
/// mix donut, stock tabs, keyword search plus category / brand filters, and stock cards
/// with view / more actions.
///
/// Everything renders from a single GET /inventory/page call and is filtered locally; the
/// stock mutations (adjust, transfer, receive) reload that call on success.
final class InventoryViewController: BaseMainViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    @IBOutlet private weak var logoImageView: UIImageView!
    @IBOutlet private weak var logoSubtitleLabel: UILabel!
    @IBOutlet private weak var pageTitleLabel: UILabel!
    @IBOutlet private weak var pageSubtitleLabel: UILabel!

    private enum Tab: Int, CaseIterable {
        case all, fast, slow, low, out, damaged, expired

        var title: String {
            switch self {
            case .all: return "All Inventory"
            case .fast: return "Fast Moving"
            case .slow: return "Slow Moving"
            case .low: return "Low Stock"
            case .out: return "Out of Stock"
            case .damaged: return "Damaged"
            case .expired: return "Expired"
            }
        }
    }

    // Only the tabs, search and filters stay put; the title, KPI cards and donut ride in
    // the list header so the stock cards always keep the remaining height.
    private let collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: AdaptiveGridLayout.make(estimatedHeight: 168, headerEstimatedHeight: 380))
    private let addStockButton = UIButton(type: .system)

    private let categoryPill = FilterPillButton(title: "All Categories")
    private let brandPill = FilterPillButton(title: "All Brands")
    private let countLabel = UILabel.make(font: AppFonts.regular(AppMetrics.textCaption),
                                          color: AppColors.textSecondary)

    private var tabViews: [ProductTabView] = []
    private var rows: [InventoryPageData.Row] = []
    private var filtered: [InventoryPageData.Row] = []
    private var warehouses: [InventoryPageData.Warehouse] = []
    private var movedProductIds: Set<String> = []
    private var chart: [InventoryPageData.ChartSlice] = []
    private var summary: InventorySummaryData.Summary?
    private var emptyMessage: String?
    private var selectedTab: Tab = .all
    private var query = ""
    private var category = ""
    private var brand = ""

    override func configureStoryboardChrome() {
        logoImageView.image = BrandAssets.logoBlack
        configureLogoHeaderImage(logoImageView, in: chromeStackView.arrangedSubviews.first)
        logoSubtitleLabel.text = S.loginSubtitle
        logoSubtitleLabel.font = AppFonts.light(AppMetrics.textLabel)
        logoSubtitleLabel.textColor = AppColors.textSecondary
        pageTitleLabel.text = S.inventoryOverview
        pageTitleLabel.font = AppFonts.bold(AppMetrics.textHeadline)
        pageTitleLabel.textColor = AppColors.textPrimary
        pageSubtitleLabel.text = S.inventorySubtitle
        pageSubtitleLabel.font = AppFonts.light(AppMetrics.textCaption)
        pageSubtitleLabel.textColor = AppColors.textSecondary
        styleNotificationBell(in: chromeStackView.arrangedSubviews.first)
    }

    private func styleNotificationBell(in panel: UIView?) {
        guard let panel = panel,
              let bell = panel.subviews.compactMap({ $0 as? UIButton }).first else { return }
        bell.tintColor = AppColors.textPrimary
        addNotificationBadge(to: bell)
    }

    @IBAction private func notificationsTapped(_ sender: UIButton) { openNotifications() }

    override func setupContent(in container: UIView) {
        let chrome = buildChrome()

        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = AppColors.background
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .onDrag
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 88, right: 0)
        collectionView.register(InventoryItemCell.self, forCellWithReuseIdentifier: "InventoryItemCell")
        collectionView.register(InventorySummaryHeaderView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: InventorySummaryHeaderView.reuseIdentifier)

        StyleKit.stylePrimaryButton(addStockButton, fontSize: 13)
        addStockButton.setTitle("  Add Stock", for: .normal)
        addStockButton.setImage(UIImage(systemName: "plus"), for: .normal)
        addStockButton.addTarget(self, action: #selector(addStockTapped), for: .touchUpInside)

        let divider = ListScreenLayout.hairline()
        [chrome, divider, collectionView, addStockButton].forEach { $0.forAutoLayout() }
        container.addSubviews(chrome, divider, collectionView, addStockButton)

        NSLayoutConstraint.activate([
            chrome.topAnchor.constraint(equalTo: container.topAnchor),
            chrome.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.topAnchor.constraint(equalTo: chrome.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            addStockButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            addStockButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            addStockButton.heightAnchor.constraint(equalToConstant: 48)
        ])

        applyFilters()   // paints the tab selection before the first response lands
    }

    /// The pinned bar: stock tabs, keyword search, filter pills and the result count.
    private func buildChrome() -> UIView {
        // Seven tabs never fit across a phone, so they scroll like the Products screen.
        let tabRow = UIStackView.horizontal(spacing: 18, alignment: .fill)
        tabViews = Tab.allCases.map { tab in
            let view = ProductTabView(title: tab.title)
            view.onTap = { [weak self] in
                self?.selectedTab = tab
                self?.applyFilters()
            }
            tabRow.addArrangedSubview(view)
            return view
        }
        let tabScroll = horizontalScroll(containing: tabRow)

        let searchBar = SearchBarView(placeholder: "Search name, SKU or barcode…", height: 42)
        searchBar.onChange = { [weak self] text in
            self?.query = text.trimmingCharacters(in: .whitespaces)
            self?.applyFilters()
        }

        categoryPill.addTarget(self, action: #selector(pickCategory), for: .touchUpInside)
        brandPill.addTarget(self, action: #selector(pickBrand), for: .touchUpInside)
        let pillRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        pillRow.addArrangedSubview(categoryPill)
        pillRow.addArrangedSubview(brandPill)
        pillRow.addArrangedSubview(UIView())

        let countRow = UIStackView.horizontal(spacing: 0, alignment: .fill)
        countRow.addArrangedSubview(countLabel)

        return ListScreenLayout.surfaceSection(
            [tabScroll, searchBar, pillRow, countRow],
            spacing: 10,
            insets: UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16))
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

    // MARK: Data

    override func loadData() { loadPage() }

    private func loadPage() {
        ApiClient.shared.getInventoryPage { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                self.rows = data.rows ?? []
                self.warehouses = data.warehouses ?? []
                self.chart = data.chart ?? []
                self.summary = data.summary
                self.movedProductIds = Set((data.movements ?? []).compactMap { $0.productId })
                self.applyFilters()   // reloads the rows and the summary header above them
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    /// Re-reads the page after a stock mutation so every number on screen stays true.
    private func reload(after message: String) {
        if !message.isEmpty { toast(message) }
        loadPage()
    }

    // MARK: Filtering

    private func applyFilters() {
        filtered = rows.filter { matchesTab($0) && matchesQuery($0) && matchesCategory($0) && matchesBrand($0) }
        for (index, tab) in Tab.allCases.enumerated() where tabViews.indices.contains(index) {
            tabViews[index].set(title: tab.title, selected: tab == selectedTab)
        }
        countLabel.text = "\(filtered.count) of \(rows.count) items"
        // The empty line lives in the header so it sits below the summary, never over it.
        emptyMessage = filtered.isEmpty
            ? (rows.isEmpty ? "No stock yet. Tap Add Stock to receive your first delivery."
                            : "No stock matches your search or filters.")
            : nil
        collectionView.reloadData()
    }

    private func matchesTab(_ row: InventoryPageData.Row) -> Bool {
        let productId = row.productId.map(String.init) ?? ""
        switch selectedTab {
        case .all: return true
        // "Fast moving" = the product shows up in the movements this page returned.
        case .fast: return movedProductIds.contains(productId)
        case .slow: return !movedProductIds.contains(productId)
        case .low: return row.isLowStock
        case .out: return row.isOutOfStock
        case .damaged: return row.hasDamaged
        case .expired: return row.hasExpired
        }
    }

    private func matchesQuery(_ row: InventoryPageData.Row) -> Bool {
        guard !query.isEmpty else { return true }
        return [row.name, row.sku, row.barcode, row.category, row.brand]
            .compactMap { $0 }
            .contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private func matchesCategory(_ row: InventoryPageData.Row) -> Bool {
        category.isEmpty || category.caseInsensitiveCompare(row.category ?? "") == .orderedSame
    }

    private func matchesBrand(_ row: InventoryPageData.Row) -> Bool {
        brand.isEmpty || brand.caseInsensitiveCompare(row.brand ?? "") == .orderedSame
    }

    @objc private func pickCategory() {
        let options = ["All Categories"] + distinct { $0.category }
        presentPicker(title: "Category", options: options) { [weak self] index in
            self?.category = index == 0 ? "" : options[index]
            self?.categoryPill.setTitle(options[index])
            self?.applyFilters()
        }
    }

    @objc private func pickBrand() {
        let options = ["All Brands"] + distinct { $0.brand }
        presentPicker(title: "Brand", options: options) { [weak self] index in
            self?.brand = index == 0 ? "" : options[index]
            self?.brandPill.setTitle(options[index])
            self?.applyFilters()
        }
    }

    /// Distinct non-empty values found in the loaded rows, keeping their order.
    private func distinct(_ value: (InventoryPageData.Row) -> String?) -> [String] {
        var seen: [String] = []
        for row in rows {
            if let text = value(row), !text.isEmpty, !seen.contains(text) { seen.append(text) }
        }
        return seen
    }

    private func presentPicker(title: String, options: [String], onPick: @escaping (Int) -> Void) {
        guard options.count > 1 else { return }
        let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for (index, option) in options.enumerated() {
            sheet.addAction(UIAlertAction(title: option, style: .default) { _ in onPick(index) })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = view.bounds
        present(sheet, animated: true)
    }

    // MARK: Actions

    @objc private func addStockTapped() {
        StockActionSheets.showReceive(from: self, warehouses: warehouses, rows: rows,
                                      preselected: nil) { [weak self] message in
            self?.reload(after: message)
        }
    }

    private func openDetails(_ row: InventoryPageData.Row, startOnHistory: Bool) {
        let detail = InventoryDetailViewController(row: row, warehouses: warehouses,
                                                   startOnHistory: startOnHistory)
        // The drawer can adjust or transfer stock, so refresh the list behind it.
        detail.onStockChanged = { [weak self] in self?.loadPage() }
        detail.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(detail, animated: true)
    }

    private func showRowMenu(_ row: InventoryPageData.Row, anchor: UIView) {
        let sheet = UIAlertController(title: row.name, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Adjust Stock", style: .default) { [weak self] _ in
            guard let self = self else { return }
            StockActionSheets.showAdjustStock(from: self, row: row) { self.reload(after: $0) }
        })
        sheet.addAction(UIAlertAction(title: "Transfer", style: .default) { [weak self] _ in
            guard let self = self else { return }
            StockActionSheets.showTransfer(from: self, row: row, warehouses: self.warehouses) {
                self.reload(after: $0)
            }
        })
        sheet.addAction(UIAlertAction(title: "View History", style: .default) { [weak self] _ in
            self?.openDetails(row, startOnHistory: true)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = anchor
        sheet.popoverPresentationController?.sourceRect = anchor.bounds
        present(sheet, animated: true)
    }

    private func format(_ value: Int64) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }

    private func toast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { alert.dismiss(animated: true) }
    }

    // MARK: Collection view

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        filtered.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "InventoryItemCell", for: indexPath) as? InventoryItemCell else {
            return UICollectionViewCell()
        }
        let row = filtered[indexPath.row]
        cell.configure(row)
        cell.onView = { [weak self] in self?.openDetails(row, startOnHistory: false) }
        cell.onMore = { [weak self] anchor in self?.showRowMenu(row, anchor: anchor) }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        openDetails(filtered[indexPath.row], startOnHistory: false)
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind, withReuseIdentifier: InventorySummaryHeaderView.reuseIdentifier,
                for: indexPath) as? InventorySummaryHeaderView else {
            return UICollectionReusableView()
        }
        header.configure(summary: summary, chart: chart, emptyMessage: emptyMessage)
        return header
    }
}
