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

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
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

    private func styleTextFields() {
        [emailField, passwordField].forEach { field in
            field?.layer.cornerRadius = AppMetrics.radiusMD
            field?.layer.borderWidth = 1
            field?.layer.borderColor = AppColors.border.cgColor
            field?.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
            field?.leftViewMode = .always
        }
        tabEmailButton.layer.cornerRadius = AppMetrics.radiusMD - 2
        tabPhoneButton.layer.cornerRadius = AppMetrics.radiusMD - 2
        loginButton.layer.cornerRadius = AppMetrics.radiusMD
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
                SessionManager.shared.token = data.token ?? ""
                if let user = data.user {
                    SessionManager.shared.setUser(firstName: user.firstName, lastName: user.lastName,
                                                  email: user.email, roleLabel: user.roleLabel)
                }
                SessionManager.shared.companyLogoUrl = data.portalInfo?.companyLogoUrl ?? ""
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
