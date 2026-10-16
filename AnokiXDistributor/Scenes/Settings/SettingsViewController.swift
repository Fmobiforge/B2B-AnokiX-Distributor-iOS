import UIKit

/// Main settings hub: profile summary + static menu rows (no inline notification toggles).
final class SettingsViewController: BaseSecondaryViewController {

    override var screenTitle: String { S.settings }

    private let avatarLabel = UILabel()
    private let nameLabel = UILabel()
    private let emailLabel = UILabel()
    private let verifiedBadge = UIView()

    override func setupContent(in container: UIView) {
        let stack = makeScrollStack(in: container)
        stack.addArrangedSubview(buildProfileCard())
        stack.addArrangedSubview(buildMenuCard())
        stack.addArrangedSubview(UILabel.make(S.settingsFooterHint, font: AppFonts.regular(11),
                                                color: AppColors.textSecondary, align: .center, lines: 0))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshProfileHeader()
    }

    override func loadData() {
        refreshProfileHeader()
        // Refresh the header from the live account (base data).
        ApiClient.shared.getBaseInfo { [weak self] result in
            guard let self = self, case .success(let data) = result, let user = data.user else { return }
            let name = "\(user.firstName ?? "") \(user.lastName ?? "")".trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                self.nameLabel.text = name
                self.avatarLabel.text = self.initialsOf(name, fallback: "?")
            }
            if let email = user.email, !email.isEmpty { self.emailLabel.text = email }
        }
    }

    private func refreshProfileHeader() {
        let profile = mergedProfile()
        avatarLabel.text = profile.initials
        nameLabel.text = profile.name
        emailLabel.text = profile.email
        verifiedBadge.isHidden = !profile.verified
    }

    private func mergedProfile() -> SettingsProfile {
        let fallback = repository.getSettingsProfile()
        let session = SessionManager.shared
        let name = session.fullName.isEmpty ? fallback.name : session.fullName
        let email = session.email.isEmpty ? fallback.email : session.email
        let initials = initialsOf(name, fallback: fallback.initials)
        return SettingsProfile(name: name, email: email, initials: initials, verified: fallback.verified)
    }

    private func initialsOf(_ name: String, fallback: String) -> String {
        let parts = name.trimmingCharacters(in: .whitespaces).split(separator: " ")
        var result = ""
        for part in parts where result.count < 2 {
            if let first = part.first { result.append(first) }
        }
        return result.isEmpty ? fallback : result.uppercased()
    }

    private func buildProfileCard() -> UIView {
        // Portal profile avatar: 135° indigo → violet gradient, white semibold initials.
        avatarLabel.font = AppFonts.semibold(22)
        avatarLabel.textColor = .white
        avatarLabel.textAlignment = .center
        avatarLabel.layer.cornerRadius = 28
        avatarLabel.layer.masksToBounds = true
        avatarLabel.constrainSize(56)
        StyleKit.applyAvatarGradient(to: avatarLabel, size: CGSize(width: 56, height: 56))

        nameLabel.font = AppFonts.bold(14)
        nameLabel.textColor = AppColors.textPrimary
        emailLabel.font = AppFonts.regular(12)
        emailLabel.textColor = AppColors.textSecondary

        let badge = StyleKit.badgeLabel()
        badge.text = S.verifiedDistributor
        badge.textColor = AppColors.purplePrimary
        badge.backgroundColor = AppColors.purpleLight
        let shield = UIImageView(image: UIImage(systemName: "checkmark.shield.fill"))
        shield.tintColor = AppColors.purplePrimary
        shield.contentMode = .scaleAspectFit
        shield.constrainSize(14)
        let badgeRow = UIStackView.horizontal(spacing: 6, alignment: .center)
        badgeRow.addArrangedSubview(shield)
        badgeRow.addArrangedSubview(badge)
        verifiedBadge.addSubview(badgeRow)
        badgeRow.pinEdges(to: verifiedBadge)

        let textStack = UIStackView.vertical(spacing: 2, alignment: .leading)
        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(emailLabel)
        textStack.addArrangedSubview(verifiedBadge)

        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.addArrangedSubview(avatarLabel)
        row.addArrangedSubview(textStack)

        let card = StyleKit.cardView()
        card.addSubview(row)
        row.pinEdges(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        return card
    }

    private func buildMenuCard() -> UIView {
        let menuCard = StyleKit.cardView()
        let menuStack = UIStackView.vertical(spacing: 0, alignment: .fill)
        menuStack.forAutoLayout()

        let items: [(String, String, Selector)] = [
            (S.settingsMenuProfile, "ic_person", #selector(openProfile)),
            (S.settingsMenuBusiness, "ic_briefcase", #selector(openBusiness)),
            (S.notifications, "ic_notifications", #selector(openNotifications)),
            (S.settingsMenuSecurity, "ic_shield", #selector(openSecurity)),
            (S.settingsMenuPreferences, "ic_tune", #selector(openPreferences))
        ]

        for (index, item) in items.enumerated() {
            menuStack.addArrangedSubview(menuRow(title: item.0, icon: item.1, action: item.2))
            if index < items.count - 1 { menuStack.addArrangedSubview(divider()) }
        }

        menuCard.addSubview(menuStack)
        menuStack.pinEdges(to: menuCard, insets: UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0))
        return menuCard
    }

    private func menuRow(title: String, icon: String, action: Selector) -> UIView {
        let iconView = UIImageView(image: AppIcons.symbol(icon))
        iconView.tintColor = AppColors.textSecondary
        iconView.contentMode = .scaleAspectFit
        iconView.constrainSize(20)

        let titleLabel = UILabel.make(title, font: AppFonts.medium(12), color: AppColors.textPrimary)
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = AppColors.textSecondary
        chevron.contentMode = .scaleAspectFit
        chevron.constrainSize(16)

        let row = UIStackView.horizontal(spacing: 14, alignment: .center)
        row.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        row.isLayoutMarginsRelativeArrangement = true
        row.addArrangedSubview(iconView)
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(chevron)

        let wrapper = UIView()
        wrapper.addSubview(row)
        row.pinEdges(to: wrapper)
        wrapper.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))
        wrapper.isUserInteractionEnabled = true
        return wrapper
    }

    @objc private func openProfile() {
        navigationController?.pushViewController(SettingsProfileViewController(), animated: true)
    }

    @objc private func openBusiness() {
        navigationController?.pushViewController(SettingsBusinessViewController(), animated: true)
    }

    @objc private func openNotifications() {
        navigationController?.pushViewController(SettingsNotificationsViewController(), animated: true)
    }

    @objc private func openSecurity() {
        navigationController?.pushViewController(SettingsSecurityViewController(), animated: true)
    }

    @objc private func openPreferences() {
        navigationController?.pushViewController(SettingsPreferencesViewController(), animated: true)
    }

    private func divider() -> UIView {
        let line = UIView()
        line.backgroundColor = AppColors.divider
        line.constrainHeight(1)
        line.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return line
    }
}
