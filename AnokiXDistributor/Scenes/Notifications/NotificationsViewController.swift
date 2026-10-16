import UIKit

/// Notifications — live feed from GET api/common/notifications (filter all/unread, paged).
/// KPI cards (total/read/unread/important), All/Unread tabs, "Mark all as read", and
/// tap-to-open: tapping a row marks it read (POST .../read) and routes to the related screen
/// via `PushManager.navigate`, the same resolver a push tap uses
/// (see `FCM-settings/3-Event-Catalogue.md`).
final class NotificationsViewController: BaseSecondaryViewController {

    override var screenTitle: String { S.notifications }
    override var screenSubtitle: String? { S.notificationsSubtitle }

    private static let perPage = 8

    // Data + filter state
    private var allItems: [NotificationDTO] = []
    private var filter = "all"          // "all" | "unread"
    private var page = 1
    private var totalPages = 1
    private var total = 0
    private var unreadCount = 0

    // UI
    private let summaryScroll = UIScrollView()
    private let summaryRow = UIStackView.horizontal(spacing: 10, alignment: .fill)
    private let tabAll = UILabel.make("All", font: AppFonts.bold(14), color: AppColors.purplePrimary)
    private let tabUnread = UILabel.make("Unread", font: AppFonts.medium(14), color: AppColors.textSecondary)
    private let listStack = UIStackView.vertical(spacing: 12, alignment: .fill)
    private let emptyView = UIStackView.vertical(spacing: 4, alignment: .center)
    private let pageInfoLabel = UILabel.make("", font: AppFonts.regular(12), color: AppColors.textSecondary)
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let paginationRow = UIStackView.horizontal(spacing: 8, alignment: .center)
    private let spinner = UIActivityIndicatorView(style: .medium)

    // MARK: - Setup

