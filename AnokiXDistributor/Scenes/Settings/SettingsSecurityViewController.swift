import UIKit

final class SettingsSecurityViewController: BaseSettingsFormViewController {

    override var screenTitle: String { S.settingsSecurityTitle }
    override var screenSubtitle: String? { S.settingsSecuritySub }

    private let currentField = UITextField()
    private let newField = UITextField()
    private let confirmField = UITextField()

    override func setupForm(in card: UIView) {
        let stack = UIStackView.vertical(spacing: 0, alignment: .fill)
        stack.addArrangedSubview(settingsFieldGroup(S.currentPasswordLabel, currentField,
                                                    placeholder: S.currentPasswordHint, secure: true))
        stack.addArrangedSubview(settingsFieldGroup(S.newPasswordLabel, newField,
                                                    placeholder: S.newPasswordHint, secure: true))
        stack.addArrangedSubview(settingsFieldGroup(S.confirmPasswordLabel, confirmField,
                                                    placeholder: S.confirmPasswordHint, secure: true))

        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
    }

    private var isSaving = false

    override func onSave() {
        let current = currentField.text ?? ""
        let newPassword = newField.text ?? ""
        let confirm = confirmField.text ?? ""

        if current.isEmpty { toast(S.errCurrentPassword); return }
        if newPassword.count < 8 { toast(S.errPasswordLength); return }
        if newPassword != confirm { toast(S.errPasswordMatch); return }
        if isSaving { return }

        isSaving = true
        ApiClient.shared.changePassword(currentPassword: current, newPassword: newPassword) { [weak self] result in
            guard let self = self else { return }
            self.isSaving = false
            switch result {
            case .success:
                self.toast(S.settingsPasswordChanged)
                self.navigationController?.popViewController(animated: true)
            case .failure(let error):
                self.toast(error.message.isEmpty ? S.settingsGenericError : error.message)
            }
        }
    }
}
