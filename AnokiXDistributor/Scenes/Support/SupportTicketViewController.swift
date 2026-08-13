import UIKit

/// One support ticket (New-Design/Support Centre/4.Open-Ticket.png, 5.Closed-Ticket.png).
///
/// The conversation reads as a chat thread: our messages on the right in green, support
/// on the left in white, and status notes centred. An open ticket gets the composer with
/// Close ticket / Send reply; a closed one replaces it with the closing notice, since
/// neither action is available any more.
///
/// Replying and closing both answer with the ticket in its new state, so the thread is
/// repainted from the response rather than re-fetched.
final class SupportTicketViewController: BaseSecondaryViewController,
                                         UICollectionViewDataSource {

    /// The number and subject come from the row that was tapped so the header is right
    /// before the detail call lands — otherwise the screen opens with an empty title.
    override var screenTitle: String {
        let number = (seed.ticketNumber ?? "").trimmingCharacters(in: .whitespaces)
        return number.isEmpty ? S.supportCentre : number
    }
    override var screenSubtitle: String? {
        let subject = (seed.subject ?? "").trimmingCharacters(in: .whitespaces)
        return subject.isEmpty ? nil : subject
    }

    private let seed: SupportOverviewData.Ticket
    private var ticket: SupportOverviewData.Ticket?
    private var messages: [SupportOverviewData.Message] = []

    /// Always one column: AdaptiveGridLayout goes 2–3 wide on iPad, which would break a
    /// conversation into parallel columns. Bubbles size themselves within the row.
    private let collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: SupportTicketViewController.threadLayout())

    private static func threadLayout() -> UICollectionViewCompositionalLayout {
        let item = NSCollectionLayoutItem(layoutSize: .init(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(64)))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: .init(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(64)), subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        return UICollectionViewCompositionalLayout(section: section)
    }

    private let statusBadge = StyleKit.badgeLabel()
    private let openedLabel = UILabel.make(font: AppFonts.regular(12), color: AppColors.textSecondary)
    private let priorityBadge = StyleKit.badgeLabel()

    private let composer = UIStackView.vertical(spacing: 10, alignment: .fill)
    private let replyView = UITextView()
    private let replyPlaceholder = UILabel.make(S.ticketReplyHint, font: AppFonts.regular(14),
                                                color: AppColors.textSecondary, lines: 0)
    private let sendButton = UIButton(type: .system)
    private let closedNotice = PaddingLabel(insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))

    init(ticket: SupportOverviewData.Ticket) {
        self.seed = ticket
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func setupContent(in container: UIView) {
        let statusStrip = ListScreenLayout.surfaceSection(
            [statusRow()], insets: UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16))

        collectionView.dataSource = self
        collectionView.backgroundColor = AppColors.background
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .interactive
        collectionView.contentInset = UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 0)
        collectionView.register(TicketMessageCell.self,
                                forCellWithReuseIdentifier: TicketMessageCell.reuseIdentifier)

        buildComposer()
        buildClosedNotice()

        let footer = UIStackView.vertical(spacing: 0, alignment: .fill)
        footer.addArrangedSubview(composer)
        footer.addArrangedSubview(closedNotice)
        footer.backgroundColor = AppColors.surface
        footer.forAutoLayout()

        let divider = ListScreenLayout.hairline()
        divider.forAutoLayout()
        statusStrip.forAutoLayout()
        collectionView.forAutoLayout()
        container.addSubviews(statusStrip, divider, collectionView, footer)

        NSLayoutConstraint.activate([
            statusStrip.topAnchor.constraint(equalTo: container.topAnchor),
            statusStrip.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            statusStrip.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.topAnchor.constraint(equalTo: statusStrip.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: footer.topAnchor),
            footer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            // Rides above the keyboard so the composer is never behind it.
            footer.bottomAnchor.constraint(equalTo: container.keyboardLayoutGuide.topAnchor)
        ])

        render(seed)   // paint what the list already knew, then refresh from the detail call
    }

    private func statusRow() -> UIView {
        statusBadge.font = AppFonts.regular(AppMetrics.textMicro)
        statusBadge.setContentHuggingPriority(.required, for: .horizontal)
        priorityBadge.font = AppFonts.regular(AppMetrics.textMicro)
        priorityBadge.setContentHuggingPriority(.required, for: .horizontal)
        priorityBadge.isHidden = true

        let row = UIStackView.horizontal(spacing: 10, alignment: .center)
        row.addArrangedSubview(statusBadge)
        row.addArrangedSubview(openedLabel)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(priorityBadge)
        return row
    }

    private func buildComposer() {
        replyView.font = AppFonts.regular(14)
        replyView.textColor = AppColors.textPrimary
        replyView.backgroundColor = AppColors.surfaceVariant
        replyView.layer.cornerRadius = AppMetrics.radiusMD
        replyView.layer.borderWidth = 1
        replyView.layer.borderColor = AppColors.border.cgColor
        replyView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        replyView.delegate = self
        replyView.constrainHeight(84)

        // UITextView has no placeholder, so a label rides behind it and hides on input.
        replyPlaceholder.forAutoLayout()
        replyView.addSubview(replyPlaceholder)
        NSLayoutConstraint.activate([
            replyPlaceholder.topAnchor.constraint(equalTo: replyView.topAnchor, constant: 12),
            replyPlaceholder.leadingAnchor.constraint(equalTo: replyView.leadingAnchor, constant: 15),
            replyPlaceholder.trailingAnchor.constraint(equalTo: replyView.trailingAnchor, constant: -15)
        ])

        let closeButton = UIButton(type: .system)
        StyleKit.styleOutlinedButton(closeButton, fontSize: 14)
        closeButton.setTitle(S.ticketClose, for: .normal)
        closeButton.constrainHeight(44)
        closeButton.addAction(UIAction { [weak self] _ in self?.confirmClose() }, for: .touchUpInside)

        StyleKit.stylePrimaryButton(sendButton, fontSize: 14)
        sendButton.setTitle(S.ticketSendReply, for: .normal)
        sendButton.constrainHeight(44)
        sendButton.addAction(UIAction { [weak self] _ in self?.sendReply() }, for: .touchUpInside)

        let buttons = UIStackView.horizontal(spacing: 12, alignment: .fill)
        buttons.distribution = .fillEqually
        buttons.addArrangedSubview(closeButton)
        buttons.addArrangedSubview(sendButton)

        composer.isLayoutMarginsRelativeArrangement = true
        composer.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        composer.addArrangedSubview(replyView)
        composer.addArrangedSubview(buttons)
    }

    private func buildClosedNotice() {
        closedNotice.text = S.ticketClosedNotice
        closedNotice.font = AppFonts.regular(13)
        closedNotice.textColor = AppColors.textSecondary
        closedNotice.numberOfLines = 0
        closedNotice.isHidden = true
    }

    override func loadData() {
        ApiClient.shared.getSupportTicket(id: seed.id ?? "") { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                if let ticket = data.ticket { self.render(ticket) }
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    // MARK: Rendering

    private func render(_ data: SupportOverviewData.Ticket) {
        ticket = data

        statusBadge.text = data.statusLabel
        statusBadge.textColor = data.open ? AppColors.danger : AppColors.success
        statusBadge.backgroundColor = data.open ? AppColors.dangerBg : AppColors.successBg

        openedLabel.text = S.ticketOpened(data.openedLabel)

        // Priority only earns a badge when it is out of the ordinary.
        let priority = (data.priority ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        let notable = priority == "high" || priority == "urgent"
        priorityBadge.isHidden = !notable
        if notable {
            priorityBadge.text = priority.prefix(1).uppercased() + priority.dropFirst()
            priorityBadge.textColor = priority == "urgent" ? AppColors.danger : AppColors.warning
            priorityBadge.backgroundColor = priority == "urgent" ? AppColors.dangerBg : AppColors.warningBg
        }

        messages = data.messages ?? []
        collectionView.reloadData()
        if !messages.isEmpty {
            // The newest message is the one worth seeing on arrival.
            collectionView.scrollToItem(at: IndexPath(item: messages.count - 1, section: 0),
                                        at: .bottom, animated: false)
        }

        composer.isHidden = !data.open
        closedNotice.isHidden = data.open
    }

    // MARK: Actions

    private func sendReply() {
        let message = (replyView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            toast(S.errReplyEmpty)
            return
        }

        sendButton.isEnabled = false
        sendButton.setTitle(S.sendingReply, for: .normal)
        ApiClient.shared.replySupportTicket(ticketId: seed.id ?? "", message: message) { [weak self] result in
            guard let self = self else { return }
            self.sendButton.isEnabled = true
            self.sendButton.setTitle(S.ticketSendReply, for: .normal)
            switch result {
            case .success(let data):
                self.replyView.text = ""
                self.replyPlaceholder.isHidden = false
                self.replyView.resignFirstResponder()
                // The response already carries the appended message.
                if let ticket = data.ticket { self.render(ticket) }
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    private func confirmClose() {
        let alert = UIAlertController(title: S.ticketCloseTitle,
                                      message: S.ticketCloseMessage(ticket?.subject ?? ""),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: S.ticketClose, style: .destructive) { [weak self] _ in
            self?.closeTicket()
        })
        present(alert, animated: true)
    }

    private func closeTicket() {
        ApiClient.shared.closeSupportTicket(ticketId: seed.id ?? "") { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                self.replyView.resignFirstResponder()
                if let ticket = data.ticket { self.render(ticket) }
                self.successBanner(S.ticketClosedMessage)
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    // MARK: Collection view

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        messages.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: TicketMessageCell.reuseIdentifier, for: indexPath) as? TicketMessageCell else {
            return UICollectionViewCell()
        }
        cell.configure(messages[indexPath.item])
        return cell
    }
}

// MARK: - Placeholder handling

extension SupportTicketViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        replyPlaceholder.isHidden = !(textView.text ?? "").isEmpty
    }
}

// MARK: - Message bubble

/// One entry in a ticket conversation. Three shapes come out of one cell: our own
/// messages right-aligned in a green bubble, a support agent's left-aligned in white with
/// their name, and a system note ("Closed by the merchant.") centred as a small pill with
/// no author or timestamp.
final class TicketMessageCell: UICollectionViewCell {

    static let reuseIdentifier = "TicketMessageCell"

    private let bubble = UIView()
    private let authorLabel = UILabel()
    private let bodyLabel = UILabel()
    private let timeLabel = UILabel()

    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    private var centreConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        build()
    }

    private func build() {
        backgroundColor = .clear

        authorLabel.font = AppFonts.bold(11)
        authorLabel.textColor = AppColors.purplePrimary
        bodyLabel.font = AppFonts.regular(13)
        bodyLabel.numberOfLines = 0
        timeLabel.font = AppFonts.regular(10)
        timeLabel.textColor = AppColors.textTertiary
        timeLabel.textAlignment = .right

        let stack = UIStackView.vertical(spacing: 3, alignment: .fill)
        stack.addArrangedSubview(authorLabel)
        stack.addArrangedSubview(bodyLabel)
        stack.addArrangedSubview(timeLabel)
        stack.forAutoLayout()
        bubble.addSubview(stack)
        stack.pinEdges(to: bubble, insets: UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))

        bubble.layer.cornerRadius = 12
        bubble.forAutoLayout()
        contentView.addSubview(bubble)

        leadingConstraint = bubble.leadingAnchor.constraint(equalTo: contentView.leadingAnchor)
        trailingConstraint = bubble.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        centreConstraint = bubble.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)

        NSLayoutConstraint.activate([
            bubble.topAnchor.constraint(equalTo: contentView.topAnchor),
            bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            // A bubble never spans the full width — the gap is what shows who spoke.
            bubble.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.82),
            bubble.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor),
            bubble.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor)
        ])
    }

    func configure(_ message: SupportOverviewData.Message) {
        bodyLabel.text = message.body

        leadingConstraint.isActive = false
        trailingConstraint.isActive = false
        centreConstraint.isActive = false

        if message.isSystem {
            centreConstraint.isActive = true
            bubble.backgroundColor = AppColors.surfaceVariant
            bubble.layer.borderWidth = 1
            bubble.layer.borderColor = AppColors.border.cgColor
            bodyLabel.textColor = AppColors.textSecondary
            authorLabel.isHidden = true
            // A status note is not part of the conversation, so it carries no timestamp.
            timeLabel.isHidden = true
            return
        }

        bodyLabel.textColor = AppColors.textPrimary
        timeLabel.isHidden = false
        timeLabel.text = message.timeLabel

        if message.isMine {
            trailingConstraint.isActive = true
            bubble.backgroundColor = AppColors.successBg
            bubble.layer.borderWidth = 0
            authorLabel.isHidden = true
        } else {
            leadingConstraint.isActive = true
            bubble.backgroundColor = AppColors.surface
            bubble.layer.borderWidth = 1
            bubble.layer.borderColor = AppColors.border.cgColor
            // Only an agent's message needs a name — our own are obviously ours.
            let name = (message.authorName ?? "").trimmingCharacters(in: .whitespaces)
            authorLabel.isHidden = name.isEmpty
            authorLabel.text = name
        }
    }
}
