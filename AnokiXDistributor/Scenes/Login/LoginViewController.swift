import UIKit

/// Login screen — layout and actions wired in Main.storyboard.
final class LoginViewController: UIViewController {

    @IBOutlet private weak var emailField: UITextField!
    @IBOutlet private weak var passwordField: UITextField!
    @IBOutlet private weak var loginButton: UIButton!
    @IBOutlet private weak var tabEmailButton: UIButton!
    @IBOutlet private weak var tabPhoneButton: UIButton!
    @IBOutlet private weak var togglePasswordButton: UIButton!

    private var passwordVisible = false
    /// Portal auth CTA: 3-stop gradient (#1E9DE6 → #4F8FF7 → #8B5CF6), fully rounded.
    private let loginGradient = CAGradientLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        StyleKit.applyInterFonts(in: view)
        styleTextFields()
        selectEmailTab()
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:)))
        view.addGestureRecognizer(tap)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        loginGradient.frame = loginButton.bounds
        loginGradient.cornerRadius = loginButton.bounds.height / 2
        CATransaction.commit()
        loginButton.layer.cornerRadius = loginButton.bounds.height / 2
    }

    private func styleTextFields() {
        [emailField, passwordField].forEach { field in
            field?.layer.cornerRadius = AppMetrics.radiusSM
            field?.layer.borderWidth = 1
            field?.layer.borderColor = AppColors.border.cgColor
            field?.font = AppFonts.regular(14)
            field?.textColor = AppColors.textPrimary
            field?.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
            field?.leftViewMode = .always
        }
        tabEmailButton.layer.cornerRadius = AppMetrics.radiusSM - 2
        tabPhoneButton.layer.cornerRadius = AppMetrics.radiusSM - 2
        tabEmailButton.titleLabel?.font = AppFonts.semibold(14)
        tabPhoneButton.titleLabel?.font = AppFonts.semibold(14)
        togglePasswordButton.tintColor = AppColors.textTertiary

        loginGradient.colors = [AppColors.authGradientStart.cgColor,
                                AppColors.authGradientCenter.cgColor,
                                AppColors.authGradientEnd.cgColor]
        loginGradient.startPoint = CGPoint(x: 0, y: 0.5)
        loginGradient.endPoint = CGPoint(x: 1, y: 0.5)
        loginButton.backgroundColor = .clear
        loginButton.layer.insertSublayer(loginGradient, at: 0)
        loginButton.clipsToBounds = true
        loginButton.titleLabel?.font = AppFonts.semibold(15)
        loginButton.layer.cornerRadius = 24
    }

    private func selectEmailTab() {
        tabEmailButton.backgroundColor = AppColors.surface
        tabEmailButton.layer.borderWidth = 1
        tabEmailButton.layer.borderColor = AppColors.purplePrimary.cgColor
        tabEmailButton.setTitleColor(AppColors.purplePrimary, for: .normal)
        tabPhoneButton.backgroundColor = .clear
        tabPhoneButton.layer.borderWidth = 0
        tabPhoneButton.setTitleColor(AppColors.textSecondary, for: .normal)
    }

    // MARK: - IBActions

    @IBAction private func selectEmailTapped(_ sender: UIButton) { selectEmailTab() }

    @IBAction private func selectPhoneTapped(_ sender: UIButton) {
        tabPhoneButton.backgroundColor = AppColors.surface
        tabPhoneButton.layer.borderWidth = 1
        tabPhoneButton.layer.borderColor = AppColors.purplePrimary.cgColor
        tabPhoneButton.setTitleColor(AppColors.purplePrimary, for: .normal)
        tabEmailButton.backgroundColor = .clear
        tabEmailButton.layer.borderWidth = 0
        tabEmailButton.setTitleColor(AppColors.textSecondary, for: .normal)
        toast("Phone login coming soon")
    }

    @IBAction private func togglePasswordTapped(_ sender: UIButton) {
        passwordVisible.toggle()
        passwordField.isSecureTextEntry = !passwordVisible
        let icon = passwordVisible ? "eye.slash" : "eye"
        togglePasswordButton.setImage(UIImage(systemName: icon), for: .normal)
    }

    @IBAction private func forgotTapped(_ sender: UIButton) {
        ForgotPasswordViewController.open(from: self)
    }
    @IBAction private func joinTapped(_ sender: UIButton) {
        RegisterDistributorViewController.open(from: self)
    }

    @IBAction private func loginTapped(_ sender: UIButton) {
        let email = emailField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let password = passwordField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !email.isEmpty, !password.isEmpty else {
            toast("Please enter email and password"); return
        }
        loginButton.isEnabled = false
        loginButton.setTitle(S.signingIn, for: .normal)

        ApiClient.shared.login(email: email, password: password) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                // Account awaiting approval: no token is issued — show the review screen
                // instead of proceeding into the app.
                if data.pendingApproval == true {
                    self.loginButton.isEnabled = true
                    self.loginButton.setTitle(S.loginButton, for: .normal)
                    PendingApprovalViewController.open(from: self, data: data)
                    return
                }
                SessionManager.shared.token = data.token ?? ""
                if let user = data.user {
                    SessionManager.shared.setUser(firstName: user.firstName, lastName: user.lastName,
                                                  email: user.email, roleLabel: user.roleLabel)
                    SessionManager.shared.phone = user.phoneNumber ?? ""
                }
                SessionManager.shared.companyLogoUrl = data.portalInfo?.companyLogoUrl ?? ""
                SessionManager.shared.companyName = data.portalInfo?.companyName ?? ""
                // FCM: ask for push permission and register this device's token now that we're signed in.
                PushManager.shared.requestAuthorization()
                PushManager.shared.registerCurrentToken()
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let main = storyboard.instantiateViewController(withIdentifier: "MainTabBarController")
                SceneDelegate.setRoot(main)
            case .failure(let error):
                self.loginButton.isEnabled = true
                self.loginButton.setTitle(S.loginButton, for: .normal)
                self.toast(error.message)
            }
        }
    }

    private func toast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { alert.dismiss(animated: true) }
    }
}
