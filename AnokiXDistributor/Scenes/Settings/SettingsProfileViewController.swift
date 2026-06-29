import UIKit

/// Profile Settings — loads the account from GET api/common/base-info and saves edits via
/// POST api/common/profile/update (1-Settings-Profile.png).
final class SettingsProfileViewController: BaseSettingsFormViewController {

    override var screenTitle: String { S.settingsProfileTitle }
    override var screenSubtitle: String? { S.settingsProfileSub }

    private let firstNameField = UITextField()
    private let lastNameField = UITextField()
    private let emailField = UITextField()
    private let phoneField = UITextField()
    private var phoneCountry = Countries.default
    private let phoneCountryButton = UIButton(type: .system)
    private let avatarLabel = UILabel()
    private let displayNameLabel = UILabel()
    private let companyLabel = UILabel()
    private var companyName = ""
    private var isSaving = false

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
        stack.addArrangedSubview(phoneGroup(S.phoneLabel))

        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
    }

    override func loadData() {
        let session = SessionManager.shared
        bindFields(first: session.firstName, last: session.lastName, email: session.email, phone: "")

        ApiClient.shared.getBaseInfo { [weak self] result in
            guard let self = self, case .success(let data) = result else { return }
            self.companyName = data.portalInfo?.companyLegalName ?? ""
            if let user = data.user {
                self.bindFields(first: user.firstName ?? "", last: user.lastName ?? "",
                                email: user.email ?? "", phone: user.phoneNumber ?? "")
            } else {
                self.companyLabel.text = self.companyName
            }
        }
    }

    private func bindFields(first: String, last: String, email: String, phone: String) {
        let displayName = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        avatarLabel.text = initialsOf(displayName)
        displayNameLabel.text = displayName
        companyLabel.text = companyName
        firstNameField.text = first
        lastNameField.text = last
        emailField.text = email
        let (country, number) = splitPhone(phone)
        phoneCountry = country
        configureCountryButton(phoneCountryButton, country: country)
        phoneField.text = number
    }

    override func onSave() {
        let firstName = firstNameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let lastName = lastNameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let email = emailField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let phone = fullPhone(phoneCountry, phoneField)

        if firstName.isEmpty { toast(S.errFirstNameSettings); return }
        if lastName.isEmpty { toast(S.errLastNameSettings); return }
        if email.isEmpty { toast(S.errEmailSettings); return }
        if isSaving { return }

        isSaving = true
        ApiClient.shared.updateProfile(firstName: firstName, lastName: lastName, email: email, phone: phone) { [weak self] result in
            guard let self = self else { return }
            self.isSaving = false
            switch result {
            case .success:
                SessionManager.shared.setUser(firstName: firstName, lastName: lastName,
                                              email: email, roleLabel: SessionManager.shared.roleLabel)
                self.settingsSavedToast()
                self.navigationController?.popViewController(animated: true)
            case .failure(let error):
                self.toast(error.message.isEmpty ? S.settingsGenericError : error.message)
            }
        }
    }

    private func initialsOf(_ name: String) -> String {
        let parts = name.trimmingCharacters(in: .whitespaces).split(separator: " ")
        var result = ""
        for part in parts where result.count < 2 {
            if let first = part.first { result.append(first) }
        }
        return result.isEmpty ? "?" : result.uppercased()
    }

    // MARK: - Phone (country picker, matching Android)

    private func phoneGroup(_ label: String) -> UIStackView {
        configureCountryButton(phoneCountryButton, country: phoneCountry)
        phoneCountryButton.addAction(UIAction { [weak self] _ in self?.pickCountry() }, for: .touchUpInside)

        phoneField.placeholder = "Phone number"
        phoneField.keyboardType = .phonePad
        phoneField.font = AppFonts.regular(14)
        phoneField.textColor = AppColors.textPrimary

        let container = UIView()
        container.backgroundColor = AppColors.surface
        container.layer.cornerRadius = AppMetrics.radiusMD
        container.layer.borderWidth = 1
        container.layer.borderColor = AppColors.border.cgColor
        container.constrainHeight(45)
        let divider = UIView()
        divider.backgroundColor = AppColors.border
        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.forAutoLayout()
        phoneCountryButton.setContentHuggingPriority(.required, for: .horizontal)
        phoneField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(phoneCountryButton)
        row.addArrangedSubview(divider)
        row.addArrangedSubview(phoneField)
        container.addSubview(row)
        row.pinEdges(to: container, insets: UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 12))
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true
        divider.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let stack = UIStackView.vertical(spacing: 5, alignment: .fill)
        stack.addArrangedSubview(UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textPrimary))
        stack.addArrangedSubview(container)
        return stack
    }

    private func configureCountryButton(_ button: UIButton, country: Country) {
        var config = UIButton.Configuration.plain()
        config.title = "\(country.flag) \(country.dialCode)"
        config.image = UIImage(systemName: "chevron.down")
        config.imagePlacement = .trailing
        config.imagePadding = 4
        config.baseForegroundColor = AppColors.textPrimary
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 10, weight: .regular)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.regular(14); return out
        }
        button.configuration = config
    }

    private func pickCountry() {
        let picker = CountryPickerViewController()
        picker.onSelect = { [weak self] country in
            guard let self = self else { return }
            self.phoneCountry = country
            self.configureCountryButton(self.phoneCountryButton, country: country)
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }

    private func fullPhone(_ country: Country, _ field: UITextField) -> String {
        var number = (field.text ?? "").filter { $0.isNumber }
        if number.isEmpty { return "" }
        if number.hasPrefix("0") { number.removeFirst() }
        return country.dialCode + number
    }

    private func splitPhone(_ raw: String?) -> (Country, String) {
        let value = (raw ?? "").trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("+") {
            let match = Countries.all
                .filter { value.hasPrefix($0.dialCode) }
                .max { $0.dialCode.count < $1.dialCode.count }
            if let c = match {
                return (c, String(value.dropFirst(c.dialCode.count)).filter { $0.isNumber })
            }
        }
        return (Countries.default, value.filter { $0.isNumber })
    }
}
