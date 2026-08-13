import UIKit

/// Trader card (New-Design/Traders/1.Traders-Dashboard.png) — the phone form of the web
/// table row: coloured initials avatar, business name, code and trading name, address and
/// phone, then the Status / Credit Status badges the table kept in their own columns.
///
/// Built in code rather than from a XIB so the overflow button that opens Edit / Delete
/// (2.Trader-Item-Menu.png) can hand its own frame back as the action-sheet anchor.
final class TraderCell: UICollectionViewCell {

    static let reuseIdentifier = "TraderCell"

    /// Passes the overflow button so the sheet can point at it on iPad.
    var onMore: ((UIView) -> Void)?

    private let cardView = UIView()
    private let avatarLabel = UILabel()
    private let nameLabel = UILabel()
    private let codeLabel = UILabel()
    private let tradingNameLabel = UILabel()
    private let addressLabel = UILabel()
    private let phoneLabel = UILabel()
    private let statusBadge = StyleKit.badgeLabel()
    private let creditBadge = StyleKit.badgeLabel()
    private let registrationBadge = StyleKit.badgeLabel()
    private let moreButton = UIButton(type: .system)
    private let badgeRow = UIStackView.horizontal(spacing: 6, alignment: .center)
    // The glyph travels with its line, so an empty address/phone hides the icon too.
    private var addressRow: UIStackView!
    private var phoneRow: UIStackView!

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
        StyleKit.styleCard(cardView)
        cardView.forAutoLayout()
        contentView.addSubview(cardView)
        cardView.pinEdges(to: contentView, insets: UIEdgeInsets(top: 0, left: 0, bottom: 10, right: 0))

        avatarLabel.font = AppFonts.bold(14)
        avatarLabel.textColor = .white
        avatarLabel.textAlignment = .center
        avatarLabel.layer.cornerRadius = 22
        avatarLabel.layer.masksToBounds = true
        avatarLabel.constrainSize(44)

        nameLabel.font = AppFonts.bold(14)
        nameLabel.textColor = AppColors.topTitle
        nameLabel.lineBreakMode = .byTruncatingTail

        codeLabel.font = AppFonts.bold(11)
        codeLabel.textColor = AppColors.textSecondary
        codeLabel.setContentHuggingPriority(.required, for: .horizontal)

        tradingNameLabel.font = AppFonts.regular(11)
        tradingNameLabel.textColor = AppColors.textTertiary
        tradingNameLabel.lineBreakMode = .byTruncatingTail

        let subtitleRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        subtitleRow.addArrangedSubview(codeLabel)
        subtitleRow.addArrangedSubview(tradingNameLabel)

        let identity = UIStackView.vertical(spacing: 2, alignment: .fill)
        identity.addArrangedSubview(nameLabel)
        identity.addArrangedSubview(subtitleRow)

        moreButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        moreButton.tintColor = AppColors.textSecondary
        moreButton.accessibilityLabel = "More actions"
        moreButton.constrainSize(32)
        moreButton.setContentHuggingPriority(.required, for: .horizontal)
        moreButton.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.onMore?(self.moreButton)
        }, for: .touchUpInside)

        let topRow = UIStackView.horizontal(spacing: 12, alignment: .center)
        topRow.addArrangedSubview(avatarLabel)
        topRow.addArrangedSubview(identity)
        topRow.addArrangedSubview(moreButton)

        addressLabel.numberOfLines = 2
        phoneLabel.numberOfLines = 1

        badgeRow.addArrangedSubview(statusBadge)
        badgeRow.addArrangedSubview(creditBadge)
        badgeRow.addArrangedSubview(registrationBadge)
        badgeRow.addArrangedSubview(UIView())

        addressRow = iconRow(symbol: "mappin.and.ellipse", label: addressLabel)
        phoneRow = iconRow(symbol: "phone", label: phoneLabel)

        let stack = UIStackView.vertical(spacing: 4, alignment: .fill)
        stack.addArrangedSubview(topRow)
        stack.addArrangedSubview(addressRow)
        stack.addArrangedSubview(phoneRow)
        stack.addArrangedSubview(badgeRow)
        stack.setCustomSpacing(10, after: topRow)
        stack.forAutoLayout()
        cardView.addSubview(stack)
        stack.pinEdges(to: cardView, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
    }

    /// A small tinted glyph in front of a secondary line, matching the web row's meta icons.
    private func iconRow(symbol: String, label: UILabel) -> UIStackView {
        label.font = AppFonts.regular(11)
        label.textColor = AppColors.textSecondary

        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = AppColors.textTertiary
        icon.contentMode = .scaleAspectFit
        icon.constrainSize(12)
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView.horizontal(spacing: 6, alignment: .top)
        row.addArrangedSubview(icon)
        row.addArrangedSubview(label)
        return row
    }

    func configure(_ trader: TradersData.Trader, index: Int) {
        let name = trader.displayName
        nameLabel.text = name
        avatarLabel.text = ApiMapper.traderInitials(name)
        avatarLabel.backgroundColor = ApiMapper.traderAvatarColor(index)

        set(codeLabel, trader.traderCode)
        // Trading name only earns a second line when it differs from the headline.
        let trading = trader.tradingName ?? ""
        set(tradingNameLabel, trading == name ? "" : trading)
        set(addressLabel, trader.address, row: addressRow)
        set(phoneLabel, phone(of: trader), row: phoneRow)

        apply(statusBadge, text: trader.status, colors: statusColors(trader.status))
        apply(creditBadge, text: trader.creditStatus, colors: creditColors(trader.creditStatus))
        // The registration badge only earns its space while approval is still outstanding.
        let registration = isApproved(trader.registrationStatus) ? nil : trader.registrationStatus
        apply(registrationBadge, text: registration, colors: (AppColors.info, AppColors.infoBg))
        badgeRow.isHidden = statusBadge.isHidden && creditBadge.isHidden && registrationBadge.isHidden
    }

    /// Prefer the business line the list actually returns, then the owner's mobile.
    private func phone(of trader: TradersData.Trader) -> String {
        for candidate in [trader.businessPhoneNumber, trader.mobileNumber] {
            guard let raw = candidate?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { continue }
            // The API stores bare MSISDNs ("27821234567"); show them dialable.
            return raw.hasPrefix("+") ? raw : "+" + raw
        }
        return ""
    }

    /// `row` is passed for the icon lines so an empty value hides the glyph with it.
    private func set(_ label: UILabel, _ value: String?, row: UIStackView? = nil) {
        let text = (value ?? "").trimmingCharacters(in: .whitespaces)
        label.text = text
        label.isHidden = text.isEmpty
        row?.isHidden = text.isEmpty
    }

    private func apply(_ badge: PaddingLabel, text: String?, colors: (fg: UIColor, bg: UIColor)) {
        let value = (text ?? "").trimmingCharacters(in: .whitespaces)
        badge.isHidden = value.isEmpty
        guard !value.isEmpty else { return }
        badge.text = value
        badge.font = AppFonts.regular(AppMetrics.textMicro)
        badge.textColor = colors.fg
        badge.backgroundColor = colors.bg
    }

    private func isApproved(_ registrationStatus: String?) -> Bool {
        let value = (registrationStatus ?? "").trimmingCharacters(in: .whitespaces)
        return value.isEmpty || value.caseInsensitiveCompare("Approved") == .orderedSame
    }

    private func statusColors(_ status: String?) -> (UIColor, UIColor) {
        switch (status ?? "").trimmingCharacters(in: .whitespaces).lowercased() {
        case "active": return (AppColors.success, AppColors.successBg)
        case "suspended": return (AppColors.danger, AppColors.dangerBg)
        case "new": return (AppColors.purplePrimary, AppColors.purpleLight)
        default: return (AppColors.textSecondary, AppColors.borderLight)
        }
    }

    private func creditColors(_ creditStatus: String?) -> (UIColor, UIColor) {
        switch (creditStatus ?? "").trimmingCharacters(in: .whitespaces).lowercased() {
        case "good standing": return (AppColors.success, AppColors.successBg)
        case "warning": return (AppColors.warning, AppColors.warningBg)
        case "overdue", "suspended": return (AppColors.danger, AppColors.dangerBg)
        default: return (AppColors.textSecondary, AppColors.borderLight)
        }
    }
}
