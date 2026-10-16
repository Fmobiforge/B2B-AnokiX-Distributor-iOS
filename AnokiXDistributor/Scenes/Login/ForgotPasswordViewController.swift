import UIKit

/// Dedicated "Forgot password" screen reached from the login form. Collects an email and
/// calls POST /api/common/forgot-password (portal_type=distributor). Mirrors the Android
/// ForgotPasswordActivity: a dark branded header over a white card with a form + success state.
final class ForgotPasswordViewController: UIViewController {

    private let card = UIView()
    private let emailField = UITextField()
    /// Auth CTA — the portal's 3-stop gradient pill.
    private let submitButton = GradientButton(title: S.sendResetLink)
    private let formStack = UIStackView.vertical(spacing: 0, alignment: .fill)
    private let successStack = UIStackView.vertical(spacing: 0, alignment: .center)
    private let successMessageLabel = UILabel()

    /// Present over the given screen (matching the login visual style).
    static func open(from presenter: UIViewController) {
        let vc = ForgotPasswordViewController()
        vc.modalPresentationStyle = .fullScreen
        presenter.present(vc, animated: true)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.loginBg
        buildCard()
        buildHeader()
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    // MARK: - Layout

    private func buildHeader() {
        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark"), for: .normal)
        close.tintColor = .white
        close.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        close.forAutoLayout()
        view.addSubview(close)

        let logo = UIImageView(image: BrandAssets.logoWhite)
        logo.contentMode = .scaleAspectFit
        logo.setContentHuggingPriority(.required, for: .vertical)

        let subtitle = UILabel()
        subtitle.text = S.loginSubtitle
        subtitle.font = AppFonts.regular(AppMetrics.textHeadline)
        subtitle.textColor = .white

        let brandStack = UIStackView.vertical(spacing: 16, alignment: .center)
        brandStack.addArrangedSubview(logo)
        brandStack.addArrangedSubview(subtitle)
        brandStack.forAutoLayout()
        view.addSubview(brandStack)

        // Center the brand block in the dark area between the safe-area top and the card.
        let topArea = UILayoutGuide()
        view.addLayoutGuide(topArea)

        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            close.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppMetrics.spacingLG),
            close.widthAnchor.constraint(equalToConstant: 44),
            close.heightAnchor.constraint(equalToConstant: 44),

            topArea.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topArea.bottomAnchor.constraint(equalTo: card.topAnchor),

            logo.widthAnchor.constraint(lessThanOrEqualToConstant: 200),
            brandStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            brandStack.centerYAnchor.constraint(equalTo: topArea.centerYAnchor),
            brandStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            brandStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func buildCard() {
        card.backgroundColor = AppColors.surface
        card.layer.cornerRadius = 24
        card.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        card.forAutoLayout()
        view.addSubview(card)

        let content = UIStackView.vertical(spacing: 0, alignment: .fill)
        content.forAutoLayout()
        card.addSubview(content)

        buildFormState()
        buildSuccessState()
        content.addArrangedSubview(formStack)
        content.addArrangedSubview(successStack)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 28),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            content.bottomAnchor.constraint(equalTo: card.safeAreaLayoutGuide.bottomAnchor, constant: -28)
        ])
    }

    private func buildFormState() {
        let title = UILabel()
        title.text = S.forgotPasswordTitle
        title.font = AppFonts.bold(AppMetrics.textHeadline)
        title.textColor = AppColors.textPrimary

        let subtitle = UILabel()
        subtitle.text = S.forgotPasswordSubtitle
        subtitle.font = AppFonts.regular(AppMetrics.textBody)
        subtitle.textColor = AppColors.textSecondary
        subtitle.numberOfLines = 0

        let emailLabel = UILabel()
        emailLabel.text = S.emailAddressLabel
        emailLabel.font = AppFonts.regular(AppMetrics.textBody)
        emailLabel.textColor = AppColors.textPrimary

        emailField.placeholder = "cong@anokix.co.za"
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        emailField.returnKeyType = .done
        emailField.delegate = self
        emailField.font = AppFonts.regular(14)
        emailField.textColor = AppColors.textPrimary
        emailField.layer.cornerRadius = AppMetrics.radiusSM
        emailField.layer.borderWidth = 1
        emailField.layer.borderColor = AppColors.border.cgColor
        emailField.leftView = fieldIcon("envelope")
        emailField.leftViewMode = .always
        emailField.forAutoLayout()
        emailField.heightAnchor.constraint(equalToConstant: 48).isActive = true

        submitButton.setTitle(S.sendResetLink, for: .normal)
        submitButton.titleLabel?.font = AppFonts.bold(15)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        submitButton.forAutoLayout()
        submitButton.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let backLink = UIButton(type: .system)
        backLink.setTitle(S.backToLogin, for: .normal)
        backLink.titleLabel?.font = AppFonts.semibold(13)
        backLink.setTitleColor(AppColors.purplePrimary, for: .normal)
        backLink.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)

        formStack.addArrangedSubview(title)
        formStack.setCustomSpacing(10, after: title)
        formStack.addArrangedSubview(subtitle)
        formStack.setCustomSpacing(24, after: subtitle)
        formStack.addArrangedSubview(emailLabel)
        formStack.setCustomSpacing(5, after: emailLabel)
        formStack.addArrangedSubview(emailField)
        formStack.setCustomSpacing(24, after: emailField)
        formStack.addArrangedSubview(submitButton)
        formStack.setCustomSpacing(18, after: submitButton)
        formStack.addArrangedSubview(backLink)
    }

    private func buildSuccessState() {
        successStack.isHidden = true

        let circle = UIView()
        circle.backgroundColor = AppColors.success
        circle.layer.cornerRadius = 36
        circle.forAutoLayout()
        circle.widthAnchor.constraint(equalToConstant: 72).isActive = true
        circle.heightAnchor.constraint(equalToConstant: 72).isActive = true

        let check = UIImageView(image: UIImage(systemName: "checkmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)))
        check.tintColor = .white
        check.contentMode = .center
        check.forAutoLayout()
        circle.addSubview(check)
        check.pinEdges(to: circle)

        let title = UILabel()
        title.text = S.resetLinkSentTitle
        title.font = AppFonts.bold(22)
        title.textColor = AppColors.textPrimary

        successMessageLabel.font = AppFonts.regular(AppMetrics.textBody)
        successMessageLabel.textColor = AppColors.textSecondary
        successMessageLabel.numberOfLines = 0
        successMessageLabel.textAlignment = .center

        let doneButton = GradientButton(title: S.backToLogin)
        doneButton.titleLabel?.font = AppFonts.bold(15)
        doneButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        doneButton.forAutoLayout()
        doneButton.heightAnchor.constraint(equalToConstant: 48).isActive = true

        successStack.addArrangedSubview(circle)
        successStack.setCustomSpacing(20, after: circle)
        successStack.addArrangedSubview(title)
        successStack.setCustomSpacing(10, after: title)
        successStack.addArrangedSubview(successMessageLabel)
        successStack.setCustomSpacing(28, after: successMessageLabel)
        successStack.addArrangedSubview(doneButton)

        // The button should span the card width even though the stack is center-aligned.
        doneButton.leadingAnchor.constraint(equalTo: successStack.leadingAnchor).isActive = true
        doneButton.trailingAnchor.constraint(equalTo: successStack.trailingAnchor).isActive = true
        successMessageLabel.leadingAnchor.constraint(equalTo: successStack.leadingAnchor).isActive = true
        successMessageLabel.trailingAnchor.constraint(equalTo: successStack.trailingAnchor).isActive = true
    }

    private func fieldIcon(_ systemName: String) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 42, height: 20))
        let icon = UIImageView(image: UIImage(systemName: systemName))
        icon.tintColor = AppColors.textSecondary
        icon.contentMode = .scaleAspectFit
        icon.frame = CGRect(x: 14, y: 0, width: 20, height: 20)
        container.addSubview(icon)
        return container
    }

    // MARK: - Actions

    @objc private func dismissSelf() { dismiss(animated: true) }

    @objc private func submitTapped() {
        view.endEditing(true)
        let email = emailField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !email.isEmpty else { toast(S.enterEmailPrompt); return }
        guard isValidEmail(email) else { toast(S.enterValidEmail); return }

        submitButton.isEnabled = false
        submitButton.setTitle(S.sending, for: .normal)

        ApiClient.shared.forgotPassword(email: email) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.showSuccess(email)
            case .failure(let error):
                self.submitButton.isEnabled = true
                self.submitButton.setTitle(S.sendResetLink, for: .normal)
                self.toast(error.message)
            }
        }
    }

    private func showSuccess(_ email: String) {
        successMessageLabel.text = S.resetLinkSentMessage(email)
        UIView.transition(with: view, duration: 0.2, options: .transitionCrossDissolve) {
            self.formStack.isHidden = true
            self.successStack.isHidden = false
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private func toast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { alert.dismiss(animated: true) }
    }
}

extension ForgotPasswordViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        submitTapped()
        return true
    }
}
