import UIKit

/// Shared scroll form + Cancel/Save footer for settings detail screens.
class BaseSettingsFormViewController: BaseSecondaryViewController {

    let formScroll = UIScrollView()
    let formStack = UIStackView()

    override func setupContent(in container: UIView) {
        let divider = ListScreenLayout.hairline()
        let footer = UIView()
        footer.backgroundColor = AppColors.surface
        footer.forAutoLayout()
        divider.forAutoLayout()

        let cancelButton = UIButton(type: .system)
        StyleKit.styleOutlinedButton(cancelButton, fontSize: 14)
        cancelButton.setTitle(S.cancel, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let saveButton = UIButton(type: .system)
        StyleKit.stylePrimaryButton(saveButton, fontSize: 14)
        saveButton.setTitle(S.saveChanges, for: .normal)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        let buttonRow = UIStackView(arrangedSubviews: [cancelButton, saveButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 12
        buttonRow.alignment = .center
        buttonRow.distribution = .fillEqually
        buttonRow.forAutoLayout()
        footer.addSubview(buttonRow)

        formScroll.alwaysBounceVertical = true
        formScroll.showsVerticalScrollIndicator = false
        formScroll.forAutoLayout()
        formStack.axis = .vertical
        formStack.spacing = 12
        formStack.alignment = .fill
        formStack.forAutoLayout()
        formScroll.addSubview(formStack)

        container.addSubviews(formScroll, divider, footer)

        NSLayoutConstraint.activate([
            formScroll.topAnchor.constraint(equalTo: container.topAnchor),
            formScroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            formScroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            formScroll.bottomAnchor.constraint(equalTo: divider.topAnchor),

            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: footer.topAnchor),

            footer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            buttonRow.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 16),
            buttonRow.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -16),
            buttonRow.topAnchor.constraint(equalTo: footer.topAnchor, constant: 12),
            buttonRow.bottomAnchor.constraint(equalTo: footer.bottomAnchor, constant: -12),
            cancelButton.heightAnchor.constraint(equalToConstant: 46),
            saveButton.heightAnchor.constraint(equalToConstant: 46),

            formStack.topAnchor.constraint(equalTo: formScroll.contentLayoutGuide.topAnchor, constant: 16),
            formStack.leadingAnchor.constraint(equalTo: formScroll.frameLayoutGuide.leadingAnchor, constant: 16),
            formStack.trailingAnchor.constraint(equalTo: formScroll.frameLayoutGuide.trailingAnchor, constant: -16),
            formStack.bottomAnchor.constraint(equalTo: formScroll.contentLayoutGuide.bottomAnchor, constant: -24)
        ])

        let card = StyleKit.cardView()
        card.forAutoLayout()
        formStack.addArrangedSubview(card)
        setupForm(in: card)
    }

    func setupForm(in card: UIView) {}

    func onSave() {}

    func settingsFieldGroup(_ label: String, _ field: UITextField, placeholder: String,
                            keyboard: UIKeyboardType = .default, secure: Bool = false) -> UIStackView {
        StyleKit.styleInput(field)
        field.placeholder = placeholder
        field.keyboardType = keyboard
        field.isSecureTextEntry = secure
        if keyboard == .emailAddress { field.autocapitalizationType = .none }
        let title = UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textPrimary)
        let stack = UIStackView.vertical(spacing: 5, alignment: .fill)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(field)
        return stack
    }

    func settingsSavedToast() {
        toast(S.settingsSaved)
    }

    @objc private func cancelTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func saveTapped() {
        onSave()
    }
}
