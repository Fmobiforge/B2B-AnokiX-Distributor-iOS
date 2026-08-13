import UIKit

/// Support Centre (New-Design/Support Centre/1.Dashboard.png).
///
/// `GET support/overview` answers with everything: which contact channels are switched
/// on, the help-article catalogue, and this account's tickets. Contact cards are built
/// from the enabled channels only — a disabled channel gets no card rather than a dead
/// one — and the help section stays hidden until there is something to show.
///
/// The web page's System Health and Knowledge Base panels are not ported; the
/// requirements mark both as unused, and on a phone they would push the two things that
/// matter below the fold.
final class SupportViewController: BaseSecondaryViewController {

    override var screenTitle: String { S.supportCentre }
    override var screenSubtitle: String? { S.supportSubtitle }

    /// Wait for a pause in typing before spending a request on the keyword.
    private static let searchDebounce: TimeInterval = 0.4

    private var stack: UIStackView!
    private let channelsStack = UIStackView.vertical(spacing: 10, alignment: .fill)
    private let hoursLabel = UILabel.make(font: AppFonts.regular(12), color: AppColors.textSecondary)
    private let articlesSection = UIStackView.vertical(spacing: 10, alignment: .fill)
    private let articlesTitle = UILabel.make(S.supportPopularTopics, font: AppFonts.bold(16),
                                             color: AppColors.topTitle)
    private let articlesStack = UIStackView.vertical(spacing: 10, alignment: .fill)
    private let articlesEmpty = UILabel.make(font: AppFonts.regular(AppMetrics.textBody),
                                             color: AppColors.textSecondary, align: .center, lines: 0)
    private let ticketsStack = UIStackView.vertical(spacing: 10, alignment: .fill)
    private let ticketsEmpty = UILabel.make(S.supportTicketsEmpty,
                                            font: AppFonts.regular(AppMetrics.textBody),
                                            color: AppColors.textSecondary, align: .center, lines: 0)

    private var overview: SupportOverviewData?
    private var search = ""
    private var searchWorkItem: DispatchWorkItem?

    override func setupContent(in container: UIView) {
        stack = makeScrollStack(in: container, spacing: 14)

        let searchBar = SearchBarView(placeholder: S.supportSearchHint, height: 44)
        searchBar.onChange = { [weak self] text in self?.searchChanged(text) }
        stack.addArrangedSubview(searchBar)

        stack.addArrangedSubview(channelsStack)

        hoursLabel.isHidden = true
        stack.addArrangedSubview(hoursLabel)

        articlesSection.addArrangedSubview(articlesTitle)
        articlesSection.addArrangedSubview(articlesStack)
        articlesSection.addArrangedSubview(articlesEmpty)
        articlesSection.isHidden = true
        stack.addArrangedSubview(articlesSection)

        stack.addArrangedSubview(ticketsHeader())
        stack.addArrangedSubview(ticketsStack)
        ticketsEmpty.isHidden = true
        stack.addArrangedSubview(ticketsEmpty)
    }

    private func ticketsHeader() -> UIView {
        let title = UILabel.make(S.supportMyTickets, font: AppFonts.bold(16), color: AppColors.topTitle)

        let newTicket = UIButton(type: .system)
        newTicket.setTitle(S.supportNewTicket, for: .normal)
        newTicket.setTitleColor(AppColors.purplePrimary, for: .normal)
        newTicket.titleLabel?.font = AppFonts.bold(13)
        newTicket.setContentHuggingPriority(.required, for: .horizontal)
        newTicket.addAction(UIAction { [weak self] _ in self?.openCreateTicket() }, for: .touchUpInside)

        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.addArrangedSubview(title)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(newTicket)
        return row
    }

