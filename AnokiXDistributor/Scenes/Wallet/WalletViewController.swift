import UIKit
import SafariServices

/// anokiX wallet (drawer › anokiX wallet, between Finances and Airtime & VAS).
/// Mobile adaptation of the web layout in newDesign/wallet/wallet02.png. Parity with the
/// Android WalletActivity.
///
/// Live data comes from `GET api/common/wallet`: the balance hero, the settlement account
/// number and the Recent Transactions list. Top Up Wallet opens the amount sheet
/// (wallet03.png) and drives the real PayCloud flow — `topup/create` returns a checkout URL
/// shown in an SFSafariViewController, and on the way back the app polls `topup/status`
/// until the wallet is credited.
///
/// The remaining panels (quick actions, recipients, loan offers, statements, microfinance)
/// are the web page's placeholder content — there is no API behind them yet, so they use
/// sample data and answer taps with a "coming soon" note.
final class WalletViewController: BaseSecondaryViewController {

    override var screenTitle: String { S.walletScreenTitle }
    override var screenSubtitle: String? { S.walletScreenSubtitle }

    /// Where PayCloud sends the user back; matches the URL scheme in Info.plist.
    private static let returnURL = "anokix://wallet"
    /// Transactions shown before "View all" expands the list.
    private static let txnPreviewCount = 6
    private static let topupMin: Double = 1
    private static let topupMax: Double = 500_000

    // Data + view state
    private var wallet: WalletData?
    private var balanceHidden = false
    private var showAllTransactions = false
    private var pendingOrderNo: String?
    private weak var checkoutController: SFSafariViewController?

    // UI
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView.vertical(spacing: 12, alignment: .fill)
    private let totalBalanceLabel = UILabel.make("—", font: AppFonts.bold(30), color: .white)
    private let availableBalanceLabel = UILabel.make("—", font: AppFonts.bold(16), color: .white)
    private let pendingBalanceLabel = UILabel.make("—", font: AppFonts.bold(16), color: .white)
    private let asOfLabel = UILabel.make("", font: AppFonts.light(11), color: UIColor.white.withAlphaComponent(0.8))
    private let hideIcon = UIImageView(image: AppIcons.symbol("ic_eye"))
    private let refreshIcon = UIImageView(image: AppIcons.symbol("ic_refresh"))
    private let noticeLabel = PaddingLabel(insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
    private let settlementAccountLabel = UILabel.make("—", font: AppFonts.regular(12), color: AppColors.textSecondary)
    private let settlementAvailableLabel = UILabel.make("—", font: AppFonts.bold(12), color: AppColors.success)
    private let settlementNextLabel = UILabel.make("", font: AppFonts.regular(12), color: AppColors.textSecondary)
    private let txnStack = UIStackView.vertical(spacing: 0, alignment: .fill)
    private let txnEmptyLabel = UILabel.make(S.walletNoTransactionsHint, font: AppFonts.regular(12),
                                             color: AppColors.textSecondary, align: .center)
    private let txnViewAllButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)

    // MARK: - Setup

