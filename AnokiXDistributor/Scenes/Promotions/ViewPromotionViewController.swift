import UIKit

/// Read-only campaign detail screen — mirrors the web portal "Campaign Details" modal
/// and Android `ViewPromotionActivity`. Loads `GET /api/distributor/promotions/get-by-id`.
final class ViewPromotionViewController: BaseSecondaryViewController {

    private let promotionId: String
    var onUpdated: (() -> Void)?

    override var screenTitle: String { S.promoViewTitle }

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView.vertical(spacing: 12, alignment: .fill)
    private let loading = UIActivityIndicatorView(style: .large)
    private let summaryStack = UIStackView.vertical(spacing: 0, alignment: .fill)
    private let productsStack = UIStackView.vertical(spacing: 0, alignment: .fill)
    private let stockLogsStack = UIStackView.vertical(spacing: 0, alignment: .fill)
    private let productsEmpty = UILabel.make(S.promoNoProducts, font: AppFonts.regular(13),
                                             color: AppColors.textSecondary, align: .center, lines: 0)
    private let stockLogsEmpty = UILabel.make(S.promoNoStockLogs, font: AppFonts.regular(13),
                                              color: AppColors.textSecondary, align: .center, lines: 0)

    // Media hero
    private let mediaHero = PromoHeroView()
    private let mediaTitle = UILabel.make(font: AppFonts.bold(18), color: .white, lines: 2)
    private let mediaDescription = UILabel.make(font: AppFonts.regular(13), color: UIColor.white.withAlphaComponent(0.9), lines: 3)
    private let mediaPlayIcon = UIImageView(image: UIImage(systemName: "play.circle.fill"))
    private let mediaImageView = UIImageView()
    private let mediaScrim = UIView()

