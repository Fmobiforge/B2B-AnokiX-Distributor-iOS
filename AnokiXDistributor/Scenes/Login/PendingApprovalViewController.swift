import UIKit

/// Shown when `POST api/common/login` returns `pending_approval=true`: the distributor
/// account has been registered but is still awaiting approval, so no token is issued.
/// Mirrors the web portal "Application Under Review" screen (newDesign/Login/Screenshot_6.png),
/// adapted to the app's light theme. Parity with Android's PendingApprovalActivity.
final class PendingApprovalViewController: UIViewController {

    private let data: LoginData

    private let nextSteps = [
        "We verify your business details and uploaded documents.",
        "You'll get an email as soon as your account is approved.",
        "Sign in again once approved to reach your dashboard."
    ]

    init(data: LoginData) {
        self.data = data
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Present over the login screen; Back to Login simply dismisses back to it.
    static func open(from presenter: UIViewController, data: LoginData) {
        let vc = PendingApprovalViewController(data: data)
        vc.modalPresentationStyle = .fullScreen
        presenter.present(vc, animated: true)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.surface
        navigationController?.setNavigationBarHidden(true, animated: false)
        buildLayout()
    }

    // MARK: - Layout

    private func buildLayout() {
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = false
        scroll.forAutoLayout()
        view.addSubview(scroll)

        let content = UIStackView.vertical(spacing: 0, alignment: .fill)
        content.isLayoutMarginsRelativeArrangement = true
        content.layoutMargins = UIEdgeInsets(top: 12, left: 24, bottom: 28, right: 24)
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

        // Back to login link.
        content.addArrangedSubview(backLink())
        content.setCustomSpacing(18, after: content.arrangedSubviews.last!)

        // Clock tile.
        let tile = UIView()
        tile.backgroundColor = AppColors.purplePrimary
        tile.layer.cornerRadius = 18
        tile.constrainSize(60)
        let clock = UIImageView(image: UIImage(systemName: "clock.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)))
        clock.tintColor = .white
        clock.contentMode = .scaleAspectFit
        clock.forAutoLayout()
        tile.addSubview(clock)
        NSLayoutConstraint.activate([
            clock.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            clock.centerYAnchor.constraint(equalTo: tile.centerYAnchor)
        ])
        content.addArrangedSubview(leading(tile))
        content.setCustomSpacing(18, after: content.arrangedSubviews.last!)

        // Title & subtitle.
        content.addArrangedSubview(UILabel.make("Application Under Review", font: AppFonts.bold(25),
            color: AppColors.textPrimary, lines: 0))
        content.setCustomSpacing(8, after: content.arrangedSubviews.last!)
        content.addArrangedSubview(UILabel.make(subtitleText(), font: AppFonts.regular(14),
            color: AppColors.textSecondary, lines: 0))
        content.setCustomSpacing(24, after: content.arrangedSubviews.last!)

        // Details card.
        content.addArrangedSubview(detailsCard())
        content.setCustomSpacing(14, after: content.arrangedSubviews.last!)

        // Wallet note (only while the wallet is not activated).
        if !isWalletActive {
            content.addArrangedSubview(walletNote())
            content.setCustomSpacing(26, after: content.arrangedSubviews.last!)
        } else {
            content.setCustomSpacing(26, after: content.arrangedSubviews.last!)
        }

        // What happens next.
        content.addArrangedSubview(UILabel.make("What happens next?", font: AppFonts.bold(16),
            color: AppColors.textPrimary))
        content.setCustomSpacing(12, after: content.arrangedSubviews.last!)
        for (i, step) in nextSteps.enumerated() {
            content.addArrangedSubview(nextStepRow(index: i + 1, text: step))
        }

        // Back to Login button.
        let backButton = GradientButton(title: "Back to Login")
        backButton.constrainHeight(52)
        backButton.addTarget(self, action: #selector(backToLogin), for: .touchUpInside)
        content.setCustomSpacing(24, after: content.arrangedSubviews.last!)
        content.addArrangedSubview(backButton)

        // Need help footer.
        content.setCustomSpacing(18, after: content.arrangedSubviews.last!)
        content.addArrangedSubview(helpFooter())
    }

    // MARK: - Pieces

    private func backLink() -> UIView {
        let arrow = UIImageView(image: UIImage(systemName: "arrow.left",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)))
        arrow.tintColor = AppColors.purplePrimary
        arrow.contentMode = .scaleAspectFit
        arrow.constrainSize(18)
        let label = UILabel.make("Back to login", font: AppFonts.medium(14), color: AppColors.purplePrimary)
        let row = UIStackView.horizontal(spacing: 6, alignment: .center)
        row.addArrangedSubview(arrow)
        row.addArrangedSubview(label)
        let wrap = leading(row)
        row.isUserInteractionEnabled = true
        wrap.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backToLogin)))
        return wrap
    }

