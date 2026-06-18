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

    override func onSave() {
        let current = currentField.text ?? ""
        let newPassword = newField.text ?? ""
        let confirm = confirmField.text ?? ""
        if let error = repository.changePassword(current: current, newPassword: newPassword, confirm: confirm) {
            toast(error)
            return
        }
        settingsSavedToast()
        navigationController?.popViewController(animated: true)
    }
}
