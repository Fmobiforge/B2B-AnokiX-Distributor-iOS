import UIKit

/// Port of RegisterSubmittedActivity — the confirmation screen shown after a
/// successful distributor registration. A success check, a "What happens next?"
/// timeline, the estimated approval window, and a Back to Login action that resets
/// the app to the login flow (mirrors the Android CLEAR_TASK navigation).
final class RegisterSubmittedViewController: UIViewController {

    private let nextSteps: [(icon: String, label: String)] = [
        ("doc.text.fill", "We review your documents"),
        ("checkmark.shield.fill", "KYC & compliance verification"),
        ("person.fill.checkmark", "Distributor approval"),
        ("wallet.pass.fill", "Wallet activation")
    ]

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.background
        navigationController?.setNavigationBarHidden(true, animated: false)
        buildLayout()
    }

    private func buildLayout() {
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = false
        scroll.forAutoLayout()
        view.addSubview(scroll)

        let content = UIStackView.vertical(spacing: 16, alignment: .fill)
        content.isLayoutMarginsRelativeArrangement = true
        content.layoutMargins = UIEdgeInsets(top: 32, left: 24, bottom: 32, right: 24)
        content.forAutoLayout()
        scroll.addSubview(content)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: guide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor)
        ])

        // Success circle with check.
        let circle = UIView()
        circle.backgroundColor = AppColors.success
        circle.layer.cornerRadius = 48
        circle.constrainSize(96)
        let check = UIImageView(image: UIImage(systemName: "checkmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 44, weight: .bold)))
        check.tintColor = .white
        check.contentMode = .scaleAspectFit
        check.forAutoLayout()
        circle.addSubview(check)
        NSLayoutConstraint.activate([
            check.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            check.centerYAnchor.constraint(equalTo: circle.centerYAnchor)
        ])
        content.addArrangedSubview(centered(circle))

        content.addArrangedSubview(UILabel.make("Application Submitted!", font: AppFonts.bold(24),
            color: AppColors.textPrimary, align: .center, lines: 0))
        content.addArrangedSubview(UILabel.make(
            "Thank you for registering. Your application is now under review by our team.",
            font: AppFonts.regular(14), color: AppColors.textSecondary, align: .center, lines: 0))

        // "What happens next?" panel.
        let panel = UIStackView.vertical(spacing: 4, alignment: .fill)
        panel.isLayoutMarginsRelativeArrangement = true
        panel.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        panel.backgroundColor = AppColors.surface
        panel.layer.cornerRadius = AppMetrics.radiusMD
        panel.layer.borderWidth = 1
        panel.layer.borderColor = AppColors.border.cgColor
        panel.addArrangedSubview(UILabel.make("What happens next?", font: AppFonts.bold(16),
            color: AppColors.purpleDark, lines: 0))
        for (i, step) in nextSteps.enumerated() {
            panel.addArrangedSubview(nextStepRow(index: i + 1, icon: step.icon, text: step.label))
        }
        content.addArrangedSubview(panel)

        // Estimated approval window.
        let approval = UIStackView.horizontal(spacing: 10, alignment: .center)
        approval.isLayoutMarginsRelativeArrangement = true
        approval.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        approval.backgroundColor = AppColors.infoBg
        approval.layer.cornerRadius = AppMetrics.radiusMD
        let clock = UIImageView(image: UIImage(systemName: "clock.fill"))
        clock.tintColor = AppColors.info
        clock.contentMode = .scaleAspectFit
        clock.constrainSize(20)
        let approvalText = UIStackView.vertical(spacing: 2, alignment: .leading)
        approvalText.addArrangedSubview(UILabel.make("Estimated approval time", font: AppFonts.bold(13),
            color: AppColors.info))
        approvalText.addArrangedSubview(UILabel.make("2–3 business days", font: AppFonts.regular(12),
            color: AppColors.textSecondary))
        approval.addArrangedSubview(clock)
        approval.addArrangedSubview(approvalText)
        approval.addArrangedSubview(UIView())
        content.addArrangedSubview(approval)

        let backButton = GradientButton(title: "Back to Login")
        backButton.constrainHeight(54)
        backButton.addTarget(self, action: #selector(backToLogin), for: .touchUpInside)
        content.addArrangedSubview(spacer(8))
        content.addArrangedSubview(backButton)
    }

    private func nextStepRow(index: Int, icon: String, text: String) -> UIView {
        let tile = UIView()
        tile.backgroundColor = AppColors.purpleLight
        tile.layer.cornerRadius = AppMetrics.radiusSM
        tile.constrainSize(40)
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = AppColors.purplePrimary
        iconView.contentMode = .scaleAspectFit
        iconView.forAutoLayout()
        tile.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20)
        ])

        let badge = UILabel.make("\(index)", font: AppFonts.bold(13), color: AppColors.purplePrimary)
        badge.constrainSize(22)
        let label = UILabel.make(text, font: AppFonts.medium(14), color: AppColors.textPrimary, lines: 0)
        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        row.addArrangedSubview(badge)
        row.addArrangedSubview(tile)
        row.addArrangedSubview(label)
        return row
    }

    private func centered(_ inner: UIView) -> UIView {
        let container = UIView()
        inner.forAutoLayout()
        container.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            inner.topAnchor.constraint(equalTo: container.topAnchor),
            inner.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private func spacer(_ height: CGFloat) -> UIView {
        let v = UIView()
        v.constrainHeight(height)
        return v
    }

    @objc private func backToLogin() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let login = storyboard.instantiateViewController(withIdentifier: "LoginNavigationController")
        SceneDelegate.setRoot(login)
    }
}