    private func detailsCard() -> UIView {
        let card = UIStackView.vertical(spacing: 0, alignment: .fill)
        card.isLayoutMarginsRelativeArrangement = true
        card.layoutMargins = UIEdgeInsets(top: 2, left: 18, bottom: 2, right: 18)
        card.backgroundColor = AppColors.surface
        card.layer.cornerRadius = AppMetrics.radiusLG
        card.layer.borderWidth = 1
        card.layer.borderColor = AppColors.border.cgColor

        // Status.
        card.addArrangedSubview(row(label: "Status", trailing: pill(
            "Pending Approval", textColor: AppColors.purplePrimary, background: AppColors.purpleLight)))
        card.addArrangedSubview(hairline())
        // Business.
        card.addArrangedSubview(row(label: "Business",
            trailing: valueLabel(data.businessName, align: .right)))
        card.addArrangedSubview(hairline())
        // Reference (monospaced).
        let refLabel = valueLabel(data.reference, align: .right)
        refLabel.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
        refLabel.textColor = AppColors.info
        card.addArrangedSubview(row(label: "Reference", trailing: refLabel))
        card.addArrangedSubview(hairline())
        // Submitted.
        card.addArrangedSubview(row(label: "Submitted",
            trailing: valueLabel(data.submittedAt, align: .right)))
        card.addArrangedSubview(hairline())
        // IMB Wallet.
        let walletPill = isWalletActive
            ? pill("Active", textColor: AppColors.success, background: AppColors.successBg)
            : pill("Not activated", textColor: AppColors.textSecondary, background: AppColors.borderLight)
        card.addArrangedSubview(row(label: "IMB Wallet", trailing: walletPill,
            leadingIcon: "wallet.pass"))
        return card
    }

    private func walletNote() -> UIView {
        let container = UIView()
        container.backgroundColor = AppColors.purpleLight
        container.layer.cornerRadius = AppMetrics.radiusSM

        let accent = UIView()
        accent.backgroundColor = AppColors.purplePrimary
        accent.forAutoLayout()
        container.addSubview(accent)

        let text = UILabel.make(
            "You chose to activate your wallet later. You can set it up from your profile once your account is approved.",
            font: AppFonts.regular(13), color: AppColors.purpleDark, lines: 0)
        text.forAutoLayout()
        container.addSubview(text)

        NSLayoutConstraint.activate([
            accent.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            accent.topAnchor.constraint(equalTo: container.topAnchor),
            accent.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            accent.widthAnchor.constraint(equalToConstant: 4),
            text.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            text.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            text.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            text.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
        return container
    }

    private func nextStepRow(index: Int, text: String) -> UIView {
        let number = UILabel.make("\(index).", font: AppFonts.bold(14), color: AppColors.purplePrimary)
        number.setContentHuggingPriority(.required, for: .horizontal)
        number.widthAnchor.constraint(equalToConstant: 20).isActive = true
        let label = UILabel.make(text, font: AppFonts.regular(14), color: AppColors.textPrimary, lines: 0)
        let row = UIStackView.horizontal(spacing: 6, alignment: .top)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 7, left: 0, bottom: 7, right: 0)
        row.addArrangedSubview(number)
        row.addArrangedSubview(label)
        return row
    }

    private func helpFooter() -> UIView {
        let envelope = UIImageView(image: UIImage(systemName: "envelope"))
        envelope.tintColor = AppColors.textTertiary
        envelope.contentMode = .scaleAspectFit
        envelope.constrainSize(16)
        let help = UILabel.make("Need help? ", font: AppFonts.regular(13), color: AppColors.textSecondary)
        let email = UILabel.make("support@anokix.com", font: AppFonts.bold(13), color: AppColors.purplePrimary)
        email.isUserInteractionEnabled = true
        email.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(emailSupport)))
        let row = UIStackView.horizontal(spacing: 6, alignment: .center)
        row.addArrangedSubview(envelope)
        row.addArrangedSubview(help)
        row.addArrangedSubview(email)