    override func loadData() {
        ApiClient.shared.getSupportOverview { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                self.overview = data
                self.renderChannels()
                self.renderTickets()
                if self.search.isEmpty {
                    self.renderArticles(data.popular, searching: false)
                }
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // A reply or a close on the detail screen changes what the list should say.
        if overview != nil { loadData() }
    }

    // MARK: Contact channels

    /// One card per enabled channel, in the order the web page lists them. Nothing is
    /// rendered for a channel the API reports as off, so the page never shows a control
    /// that cannot do anything.
    private func renderChannels() {
        channelsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let channels = overview?.channels else { return }

        if let whatsapp = channels.whatsapp, whatsapp.enabled == true {
            let display = (whatsapp.display ?? "").trimmingCharacters(in: .whitespaces)
            channelsStack.addArrangedSubview(channelCard(
                icon: "ic_whatsapp", title: S.channelWhatsapp,
                subtitle: display.isEmpty ? S.channelWhatsappSub : display,
                tint: AppColors.success, tile: AppColors.successBg) { [weak self] in
                    self?.openWhatsApp(whatsapp)
                })
        }
        if channels.callback?.enabled == true {
            channelsStack.addArrangedSubview(channelCard(
                icon: "ic_phone", title: S.channelCallback, subtitle: S.channelCallbackSub,
                tint: AppColors.purplePrimary, tile: AppColors.purpleLight) { [weak self] in
                    self?.openCallbackRequest()
                })
        }
        if channels.tickets?.enabled == true {
            channelsStack.addArrangedSubview(channelCard(
                icon: "ic_document", title: S.channelTicket, subtitle: S.channelTicketSub,
                tint: AppColors.purplePrimary, tile: AppColors.purpleLight) { [weak self] in
                    self?.openCreateTicket()
                })
        }
        if let phone = channels.phone, phone.enabled == true,
           let number = phone.number, !number.trimmingCharacters(in: .whitespaces).isEmpty {
            channelsStack.addArrangedSubview(channelCard(
                icon: "ic_headset", title: S.channelPhone, subtitle: number,
                tint: AppColors.info, tile: AppColors.infoBg) { [weak self] in
                    self?.open("tel:\(number.trimmingCharacters(in: .whitespaces))",
                               failure: S.errNoDialer)
                })
        }
        if let email = channels.email, email.enabled == true,
           let address = email.address, !address.trimmingCharacters(in: .whitespaces).isEmpty {
            channelsStack.addArrangedSubview(channelCard(
                icon: "ic_email", title: S.channelEmail, subtitle: address,
                tint: AppColors.info, tile: AppColors.infoBg) { [weak self] in
                    self?.open("mailto:\(address.trimmingCharacters(in: .whitespaces))",
                               failure: S.errNoEmailApp)
                })
        }
        if channels.liveChat?.enabled == true {
            channelsStack.addArrangedSubview(channelCard(
                icon: "ic_chat", title: S.channelLiveChat, subtitle: S.channelLiveChatSub,
                tint: AppColors.warning, tile: AppColors.warningBg) { [weak self] in
                    self?.toast(S.featureComingSoon(S.channelLiveChat))
                })
        }

        let hours = (channels.hours ?? "").trimmingCharacters(in: .whitespaces)
        hoursLabel.isHidden = hours.isEmpty
        hoursLabel.text = hours.isEmpty ? nil : S.supportHours(hours)
    }

    /// One way of reaching support — tinted glyph, name, detail, chevron.
    private func channelCard(icon: String, title: String, subtitle: String,
                             tint: UIColor, tile: UIColor,
                             action: @escaping () -> Void) -> UIView {
        let card = TappableCardView(action: action)

        let iconTile = StyleKit.iconTile(color: tile)
        iconTile.constrainSize(40)
        let glyph = UIImageView(image: AppIcons.symbol(icon))
        glyph.tintColor = tint
        glyph.contentMode = .scaleAspectFit
        glyph.forAutoLayout()
        iconTile.addSubview(glyph)
        NSLayoutConstraint.activate([
            glyph.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            glyph.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor),
            glyph.widthAnchor.constraint(equalToConstant: 20),
            glyph.heightAnchor.constraint(equalToConstant: 20)
        ])

        let titleLabel = UILabel.make(title, font: AppFonts.bold(14), color: AppColors.topTitle)
        let subtitleLabel = UILabel.make(subtitle, font: AppFonts.regular(12),
                                         color: AppColors.textSecondary)
        subtitleLabel.lineBreakMode = .byTruncatingTail
        let text = UIStackView.vertical(spacing: 2, alignment: .fill)
        text.addArrangedSubview(titleLabel)
        text.addArrangedSubview(subtitleLabel)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = AppColors.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.constrainSize(16)
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.isUserInteractionEnabled = false
        row.addArrangedSubview(iconTile)
        row.addArrangedSubview(text)
        row.addArrangedSubview(chevron)
        row.forAutoLayout()
        card.addSubview(row)
        row.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return card
    }

