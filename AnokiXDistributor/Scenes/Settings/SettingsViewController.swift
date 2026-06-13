import UIKit

/// Port of SettingsActivity. Profile card (session-aware), settings menu, notification toggles, Save.
final class SettingsViewController: BaseSecondaryViewController {

    override var screenTitle: String { S.settings }

    private var preferences: [NotificationPreference] = []

    override func setupContent(in container: UIView) {
        let stack = makeScrollStack(in: container)

        stack.addArrangedSubview(buildProfileCard(mergedProfile()))

        let menuCard = StyleKit.cardView()
        let menuStack = UIStackView.vertical(spacing: 0, alignment: .fill)
        menuStack.forAutoLayout()
        let entries = repository.getSettingsMenuEntries()
        for (i, entry) in entries.enumerated() {
            menuStack.addArrangedSubview(menuRow(entry))
            if i < entries.count - 1 { menuStack.addArrangedSubview(divider()) }
        }
        menuCard.addSubview(menuStack)
        menuStack.pinEdges(to: menuCard, insets: UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12))
        stack.addArrangedSubview(menuCard)

        stack.addArrangedSubview(UILabel.title("Notification Preferences"))
        preferences = repository.getNotificationPreferences()
        let prefCard = StyleKit.cardView()
        let prefStack = UIStackView.vertical(spacing: 0, alignment: .fill)
        prefStack.forAutoLayout()
        for (i, pref) in preferences.enumerated() {
            prefStack.addArrangedSubview(preferenceRow(pref, index: i))
            if i < preferences.count - 1 { prefStack.addArrangedSubview(divider()) }
        }
        prefCard.addSubview(prefStack)
        prefStack.pinEdges(to: prefCard, insets: UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12))
        stack.addArrangedSubview(prefCard)

        let save = UIButton(type: .system)
        StyleKit.stylePrimaryButton(save)
        save.setTitle(S.saveChanges, for: .normal)
        save.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        stack.addArrangedSubview(save)
    }

    override func loadData() {}

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

    private func buildProfileCard(_ profile: SettingsProfile) -> UIView {
        let card = StyleKit.cardView()
        let avatar = UILabel()
        avatar.text = profile.initials
        avatar.font = AppFonts.bold(22)
        avatar.textColor = AppColors.purplePrimary
        avatar.textAlignment = .center
        avatar.backgroundColor = AppColors.purpleLight
        avatar.layer.cornerRadius = 28
        avatar.layer.masksToBounds = true
        avatar.constrainSize(56)

        let name = UILabel.make(profile.name, font: AppFonts.bold(16), color: AppColors.textPrimary)
        let email = UILabel.make(profile.email, font: AppFonts.regular(12), color: AppColors.textSecondary)
        let textStack = UIStackView.vertical(spacing: 2, alignment: .leading)
        textStack.addArrangedSubview(name)
        textStack.addArrangedSubview(email)
        if profile.verified {
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
            textStack.addArrangedSubview(badgeRow)
        }

        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.forAutoLayout()
        row.addArrangedSubview(avatar)
        row.addArrangedSubview(textStack)
        card.addSubview(row)
        row.pinEdges(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        return card
    }

    private func menuRow(_ entry: SettingsMenuEntry) -> UIView {
        let icon = UIImageView(image: AppIcons.symbol(entry.icon))
        icon.tintColor = AppColors.purplePrimary
        icon.contentMode = .scaleAspectFit
        icon.constrainSize(22)
        let title = UILabel.make(entry.title, font: AppFonts.medium(14), color: AppColors.textPrimary)
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = AppColors.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.constrainSize(16)
        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        [icon, title, UIView(), chevron].forEach { row.addArrangedSubview($0) }
        let wrapper = UIView()
        wrapper.forAutoLayout()
        wrapper.constrainHeight(48)
        row.forAutoLayout()
        wrapper.addSubview(row)
        row.pinEdges(to: wrapper)
        wrapper.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(menuTapped(_:))))
        wrapper.isUserInteractionEnabled = true
        wrapper.accessibilityLabel = entry.title
        return wrapper
    }

    @objc private func menuTapped(_ gesture: UITapGestureRecognizer) {
        guard let title = gesture.view?.accessibilityLabel else { return }
        toast(title)
    }

    private func preferenceRow(_ pref: NotificationPreference, index: Int) -> UIView {
        let title = UILabel.make(pref.title, font: AppFonts.medium(14), color: AppColors.textPrimary)
        let subtitle = UILabel.make(pref.subtitle, font: AppFonts.regular(11), color: AppColors.textSecondary)
        let textStack = UIStackView.vertical(spacing: 2, alignment: .leading)
        textStack.addArrangedSubview(title)
        textStack.addArrangedSubview(subtitle)

        let toggle = UISwitch()
        toggle.isOn = pref.enabled
        toggle.onTintColor = AppColors.purplePrimary
        toggle.tag = index
        toggle.addTarget(self, action: #selector(preferenceToggled(_:)), for: .valueChanged)

        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.forAutoLayout()
        [textStack, UIView(), toggle].forEach { row.addArrangedSubview($0) }
        let wrapper = UIView()
        wrapper.addSubview(row)
        row.pinEdges(to: wrapper, insets: UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0))
        return wrapper
    }

    @objc private func preferenceToggled(_ sender: UISwitch) {
        guard preferences.indices.contains(sender.tag) else { return }
        preferences[sender.tag].enabled = sender.isOn
    }

    private func divider() -> UIView {
        let line = UIView()
        line.backgroundColor = AppColors.divider
        line.constrainHeight(1)
        return line
    }

    @objc private func saveTapped() {
        repository.saveNotificationPreferences(preferences)
        toast(S.saveChanges)
    }
}