    private let footerRow = UIStackView.horizontal(spacing: 10, alignment: .fill)
    private let editButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)

    init(promotionId: String) {
        self.promotionId = promotionId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func setupContent(in container: UIView) {
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.forAutoLayout()
        contentStack.forAutoLayout()
        scrollView.addSubview(contentStack)
        container.addSubview(scrollView)

        loading.hidesWhenStopped = true
        loading.forAutoLayout()
        container.addSubview(loading)

        setupMediaHero()
        contentStack.addArrangedSubview(mediaHero)
        contentStack.addArrangedSubview(sectionCard(title: S.promoSummaryTitle, body: summaryStack))
        contentStack.addArrangedSubview(sectionCard(title: S.promoAddedProducts, body: productsStack, empty: productsEmpty))
        contentStack.addArrangedSubview(sectionCard(title: S.promoStockLogs, body: stockLogsStack, empty: stockLogsEmpty))

        StyleKit.styleOutlinedButton(editButton)
        editButton.setTitle(S.promoEditCampaign, for: .normal)
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)

        StyleKit.stylePrimaryButton(closeButton)
        closeButton.setTitle(S.promoClose, for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        footerRow.distribution = .fillEqually
        footerRow.addArrangedSubview(editButton)
        footerRow.addArrangedSubview(closeButton)
        footerRow.forAutoLayout()
        footerRow.isHidden = true
        container.addSubview(footerRow)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerRow.topAnchor, constant: -10),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),

            mediaHero.heightAnchor.constraint(equalToConstant: 200),

            footerRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            footerRow.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            footerRow.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            editButton.heightAnchor.constraint(equalToConstant: 48),
            closeButton.heightAnchor.constraint(equalToConstant: 48),

            loading.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            loading.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
    }

    override func loadData() {
        scrollView.isHidden = true
        footerRow.isHidden = true
        loading.startAnimating()

        ApiClient.shared.getPromotionById(id: promotionId) { [weak self] result in
            guard let self = self else { return }
            self.loading.stopAnimating()
            switch result {
            case .success(let data):
                guard let promotion = data.promotion else {
                    self.toast(S.errPromoName)
                    self.navigationController?.popViewController(animated: true)
                    return
                }
                self.bind(promotion, stockLogs: data.resolvedStockLogs())
                self.scrollView.isHidden = false
                self.footerRow.isHidden = false
            case .failure(let error):
                self.toast(error.message)
                self.navigationController?.popViewController(animated: true)
            }
        }
    }

    // MARK: - Bind

    private func bind(_ p: PromotionDetailData.Promotion,
                      stockLogs: [PromotionDetailData.StockLog]) {
        bindMedia(p)
        bindSummary(p)
        bindProducts(p.selectedProducts)
        bindStockLogs(stockLogs)
    }

    private func bindMedia(_ p: PromotionDetailData.Promotion) {
        mediaTitle.text = p.name ?? ""
        mediaDescription.text = p.promotionDescription ?? ""

        let bannerUrl = p.bannerFile?.bestUrl
        let videoUrl = p.videoFile?.bestUrl
        let hasBanner = !(bannerUrl?.isEmpty ?? true)
        let hasVideo = !(videoUrl?.isEmpty ?? true)

        mediaImageView.isHidden = true
        mediaScrim.isHidden = true
        mediaPlayIcon.isHidden = true
        mediaHero.showGradient = true

        if hasBanner, let urlString = bannerUrl, let url = URL(string: urlString) {
            mediaImageView.isHidden = false
            mediaScrim.isHidden = false
            mediaPlayIcon.isHidden = !hasVideo
            mediaHero.showGradient = false
            ImageLoader.load(url) { [weak self] image in
                self?.mediaImageView.image = image
            }
        } else if hasVideo {
            mediaPlayIcon.isHidden = false
        }
    }

    private func bindSummary(_ p: PromotionDetailData.Promotion) {
        summaryStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        addStatusRow(p.status)
        addSummaryRow(S.promoTypeLabel, ApiMapper.campaignTypeLabel(p.campaignType))
        addSummaryRow(S.promoObjective, ApiMapper.prettify(p.objective))
        addSummaryRow(S.promoDuration, formatDateRange(p.startDate, p.endDate))
        addSummaryRow(S.budget, formatBudget(p.budget, p.dailyBudget))
        addSummaryRow(S.promoTargeting, formatTargeting(p))
        addSummaryRow(S.promoProductsSummary, summarizeProducts(p.selectedProducts))
        addSummaryRow(S.promoProductsCost, formatMoney(p.productsCost))
        addSummaryRow(S.reach, formatCount(p.reach))
        addSummaryRow(S.clicks, formatCount(p.clicks))
        addSummaryRow(S.ctr, formatPercent(p.ctr))
        addSummaryRow(S.promoSalesImpact, formatMoney(p.attributedSales))
    }

    private func bindProducts(_ raw: JSONValue?) {
        productsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let root = raw?.unwrapped, root.objectValue != nil else {
            productsEmpty.isHidden = false
            return
        }

        var sections = 0

        let singles = root.array("single_products")
        if !singles.isEmpty {
            sections += 1
            addProductSection(title: S.promoSingleProducts, subtitle: nil, lines: singles, role: nil)
        }

        for dealEl in root.array("combo_deals") {
            guard dealEl.objectValue != nil else { continue }
            var lines = dealEl.array("products")
            if lines.isEmpty, let bare = dealEl.arrayValue { lines = bare }
            guard !lines.isEmpty else { continue }
            sections += 1
            addProductSection(title: S.promoComboDeals,
                              subtitle: comboDealSubtitle(dealEl), lines: lines, role: nil)
        }

        for dealEl in root.array("buy1_get1_deals") {
            guard dealEl.objectValue != nil else { continue }
            sections += 1
            addDealHeader(title: S.promoB1g1Deals, subtitle: b1g1DealSubtitle(dealEl))
            appendProductLines(dealEl.array("buy_products"), role: S.promoRoleBuy)
            appendProductLines(dealEl.array("free_products"), role: S.promoRoleFree)
        }

        productsEmpty.isHidden = sections > 0
    }

    private func bindStockLogs(_ logs: [PromotionDetailData.StockLog]) {
        stockLogsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !logs.isEmpty else {
            stockLogsEmpty.isHidden = false
            return
        }
        stockLogsEmpty.isHidden = true
        for log in logs {
            stockLogsStack.addArrangedSubview(makeStockLogRow(log))
        }
    }

    // MARK: - UI builders

    private func setupMediaHero() {
        mediaHero.clipsToBounds = true
        mediaHero.layer.cornerRadius = AppMetrics.radiusLG

        mediaImageView.contentMode = .scaleAspectFill
        mediaImageView.clipsToBounds = true
        mediaImageView.forAutoLayout()

        mediaScrim.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        mediaScrim.forAutoLayout()

        mediaPlayIcon.tintColor = .white
        mediaPlayIcon.contentMode = .scaleAspectFit
        mediaPlayIcon.forAutoLayout()

        let textStack = UIStackView.vertical(spacing: 4, alignment: .fill)
        textStack.addArrangedSubview(mediaTitle)
        textStack.addArrangedSubview(mediaDescription)
        textStack.forAutoLayout()

        mediaHero.addSubviews(mediaImageView, mediaScrim, mediaPlayIcon, textStack)
        NSLayoutConstraint.activate([
            mediaImageView.topAnchor.constraint(equalTo: mediaHero.topAnchor),
            mediaImageView.leadingAnchor.constraint(equalTo: mediaHero.leadingAnchor),
            mediaImageView.trailingAnchor.constraint(equalTo: mediaHero.trailingAnchor),
            mediaImageView.bottomAnchor.constraint(equalTo: mediaHero.bottomAnchor),

            mediaScrim.topAnchor.constraint(equalTo: mediaHero.topAnchor),
            mediaScrim.leadingAnchor.constraint(equalTo: mediaHero.leadingAnchor),
            mediaScrim.trailingAnchor.constraint(equalTo: mediaHero.trailingAnchor),
            mediaScrim.bottomAnchor.constraint(equalTo: mediaHero.bottomAnchor),

            mediaPlayIcon.centerXAnchor.constraint(equalTo: mediaHero.centerXAnchor),
            mediaPlayIcon.centerYAnchor.constraint(equalTo: mediaHero.centerYAnchor),
            mediaPlayIcon.widthAnchor.constraint(equalToConstant: 48),
            mediaPlayIcon.heightAnchor.constraint(equalToConstant: 48),

            textStack.leadingAnchor.constraint(equalTo: mediaHero.leadingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: mediaHero.trailingAnchor, constant: -16),
            textStack.bottomAnchor.constraint(equalTo: mediaHero.bottomAnchor, constant: -16)
        ])
    }

    private func sectionCard(title: String, body: UIStackView, empty: UILabel? = nil) -> UIView {
        let card = StyleKit.cardView()
        let heading = UILabel.make(title, font: AppFonts.bold(16), color: AppColors.topTitle)
        let divider = ListScreenLayout.hairline()
        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(heading)
        stack.addArrangedSubview(divider)
        stack.addArrangedSubview(body)
        if let empty = empty {
            empty.isHidden = true
            stack.addArrangedSubview(empty)
        }
        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        return card
    }

    private func addSummaryRow(_ label: String, _ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        summaryStack.addArrangedSubview(makeKVRow(label: label, value: trimmed, valueView: nil))
    }

    private func addStatusRow(_ status: String?) {
        let badge = StyleKit.badgeLabel()
        applyPromotionStatusBadge(badge, status: status)
        summaryStack.addArrangedSubview(makeKVRow(label: S.promoStatusLabel, value: "", valueView: badge))
    }

    private func makeKVRow(label: String, value: String, valueView: UIView?) -> UIView {
        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.distribution = .fillEqually
        let labelView = UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textSecondary)
        row.addArrangedSubview(labelView)
        if let valueView = valueView {
            let wrap = UIView()
            valueView.forAutoLayout()
            wrap.addSubview(valueView)
            NSLayoutConstraint.activate([
                valueView.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
                valueView.centerYAnchor.constraint(equalTo: wrap.centerYAnchor)
            ])
            row.addArrangedSubview(wrap)
        } else {
            let valueLabel = UILabel.make(value, font: AppFonts.bold(13), color: AppColors.topTitle, align: .right, lines: 0)
            row.addArrangedSubview(valueLabel)
        }
        row.layoutMargins = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        row.isLayoutMarginsRelativeArrangement = true
        let container = UIStackView.vertical(spacing: 0, alignment: .fill)
        container.addArrangedSubview(row)
        container.addArrangedSubview(ListScreenLayout.hairline())
        return container
    }

    private func addProductSection(title: String, subtitle: String?, lines: [JSONValue], role: String?) {
        addDealHeader(title: title, subtitle: subtitle)
        appendProductLines(lines, role: role)
    }

    private func addDealHeader(title: String, subtitle: String?) {
        if !productsStack.arrangedSubviews.isEmpty {
            productsStack.addArrangedSubview(UIView.spacer(height: 14))
        }
        productsStack.addArrangedSubview(UILabel.make(title, font: AppFonts.bold(13), color: AppColors.textPrimary))
        if let subtitle = subtitle, !subtitle.trimmingCharacters(in: .whitespaces).isEmpty {
            productsStack.addArrangedSubview(
                UILabel.make(subtitle, font: AppFonts.regular(11), color: AppColors.textSecondary))
        }
        productsStack.addArrangedSubview(UIView.spacer(height: 8))
        productsStack.addArrangedSubview(ListScreenLayout.hairline())
    }

    private func appendProductLines(_ lines: [JSONValue], role: String?) {
        for el in lines {
            guard el.objectValue != nil else { continue }
            productsStack.addArrangedSubview(makeProductRow(el, role: role))
        }
    }

    private func makeProductRow(_ o: JSONValue, role: String?) -> UIView {
        let row = UIStackView.horizontal(spacing: 10, alignment: .center)

        let thumb = UIImageView()
        thumb.backgroundColor = AppColors.borderLight
        thumb.layer.cornerRadius = AppMetrics.radiusSM
        thumb.clipsToBounds = true
        thumb.contentMode = .scaleAspectFill
        thumb.constrainSize(40)

        let name = firstNonEmpty(o.string("name"), o.string("product_name"), "Product")
        let category = firstNonEmpty(o.string("category_title"), o["category"]?.string("title") ?? "")
        let brand = firstNonEmpty(o.string("brand_name"), o["brand"]?.string("name") ?? "")
        var meta = ""
        if !category.isEmpty && !brand.isEmpty { meta = "\(category) · \(brand)" }
        else if !category.isEmpty { meta = category }
        else { meta = brand }

        let textStack = UIStackView.vertical(spacing: 2, alignment: .leading)
        textStack.addArrangedSubview(UILabel.make(name, font: AppFonts.bold(14), color: AppColors.textPrimary))
        if !meta.isEmpty {
            textStack.addArrangedSubview(UILabel.make(meta, font: AppFonts.regular(11), color: AppColors.textSecondary))
        }

        let price = firstNonEmpty(o.string("campaign_selling_price"), o.string("selling_price"))
        let stock = firstNonEmpty(o.string("available_stock"), o.string("stock"))
        if !price.isEmpty || !stock.isEmpty {
            var extra = formatMoney(price)
            if !stock.isEmpty { extra += " · Stock: \(stock)" }
            textStack.addArrangedSubview(UILabel.make(extra, font: AppFonts.regular(11), color: AppColors.textSecondary))
        }

        row.addArrangedSubview(thumb)
        row.addArrangedSubview(textStack)

        if let role = role {
            let badge = StyleKit.badgeLabel()
            badge.text = role
            badge.textColor = AppColors.purplePrimary
            badge.backgroundColor = AppColors.purpleLight
            badge.setContentHuggingPriority(.required, for: .horizontal)
            row.addArrangedSubview(badge)
        }

        let imageUrl = firstNonEmpty(o.string("image_url"), o.string("primary_product_image_url"))
        if !imageUrl.isEmpty, let url = URL(string: imageUrl) {
            ImageLoader.load(url) { image in thumb.image = image }
        }

        row.layoutMargins = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        row.isLayoutMarginsRelativeArrangement = true
        return row
    }

    private func makeStockLogRow(_ log: PromotionDetailData.StockLog) -> UIView {
        let resolved = firstNonEmpty(log.productName, log.productId)
        let product = resolved.isEmpty ? "—" : resolved
        let row = UIStackView.vertical(spacing: 4, alignment: .leading)
        row.addArrangedSubview(UILabel.make(product, font: AppFonts.bold(14), color: AppColors.textPrimary))
        let detail = UIStackView.horizontal(spacing: 8, alignment: .center)
        detail.distribution = .fillEqually
        detail.addArrangedSubview(UILabel.make(log.action ?? "", font: AppFonts.regular(12), color: AppColors.textSecondary))
        let qty = log.quantity.map { "Qty: \($0)" } ?? ""
        detail.addArrangedSubview(UILabel.make(qty, font: AppFonts.regular(12), color: AppColors.textSecondary))
        detail.addArrangedSubview(UILabel.make(log.createdAt ?? "", font: AppFonts.regular(12),
                                               color: AppColors.textSecondary, align: .right))
        row.addArrangedSubview(detail)
        row.layoutMargins = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        row.isLayoutMarginsRelativeArrangement = true
        row.addArrangedSubview(ListScreenLayout.hairline())
        return row
    }

    private func applyPromotionStatusBadge(_ badge: PaddingLabel, status: String?) {
        let display = ApiMapper.prettify(status)
        badge.text = display.isEmpty ? "—" : display
        let s = (status ?? "").lowercased()
        switch s {
        case "active":
            badge.textColor = AppColors.success
            badge.backgroundColor = AppColors.successBg
        case "rejected", "inactive", "expired":
            badge.textColor = AppColors.danger
            badge.backgroundColor = AppColors.dangerBg
        case "pending_approval", "paused", "draft", "scheduled":
            badge.textColor = AppColors.warning
            badge.backgroundColor = AppColors.warningBg
        default:
            badge.textColor = AppColors.info
            badge.backgroundColor = AppColors.infoBg
        }
    }

    // MARK: - Actions

    @objc private func editTapped() {
        let wizard = CreatePromotionViewController(promotionId: promotionId)
        wizard.onSaved = { [weak self] message in
            guard let self = self else { return }
            self.onUpdated?()
            self.successBanner(message)
            self.loadData()
        }
        navigationController?.pushViewController(wizard, animated: true)
    }

    @objc private func closeTapped() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Parsing / formatting

    private struct DealMetrics {
        var sumPrice: Double = 0
        var minStock: Int?
    }

    private func metricsFromLines(_ lines: [JSONValue]) -> DealMetrics {
        var m = DealMetrics()
        for el in lines {
            guard el.objectValue != nil else { continue }
            let cpStr = el.string("campaign_selling_price")
            if !cpStr.isEmpty, let cp = Double(cpStr) { m.sumPrice += cp }
            let stockRaw = firstNonEmpty(el.string("available_stock"), el.string("original_stock"))
            if !stockRaw.isEmpty, let stockVal = Double(stockRaw) {
                let s = Int(stockVal.rounded())
                m.minStock = min(m.minStock ?? s, s)
            }
        }
        return m
    }

    private func comboDealSubtitle(_ deal: JSONValue) -> String? {
        var price = deal.string("campaign_selling_price")
        var stock = deal.string("available_stock")
        if price.isEmpty || stock.isEmpty {
            let metrics = metricsFromLines(deal.array("products"))
            if price.isEmpty, metrics.sumPrice > 0 {
                price = metrics.sumPrice.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(metrics.sumPrice)) : String(metrics.sumPrice)
            }
            if stock.isEmpty, let minStock = metrics.minStock {
                stock = String(minStock)
            }
        }
        return dealSubtitle(price: price, stock: stock)
    }

    private func b1g1DealSubtitle(_ deal: JSONValue) -> String? {
        var price = deal.string("campaign_selling_price")
        var stock = deal.string("available_stock")
        if stock.isEmpty {
            let metrics = metricsFromLines(deal.array("buy_products"))
            if let minStock = metrics.minStock { stock = String(minStock) }
        }
        return dealSubtitle(price: price, stock: stock)
    }

    private func dealSubtitle(price: String, stock: String) -> String? {
        let priceText = formatMoney(price)
        if priceText.isEmpty && stock.isEmpty { return nil }
        return S.promoDealPriceStock(priceText.isEmpty ? "—" : priceText, stock.isEmpty ? "—" : stock)
    }

    private func formatTargeting(_ p: PromotionDetailData.Promotion) -> String {
        var parts: [String] = []
        if let address = p.address?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty {
            parts.append(address)
        }
        let segments = formatSegments(p.traderSegments)
        if !segments.isEmpty {
            parts.append("\(S.promoTraderSegmentsLabel): \(segments)")
        }
        return parts.joined(separator: "\n")
    }

    private func formatSegments(_ raw: JSONValue?) -> String {
        guard let array = raw?.unwrapped.arrayValue else { return "" }
        var names: [String] = []
        for el in array {
            if let s = el.stringValue, !s.isEmpty {
                names.append(s)
            } else if el.objectValue != nil {
                let name = firstNonEmpty(el.string("name"), el.string("title"))
                if !name.isEmpty { names.append(name) }
            }
        }
        return names.joined(separator: ", ")
    }

    private func summarizeProducts(_ raw: JSONValue?) -> String {
        guard let root = raw?.unwrapped, root.objectValue != nil else { return "" }
        var parts: [String] = []
        let singles = root.array("single_products").count
        let combos = root.array("combo_deals").count
        let b1g1 = root.array("buy1_get1_deals").count
        if singles > 0 { parts.append("\(singles) Single Product\(singles > 1 ? "s" : "")") }
        if combos > 0 { parts.append("\(combos) Combo Deal\(combos > 1 ? "s" : "")") }
        if b1g1 > 0 { parts.append("\(b1g1) Buy1Get1 Deal\(b1g1 > 1 ? "s" : "")") }
        return parts.joined(separator: ", ")
    }

    private func formatBudget(_ budget: String?, _ daily: String?) -> String {
        let b = formatMoney(budget)
        let d = formatMoney(daily)
        if b.isEmpty { return d }
        if d.isEmpty { return b }
        return "\(b) (\(d) daily)"
    }

    private func formatMoney(_ value: String?) -> String {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return "" }
        if raw.hasPrefix("R") { return raw }
        if let num = Double(raw) {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.groupingSeparator = " "
            f.maximumFractionDigits = num.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
            f.minimumFractionDigits = num.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
            return "R" + (f.string(from: NSNumber(value: num)) ?? raw)
        }
        return "R" + raw
    }

    private func formatCount(_ value: String?) -> String {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return "0" }
        if let num = Double(raw) {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.groupingSeparator = " "
            f.maximumFractionDigits = 0
            return f.string(from: NSNumber(value: num)) ?? raw
        }
        return raw
    }

    private func formatPercent(_ value: String?) -> String {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return "0.0%" }
        if raw.hasSuffix("%") { return raw }
        if let num = Double(raw) { return String(format: "%.1f%%", num) }
        return raw
    }

    private func formatDateRange(_ start: String?, _ end: String?) -> String {
        let s = formatDisplayDate(start)
        let e = formatDisplayDate(end)
        if s.isEmpty && e.isEmpty { return "" }
        if s.isEmpty { return e }
        if e.isEmpty { return s }
        return "\(s) – \(e)"
    }

    private func formatDisplayDate(_ api: String?) -> String {
        guard let api = api, !api.isEmpty else { return "" }
        let inF = DateFormatter()
        inF.locale = Locale(identifier: "en_US_POSIX")
        inF.dateFormat = "yyyy-MM-dd"
        guard let date = inF.date(from: api) else { return api }
        let outF = DateFormatter()
        outF.locale = Locale(identifier: "en_US_POSIX")
        outF.dateFormat = "dd MMM yyyy"
        return outF.string(from: date)
    }

    private func firstNonEmpty(_ values: String?...) -> String {
        for case let value? in values where !value.isEmpty {
            return value
        }
        return ""
    }
}

// MARK: - Promo hero gradient (Android bg_promo_hero_default)

private final class PromoHeroView: UIView {
    var showGradient = true {
        didSet { gradientLayer.isHidden = !showGradient }
    }

    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.colors = [UIColor(hex: 0x7C3AED).cgColor, UIColor(hex: 0x4338CA).cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = layer.cornerRadius
    }
}

private extension UIView {
    static func spacer(height: CGFloat) -> UIView {
        let v = UIView()
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }
}
