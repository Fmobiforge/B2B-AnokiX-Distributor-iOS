import UIKit

/// Warehouse Staff (New-Design/Warehouse Staff): the people who sign in with their own
/// credentials to pick, pack and handle stock — add them, reset their password, and turn
/// their sign-in on or off.
final class WarehouseStaffViewController: BaseSecondaryViewController {

    override var screenTitle: String { "Warehouse Staff" }
    override var screenSubtitle: String? { "Who can pick and pack" }

    private static let minPassword = 8

    private var staff: [StaffData.Staff] = []

    private let staffStack = UIStackView.vertical(spacing: 0, alignment: .fill)
    private let staffEmpty = UIStackView.vertical(spacing: 12, alignment: .center)

    override func setupContent(in container: UIView) {
        let stack = makeScrollStack(in: container, spacing: 12,
                                    insets: UIEdgeInsets(top: 14, left: 16, bottom: 24, right: 16))
        stack.addArrangedSubview(buildCapabilityBanner())
        stack.addArrangedSubview(buildStaffCard())
    }

    override func loadData() { loadStaff() }

    // MARK: What staff can do

    private func buildCapabilityBanner() -> UIView {
        let banner = UIView()
        banner.backgroundColor = AppColors.infoBg
        banner.layer.cornerRadius = AppMetrics.radiusMD

        let icon = UIImageView(image: UIImage(systemName: "info.circle.fill"))
        icon.tintColor = AppColors.info
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20)
        ])

        let text = UIStackView.vertical(spacing: 3, alignment: .fill)
        text.addArrangedSubview(UILabel.make("What staff can do",
                                             font: AppFonts.bold(AppMetrics.textBody),
                                             color: AppColors.textPrimary))
        text.addArrangedSubview(UILabel.make(
            "Warehouse staff can pick and pack orders, update shipment status and handle stock. They cannot change products or pricing, manage the wallet, or see financial reports.",
            font: AppFonts.regular(AppMetrics.textCaption), color: AppColors.textSecondary, lines: 0))

        let row = UIStackView.horizontal(spacing: 10, alignment: .top)
        row.addArrangedSubview(icon)
        row.addArrangedSubview(text)
        row.forAutoLayout()
        banner.addSubview(row)
        row.pinEdges(to: banner, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return banner
    }

    // MARK: Your warehouse staff

    private func buildStaffCard() -> UIView {
        let card = StyleKit.cardView()

        let title = UILabel.make("Your warehouse staff", font: AppFonts.bold(AppMetrics.textDisplay),
                                 color: AppColors.topTitle)
        let addButton = UIButton(type: .system)
        addButton.setTitle("Add staff", for: .normal)
        addButton.setImage(UIImage(systemName: "person.badge.plus"), for: .normal)
        StyleKit.stylePrimaryButton(addButton, fontSize: AppMetrics.textBodySM)
        addButton.configuration?.contentInsets = NSDirectionalEdgeInsets(
            top: 10, leading: 14, bottom: 10, trailing: 14)
        addButton.configuration?.imagePadding = 6
        addButton.setContentHuggingPriority(.required, for: .horizontal)
        addButton.addTarget(self, action: #selector(addStaff), for: .touchUpInside)

        let header = UIStackView.horizontal(spacing: 12, alignment: .center)
        header.addArrangedSubview(title)
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(addButton)

        let subtitle = UILabel.make("Each person signs in with their own email and password.",
                                    font: AppFonts.regular(AppMetrics.textCaption),
                                    color: AppColors.textSecondary, lines: 0)

        let emptyIcon = UIImageView(image: AppIcons.symbol("ic_empty_inbox"))
        emptyIcon.tintColor = AppColors.border
        emptyIcon.contentMode = .scaleAspectFit
        emptyIcon.forAutoLayout()
        NSLayoutConstraint.activate([
            emptyIcon.widthAnchor.constraint(equalToConstant: 52),
            emptyIcon.heightAnchor.constraint(equalToConstant: 52)
        ])
        staffEmpty.isLayoutMarginsRelativeArrangement = true
        staffEmpty.layoutMargins = UIEdgeInsets(top: 22, left: 0, bottom: 10, right: 0)
        staffEmpty.addArrangedSubview(emptyIcon)
        staffEmpty.addArrangedSubview(UILabel.make("No staff yet. Tap Add staff to give someone access.",
                                                   font: AppFonts.regular(AppMetrics.textBody),
                                                   color: AppColors.textTertiary, align: .center, lines: 0))
        staffEmpty.isHidden = true

        let stack = UIStackView.vertical(spacing: 6, alignment: .fill)
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(staffStack)
        stack.addArrangedSubview(staffEmpty)
        stack.setCustomSpacing(4, after: header)
        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        return card
    }

    private func loadStaff() {
        ApiClient.shared.getStaff { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                self.staff = data.staff ?? []
                self.render()
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    private func render() {
        staffStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        staffEmpty.isHidden = !staff.isEmpty
        for (index, member) in staff.enumerated() {
            if index > 0 { staffStack.addArrangedSubview(ListScreenLayout.hairline()) }
            staffStack.addArrangedSubview(staffRow(member))
        }
    }

    private func staffRow(_ member: StaffData.Staff) -> UIView {
        let name = UILabel.make(member.displayName, font: AppFonts.bold(AppMetrics.textBody),
                                color: AppColors.topTitle)
        let email = UILabel.make(member.email ?? "", font: AppFonts.regular(AppMetrics.textCaption),
                                 color: AppColors.textSecondary)
        let identity = UIStackView.vertical(spacing: 2, alignment: .leading)
        identity.addArrangedSubview(name)
        identity.addArrangedSubview(email)
        // Disabled people stay listed but read as muted, matching the web row.
        identity.alpha = member.isActive ? 1 : 0.6

        let badge = PaddingLabel(insets: UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10))
        StyleKit.styleBadge(badge)
        badge.font = AppFonts.regular(AppMetrics.textMicro)
        badge.text = member.signInAllowed ? "Can sign in" : "Disabled"
        badge.textColor = member.signInAllowed ? AppColors.success : AppColors.textSecondary
        badge.backgroundColor = member.signInAllowed ? AppColors.successBg : AppColors.borderLight
        badge.setContentHuggingPriority(.required, for: .horizontal)

        let top = UIStackView.horizontal(spacing: 8, alignment: .top)
        top.addArrangedSubview(identity)
        top.addArrangedSubview(UIView())
        top.addArrangedSubview(badge)

        let meta = UILabel.make(metaLine(member), font: AppFonts.regular(AppMetrics.textMicro),
                                color: AppColors.textTertiary)

        let passwordButton = UIButton(type: .system)
        passwordButton.setTitle("Password", for: .normal)
        passwordButton.setImage(UIImage(systemName: "key"), for: .normal)
        StyleKit.styleOutlinedButton(passwordButton, fontSize: AppMetrics.textBodySM)
        passwordButton.configuration?.baseForegroundColor = AppColors.textPrimary
        passwordButton.configuration?.background.strokeColor = AppColors.border
        passwordButton.configuration?.background.backgroundColor = AppColors.surfaceVariant
        passwordButton.configuration?.contentInsets = NSDirectionalEdgeInsets(
            top: 9, leading: 12, bottom: 9, trailing: 12)
        passwordButton.configuration?.imagePadding = 6
        passwordButton.setContentHuggingPriority(.required, for: .horizontal)
        passwordButton.addAction(UIAction { [weak self] _ in
            self?.showPasswordForm(for: member)
        }, for: .touchUpInside)

        let toggleButton = UIButton(type: .system)
        toggleButton.setTitle(member.isActive ? "Disable" : "Enable", for: .normal)
        toggleButton.setTitleColor(member.isActive ? AppColors.danger : AppColors.purplePrimary,
                                   for: .normal)
        toggleButton.titleLabel?.font = AppFonts.bold(AppMetrics.textBodySM)
        toggleButton.setContentHuggingPriority(.required, for: .horizontal)
        toggleButton.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            if member.isActive {
                self.confirmDisable(member)
            } else {
                self.updateStatus(member, status: "active")
            }
        }, for: .touchUpInside)

        let actions = UIStackView.horizontal(spacing: 8, alignment: .center)
        actions.addArrangedSubview(passwordButton)
        actions.addArrangedSubview(toggleButton)
        actions.addArrangedSubview(UIView())

        let row = UIStackView.vertical(spacing: 4, alignment: .fill)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 0)
        row.addArrangedSubview(top)
        row.addArrangedSubview(meta)
        row.addArrangedSubview(actions)
        row.setCustomSpacing(12, after: meta)
        return row
    }

    /// "Picker · Added 13 Aug 2026".
    private func metaLine(_ member: StaffData.Staff) -> String {
        var parts: [String] = []
        if let job = member.jobTitle, !job.isEmpty { parts.append(job) }
        let added = formatDate(member.createdAt)
        if !added.isEmpty { parts.append("Added \(added)") }
        return parts.joined(separator: "  ·  ")
    }

    /// API timestamps come back as "yyyy-MM-dd HH:mm:ss"; show them as "13 Aug 2026".
    private func formatDate(_ raw: String?) -> String {
        guard let raw = raw, !raw.isEmpty else { return "" }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = parser.date(from: raw) else { return raw }
        let display = DateFormatter()
        display.dateFormat = "d MMM yyyy"
        return display.string(from: date)
    }

    // MARK: Actions

    private func confirmDisable(_ member: StaffData.Staff) {
        let alert = UIAlertController(
            title: "Stop \(member.displayName) signing in?",
            message: "They keep their account, but cannot sign in until you enable them again.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Disable", style: .destructive) { [weak self] _ in
            self?.updateStatus(member, status: "disabled")
        })
        present(alert, animated: true)
    }

    private func updateStatus(_ member: StaffData.Staff, status: String) {
        ApiClient.shared.updateStaffStatus(staffId: member.id, status: status) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                if !message.isEmpty { self.toast(message) }
                self.loadStaff()
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    private func showPasswordForm(for member: StaffData.Staff) {
        let form = StockFormViewController(title: "New password for \(member.displayName)",
                                           help: "Tell them the new password — they are not emailed.",
                                           submitTitle: "Set password")
        let password = form.addSecureField(placeholder: "At least 8 characters")

        form.onSubmit = { [weak form, weak self] in
            guard let form = form, let self = self else { return }
            let value = password.text ?? ""
            guard value.count >= Self.minPassword else {
                form.showError("Use at least 8 characters."); return
            }
            form.setSubmitting(true)
            ApiClient.shared.setStaffPassword(staffId: member.id, password: value) { result in
                switch result {
                case .success(let message):
                    form.dismiss(animated: true) {
                        if !message.isEmpty { self.toast(message) }
                    }
                case .failure(let error):
                    form.setSubmitting(false)
                    form.showError(error.message)
                }
            }
        }
        present(form.wrappedInNavigation(), animated: true)
    }

    @objc private func addStaff() {
        let form = StockFormViewController(title: "Add a warehouse staff member",
                                           help: nil, submitTitle: "Add")
        let firstName = form.addTextField(placeholder: "First name *")
        firstName.autocapitalizationType = .words
        let lastName = form.addTextField(placeholder: "Last name *")
        lastName.autocapitalizationType = .words
        let email = form.addTextField(placeholder: "Email *", keyboard: .emailAddress)
        email.autocapitalizationType = .none
        email.autocorrectionType = .no
        form.addCaption("They sign in with this.")
        let password = form.addSecureField(placeholder: "Password * — at least 8 characters")
        let jobTitle = form.addTextField(placeholder: "Job title (optional) — e.g. Picker")
        jobTitle.autocapitalizationType = .words
        let phone = form.addTextField(placeholder: "Mobile number (optional)", keyboard: .phonePad)

        form.onSubmit = { [weak form, weak self] in
            guard let form = form, let self = self else { return }
            let first = (firstName.text ?? "").trimmingCharacters(in: .whitespaces)
            let last = (lastName.text ?? "").trimmingCharacters(in: .whitespaces)
            let mail = (email.text ?? "").trimmingCharacters(in: .whitespaces)
            let secret = password.text ?? ""

            guard !first.isEmpty else { form.showError("Enter a first name."); return }
            guard !last.isEmpty else { form.showError("Enter a last name."); return }
            guard self.isValidEmail(mail) else { form.showError("Enter a valid email address."); return }
            guard secret.count >= Self.minPassword else {
                form.showError("Use at least 8 characters."); return
            }

            form.setSubmitting(true)
            ApiClient.shared.addStaff(firstName: first, lastName: last, email: mail,
                                      password: secret,
                                      phone: (phone.text ?? "").trimmingCharacters(in: .whitespaces),
                                      jobTitle: (jobTitle.text ?? "").trimmingCharacters(in: .whitespaces)) { result in
                switch result {
                case .success(let message):
                    form.dismiss(animated: true) {
                        if !message.isEmpty { self.toast(message) }
                        self.loadStaff()
                    }
                case .failure(let error):
                    form.setSubmitting(false)
                    form.showError(error.message)
                }
            }
        }
        present(form.wrappedInNavigation(), animated: true)
    }

    private func isValidEmail(_ value: String) -> Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}