    override func setupContent(in container: UIView) {
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = AppColors.background
        scrollView.forAutoLayout()
        container.addSubview(scrollView)

        let refresh = UIRefreshControl()
        refresh.tintColor = AppColors.purplePrimary
        refresh.addTarget(self, action: #selector(handlePullToRefresh), for: .valueChanged)
        scrollView.refreshControl = refresh

        contentStack.forAutoLayout()
        scrollView.addSubview(contentStack)

        contentStack.addArrangedSubview(buildBalanceCard())
        contentStack.addArrangedSubview(buildNotice())
        contentStack.addArrangedSubview(buildSettlementCard())
        contentStack.addArrangedSubview(buildQuickActionsCard())
        contentStack.addArrangedSubview(buildRecipientsCard())
        contentStack.addArrangedSubview(buildTransactionsCard())
        contentStack.addArrangedSubview(buildLoanOffersCard())
        contentStack.addArrangedSubview(buildStatementsCard())
        contentStack.addArrangedSubview(buildMicrofinanceCard())
        contentStack.addArrangedSubview(buildNeedFundsCard())

        spinner.hidesWhenStopped = true
        spinner.forAutoLayout()
        container.addSubview(spinner)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -12),

            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: container.topAnchor, constant: 160)
        ])

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleTopupReturn),
            name: WalletViewController.topupReturnNotification, object: nil)
    }

    override func loadData() {
        spinner.startAnimating()
        load(forceRefresh: false)
    }

    // MARK: - Balance hero

    private func buildBalanceCard() -> UIView {
        let card = GradientCardView(colors: [UIColor(hex: 0x7C3AED), UIColor(hex: 0x5B21B6)])
        card.layer.cornerRadius = AppMetrics.radiusXL

        let title = UILabel.make(S.walletTotalBalance, font: AppFonts.regular(12),
                                 color: UIColor.white.withAlphaComponent(0.9))
        let refreshButton = glassButton(icon: refreshIcon, action: #selector(refreshTapped))
        let hideButton = glassButton(icon: hideIcon, action: #selector(hideTapped))

        let topRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        topRow.addArrangedSubview(title)
        topRow.addArrangedSubview(UIView())
        topRow.addArrangedSubview(refreshButton)
        topRow.addArrangedSubview(hideButton)

        let balanceRow = UIStackView.horizontal(spacing: 12, alignment: .top)
        balanceRow.distribution = .fillEqually
        balanceRow.addArrangedSubview(balanceColumn(S.walletAvailableBalance, availableBalanceLabel))
        balanceRow.addArrangedSubview(balanceColumn(S.walletPendingBalance, pendingBalanceLabel))

        let topUpButton = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .white
        config.baseForegroundColor = AppColors.purplePrimary
        config.cornerStyle = .medium
        config.image = UIImage(systemName: "plus")
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16)
        config.title = S.walletTopUp
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.bold(14); return out
        }
        topUpButton.configuration = config
        topUpButton.addTarget(self, action: #selector(topUpTapped), for: .touchUpInside)

        let divider = UIView()
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        divider.constrainHeight(1)

        let brand = UILabel.make(S.walletFooterBrand, font: AppFonts.regular(10),
                                 color: UIColor.white.withAlphaComponent(0.85))
        let imbChip = PaddingLabel(insets: UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
        imbChip.text = S.walletImb
        imbChip.font = AppFonts.bold(10)
        imbChip.textColor = .white
        imbChip.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        imbChip.layer.cornerRadius = AppMetrics.radiusSM
        imbChip.layer.masksToBounds = true
        imbChip.setContentHuggingPriority(.required, for: .horizontal)

        let footer = UIStackView.horizontal(spacing: 8, alignment: .center)
        footer.addArrangedSubview(brand)
        footer.addArrangedSubview(UIView())
        footer.addArrangedSubview(imbChip)

        let stack = UIStackView.vertical(spacing: 0, alignment: .fill)
        stack.forAutoLayout()
        stack.addArrangedSubview(topRow)
        stack.setCustomSpacing(6, after: topRow)
        stack.addArrangedSubview(totalBalanceLabel)
        stack.setCustomSpacing(14, after: totalBalanceLabel)
        stack.addArrangedSubview(balanceRow)
        stack.setCustomSpacing(10, after: balanceRow)
        stack.addArrangedSubview(asOfLabel)
        stack.setCustomSpacing(14, after: asOfLabel)
        stack.addArrangedSubview(topUpButton)
        stack.setCustomSpacing(16, after: topUpButton)
        stack.addArrangedSubview(divider)
        stack.setCustomSpacing(12, after: divider)
        stack.addArrangedSubview(footer)

        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18))
        return card
    }

    private func balanceColumn(_ title: String, _ value: UILabel) -> UIView {
        let caption = UILabel.make(title, font: AppFonts.regular(11),
                                   color: UIColor.white.withAlphaComponent(0.85))
        let column = UIStackView.vertical(spacing: 3, alignment: .leading)
        column.addArrangedSubview(caption)
        column.addArrangedSubview(value)
        return column
    }

    private func glassButton(icon: UIImageView, action: Selector) -> UIView {
        let button = UIControl()
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = AppMetrics.radiusSM
        button.constrainSize(32)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.addTarget(self, action: action, for: .touchUpInside)

        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        button.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16)
        ])
        return button
    }

    /// Non-active wallet / stale balance banner; hidden until there is something to say.
    private func buildNotice() -> UIView {
        noticeLabel.font = AppFonts.regular(12)
        noticeLabel.textColor = AppColors.warning
        noticeLabel.backgroundColor = AppColors.warningBg
        noticeLabel.numberOfLines = 0
        noticeLabel.layer.cornerRadius = AppMetrics.radiusMD
        noticeLabel.layer.masksToBounds = true
        noticeLabel.isHidden = true
        return noticeLabel
    }

    // MARK: - Settlement account

    private func buildSettlementCard() -> UIView {
        let card = StyleKit.cardView()

        let title = UILabel.make(S.walletSettlementAccount, font: AppFonts.bold(16), color: AppColors.textPrimary)
        let manage = linkButton(S.walletManage) { [weak self] in self?.comingSoon(S.walletManage) }
        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        header.addArrangedSubview(title)
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(manage)

        let tile = iconTile(symbol: "ic_bank", size: 36, iconSize: 19)
        let accountName = UILabel.make(S.walletImbBusinessAccount, font: AppFonts.bold(13), color: AppColors.textPrimary)
        let accountColumn = UIStackView.vertical(spacing: 2, alignment: .leading)
        accountColumn.addArrangedSubview(accountName)
        accountColumn.addArrangedSubview(settlementAccountLabel)
        let accountRow = UIStackView.horizontal(spacing: 10, alignment: .center)
        accountRow.addArrangedSubview(tile)
        accountRow.addArrangedSubview(accountColumn)
        accountRow.addArrangedSubview(UIView())

        let availableCaption = UILabel.make(S.walletAvailableForSettlement, font: AppFonts.regular(12),
                                            color: AppColors.textSecondary)
        let availableRow = UIStackView.horizontal(spacing: 6, alignment: .center)
        availableRow.addArrangedSubview(availableCaption)
        availableRow.addArrangedSubview(settlementAvailableLabel)
        availableRow.addArrangedSubview(UIView())

        let historyButton = outlinedButton(S.walletViewSettlementHistory) { [weak self] in
            self?.comingSoon(S.walletViewSettlementHistory)
        }

        let stack = UIStackView.vertical(spacing: 0, alignment: .fill)
        stack.forAutoLayout()
        stack.addArrangedSubview(header)
        stack.setCustomSpacing(12, after: header)
        stack.addArrangedSubview(accountRow)
        stack.setCustomSpacing(12, after: accountRow)
        stack.addArrangedSubview(availableRow)
        stack.setCustomSpacing(4, after: availableRow)
        stack.addArrangedSubview(settlementNextLabel)
        stack.setCustomSpacing(12, after: settlementNextLabel)
        stack.addArrangedSubview(historyButton)

        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return card
    }

    // MARK: - Quick actions

    private func buildQuickActionsCard() -> UIView {
        let card = StyleKit.cardView()
        let title = UILabel.make(S.walletQuickActions, font: AppFonts.bold(16), color: AppColors.textPrimary)

        let actions: [(key: String, label: String, icon: String)] = [
            ("send", S.walletActionSendMoney, "ic_send"),
            ("receive", S.walletActionReceiveMoney, "ic_arrow_down_left"),
            ("airtime", S.walletActionBuyAirtime, "ic_phone"),
            ("bills", S.walletActionPayBills, "ic_receipt"),
            ("add", S.walletActionAddMoney, "ic_add"),
            ("bank", S.walletActionMoveToBank, "ic_bank"),
            ("qr", S.walletActionQrPayment, "ic_qr_code"),
            ("more", S.walletActionMore, "ic_dots_horizontal")
        ]

        let grid = UIStackView.vertical(spacing: 6, alignment: .fill)
        for chunk in stride(from: 0, to: actions.count, by: 4) {
            let row = UIStackView.horizontal(spacing: 4, alignment: .top)
            row.distribution = .fillEqually
            for action in actions[chunk..<min(chunk + 4, actions.count)] {
                row.addArrangedSubview(quickActionTile(action))
            }
            grid.addArrangedSubview(row)
        }

        let stack = UIStackView.vertical(spacing: 8, alignment: .fill)
        stack.forAutoLayout()
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(grid)
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return card
    }

    private func quickActionTile(_ action: (key: String, label: String, icon: String)) -> UIView {
        let tile = iconTile(symbol: action.icon, size: 44, iconSize: 21, circular: true)
        let label = UILabel.make(action.label, font: AppFonts.regular(11),
                                 color: AppColors.textPrimary, align: .center, lines: 2)

        let column = UIStackView.vertical(spacing: 7, alignment: .center)
        column.isLayoutMarginsRelativeArrangement = true
        column.layoutMargins = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        column.addArrangedSubview(tile)
        column.addArrangedSubview(label)

        let button = TapContainerView()
        button.onTap = { [weak self] in self?.onQuickAction(action.key, label: action.label) }
        column.forAutoLayout()
        button.addSubview(column)
        column.pinEdges(to: button)
        return button
    }

    private func onQuickAction(_ key: String, label: String) {
        switch key {
        case "add":
            topUpTapped()
        case "airtime":
            navigationController?.pushViewController(AirtimeViewController(), animated: true)
        default:
            comingSoon(label)
        }
    }

    // MARK: - Send money quickly

    private func buildRecipientsCard() -> UIView {
        let card = StyleKit.cardView()

        let title = UILabel.make(S.walletSendMoneyQuickly, font: AppFonts.bold(16), color: AppColors.textPrimary)
        let viewAll = linkButton(S.viewAll, trailingSymbol: "arrow.right") { [weak self] in
            self?.comingSoon(S.walletSendMoneyQuickly)
        }
        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        header.isLayoutMarginsRelativeArrangement = true
        header.layoutMargins = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        header.addArrangedSubview(title)
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(viewAll)

        let recipients: [(name: String, account: String, initial: String, colour: UIColor)] = [
            ("Thabo M.", "**** 4521", "T", AppColors.info),
            ("Nomsa K.", "**** 8892", "N", AppColors.success),
            ("Sipho D.", "**** 1103", "S", AppColors.warning),
            ("Lerato P.", "**** 7744", "L", AppColors.danger),
            ("Zanele N.", "**** 3390", "Z", AppColors.purplePrimary)
        ]

        let strip = UIStackView.horizontal(spacing: 4, alignment: .top)
        strip.addArrangedSubview(newRecipientTile())
        for recipient in recipients {
            strip.addArrangedSubview(recipientTile(recipient))
        }

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        strip.forAutoLayout()
        scroll.addSubview(strip)
        NSLayoutConstraint.activate([
            strip.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            strip.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            strip.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 10),
            strip.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -10),
            // The scroll view sits in a vertical stack and has no intrinsic height —
            // take it from the strip so the row does not collapse.
            scroll.heightAnchor.constraint(equalTo: strip.heightAnchor)
        ])

        let stack = UIStackView.vertical(spacing: 10, alignment: .fill)
        stack.forAutoLayout()
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(scroll)
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 0))
        return card
    }

    private func newRecipientTile() -> UIView {
        let circle = DashedCircleView()
        circle.constrainSize(52)
        let plus = UIImageView(image: UIImage(systemName: "plus"))
        plus.tintColor = AppColors.textSecondary
        plus.contentMode = .scaleAspectFit
        plus.forAutoLayout()
        circle.addSubview(plus)
        NSLayoutConstraint.activate([
            plus.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            plus.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
            plus.widthAnchor.constraint(equalToConstant: 20),
            plus.heightAnchor.constraint(equalToConstant: 20)
        ])
        return recipientColumn(avatar: circle, name: S.walletNewRecipient, account: nil) { [weak self] in
            self?.comingSoon(S.walletNewRecipient)
        }
    }

    private func recipientTile(_ recipient: (name: String, account: String, initial: String, colour: UIColor)) -> UIView {
        let circle = UIView()
        circle.backgroundColor = recipient.colour
        circle.layer.cornerRadius = 26
        circle.constrainSize(52)
        let initial = UILabel.make(recipient.initial, font: AppFonts.bold(16), color: .white, align: .center)
        initial.forAutoLayout()
        circle.addSubview(initial)
        NSLayoutConstraint.activate([
            initial.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            initial.centerYAnchor.constraint(equalTo: circle.centerYAnchor)
        ])
        return recipientColumn(avatar: circle, name: recipient.name, account: recipient.account) { [weak self] in
            self?.comingSoon(recipient.name)
        }
    }

    private func recipientColumn(avatar: UIView, name: String, account: String?,
                                 onTap: @escaping () -> Void) -> UIView {
        let nameLabel = UILabel.make(name, font: AppFonts.regular(11), color: AppColors.textPrimary,
                                     align: .center, lines: 1)
        let accountLabel = UILabel.make(account ?? " ", font: AppFonts.light(10),
                                        color: AppColors.textTertiary, align: .center, lines: 1)
        accountLabel.alpha = account == nil ? 0 : 1

        let column = UIStackView.vertical(spacing: 1, alignment: .center)
        column.addArrangedSubview(avatar)
        column.setCustomSpacing(7, after: avatar)
        column.addArrangedSubview(nameLabel)
        column.addArrangedSubview(accountLabel)

        let container = TapContainerView()
        container.onTap = onTap
        column.forAutoLayout()
        container.addSubview(column)
        column.pinEdges(to: container)
        container.widthAnchor.constraint(equalToConstant: 84).isActive = true
        return container
    }

    // MARK: - Recent transactions

    private func buildTransactionsCard() -> UIView {
        let card = StyleKit.cardView()

        let title = UILabel.make(S.walletRecentTransactions, font: AppFonts.bold(16), color: AppColors.textPrimary)
        txnViewAllButton.setTitle(S.viewAll, for: .normal)
        txnViewAllButton.setTitleColor(AppColors.purplePrimary, for: .normal)
        txnViewAllButton.titleLabel?.font = AppFonts.medium(12)
        txnViewAllButton.setContentHuggingPriority(.required, for: .horizontal)
        txnViewAllButton.addTarget(self, action: #selector(toggleTransactions), for: .touchUpInside)
        txnViewAllButton.isHidden = true

        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        header.addArrangedSubview(title)
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(txnViewAllButton)

        let emptyTitle = UILabel.make(S.walletNoTransactions, font: AppFonts.bold(13),
                                      color: AppColors.textPrimary, align: .center)
        let empty = UIStackView.vertical(spacing: 3, alignment: .fill)
        empty.isLayoutMarginsRelativeArrangement = true
        empty.layoutMargins = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
        empty.addArrangedSubview(emptyTitle)
        empty.addArrangedSubview(txnEmptyLabel)
        empty.isHidden = true   // stays hidden until the first load says the ledger is empty
        emptyContainer = empty

        let stack = UIStackView.vertical(spacing: 2, alignment: .fill)
        stack.forAutoLayout()
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(txnStack)
        stack.addArrangedSubview(empty)
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return card
    }

    private var emptyContainer: UIStackView?

    private func bindTransactions() {
        txnStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let all = wallet?.balance?.transactions ?? []

        emptyContainer?.isHidden = !all.isEmpty
        txnStack.isHidden = all.isEmpty
        txnViewAllButton.isHidden = all.count <= Self.txnPreviewCount
        txnViewAllButton.setTitle(showAllTransactions ? S.walletShowLess : S.viewAll, for: .normal)
        guard !all.isEmpty else { return }

        let limit = showAllTransactions ? all.count : min(Self.txnPreviewCount, all.count)
        for (index, txn) in all.prefix(limit).enumerated() {
            if index > 0 { txnStack.addArrangedSubview(hairline()) }
            txnStack.addArrangedSubview(transactionRow(txn))
        }
    }

    private func transactionRow(_ txn: WalletData.Transaction) -> UIView {
        let amount = WalletFormat.parseAmount(txn.amount)
        let credit = amount >= 0

        let tile = iconTile(symbol: credit ? "ic_arrow_down_left" : "ic_arrow_up_right",
                            size: 34, iconSize: 17, circular: true,
                            background: credit ? AppColors.successBg : AppColors.dangerBg,
                            tint: credit ? AppColors.success : AppColors.danger)

        let title = UILabel.make(credit ? S.walletMoneyReceived : S.walletMoneySent,
                                 font: AppFonts.bold(13), color: AppColors.textPrimary, lines: 1)
        let subtitle = UILabel.make(S.walletTxnReference(String(txn.transactionId ?? 0)),
                                    font: AppFonts.regular(11), color: AppColors.textSecondary, lines: 1)
        let left = UIStackView.vertical(spacing: 2, alignment: .leading)
        left.addArrangedSubview(title)
        left.addArrangedSubview(subtitle)

        let amountLabel = UILabel.make(balanceHidden ? S.walletBalanceMasked : WalletFormat.signedZaMoney(amount),
                                       font: AppFonts.bold(14),
                                       color: credit ? AppColors.success : AppColors.danger, align: .right)
        let dateLabel = UILabel.make(WalletFormat.relativeDateTime(txn.date), font: AppFonts.regular(11),
                                     color: AppColors.textSecondary, align: .right)
        let pending = txn.pending == true
        let badge = StyleKit.badgeLabel()
        badge.text = pending ? S.walletTxnPending : S.walletTxnSuccess
        badge.font = AppFonts.regular(10)
        badge.textColor = pending ? AppColors.warning : AppColors.success
        badge.backgroundColor = pending ? AppColors.warningBg : AppColors.successBg

        let right = UIStackView.vertical(spacing: 2, alignment: .trailing)
        right.setContentHuggingPriority(.required, for: .horizontal)
        right.setContentCompressionResistancePriority(.required, for: .horizontal)
        right.addArrangedSubview(amountLabel)
        right.addArrangedSubview(dateLabel)
        right.setCustomSpacing(4, after: dateLabel)
        right.addArrangedSubview(badge)

        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        row.addArrangedSubview(tile)
        row.addArrangedSubview(left)
        row.addArrangedSubview(right)
        return row
    }

    @objc private func toggleTransactions() {
        showAllTransactions.toggle()
        bindTransactions()
    }

    // MARK: - Loan offers / statements / microfinance (placeholder panels)

    private func buildLoanOffersCard() -> UIView {
        let card = StyleKit.cardView()

        let title = UILabel.make(S.walletLoanOffers, font: AppFonts.bold(16), color: AppColors.textPrimary)
        let viewAll = linkButton(S.viewAll) { [weak self] in self?.comingSoon(S.walletLoanOffers) }
        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        header.addArrangedSubview(title)
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(viewAll)

        let offers: [(title: String, badge: String?, amount: String, rate: String, icon: String)] = [
            (S.walletLoanBusinessBoost, S.walletBadgeRecommended, "Up to R50 000", "From 1.75% p.m.", "ic_finances"),
            (S.walletLoanStockFinance, S.walletBadgePopular, "Up to R100 000", "From 1.5% p.m.", "ic_inventory"),
            (S.walletLoanEquipmentFinance, nil, "Up to R200 000", "From 1.9% p.m.", "ic_wrench")
        ]

        let list = UIStackView.vertical(spacing: 10, alignment: .fill)
        offers.forEach { list.addArrangedSubview(loanCard($0)) }

        let stack = UIStackView.vertical(spacing: 10, alignment: .fill)
        stack.forAutoLayout()
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(list)
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return card
    }

    private func loanCard(_ offer: (title: String, badge: String?, amount: String, rate: String, icon: String)) -> UIView {
        let card = StyleKit.cardView()

        let tile = iconTile(symbol: offer.icon, size: 32, iconSize: 17, circular: true)
        let title = UILabel.make(offer.title, font: AppFonts.bold(14), color: AppColors.textPrimary, lines: 1)
        let titleColumn = UIStackView.vertical(spacing: 4, alignment: .leading)
        titleColumn.addArrangedSubview(title)
        if let badgeText = offer.badge {
            let badge = StyleKit.badgeLabel()
            badge.text = badgeText
            badge.textColor = AppColors.purplePrimary
            badge.backgroundColor = AppColors.purpleLight
            titleColumn.addArrangedSubview(badge)
        }
        let header = UIStackView.horizontal(spacing: 10, alignment: .center)
        header.addArrangedSubview(tile)
        header.addArrangedSubview(titleColumn)
        header.addArrangedSubview(UIView())

        let figures = UIStackView.horizontal(spacing: 12, alignment: .top)
        figures.distribution = .fillEqually
        figures.addArrangedSubview(figureColumn(S.walletLoanAmount, offer.amount))
        figures.addArrangedSubview(figureColumn(S.walletInterestRate, offer.rate))

        let apply = outlinedButton(S.walletApplyNow) { [weak self] in self?.comingSoon(offer.title) }

        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.forAutoLayout()
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(figures)
        stack.addArrangedSubview(apply)
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return card
    }

    private func figureColumn(_ caption: String, _ value: String) -> UIView {
        let column = UIStackView.vertical(spacing: 2, alignment: .leading)
        column.addArrangedSubview(UILabel.make(caption, font: AppFonts.regular(11), color: AppColors.textSecondary))
        column.addArrangedSubview(UILabel.make(value, font: AppFonts.bold(13), color: AppColors.textPrimary))
        return column
    }

    private func buildStatementsCard() -> UIView {
        let card = StyleKit.cardView()

        let title = UILabel.make(S.walletStatements, font: AppFonts.bold(16), color: AppColors.textPrimary)
        let viewAll = linkButton(S.viewAll) { [weak self] in self?.comingSoon(S.walletStatements) }
        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        header.addArrangedSubview(title)
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(viewAll)

        let periods = [S.walletStatementToday, S.walletStatementYesterday, S.walletStatementThisWeek,
                       S.walletStatementThisMonth, S.walletStatementCustom]
        let list = UIStackView.vertical(spacing: 0, alignment: .fill)
        for (index, period) in periods.enumerated() {
            let isCustom = index == periods.count - 1
            list.addArrangedSubview(statementRow(period, icon: isCustom ? "ic_calendar" : "ic_document"))
        }

        let stack = UIStackView.vertical(spacing: 4, alignment: .fill)
        stack.forAutoLayout()
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(list)
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return card
    }

    private func statementRow(_ label: String, icon: String) -> UIView {
        let tile = iconTile(symbol: icon, size: 30, iconSize: 15, circular: true)
        let text = UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textPrimary)
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = AppColors.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.constrainSize(16)

        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 9, left: 0, bottom: 9, right: 0)
        row.addArrangedSubview(tile)
        row.addArrangedSubview(text)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(chevron)

        let container = TapContainerView()
        container.onTap = { [weak self] in
            self?.comingSoon("\(S.walletStatements) · \(label)")
        }
        row.forAutoLayout()
        container.addSubview(row)
        row.pinEdges(to: container)
        return container
    }

    private func buildMicrofinanceCard() -> UIView {
        let card = GradientCardView(colors: [UIColor(hex: 0xDBEAFE), UIColor(hex: 0xEFF6FF)])
        card.layer.cornerRadius = AppMetrics.radiusLG

        let title = UILabel.make(S.walletMicrofinanceTitle, font: AppFonts.bold(18), color: AppColors.textPrimary)
        let body = UILabel.make(S.walletMicrofinanceBody, font: AppFonts.regular(12), color: AppColors.textSecondary)
        let button = outlinedButton(S.walletExploreMicrofinance, fullWidth: false) { [weak self] in
            self?.comingSoon(S.walletExploreMicrofinance)
        }

        let buttonRow = UIStackView.horizontal(spacing: 0, alignment: .center)
        buttonRow.addArrangedSubview(button)
        buttonRow.addArrangedSubview(UIView())

        let stack = UIStackView.vertical(spacing: 6, alignment: .fill)
        stack.forAutoLayout()
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(body)
        stack.setCustomSpacing(14, after: body)
        stack.addArrangedSubview(buttonRow)
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18))
        return card
    }

    private func buildNeedFundsCard() -> UIView {
        let card = GradientCardView(colors: [UIColor(hex: 0x7C3AED), UIColor(hex: 0x5B21B6)])
        card.layer.cornerRadius = AppMetrics.radiusLG

        let title = UILabel.make(S.walletNeedFunds, font: AppFonts.bold(18), color: .white)
        let body = UILabel.make(S.walletNeedFundsSub, font: AppFonts.regular(12),
                                color: UIColor.white.withAlphaComponent(0.9))

        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .white
        config.baseForegroundColor = AppColors.purplePrimary
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 11, leading: 20, bottom: 11, trailing: 20)
        config.title = S.walletApplyMicrofinance
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.bold(13); return out
        }
        button.configuration = config
        button.addTarget(self, action: #selector(applyMicrofinanceTapped), for: .touchUpInside)

        let buttonRow = UIStackView.horizontal(spacing: 0, alignment: .center)
        buttonRow.addArrangedSubview(button)
        buttonRow.addArrangedSubview(UIView())

        let stack = UIStackView.vertical(spacing: 4, alignment: .fill)
        stack.forAutoLayout()
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(body)
        stack.setCustomSpacing(14, after: body)
        stack.addArrangedSubview(buttonRow)
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18))
        return card
    }

    @objc private func applyMicrofinanceTapped() { comingSoon(S.walletApplyMicrofinance) }

    // MARK: - Data

    @objc private func handlePullToRefresh() {
        load(forceRefresh: true)
    }

    private func load(forceRefresh: Bool) {
        ApiClient.shared.getWallet(refresh: forceRefresh) { [weak self] result in
            guard let self = self else { return }
            self.spinner.stopAnimating()
            self.scrollView.refreshControl?.endRefreshing()
            switch result {
            case .success(let data):
                self.wallet = data
            case .failure(let error):
                self.toast(error.message)
            }
            self.bindWallet()
        }
    }

    private func bindWallet() {
        let balance = wallet?.balance
        totalBalanceLabel.text = maskable(balance?.current)
        availableBalanceLabel.text = maskable(balance?.available)
        pendingBalanceLabel.text = maskable(balance?.pending)

        let asOf = WalletFormat.asOfTime(balance?.asOf)
        asOfLabel.isHidden = asOf.isEmpty
        asOfLabel.text = asOf.isEmpty ? nil : "as of \(asOf)"

        let isActive = wallet?.status?.lowercased() == "active"
        if wallet != nil && !isActive {
            noticeLabel.text = S.walletInactiveBody
            noticeLabel.isHidden = false
        } else if balance?.stale == true {
            noticeLabel.text = S.walletStaleNotice
            noticeLabel.isHidden = false
        } else {
            noticeLabel.isHidden = true
        }

        settlementAccountLabel.text = WalletFormat.maskAccount(wallet?.accountNumber)
        settlementAvailableLabel.text = maskable(balance?.available)
        settlementNextLabel.text = S.walletNextSettlement(WalletFormat.nextSettlementLabel())

        bindTransactions()
    }

    private func maskable(_ value: Double?) -> String {
        balanceHidden ? S.walletBalanceMasked : WalletFormat.zaMoneyCompact(value ?? 0)
    }

    // MARK: - Header actions

    @objc private func refreshTapped() {
        let spin = CABasicAnimation(keyPath: "transform.rotation")
        spin.fromValue = 0
        spin.toValue = 2 * Double.pi
        spin.duration = 0.6
        refreshIcon.layer.add(spin, forKey: "spin")
        load(forceRefresh: true)
    }

    @objc private func hideTapped() {
        balanceHidden.toggle()
        hideIcon.image = AppIcons.symbol(balanceHidden ? "ic_visibility_off" : "ic_eye")
        bindWallet()
    }

    // MARK: - Top-up (PayCloud)

    @objc private func topUpTapped() {
        let sheet = TopUpViewController { [weak self] amount, controller in
            self?.createTopup(amount: amount, from: controller)
        }
        if let sheetPresentation = sheet.sheetPresentationController {
            sheetPresentation.detents = [.medium(), .large()]
            sheetPresentation.prefersGrabberVisible = true
            sheetPresentation.preferredCornerRadius = 20
        }
        present(sheet, animated: true)
    }

    private func createTopup(amount: Double, from sheet: TopUpViewController) {
        guard amount >= Self.topupMin else {
            sheet.showError(amount <= 0 ? S.topupErrAmount : S.topupErrMin)
            return
        }
        guard amount <= Self.topupMax else {
            sheet.showError(S.topupErrMax)
            return
        }

        sheet.setBusy(true)
        ApiClient.shared.createTopup(amount: amount, returnUrl: Self.returnURL) { [weak self] result in
            guard let self = self else { return }
            sheet.setBusy(false)
            switch result {
            case .success(let data):
                guard let raw = data.payUrl, let url = URL(string: raw) else {
                    sheet.showError(S.topupFailedNotice)
                    return
                }
                self.pendingOrderNo = data.merchantOrderNo
                sheet.dismiss(animated: true) { self.openCheckout(url) }
            case .failure(let error):
                sheet.showError(error.message)
            }
        }
    }

    private func openCheckout(_ url: URL) {
        let safari = SFSafariViewController(url: url)
        safari.delegate = self
        safari.preferredControlTintColor = AppColors.purplePrimary
        checkoutController = safari
        present(safari, animated: true)
    }

    /// Posted by SceneDelegate when PayCloud redirects back to `anokix://wallet`.
    static let topupReturnNotification = Notification.Name("WalletTopupReturn")

    @objc private func handleTopupReturn() {
        guard let orderNo = pendingOrderNo else { return }
        if let safari = checkoutController {
            checkoutController = nil
            safari.dismiss(animated: true) { [weak self] in self?.pollTopupStatus(orderNo, attempt: 0) }
        } else {
            pollTopupStatus(orderNo, attempt: 0)
        }
    }

    /// Poll `topup/status` after the checkout. The webhook that credits the wallet is
    /// asynchronous, so a paid-but-not-yet-credited result is retried a few times before
    /// the user is told the credit is on its way.
    private func pollTopupStatus(_ orderNo: String, attempt: Int) {
        let maxAttempts = 5
        if attempt == 0 { toast(S.topupChecking) }

        ApiClient.shared.getTopupStatus(merchantOrderNo: orderNo) { [weak self] result in
            guard let self = self else { return }
            guard case .success(let data) = result else {
                self.pendingOrderNo = nil
                if case .failure(let error) = result { self.toast(error.message) }
                return
            }

            if data.isCredited {
                self.pendingOrderNo = nil
                self.toast(S.topupCredited(WalletFormat.zaMoneyCompact(data.amount ?? 0)))
                self.load(forceRefresh: true)
                return
            }
            if data.isFailed {
                self.pendingOrderNo = nil
                self.toast(S.topupFailedNotice)
                return
            }
            if attempt + 1 < maxAttempts {
                // Give the PayCloud webhook a moment, then look again.
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    self.pollTopupStatus(orderNo, attempt: attempt + 1)
                }
                return
            }
            self.pendingOrderNo = nil
            // status=paid means the card was charged and only the credit is outstanding;
            // still-pending means the user never completed (or abandoned) the checkout.
            if data.status?.lowercased() == "paid" || data.creditStatus?.lowercased() == "pending" {
                self.toast(S.topupPendingNotice)
                self.load(forceRefresh: true)
            } else {
                self.toast(S.topupNotCompleted)
            }
        }
    }

    // MARK: - Small builders

    private func iconTile(symbol: String, size: CGFloat, iconSize: CGFloat,
                          circular: Bool = false,
                          background: UIColor = AppColors.purpleLight,
                          tint: UIColor = AppColors.purplePrimary) -> UIView {
        let tile = StyleKit.iconTile(color: background, radius: circular ? size / 2 : AppMetrics.radiusMD)
        tile.constrainSize(size)
        tile.setContentHuggingPriority(.required, for: .horizontal)

        let icon = UIImageView(image: AppIcons.symbol(symbol))
        icon.tintColor = tint
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        tile.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: iconSize),
            icon.heightAnchor.constraint(equalToConstant: iconSize)
        ])
        return tile
    }

    private func linkButton(_ title: String, trailingSymbol: String? = nil,
                            action: @escaping () -> Void) -> UIButton {
        let button = ActionButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = AppColors.purplePrimary
        config.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
        config.title = title
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.medium(12); return out
        }
        if let symbol = trailingSymbol {
            config.image = UIImage(systemName: symbol)
            config.imagePlacement = .trailing
            config.imagePadding = 4
        }
        button.configuration = config
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.onTap = action
        return button
    }

    private func outlinedButton(_ title: String, fullWidth: Bool = true,
                                action: @escaping () -> Void) -> UIButton {
        let button = ActionButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = AppColors.purplePrimary
        config.background.strokeColor = AppColors.purplePrimary
        config.background.strokeWidth = 1
        config.background.cornerRadius = AppMetrics.radiusMD
        config.background.backgroundColor = AppColors.surface
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
        config.title = title
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.bold(13); return out
        }
        button.configuration = config
        button.onTap = action
        if fullWidth {
            button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        } else {
            button.setContentHuggingPriority(.required, for: .horizontal)
        }
        return button
    }

    private func hairline() -> UIView {
        let line = UIView()
        line.backgroundColor = AppColors.borderLight
        line.constrainHeight(1)
        return line
    }

    private func comingSoon(_ feature: String) {
        toast(S.walletComingSoon(feature))
    }
}

