import UIKit
import MessageUI

/// Port of WelcomeActivity + activity_welcome.xml. Shown after the splash when the
/// user is not logged in.
///
/// Login / Sign In → the storyboard login flow.
/// Create Account  → Distributor registration (to be implemented later).
/// Support Centre  → opens the device mail composer / mail app to the support team.
final class WelcomeViewController: UIViewController, MFMailComposeViewControllerDelegate {

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.loginBg
        buildLayout()
    }

    private func buildLayout() {
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = false
        scroll.forAutoLayout()
        view.addSubview(scroll)
        scroll.pinEdges(to: view)

        let content = UIStackView.vertical(spacing: 0, alignment: .fill)
        content.forAutoLayout()
        scroll.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -24),
            content.heightAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.heightAnchor)
        ])

        // Storefront illustration tile.
        let iconTile = UIView()
        iconTile.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        iconTile.layer.cornerRadius = 28
        iconTile.constrainSize(140)
        let storefront = UIImageView(image: UIImage(systemName: "storefront.fill")
                                     ?? UIImage(systemName: "building.2.fill"))
        storefront.tintColor = AppColors.purpleTextLight
        storefront.contentMode = .scaleAspectFit
        storefront.forAutoLayout()
        iconTile.addSubview(storefront)
        NSLayoutConstraint.activate([
            storefront.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            storefront.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor),
            storefront.widthAnchor.constraint(equalToConstant: 76),
            storefront.heightAnchor.constraint(equalToConstant: 76)
        ])
        let iconRow = UIStackView.horizontal(spacing: 0, alignment: .center)
        iconRow.distribution = .equalCentering
        iconRow.addArrangedSubview(UIView())
        iconRow.addArrangedSubview(iconTile)
        iconRow.addArrangedSubview(UIView())

        let title = UILabel.make(S.welcomeTitle, font: AppFonts.bold(28), color: .white, align: .center)
        let tagline = UILabel.make(S.welcomeTagline, font: AppFonts.regular(15),
                                   color: UIColor(hex: 0x8A93B2), align: .center, lines: 0)

        let topSpacer = UIView()
        let midSpacer = UIView()

        let loginButton = GradientButton(title: S.welcomeLogin)
        loginButton.constrainHeight(56)
        loginButton.addTarget(self, action: #selector(goToLogin), for: .touchUpInside)

        let createButton = UIButton(type: .system)
        createButton.setTitle(S.welcomeCreateAccount, for: .normal)
        createButton.setTitleColor(AppColors.success, for: .normal)
        createButton.titleLabel?.font = AppFonts.bold(16)
        createButton.layer.cornerRadius = 28
        createButton.layer.borderWidth = 1.5
        createButton.layer.borderColor = UIColor(hex: 0x2B3B63).cgColor
        createButton.constrainHeight(56)
        createButton.addTarget(self, action: #selector(createAccount), for: .touchUpInside)

        let signInRow = makeSignInRow()
        let supportRow = makeSupportRow()

        [topSpacer,
         iconRow,
         spacer(24), title,
         spacer(14), tagline,
         midSpacer,
         loginButton,
         spacer(14), createButton,
         spacer(22), signInRow,
         spacer(10), supportRow,
         spacer(28)].forEach { content.addArrangedSubview($0) }

        // Keep the buttons anchored toward the bottom like the Android layout.
        topSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
        midSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        topSpacer.heightAnchor.constraint(equalTo: midSpacer.heightAnchor).isActive = true
    }

    private func spacer(_ height: CGFloat) -> UIView {
        let v = UIView()
        v.constrainHeight(height)
        return v
    }

    private func makeSignInRow() -> UIView {
        let prompt = UILabel.make(S.welcomeHaveAccount, font: AppFonts.regular(14), color: UIColor(hex: 0x8A93B2))
        let signIn = UILabel.make(S.welcomeSignIn, font: AppFonts.bold(14), color: UIColor(hex: 0x5B8DEF))
        signIn.isUserInteractionEnabled = true
        signIn.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(goToLogin)))
        let row = UIStackView.horizontal(spacing: 0, alignment: .center)
        row.distribution = .equalCentering
        let inner = UIStackView.horizontal(spacing: 2, alignment: .center)
        inner.addArrangedSubview(prompt)
        inner.addArrangedSubview(signIn)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(inner)
        row.addArrangedSubview(UIView())
        return row
    }

    private func makeSupportRow() -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "headphones"))
        icon.tintColor = UIColor(hex: 0x8A93B2)
        icon.contentMode = .scaleAspectFit
        icon.constrainSize(18)
        let prompt = UILabel.make(S.welcomeNeedHelp, font: AppFonts.regular(14), color: UIColor(hex: 0x8A93B2))
        let support = UILabel.make(S.welcomeSupportCentre, font: AppFonts.bold(14), color: UIColor(hex: 0x5B8DEF))

        let inner = UIStackView.horizontal(spacing: 6, alignment: .center)
        inner.addArrangedSubview(icon)
        inner.addArrangedSubview(prompt)
        inner.addArrangedSubview(support)
        inner.isUserInteractionEnabled = true
        inner.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openSupport)))

        let row = UIStackView.horizontal(spacing: 0, alignment: .center)
        row.distribution = .equalCentering
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(inner)
        row.addArrangedSubview(UIView())
        return row
    }

    // MARK: - Actions

    @objc private func goToLogin() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let login = storyboard.instantiateViewController(withIdentifier: "LoginNavigationController")
        SceneDelegate.setRoot(login)
    }

    @objc private func createAccount() {
        toast(S.distributorRegisterComingSoon)
    }

    @objc private func openSupport() {
        if MFMailComposeViewController.canSendMail() {
            let composer = MFMailComposeViewController()
            composer.mailComposeDelegate = self
            composer.setToRecipients([S.supportEmail])
            composer.setSubject(S.supportSubject)
            present(composer, animated: true)
        } else if let url = URL(string: "mailto:\(S.supportEmail)?subject=\(S.supportSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"),
                  UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            toast("No email app found on this device.")
        }
    }

    func mailComposeController(_ controller: MFMailComposeViewController,
                              didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }

    private func toast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { alert.dismiss(animated: true) }
    }
}

/// Pill button with the blue→purple welcome gradient (bg_welcome_login_gradient.xml).
final class GradientButton: UIButton {
    private let gradient = CAGradientLayer()

    init(title: String) {
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        setTitleColor(.white, for: .normal)
        titleLabel?.font = AppFonts.bold(16)
        gradient.colors = [UIColor(hex: 0x3B82F6).cgColor,
                           UIColor(hex: 0x6366F1).cgColor,
                           UIColor(hex: 0xA855F7).cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        layer.insertSublayer(gradient, at: 0)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        gradient.cornerRadius = bounds.height / 2
        layer.cornerRadius = bounds.height / 2
        clipsToBounds = true
    }
}