    override func setupContent(in container: UIView) {
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = false
        scroll.backgroundColor = AppColors.background
        scroll.forAutoLayout()
        container.addSubview(scroll)

        let stack = UIStackView.vertical(spacing: 14, alignment: .fill)
        stack.forAutoLayout()
        scroll.addSubview(stack)

        // Summary stat cards (horizontally scrollable).
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
        let summaryHeight = summaryScroll.heightAnchor.constraint(equalToConstant: 120)
        summaryHeight.priority = .defaultHigh
        summaryHeight.isActive = true
        stack.addArrangedSubview(summaryScroll)

        // Tabs (All / Unread) + Mark all as read.
        tabAll.isUserInteractionEnabled = true
        tabAll.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapAll)))
        tabUnread.isUserInteractionEnabled = true
        tabUnread.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapUnread)))

        let markAll = UIButton(type: .system)
        var markConfig = UIButton.Configuration.plain()
        markConfig.title = S.markAllRead
        markConfig.image = UIImage(systemName: "checkmark.circle")
        markConfig.imagePadding = 6
        markConfig.baseForegroundColor = AppColors.purplePrimary
        markConfig.contentInsets = .zero
        markConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        markConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.bold(13); return out
        }
        markAll.configuration = markConfig
        markAll.addTarget(self, action: #selector(markAllTapped), for: .touchUpInside)

        let tabsRow = UIStackView.horizontal(spacing: 20, alignment: .center)
        tabsRow.addArrangedSubview(tabAll)
        tabsRow.addArrangedSubview(tabUnread)
        tabsRow.addArrangedSubview(UIView())
        tabsRow.addArrangedSubview(markAll)
        stack.addArrangedSubview(tabsRow)
        stack.addArrangedSubview(ListScreenLayout.hairline())

        // Empty state.
        let emptyIcon = UIImageView(image: UIImage(systemName: "bell.slash"))
        emptyIcon.tintColor = AppColors.textSecondary
        emptyIcon.contentMode = .scaleAspectFit
        emptyIcon.alpha = 0.4
        emptyIcon.forAutoLayout()
        emptyIcon.constrainSize(48)
        emptyView.addArrangedSubview(emptyIcon)
        emptyView.addArrangedSubview(UILabel.make(S.notifEmptyTitle, font: AppFonts.bold(15), color: AppColors.textPrimary, align: .center))
        emptyView.addArrangedSubview(UILabel.make(S.notifEmptySub, font: AppFonts.regular(12), color: AppColors.textSecondary, align: .center, lines: 0))
        emptyView.isHidden = true
        emptyView.isLayoutMarginsRelativeArrangement = true
        emptyView.layoutMargins = UIEdgeInsets(top: 32, left: 16, bottom: 32, right: 16)
        stack.addArrangedSubview(emptyView)

        stack.addArrangedSubview(listStack)

        // Pagination footer.
        configurePaginationButton(prevButton, symbol: "chevron.left", action: #selector(prevPage))
        configurePaginationButton(nextButton, symbol: "chevron.right", action: #selector(nextPage))
        paginationRow.addArrangedSubview(pageInfoLabel)
        paginationRow.addArrangedSubview(UIView())
        paginationRow.addArrangedSubview(prevButton)
        paginationRow.addArrangedSubview(nextButton)
        paginationRow.isHidden = true
        stack.addArrangedSubview(paginationRow)

        spinner.hidesWhenStopped = true
        spinner.color = AppColors.purplePrimary
        spinner.forAutoLayout()
        container.addSubview(spinner)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: container.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),

            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: container.topAnchor, constant: 140)
        ])
    }

    private func configurePaginationButton(_ button: UIButton, symbol: String, action: Selector) {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: symbol)
        config.baseForegroundColor = AppColors.textPrimary
        button.configuration = config
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    override func loadData() { load(page: 1) }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if hasAppeared { load(page: page) }
        hasAppeared = true
    }
    private var hasAppeared = false

    // MARK: - Data

    private func load(page requestedPage: Int) {
        spinner.startAnimating()
        emptyView.isHidden = true
        ApiClient.shared.getNotifications(filter: filter, page: requestedPage, perPage: Self.perPage) { [weak self] result in
            guard let self = self else { return }
            self.spinner.stopAnimating()
            switch result {
            case .success(let data):
                self.allItems = data.notifications ?? []
                self.unreadCount = data.unreadCount ?? 0
                if let p = data.pagination {
                    self.page = p.page ?? 1
                    self.totalPages = max(1, p.totalPages ?? 1)
                    self.total = p.total ?? 0
                }
                self.renderList()
                self.renderSummary()
                self.renderPagination()
            case .failure(let error):
                self.allItems = []
                self.renderList()
                self.toast(error.message.isEmpty ? S.notificationsLoadFailed : error.message)
            }
        }
    }

    // MARK: - Tabs

    @objc private func tapAll() { selectFilter("all") }
    @objc private func tapUnread() { selectFilter("unread") }

    private func selectFilter(_ f: String) {
        guard f != filter else { return }
        filter = f
        applyTabStyles()
        load(page: 1)
    }

    private func applyTabStyles() {
        let all = filter == "all"
        tabAll.textColor = all ? AppColors.purplePrimary : AppColors.textSecondary
        tabUnread.textColor = all ? AppColors.textSecondary : AppColors.purplePrimary
        tabAll.font = all ? AppFonts.semibold(14) : AppFonts.medium(14)
        tabUnread.font = all ? AppFonts.medium(14) : AppFonts.semibold(14)
    }

    // MARK: - Summary cards

    private func renderSummary() {
        summaryRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        summaryScroll.isHidden = false
        let read = max(0, total - unreadCount)
        let important = allItems.filter(Self.isImportant).count
        summaryRow.addArrangedSubview(statCard(S.allNotifications, "\(total)", S.totalNotificationsSub, AppColors.textSecondary,
                                               icon: "bell.fill", tint: AppColors.purplePrimary, tile: AppColors.purpleLight))
        summaryRow.addArrangedSubview(statCard(S.readLabel, "\(read)", percent(read, total), AppColors.success,
                                               icon: "checkmark.circle.fill", tint: AppColors.success, tile: AppColors.successBg))
        summaryRow.addArrangedSubview(statCard(S.unreadTab, "\(unreadCount)", percent(unreadCount, total), AppColors.warning,
                                               icon: "circle.fill", tint: AppColors.warning, tile: AppColors.warningBg))
        summaryRow.addArrangedSubview(statCard(S.importantLabel, "\(important)", S.importantSub, AppColors.textSecondary,
                                               icon: "exclamationmark.circle.fill", tint: AppColors.danger, tile: AppColors.dangerBg))

        tabUnread.text = unreadCount > 0 ? "\(S.unreadTab) (\(unreadCount))" : S.unreadTab
    }

    private func statCard(_ title: String, _ value: String, _ sub: String, _ subColor: UIColor,
                          icon: String, tint: UIColor, tile tileColor: UIColor) -> UIView {
        let card = StyleKit.cardView()

        let tile = StyleKit.iconTile(color: tileColor)
        tile.constrainSize(30)
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = tint
        iconView.contentMode = .scaleAspectFit
        iconView.forAutoLayout()
        tile.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16)
        ])

        let label = UILabel.make(title, font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 1)
        let valueLabel = UILabel.make(value, font: AppFonts.bold(22), color: AppColors.textPrimary, lines: 1)
        let subLabel = UILabel.make(sub, font: AppFonts.regular(10), color: subColor, lines: 1)
        let stack = UIStackView.vertical(spacing: 4, alignment: .leading)
        stack.forAutoLayout()
        stack.addArrangedSubview(tile)
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(subLabel)
        stack.setCustomSpacing(8, after: tile)
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14))
        card.widthAnchor.constraint(equalToConstant: 150).isActive = true
        return card
    }

    private func percent(_ part: Int, _ whole: Int) -> String {
        whole <= 0 ? "0%" : String(format: "%.1f%%", 100.0 * Double(part) / Double(whole))
    }

    // MARK: - Pagination

    private func renderPagination() {
        guard total > 0 else { paginationRow.isHidden = true; return }
        paginationRow.isHidden = false
        let from = (page - 1) * Self.perPage + 1
        let to = min(page * Self.perPage, total)
        pageInfoLabel.text = S.showingRange(from, to, total)
        prevButton.isEnabled = page > 1
        prevButton.alpha = page > 1 ? 1 : 0.3
        nextButton.isEnabled = page < totalPages
        nextButton.alpha = page < totalPages ? 1 : 0.3
    }

    @objc private func prevPage() { if page > 1 { load(page: page - 1) } }
    @objc private func nextPage() { if page < totalPages { load(page: page + 1) } }

    // MARK: - List

    private func renderList() {
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        emptyView.isHidden = !allItems.isEmpty
        for (index, n) in allItems.enumerated() {
            listStack.addArrangedSubview(card(n, index: index))
        }
    }

    private func card(_ n: NotificationDTO, index: Int) -> UIView {
        let card = StyleKit.cardView()
        let unread = !(n.isRead ?? false)
        if unread { card.layer.borderColor = AppColors.purplePrimary.withAlphaComponent(0.4).cgColor }

        let meta = Self.meta(for: n)
        let tile = StyleKit.iconTile(color: meta.tile)
        tile.constrainSize(40)
        let icon = UIImageView(image: UIImage(systemName: meta.icon))
        icon.tintColor = meta.tint
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        tile.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18)
        ])
        tile.setContentHuggingPriority(.required, for: .horizontal)

        // Title row + unread dot
        let title = UILabel.make(n.title ?? "", font: AppFonts.bold(13), color: AppColors.textPrimary, lines: 0)
        let titleRow = UIStackView.horizontal(spacing: 6, alignment: .center)
        if unread {
            let dot = UIView()
            dot.backgroundColor = AppColors.purplePrimary
            dot.layer.cornerRadius = 4
            dot.forAutoLayout()
            dot.constrainSize(8)
            dot.setContentHuggingPriority(.required, for: .horizontal)
            titleRow.addArrangedSubview(dot)
        }
        titleRow.addArrangedSubview(title)

        let textStack = UIStackView.vertical(spacing: 3, alignment: .leading)
        textStack.addArrangedSubview(titleRow)
        if Self.isImportant(n) {
            let tag = StyleKit.badgeLabel()
            tag.text = S.importantTag
            tag.textColor = AppColors.danger
            tag.backgroundColor = AppColors.dangerBg
            tag.font = AppFonts.bold(10)
            tag.setContentHuggingPriority(.required, for: .horizontal)
            let tagRow = UIStackView.horizontal(spacing: 0, alignment: .leading)
            tagRow.addArrangedSubview(tag)
            tagRow.addArrangedSubview(UIView())
            textStack.addArrangedSubview(tagRow)
        }
        textStack.addArrangedSubview(UILabel.make(n.body ?? "", font: AppFonts.regular(11), color: AppColors.textSecondary, lines: 0))
        textStack.addArrangedSubview(UILabel.make(Self.relativeTime(n.createdAt), font: AppFonts.light(10), color: AppColors.textTertiary))
        if !meta.action.isEmpty {
            textStack.addArrangedSubview(UILabel.make(meta.action, font: AppFonts.medium(12), color: AppColors.purplePrimary))
        }

        let row = UIStackView.horizontal(spacing: 12, alignment: .top)
        row.forAutoLayout()
        row.addArrangedSubview(tile)
        row.addArrangedSubview(textStack)
        card.addSubview(row)
        row.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))

        card.isUserInteractionEnabled = true
        let tap = TapClosureGesture { [weak self] in self?.onItemTapped(index) }
        card.addGestureRecognizer(tap)
        return card
    }

    // MARK: - Actions

    private func onItemTapped(_ index: Int) {
        guard index >= 0 && index < allItems.count else { return }
        let n = allItems[index]
        if !(n.isRead ?? false) {
            allItems[index].isRead = true
            if unreadCount > 0 { unreadCount -= 1 }
            ApiClient.shared.markNotificationRead(id: n.id) { _ in }
            if filter == "unread" {
                allItems.remove(at: index)
                renderList()
            } else {
                renderList()
            }
            renderSummary()
        }
        navigate(n)
    }

    @objc private func markAllTapped() {
        ApiClient.shared.markAllNotificationsRead { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.toast(S.allMarkedRead)
                self.load(page: 1)
            case .failure(let error):
                self.toast(error.message.isEmpty ? S.notificationsLoadFailed : error.message)
            }
        }
    }

    /// Open the screen related to the notification's type/route. Delegates to
    /// `PushManager.navigate` so a row tap and a push tap for the same payload always land
    /// on the same screen. `fallbackToFeed` is false — we are already on the feed, so an
    /// unroutable row simply does nothing.
    private func navigate(_ n: NotificationDTO) {
        PushManager.shared.navigate(Self.route(for: n), fallbackToFeed: false)
    }

    // MARK: - Mapping / helpers

    private static func route(for n: NotificationDTO) -> PushRoute {
        PushRoute.resolve(type: n.type, route: n.data?.route, ids: n.data?.ids ?? PushIds())
    }

    private struct NotifMeta { let icon: String; let tile: UIColor; let tint: UIColor; let action: String }

    /// Icon, accent and action label per destination — keyed off the same `PushRoute` the
    /// tap uses, so the row's affordance and where it actually goes can never disagree.
    private static func meta(for n: NotificationDTO) -> NotifMeta {
        switch route(for: n) {
        case .returnDetail:
            return NotifMeta(icon: "arrow.uturn.backward", tile: AppColors.warningBg, tint: AppColors.warning, action: S.viewReturns)
        case .delivery:
            return NotifMeta(icon: "shippingbox.fill", tile: AppColors.infoBg, tint: AppColors.info, action: S.viewDelivery)
        case .products:
            return NotifMeta(icon: "archivebox.fill", tile: AppColors.infoBg, tint: AppColors.info, action: S.viewInventory)
        case .order:
            return NotifMeta(icon: "bag.fill", tile: AppColors.purpleLight, tint: AppColors.purplePrimary, action: S.viewOrder)
        case .finance:
            return NotifMeta(icon: "creditcard.fill", tile: AppColors.successBg, tint: AppColors.success, action: S.viewFinances)
        case .wallet:
            return NotifMeta(icon: "wallet.pass.fill", tile: AppColors.successBg, tint: AppColors.success, action: S.viewWallet)
        case .vas:
            return NotifMeta(icon: "antenna.radiowaves.left.and.right", tile: AppColors.infoBg, tint: AppColors.info, action: S.viewAirtime)
        case .promotion:
            return NotifMeta(icon: "tag.fill", tile: AppColors.purpleLight, tint: AppColors.purplePrimary, action: S.viewPromotion)
        case .report:
            return NotifMeta(icon: "chart.bar.fill", tile: AppColors.infoBg, tint: AppColors.info, action: S.viewReport)
        case .traders:
            return NotifMeta(icon: "person.2.fill", tile: AppColors.purpleLight, tint: AppColors.purplePrimary, action: S.viewTrader)
        case .settings, .notifications:
            return NotifMeta(icon: "bell.fill", tile: AppColors.purpleLight, tint: AppColors.purplePrimary, action: "")
        }
    }

    /// Important = any return decision, or an order whose status is Failed/Cancelled.
    ///
    /// The comparison is case-insensitive and also reads `status_key`: the push contract
    /// uses machine values ("cancelled", "out_for_delivery") while the portal uses display
    /// case, and a row built from either source has to raise the same flag.
    private static func isImportant(_ n: NotificationDTO) -> Bool {
        guard let type = n.type else { return false }
        if type == "return.decision" { return true }
        if type == "order.status" {
            return isFailedOrCancelled(n.data?.status) || isFailedOrCancelled(n.data?.statusKey)
        }
        return false
    }

    private static func isFailedOrCancelled(_ status: String?) -> Bool {
        guard let s = status?.trimmingCharacters(in: .whitespaces).lowercased() else { return false }
        return s == "failed" || s == "cancelled" || s == "canceled"
    }

    /// Recent (< 24h) → "x hours/minutes ago"; older → "dd MMM yyyy, HH:mm".
    private static func relativeTime(_ raw: String?) -> String {
        guard let date = parse(raw) else { return raw ?? "" }
        let diff = Date().timeIntervalSince(date)
        if diff >= 0 && diff < 24 * 60 * 60 {
            let hours = Int(diff / 3600)
            if hours >= 1 { return "\(hours) " + (hours == 1 ? "hour ago" : "hours ago") }
            let mins = Int(diff / 60)
            if mins >= 1 { return "\(mins) " + (mins == 1 ? "minute ago" : "minutes ago") }
            return "Just now"
        }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "dd MMM yyyy, HH:mm"
        return out.string(from: date)
    }

    private static func parse(_ raw: String?) -> Date? {
        guard let raw = raw, !raw.isEmpty else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return f.date(from: raw)
    }
}

/// Lightweight tap gesture that runs a closure (avoids per-cell target/action plumbing).
final class TapClosureGesture: UITapGestureRecognizer {
    private let handler: () -> Void
    init(handler: @escaping () -> Void) {
        self.handler = handler
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(fire))
    }
    @objc private func fire() { handler() }
}
