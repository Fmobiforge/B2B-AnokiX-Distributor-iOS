import UIKit

/// Card Machine (New-Design/Card-Machine): push an amount to a PayCloud terminal, manage
/// the machines linked to this account, and review every payment taken on them.
///
/// Card details never reach the app — the customer taps / inserts / swipes on the device.
final class CardMachineViewController: BaseSecondaryViewController {

    override var screenTitle: String { "Card Machine" }
    override var screenSubtitle: String? { "Take card payments on your PayCloud terminal" }

    private static let perPage = 10

    private var terminals: [PosTerminalsData.Terminal] = []
    private var activeTerminals: [PosTerminalsData.Terminal] { terminals.filter { $0.active } }
    private var selectedTerminal: PosTerminalsData.Terminal?
    private var posConfigured = true

    private var page = 1
    private var totalPages = 1
    private var totalPayments = 0
    /// Kept so payment rows can be re-labelled once the machine names arrive.
    private var lastPayments: PosPaymentsData?

    private let amountField = UITextField()
    private let referenceField = UITextField()
    private let terminalPicker = CardMachinePickerRow(placeholder: "Select a machine")
    private let sendButton = UIButton(type: .system)
    private let paymentFormStack = UIStackView.vertical(spacing: 12, alignment: .fill)
    private let noMachineBanner = UIView()
    private let bannerTitle = UILabel.make(font: AppFonts.bold(AppMetrics.textBody),
                                           color: AppColors.textPrimary, lines: 0)
    private let bannerBody = UILabel.make(font: AppFonts.regular(AppMetrics.textCaption),
                                          color: AppColors.textSecondary, lines: 0)
    private let machineStack = UIStackView.vertical(spacing: 0, alignment: .fill)
    private let machinesEmpty = UILabel.make("No card machines yet.",
                                             font: AppFonts.regular(AppMetrics.textBody),
                                             color: AppColors.textTertiary, align: .center, lines: 0)
    private let paymentStack = UIStackView.vertical(spacing: 10, alignment: .fill)
    private let paymentsEmpty = UIStackView.vertical(spacing: 12, alignment: .center)
    private let paginationRow = UIStackView.horizontal(spacing: 8, alignment: .center)
    private let paginationLabel = UILabel.make(font: AppFonts.regular(AppMetrics.textCaption),
                                               color: AppColors.textSecondary)
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)

    override func setupContent(in container: UIView) {
        let stack = makeScrollStack(in: container, spacing: 14,
                                    insets: UIEdgeInsets(top: 14, left: 16, bottom: 24, right: 16))
        stack.addArrangedSubview(buildPaymentCard())
        stack.addArrangedSubview(buildMachinesCard())
        stack.addArrangedSubview(buildPaymentsCard())
    }

    override func loadData() {
        loadTerminals()
        loadPayments()
    }

    // MARK: Take a card payment

    private func buildPaymentCard() -> UIView {
        let card = StyleKit.cardView()

        let title = UILabel.make("Take a card payment", font: AppFonts.bold(AppMetrics.textDisplay),
                                 color: AppColors.topTitle)
        let subtitle = UILabel.make(
            "The amount is sent to the machine — the customer taps, inserts or swipes there. Card details never pass through this screen.",
            font: AppFonts.regular(AppMetrics.textCaption), color: AppColors.textSecondary, lines: 0)

        buildBanner()

        StyleKit.styleInput(amountField)
        amountField.placeholder = "0.00"
        amountField.keyboardType = .decimalPad
        amountField.font = AppFonts.bold(AppMetrics.textTitle)
        let currency = UILabel.make("R", font: AppFonts.bold(AppMetrics.textTitle),
                                    color: AppColors.textSecondary)
        currency.forAutoLayout()
        let currencyHolder = UIView()
        currencyHolder.addSubview(currency)
        NSLayoutConstraint.activate([
            currencyHolder.widthAnchor.constraint(equalToConstant: 26),
            currency.leadingAnchor.constraint(equalTo: currencyHolder.leadingAnchor, constant: 10),
            currency.centerYAnchor.constraint(equalTo: currencyHolder.centerYAnchor)
        ])
        amountField.leftView = currencyHolder
        amountField.leftViewMode = .always

        StyleKit.styleInput(referenceField)
        referenceField.placeholder = "e.g. Invoice INV-1042"

        terminalPicker.addTarget(self, action: #selector(pickTerminal), for: .touchUpInside)

        sendButton.setTitle("Send to machine", for: .normal)
        sendButton.setImage(UIImage(systemName: "creditcard"), for: .normal)
        StyleKit.stylePrimaryButton(sendButton)
        sendButton.configuration?.imagePadding = 8
        sendButton.constrainHeight(50)
        sendButton.addTarget(self, action: #selector(sendPayment), for: .touchUpInside)

        paymentFormStack.addArrangedSubview(fieldGroup("Amount", amountField))
        paymentFormStack.addArrangedSubview(fieldGroup("Card machine", terminalPicker))
        paymentFormStack.addArrangedSubview(fieldGroup("Reference (optional)", referenceField))
        paymentFormStack.addArrangedSubview(sendButton)
        paymentFormStack.setCustomSpacing(16, after: paymentFormStack.arrangedSubviews[2])

        let stack = UIStackView.vertical(spacing: 14, alignment: .fill)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(noMachineBanner)
        stack.addArrangedSubview(paymentFormStack)
        stack.setCustomSpacing(4, after: title)
        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        return card
    }

    private func buildBanner() {
        noMachineBanner.backgroundColor = AppColors.infoBg
        noMachineBanner.layer.cornerRadius = AppMetrics.radiusMD

        let icon = UIImageView(image: UIImage(systemName: "info.circle.fill"))
        icon.tintColor = AppColors.info
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20)
        ])

        bannerTitle.text = "No card machine added yet"
        bannerBody.text = "Add one below using the serial number printed on the device."

        let text = UIStackView.vertical(spacing: 2, alignment: .fill)
        text.addArrangedSubview(bannerTitle)
        text.addArrangedSubview(bannerBody)

        let row = UIStackView.horizontal(spacing: 10, alignment: .top)
        row.addArrangedSubview(icon)
        row.addArrangedSubview(text)
        row.forAutoLayout()
        noMachineBanner.addSubview(row)
        row.pinEdges(to: noMachineBanner, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        noMachineBanner.isHidden = true
    }

    private func fieldGroup(_ label: String, _ field: UIView) -> UIStackView {
        let title = UILabel.make(label, font: AppFonts.regular(AppMetrics.textBody),
                                 color: AppColors.textPrimary)
        let stack = UIStackView.vertical(spacing: 5, alignment: .fill)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(field)
        return stack
    }

    @objc private func pickTerminal() {
        guard !activeTerminals.isEmpty else {
            presentInfo("Select a card machine."); return
        }
        let sheet = UIAlertController(title: "Card machine", message: nil, preferredStyle: .actionSheet)
        for terminal in activeTerminals {
            sheet.addAction(UIAlertAction(title: terminal.displayName, style: .default) { [weak self] _ in
                self?.selectedTerminal = terminal
                self?.terminalPicker.setTitle(terminal.displayName)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = terminalPicker
        sheet.popoverPresentationController?.sourceRect = terminalPicker.bounds
        present(sheet, animated: true)
    }

    @objc private func sendPayment() {
        let amount = (amountField.text ?? "").trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(amount), value > 0 else {
            presentInfo("Enter an amount."); return
        }
        guard let terminal = selectedTerminal else {
            presentInfo("Select a card machine."); return
        }

        sendButton.isEnabled = false
        ApiClient.shared.sendPosPayment(amount: amount, terminalId: terminal.id,
                                        description: referenceField.text ?? "") { [weak self] result in
            guard let self = self else { return }
            self.sendButton.isEnabled = true
            switch result {
            case .success(let message):
                self.toast(message.isEmpty
                           ? "Sent to the machine — ask the customer to tap or insert their card."
                           : message)
                self.amountField.text = ""
                self.referenceField.text = ""
            case .failure(let error):
                // The terminal's own error ("device does not exist") lands here.
                let alert = UIAlertController(title: "Send to machine", message: error.message,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
            self.page = 1
            self.loadPayments()
        }
    }

    // MARK: Your card machines

    private func buildMachinesCard() -> UIView {
        let card = StyleKit.cardView()

        let title = UILabel.make("Your card machines", font: AppFonts.bold(AppMetrics.textDisplay),
                                 color: AppColors.topTitle)
        let addButton = UIButton(type: .system)
        addButton.setTitle("Add machine", for: .normal)
        addButton.setImage(UIImage(systemName: "plus"), for: .normal)
        StyleKit.styleOutlinedButton(addButton, fontSize: AppMetrics.textBodySM)
        addButton.configuration?.contentInsets = NSDirectionalEdgeInsets(
            top: 10, leading: 14, bottom: 10, trailing: 14)
        addButton.configuration?.imagePadding = 6
        addButton.setContentHuggingPriority(.required, for: .horizontal)
        addButton.addTarget(self, action: #selector(addMachine), for: .touchUpInside)

        let header = UIStackView.horizontal(spacing: 12, alignment: .center)
        header.addArrangedSubview(title)
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(addButton)

        let subtitle = UILabel.make("Identified by the serial number printed on the device.",
                                    font: AppFonts.regular(AppMetrics.textCaption),
                                    color: AppColors.textSecondary, lines: 0)

        machinesEmpty.isHidden = true

        let stack = UIStackView.vertical(spacing: 6, alignment: .fill)
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(machineStack)
        stack.addArrangedSubview(machinesEmpty)
        stack.setCustomSpacing(4, after: header)
        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        return card
    }

    private func loadTerminals() {
        ApiClient.shared.getPosTerminals { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                self.posConfigured = data.configured ?? true
                self.terminals = data.terminals ?? []
                self.renderTerminals()
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    private func renderTerminals() {
        // Keep the current pick when it survived a reload, otherwise take the first machine.
        if let current = selectedTerminal {
            selectedTerminal = activeTerminals.first { $0.id == current.id }
        }
        if selectedTerminal == nil { selectedTerminal = activeTerminals.first }
        terminalPicker.setTitle(selectedTerminal?.displayName)

        // Without an active machine (or without PayCloud switched on) there is nothing to
        // send to, so the form gives way to an explanatory banner.
        let canTakePayment = posConfigured && !activeTerminals.isEmpty
        paymentFormStack.isHidden = !canTakePayment
        noMachineBanner.isHidden = canTakePayment
        bannerTitle.text = posConfigured
            ? "No card machine added yet"
            : "Card machine payments are not switched on for this account yet."
        bannerBody.isHidden = !posConfigured

        machineStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        machinesEmpty.isHidden = !terminals.isEmpty
        for (index, terminal) in terminals.enumerated() {
            if index > 0 { machineStack.addArrangedSubview(ListScreenLayout.hairline()) }
            machineStack.addArrangedSubview(machineRow(terminal))
        }

        // Payments may have rendered before the machines did — relabel them now.
        if let payments = lastPayments { renderPayments(payments) }
    }

    private func machineRow(_ terminal: PosTerminalsData.Terminal) -> UIView {
        let tile = StyleKit.iconTile(color: AppColors.purpleLight)
        tile.forAutoLayout()
        let icon = UIImageView(image: UIImage(systemName: "creditcard.fill"))
        icon.tintColor = AppColors.purplePrimary
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        tile.addSubview(icon)
        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: 38),
            tile.heightAnchor.constraint(equalToConstant: 38),
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 19),
            icon.heightAnchor.constraint(equalToConstant: 19)
        ])

        let name = UILabel.make(terminal.displayName, font: AppFonts.bold(AppMetrics.textBody),
                                color: AppColors.topTitle)
        let serial = UILabel()
        serial.text = terminal.terminalSn
        serial.font = UIFont.monospacedSystemFont(ofSize: AppMetrics.textCaption, weight: .regular)
        serial.textColor = AppColors.textSecondary
        let text = UIStackView.vertical(spacing: 2, alignment: .leading)
        text.addArrangedSubview(name)
        text.addArrangedSubview(serial)

        let badge = PaddingLabel(insets: UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
        StyleKit.styleBadge(badge)
        badge.font = AppFonts.bold(AppMetrics.textMicro)
        badge.text = terminal.active ? "Active" : "Removed"
        badge.textColor = terminal.active ? AppColors.success : AppColors.textSecondary
        badge.backgroundColor = terminal.active ? AppColors.successBg : AppColors.borderLight

        let trailing = UIStackView.vertical(spacing: 6, alignment: .trailing)
        trailing.addArrangedSubview(badge)
        if terminal.active {
            let remove = UIButton(type: .system)
            remove.setTitle("Remove", for: .normal)
            remove.setTitleColor(AppColors.danger, for: .normal)
            remove.titleLabel?.font = AppFonts.bold(AppMetrics.textCaption)
            remove.addAction(UIAction { [weak self] _ in self?.confirmRemove(terminal) }, for: .touchUpInside)
            trailing.addArrangedSubview(remove)
        }

        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 0)
        row.addArrangedSubview(tile)
        row.addArrangedSubview(text)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(trailing)
        return row
    }

    private func confirmRemove(_ terminal: PosTerminalsData.Terminal) {
        let alert = UIAlertController(
            title: "Remove this machine?",
            message: "\"\(terminal.displayName)\" will no longer accept payments from this app. You can add it again with the same serial number.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            ApiClient.shared.removePosTerminal(terminalId: terminal.id) { result in
                guard let self = self else { return }
                switch result {
                case .success(let message):
                    if !message.isEmpty { self.toast(message) }
                    self.loadTerminals()
                case .failure(let error):
                    self.toast(error.message)
                }
            }
        })
        present(alert, animated: true)
    }

    @objc private func addMachine() {
        let form = StockFormViewController(title: "Add a card machine",
                                           help: "Printed on the back of the machine, or under Settings on the device.",
                                           submitTitle: "Save")
        let serial = form.addTextField(placeholder: "e.g. WPHK002352000111")
        serial.autocapitalizationType = .allCharacters
        serial.autocorrectionType = .no
        let label = form.addTextField(placeholder: "Name (optional) — e.g. Front counter")

        form.onSubmit = { [weak form, weak self] in
            guard let form = form, let self = self else { return }
            let sn = (serial.text ?? "").trimmingCharacters(in: .whitespaces)
            guard !sn.isEmpty else {
                form.showError("Enter the machine's serial number."); return
            }
            form.setSubmitting(true)
            ApiClient.shared.addPosTerminal(terminalSn: sn, label: label.text ?? "") { result in
                switch result {
                case .success(let message):
                    form.dismiss(animated: true) {
                        if !message.isEmpty { self.toast(message) }
                        self.loadTerminals()
                    }
                case .failure(let error):
                    form.setSubmitting(false)
                    form.showError(error.message)
                }
            }
        }
        present(form.wrappedInNavigation(), animated: true)
    }

    // MARK: Card machine payments

    private func buildPaymentsCard() -> UIView {
        let card = StyleKit.cardView()

        let title = UILabel.make("Card machine payments", font: AppFonts.bold(AppMetrics.textDisplay),
                                 color: AppColors.topTitle)
        let subtitle = UILabel.make("Every payment taken on a machine, newest first.",
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
        paymentsEmpty.isLayoutMarginsRelativeArrangement = true
        paymentsEmpty.layoutMargins = UIEdgeInsets(top: 24, left: 0, bottom: 12, right: 0)
        paymentsEmpty.addArrangedSubview(emptyIcon)
        paymentsEmpty.addArrangedSubview(UILabel.make("No payments yet.",
                                                      font: AppFonts.regular(AppMetrics.textBody),
                                                      color: AppColors.textTertiary, align: .center))
        paymentsEmpty.isHidden = true

        configurePageButton(prevButton, systemName: "chevron.left")
        prevButton.addAction(UIAction { [weak self] _ in
            guard let self = self, self.page > 1 else { return }
            self.page -= 1
            self.loadPayments()
        }, for: .touchUpInside)
        configurePageButton(nextButton, systemName: "chevron.right")
        nextButton.addAction(UIAction { [weak self] _ in
            guard let self = self, self.page < self.totalPages else { return }
            self.page += 1
            self.loadPayments()
        }, for: .touchUpInside)

        paginationRow.addArrangedSubview(paginationLabel)
        paginationRow.addArrangedSubview(UIView())
        paginationRow.addArrangedSubview(prevButton)
        paginationRow.addArrangedSubview(nextButton)
        paginationRow.isHidden = true

        let stack = UIStackView.vertical(spacing: 10, alignment: .fill)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(paymentStack)
        stack.addArrangedSubview(paymentsEmpty)
        stack.addArrangedSubview(paginationRow)
        stack.setCustomSpacing(4, after: title)
        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        return card
    }

    private func configurePageButton(_ button: UIButton, systemName: String) {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: systemName)
        config.baseForegroundColor = AppColors.textSecondary
        config.background.backgroundColor = AppColors.surfaceVariant
        config.background.strokeColor = AppColors.border
        config.background.strokeWidth = 1
        config.background.cornerRadius = 18
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        button.configuration = config
        button.forAutoLayout()
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 36),
            button.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func loadPayments() {
        ApiClient.shared.getPosPayments(page: page, perPage: Self.perPage) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                self.renderPayments(data)
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    private func renderPayments(_ data: PosPaymentsData) {
        lastPayments = data
        paymentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let payments = data.payments ?? []
        page = max(1, data.pagination?.page ?? page)
        totalPages = max(1, data.pagination?.totalPages ?? 1)
        totalPayments = data.pagination?.total ?? payments.count

        for payment in payments {
            paymentStack.addArrangedSubview(paymentRow(payment))
        }
        paymentsEmpty.isHidden = !payments.isEmpty

        paginationRow.isHidden = totalPayments == 0
        if totalPayments > 0 {
            let first = (page - 1) * Self.perPage + 1
            let last = min(totalPayments, first + payments.count - 1)
            paginationLabel.text = "\(first)–\(last) of \(totalPayments) payments"
            prevButton.isEnabled = page > 1
            prevButton.alpha = page > 1 ? 1 : 0.4
            nextButton.isEnabled = page < totalPages
            nextButton.alpha = page < totalPages ? 1 : 0.4
        }
    }

    private func paymentRow(_ payment: PosPaymentsData.Payment) -> UIView {
        let card = StyleKit.cardView()

        let amount = UILabel.make(formatAmount(payment), font: AppFonts.bold(AppMetrics.textHeadline),
                                  color: AppColors.topTitle)
        let badge = PaddingLabel(insets: UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
        StyleKit.styleBadge(badge)
        badge.font = AppFonts.bold(AppMetrics.textMicro)
        badge.text = statusLabel(payment.status)
        let colors = statusColors(payment.status)
        badge.textColor = colors.fg
        badge.backgroundColor = colors.bg
        badge.setContentHuggingPriority(.required, for: .horizontal)

        let top = UIStackView.horizontal(spacing: 8, alignment: .center)
        top.addArrangedSubview(amount)
        top.addArrangedSubview(UIView())
        top.addArrangedSubview(badge)

        let stack = UIStackView.vertical(spacing: 4, alignment: .fill)
        stack.addArrangedSubview(top)
        if let description = payment.description, !description.isEmpty {
            stack.addArrangedSubview(UILabel.make(description, font: AppFonts.regular(AppMetrics.textBody),
                                                  color: AppColors.textPrimary, lines: 2))
        }
        stack.addArrangedSubview(UILabel.make(meta(payment), font: AppFonts.regular(AppMetrics.textCaption),
                                              color: AppColors.textSecondary, lines: 2))
        stack.setCustomSpacing(6, after: top)

        if let error = payment.lastError, !error.isEmpty {
            let errorLabel = PaddingLabel(insets: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))
            errorLabel.text = error
            errorLabel.numberOfLines = 3
            errorLabel.font = AppFonts.regular(AppMetrics.textMicro)
            errorLabel.textColor = AppColors.danger
            errorLabel.backgroundColor = AppColors.dangerBg
            errorLabel.layer.cornerRadius = AppMetrics.radiusSM
            errorLabel.layer.masksToBounds = true
            stack.addArrangedSubview(errorLabel)
            stack.setCustomSpacing(8, after: stack.arrangedSubviews[stack.arrangedSubviews.count - 2])
        }

        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return card
    }

    /// "12 Aug, 23:01 · Front Machine · Card 1234".
    private func meta(_ payment: PosPaymentsData.Payment) -> String {
        var parts = [formatWhen(payment)]
        if let machine = machineName(payment.terminalSn), !machine.isEmpty { parts.append(machine) }
        if let card = payment.cardNo, !card.isEmpty { parts.append("Card \(card)") }
        return parts.filter { !$0.isEmpty }.joined(separator: "  ·  ")
    }

    private func machineName(_ serial: String?) -> String? {
        guard let serial = serial, !serial.isEmpty else { return nil }
        return terminals.first { $0.terminalSn == serial }?.displayName ?? serial
    }

    private func formatAmount(_ payment: PosPaymentsData.Payment) -> String {
        let currency = payment.currency ?? ""
        let symbol = (currency.isEmpty || currency.caseInsensitiveCompare("ZAR") == .orderedSame)
            ? "R" : currency + " "
        return String(format: "%@%.2f", symbol, payment.amount ?? 0)
    }

    /// API timestamps come back as "yyyy-MM-dd HH:mm:ss"; show them as "12 Aug, 23:01".
    private func formatWhen(_ payment: PosPaymentsData.Payment) -> String {
        let raw = (payment.paidAt?.isEmpty == false ? payment.paidAt : payment.createdAt) ?? ""
        guard !raw.isEmpty else { return "" }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = parser.date(from: raw) else { return raw }
        let display = DateFormatter()
        display.dateFormat = "d MMM, HH:mm"
        return display.string(from: date)
    }

    private func statusLabel(_ status: String?) -> String {
        guard let status = status, !status.isEmpty else { return "Pending" }
        return status.prefix(1).uppercased() + status.dropFirst()
    }

    private func statusColors(_ status: String?) -> (fg: UIColor, bg: UIColor) {
        let value = (status ?? "").lowercased()
        if value.contains("paid") || value.contains("success") || value.contains("complete") {
            return (AppColors.success, AppColors.successBg)
        }
        if value.contains("fail") || value.contains("cancel") || value.contains("declin") {
            return (AppColors.danger, AppColors.dangerBg)
        }
        return (AppColors.warning, AppColors.warningBg)
    }
}

/// Bordered select row matching the text inputs beside it (ProductDropdown on Android).
final class CardMachinePickerRow: UIControl {

    private let placeholder: String
    private let label = UILabel()

    init(placeholder: String) {
        self.placeholder = placeholder
        super.init(frame: .zero)

        backgroundColor = AppColors.surface
        layer.cornerRadius = AppMetrics.radiusMD
        layer.borderWidth = 1
        layer.borderColor = AppColors.border.cgColor

        label.text = placeholder
        label.font = AppFonts.regular(AppMetrics.textBody)
        label.textColor = AppColors.textSecondary
        label.lineBreakMode = .byTruncatingTail
        label.forAutoLayout()

        let chevron = UIImageView(image: UIImage(systemName: "chevron.down"))
        chevron.tintColor = AppColors.textSecondary
        chevron.contentMode = .scaleAspectFit
        chevron.forAutoLayout()

        addSubviews(label, chevron)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 48),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 14),
            chevron.heightAnchor.constraint(equalToConstant: 14)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Passing nil restores the placeholder styling.
    func setTitle(_ title: String?) {
        let value = title?.trimmingCharacters(in: .whitespaces) ?? ""
        label.text = value.isEmpty ? placeholder : value
        label.textColor = value.isEmpty ? AppColors.textSecondary : AppColors.textPrimary
    }
}
