import UIKit

final class SettingsProfileViewController: BaseSettingsFormViewController {

    override var screenTitle: String { S.settingsProfileTitle }
    override var screenSubtitle: String? { S.settingsProfileSub }

    private let firstNameField = UITextField()
    private let lastNameField = UITextField()
    private let emailField = UITextField()
    private let phoneField = UITextField()
    private let avatarLabel = UILabel()
    private let displayNameLabel = UILabel()
    private let companyLabel = UILabel()

    override func setupForm(in card: UIView) {
        avatarLabel.font = AppFonts.bold(22)
        avatarLabel.textColor = AppColors.purplePrimary
        avatarLabel.textAlignment = .center
        avatarLabel.backgroundColor = AppColors.purpleLight
        avatarLabel.layer.cornerRadius = 28
        avatarLabel.layer.masksToBounds = true
        avatarLabel.constrainSize(56)

        displayNameLabel.font = AppFonts.bold(14)
        displayNameLabel.textColor = AppColors.textPrimary
        companyLabel.font = AppFonts.regular(12)
        companyLabel.textColor = AppColors.textSecondary

        let textStack = UIStackView.vertical(spacing: 2, alignment: .leading)
        textStack.addArrangedSubview(displayNameLabel)
        textStack.addArrangedSubview(companyLabel)

        let headerRow = UIStackView.horizontal(spacing: 12, alignment: .center)
        headerRow.addArrangedSubview(avatarLabel)
        headerRow.addArrangedSubview(textStack)

        let divider = ListScreenLayout.hairline()

        let stack = UIStackView.vertical(spacing: 0, alignment: .fill)
        stack.addArrangedSubview(headerRow)
        stack.addArrangedSubview(divider)
        stack.setCustomSpacing(16, after: headerRow)
        stack.setCustomSpacing(12, after: divider)
        stack.addArrangedSubview(settingsFieldGroup(S.firstNameReq, firstNameField, placeholder: ""))
        stack.addArrangedSubview(settingsFieldGroup(S.lastNameReq, lastNameField, placeholder: ""))
        stack.addArrangedSubview(settingsFieldGroup(S.emailReq, emailField, placeholder: "", keyboard: .emailAddress))
        stack.addArrangedSubview(settingsFieldGroup(S.phoneLabel, phoneField, placeholder: S.phoneHint, keyboard: .phonePad))

        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
    }

    override func loadData() {
        let data = repository.getProfileSettings()
        let session = SessionManager.shared
        let firstName = session.firstName.isEmpty ? data.firstName : session.firstName
        let lastName = session.lastName.isEmpty ? data.lastName : session.lastName
        let email = session.email.isEmpty ? data.email : session.email
        let displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)

        avatarLabel.text = initialsOf(displayName.isEmpty ? data.firstName + " " + data.lastName : displayName)
        displayNameLabel.text = displayName.isEmpty ? "\(data.firstName) \(data.lastName)" : displayName
        companyLabel.text = data.companyName
        firstNameField.text = firstName
        lastNameField.text = lastName
        emailField.text = email
        phoneField.text = data.phone
    }

    override func onSave() {
        let firstName = firstNameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let lastName = lastNameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let email = emailField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let phone = phoneField.text?.trimmingCharacters(in: .whitespaces) ?? ""

        if firstName.isEmpty { toast(S.errFirstNameSettings); return }
        if lastName.isEmpty { toast(S.errLastNameSettings); return }
        if email.isEmpty { toast(S.errEmailSettings); return }

        let current = repository.getProfileSettings()
        repository.saveProfileSettings(ProfileSettings(
            firstName: firstName, lastName: lastName, email: email, phone: phone, companyName: current.companyName))
        SessionManager.shared.setUser(firstName: firstName, lastName: lastName, email: email,
                                      roleLabel: SessionManager.shared.roleLabel)
        settingsSavedToast()
        navigationController?.popViewController(animated: true)
    }

    private func initialsOf(_ name: String) -> String {
        let parts = name.trimmingCharacters(in: .whitespaces).split(separator: " ")
        var result = ""
        for part in parts where result.count < 2 {
            if let first = part.first { result.append(first) }
        }
        return result.isEmpty ? "?" : result.uppercased()
    }
}