// MARK: - SFSafariViewControllerDelegate

extension WalletViewController: SFSafariViewControllerDelegate {
    /// The user closed the checkout by hand — poll anyway, they may have paid.
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        checkoutController = nil
        guard let orderNo = pendingOrderNo else { return }
        pollTopupStatus(orderNo, attempt: 0)
    }
}

// MARK: - Small reusable views

/// A card whose background is a linear gradient (the Android bg_wallet_balance_card /
/// bg_microfinance_card drawables).
final class GradientCardView: UIView {
    private let gradient = CAGradientLayer()

    init(colors: [UIColor]) {
        super.init(frame: .zero)
        gradient.colors = colors.map { $0.cgColor }
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradient, at: 0)
        layer.masksToBounds = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}

/// Dashed circle behind the "New Recipient" plus (bg_circle_outline_dashed).
final class DashedCircleView: UIView {
    private let border = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        border.fillColor = UIColor.clear.cgColor
        border.strokeColor = AppColors.textTertiary.cgColor
        border.lineWidth = 1
        border.lineDashPattern = [4, 3]
        layer.addSublayer(border)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        border.frame = bounds
        border.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 0.5, dy: 0.5)).cgPath
    }
}

/// A plain view that reports taps — used to make composed stacks tappable.
final class TapContainerView: UIView {
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped() { onTap?() }
}