    // MARK: Help articles

    private func searchChanged(_ text: String) {
        let keyword = text.trimmingCharacters(in: .whitespaces)
        guard keyword != search else { return }
        searchWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.search = keyword
            if keyword.isEmpty {
                // Back to the popular list rather than an empty result set.
                self.renderArticles(self.overview?.popular, searching: false)
            } else {
                self.searchArticles(keyword)
            }
        }
        searchWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.searchDebounce, execute: work)
    }

    private func searchArticles(_ keyword: String) {
        ApiClient.shared.searchSupportArticles(query: keyword) { [weak self] result in
            guard let self = self else { return }
            // A slow response for an abandoned keyword must not replace the current one.
            guard keyword == self.search else { return }
            switch result {
            case .success(let data):
                self.renderArticles(data.articles, searching: true)
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    /// - Parameter searching: true when showing search results — the section then keeps
    ///   its place and explains a miss, instead of silently disappearing.
    private func renderArticles(_ articles: [SupportOverviewData.Article]?, searching: Bool) {
        let items = articles ?? []

        // With nothing typed and no popular articles there is nothing worth a heading.
        guard searching || !items.isEmpty else {
            articlesSection.isHidden = true
            return
        }
        articlesSection.isHidden = false
        articlesTitle.text = searching ? S.supportSearchResults(search) : S.supportPopularTopics

        articlesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for article in items {
            articlesStack.addArrangedSubview(articleCard(article))
        }

        articlesEmpty.isHidden = !items.isEmpty
        articlesEmpty.text = items.isEmpty ? S.supportSearchEmpty(search) : nil
    }

    private func articleCard(_ article: SupportOverviewData.Article) -> UIView {
        let card = TappableCardView { [weak self] in self?.openArticle(article) }

        let title = UILabel.make(article.title, font: AppFonts.bold(14),
                                 color: AppColors.topTitle, lines: 2)
        let text = UIStackView.vertical(spacing: 3, alignment: .fill)
        text.addArrangedSubview(title)
        let excerpt = (article.excerpt ?? "").trimmingCharacters(in: .whitespaces)
        if !excerpt.isEmpty {
            text.addArrangedSubview(UILabel.make(excerpt, font: AppFonts.regular(12),
                                                 color: AppColors.textSecondary, lines: 2))
        }

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = AppColors.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.constrainSize(16)
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView.horizontal(spacing: 10, alignment: .center)
        row.isUserInteractionEnabled = false
        row.addArrangedSubview(text)
        row.addArrangedSubview(chevron)
        row.forAutoLayout()
        card.addSubview(row)
        row.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return card
    }

    private func openArticle(_ article: SupportOverviewData.Article) {
        guard let url = article.url, !url.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        open(url, failure: S.errNoBrowser)
    }

    // MARK: Tickets

    private func renderTickets() {
        ticketsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let tickets = overview?.tickets ?? []
        ticketsEmpty.isHidden = !tickets.isEmpty
        for ticket in tickets {
            ticketsStack.addArrangedSubview(ticketCard(ticket))
        }
    }

    /// Number + status badge and last activity on the top line, subject under it, then
    /// who the ticket is waiting on.
    private func ticketCard(_ ticket: SupportOverviewData.Ticket) -> UIView {
        let card = TappableCardView { [weak self] in self?.openTicket(ticket) }

        let number = UILabel.make(ticket.ticketNumber, font: AppFonts.bold(12),
                                  color: AppColors.textSecondary)
        number.setContentHuggingPriority(.required, for: .horizontal)

        let badge = StyleKit.badgeLabel()
        badge.text = ticket.statusLabel
        badge.font = AppFonts.regular(AppMetrics.textMicro)
        badge.textColor = ticket.open ? AppColors.danger : AppColors.success
        badge.backgroundColor = ticket.open ? AppColors.dangerBg : AppColors.successBg
        badge.setContentHuggingPriority(.required, for: .horizontal)

        let time = UILabel.make(ticket.lastActivityLabel, font: AppFonts.regular(11),
                                color: AppColors.textTertiary, align: .right)

        let topRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        topRow.addArrangedSubview(number)
        topRow.addArrangedSubview(badge)
        topRow.addArrangedSubview(time)

        let subject = UILabel.make(ticket.subject, font: AppFonts.bold(14),
                                   color: AppColors.topTitle, lines: 2)
        let state = UILabel.make(stateLabel(ticket), font: AppFonts.regular(12),
                                 color: AppColors.textSecondary)

        let stack = UIStackView.vertical(spacing: 4, alignment: .fill)
        stack.addArrangedSubview(topRow)
        stack.addArrangedSubview(subject)
        stack.addArrangedSubview(state)
        stack.setCustomSpacing(6, after: topRow)
        stack.isUserInteractionEnabled = false
        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return card
    }

    /// Who the ticket is waiting on — the line the web row shows under the subject.
    private func stateLabel(_ ticket: SupportOverviewData.Ticket) -> String {
        guard ticket.open else { return S.ticketResolved }
        return ticket.isWaitingForSupport ? S.ticketWaitingSupport : S.ticketSupportReplied
    }

    private func openTicket(_ ticket: SupportOverviewData.Ticket) {
        let detail = SupportTicketViewController(ticket: ticket)
        navigationController?.pushViewController(detail, animated: true)
    }

    // MARK: Actions

    private func openCallbackRequest() {
        let sheet = SupportRequestViewController(mode: .callback, categories: [])
        sheet.onSubmitted = { [weak self] message in
            self?.toast(message)
            self?.loadData()   // the new ticket belongs in the list straight away
        }
        present(sheet, animated: true)
    }

    private func openCreateTicket() {
        let sheet = SupportRequestViewController(mode: .ticket,
                                                 categories: overview?.categories ?? [])
        sheet.onSubmitted = { [weak self] message in
            self?.toast(message)
            self?.loadData()
        }
        present(sheet, animated: true)
    }

    /// Opens the conversation in the WhatsApp app rather than Safari: the app's own
    /// scheme is tried first, and only if WhatsApp is not installed do we fall back to
    /// the wa.me link (which universal-links into the app anyway when it is).
    private func openWhatsApp(_ whatsapp: SupportOverviewData.Whatsapp) {
        let link = (whatsapp.link ?? "").trimmingCharacters(in: .whitespaces)
        guard !link.isEmpty else {
            toast(S.errNoWhatsapp)
            return
        }
        if let scheme = whatsappScheme(from: link), UIApplication.shared.canOpenURL(scheme) {
            UIApplication.shared.open(scheme)
            return
        }
        open(link, failure: S.errNoWhatsapp)
    }

    /// Rewrites `https://wa.me/<number>?text=…` as `whatsapp://send?phone=<number>&text=…`.
    private func whatsappScheme(from link: String) -> URL? {
        guard let components = URLComponents(string: link) else { return nil }
        let number = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !number.isEmpty else { return nil }
        var scheme = URLComponents()
        scheme.scheme = "whatsapp"
        scheme.host = "send"
        var items = [URLQueryItem(name: "phone", value: number)]
        if let text = components.queryItems?.first(where: { $0.name == "text" })?.value {
            items.append(URLQueryItem(name: "text", value: text))
        }
        scheme.queryItems = items
        return scheme.url
    }

    private func open(_ urlString: String, failure: String) {
        guard let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) else {
            toast(failure)
            return
        }
        UIApplication.shared.open(url)
    }
}

// MARK: - Tappable card

/// A card that behaves as a button. `UIControl` rather than a tap gesture so it picks up
/// the standard highlight and accessibility treatment.
final class TappableCardView: UIControl {

    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)
        StyleKit.styleCard(self)
        addAction(UIAction { [weak self] _ in self?.action() }, for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }
}