        let wrap = UIView()
        row.forAutoLayout()
        wrap.addSubview(row)
        NSLayoutConstraint.activate([
            row.centerXAnchor.constraint(equalTo: wrap.centerXAnchor),
            row.topAnchor.constraint(equalTo: wrap.topAnchor),
            row.bottomAnchor.constraint(equalTo: wrap.bottomAnchor)
        ])
        return wrap
    }

    // MARK: - Row helpers

    /// A key/value row: label on the left, an arbitrary trailing view on the right, min 52pt tall.
    private func row(label: String, trailing: UIView, leadingIcon: String? = nil) -> UIView {
        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.layoutMargins = UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 0)
        row.isLayoutMarginsRelativeArrangement = true

        if let icon = leadingIcon {
            let iv = UIImageView(image: UIImage(systemName: icon))
            iv.tintColor = AppColors.textSecondary
            iv.contentMode = .scaleAspectFit
            iv.constrainSize(18)
            row.addArrangedSubview(iv)
        }
        let key = UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textSecondary)
        key.setContentCompressionResistancePriority(.required, for: .horizontal)
        row.addArrangedSubview(key)
        row.addArrangedSubview(UIView())   // flexible spacer
        row.addArrangedSubview(trailing)
        trailing.setContentHuggingPriority(.required, for: .horizontal)
        trailing.setContentCompressionResistancePriority(.required, for: .horizontal)
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        return row
    }

    private func valueLabel(_ value: String?, align: NSTextAlignment) -> UILabel {
        let text = (value?.isEmpty == false) ? value! : "—"
        let l = UILabel.make(text, font: AppFonts.bold(14), color: AppColors.textPrimary, align: align, lines: 0)
        return l
    }

    private func pill(_ text: String, textColor: UIColor, background: UIColor) -> UIView {
        let label = PaddingLabel(insets: UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12))
        label.text = text
        label.font = AppFonts.bold(12)
        label.textColor = textColor
        label.backgroundColor = background
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        return label
    }

    private func hairline() -> UIView {
        let v = UIView()
        v.backgroundColor = AppColors.borderLight
        v.constrainHeight(1)
        return v
    }

    /// Wraps a view so it hugs the leading edge inside a fill stack.
    private func leading(_ inner: UIView) -> UIView {
        let container = UIView()
        inner.forAutoLayout()
        container.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            inner.topAnchor.constraint(equalTo: container.topAnchor),
            inner.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            inner.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor)
        ])
        return container
    }

    // MARK: - Data

    private var isWalletActive: Bool {
        guard let wallet = data.wallet else { return false }
        let activated = (wallet.activatedAt?.isEmpty == false)
        let statusActive = wallet.status?.lowercased() == "active"
        return activated || statusActive
    }

    private func subtitleText() -> String {
        if let name = data.user?.firstName, !name.isEmpty {
            return "\(name), thanks for registering. Our team is reviewing your application and documents."
        }
        return "Thanks for registering. Our team is reviewing your application and documents."
    }

    // MARK: - Actions

    @objc private func backToLogin() {
        dismiss(animated: true)
    }

    @objc private func emailSupport() {
        guard let url = URL(string: "mailto:support@anokix.com") else { return }
        UIApplication.shared.open(url)
    }
}