/// UIButton carrying its own closure, so the wallet screen's many small buttons don't each
/// need a distinct @objc selector.
final class ActionButton: UIButton {
    var onTap: (() -> Void)? {
        didSet {
            removeTarget(self, action: #selector(fire), for: .touchUpInside)
            addTarget(self, action: #selector(fire), for: .touchUpInside)
        }
    }

    @objc private func fire() { onTap?() }
}

// MARK: - Wallet screen formatting

extension WalletFormat {

    /// `41418.5` → `"R41 418,50"` — the web portal's ZA money without a space after R.
    static func zaMoneyCompact(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        let digits = formatter.string(from: NSNumber(value: abs(value)))
            ?? String(format: "%.2f", abs(value))
        let za = digits.replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ".", with: ",")
        return (value < 0 ? "-R" : "R") + za
    }

    /// Same as `zaMoneyCompact` but credits keep an explicit `+`.
    static func signedZaMoney(_ value: Double) -> String {
        value > 0 ? "+" + zaMoneyCompact(value) : zaMoneyCompact(value)
    }

    /// The API sends transaction amounts as a signed string; bad input reads as 0.
    static func parseAmount(_ raw: String?) -> Double {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return 0 }
        return Double(raw.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")) ?? 0
    }

    /// "Today, 15:32" / "Yesterday, 08:11" / "15 Jul 2026, 15:58".
    static func relativeDateTime(_ iso: String?) -> String {
        guard let iso = iso, !iso.isEmpty else { return "" }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        guard let date = parser.date(from: iso) else { return iso }

        let time = DateFormatter()
        time.dateFormat = "HH:mm"
        time.locale = Locale(identifier: "en_US_POSIX")

        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today, " + time.string(from: date) }
        if calendar.isDateInYesterday(date) { return "Yesterday, " + time.string(from: date) }

        let full = DateFormatter()
        full.dateFormat = "dd MMM yyyy, HH:mm"
        full.locale = Locale(identifier: "en_US_POSIX")
        return full.string(from: date)
    }

    /// Account number → the masked form shown on the settlement card (`***3345`).
    static func maskAccount(_ accountNumber: String?) -> String {
        guard let number = accountNumber, number.count >= 4 else { return "***" }
        return "***" + number.suffix(4)
    }

    /// The settlement schedule has no API yet — show a plausible fixed cadence.
    static func nextSettlementLabel() -> String {
        var next = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        next = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: next) ?? next
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy, HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: next)
    }
}
