import UIKit

/// The two ways of raising a ticket from the Support Centre:
/// "Request a call back" (2.Call-Request.png) and "Tell us what's wrong"
/// (3.Create-Ticket.png).
///
/// Both post to the same `support/tickets` endpoint and differ only in their `channel` —
/// `callback` carries the number to ring, `web` carries a priority — so one sheet builds
/// whichever set of fields the mode calls for.
final class SupportRequestViewController: UIViewController {

    enum Mode {
        case callback
        case ticket
    }

    /// Called after a ticket is raised, with the server's confirmation message.
    var onSubmitted: ((String) -> Void)?

    /// The urgency options, in the order and wording the requirements specify.
    private static let priorities: [(value: String, label: String)] = [
        ("low", S.priorityLow),
        ("normal", S.priorityNormal),
        ("high", S.priorityHigh),
        ("urgent", S.priorityUrgent)
    ]
    /// "Normal" — the default the web dialog opens with.
    private static let defaultPriority = 1

    private let mode: Mode
    private let categories: [SupportOverviewData.Category]

    private var priorityIndex = SupportRequestViewController.defaultPriority
    private var topic: SupportOverviewData.Category?

    private let phoneField = UITextField()
    private let subjectField = UITextField()
    private let messageView = UITextView()
    private let priorityRow = ValueRow(placeholder: "")
    private let topicRow = ValueRow(placeholder: S.ticketTopicHint)
    private let submitButton = UIButton(type: .system)
    /// UITextView has no placeholder, so a label rides behind it and hides on input.
    private weak var messagePlaceholder: UILabel?

    init(mode: Mode, categories: [SupportOverviewData.Category]) {
        self.mode = mode
        self.categories = categories
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.surface

        let title = UILabel.make(mode == .callback ? S.callbackTitle : S.createTicketTitle,
                                 font: AppFonts.bold(AppMetrics.textHeadline),
                                 color: AppColors.textPrimary)
        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark"), for: .normal)
        close.tintColor = AppColors.textSecondary
        close.constrainSize(32)
        close.setContentHuggingPriority(.required, for: .horizontal)
        close.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)

        let titleRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        titleRow.addArrangedSubview(title)
        titleRow.addArrangedSubview(UIView())
        titleRow.addArrangedSubview(close)

        let stack = UIStackView.vertical(spacing: 14, alignment: .fill)
        stack.addArrangedSubview(titleRow)
        (mode == .callback ? callbackFields() : ticketFields()).forEach {
            stack.addArrangedSubview($0)
        }
        stack.addArrangedSubview(buttonRow())
        stack.forAutoLayout()

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.keyboardDismissMode = .interactive
        scroll.forAutoLayout()
        scroll.addSubview(stack)
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20)
        ])
    }

    // MARK: Fields

    private func callbackFields() -> [UIView] {
        phoneField.keyboardType = .phonePad
        phoneField.placeholder = S.callbackNumberHint
        subjectField.placeholder = S.callbackSubjectHint
        subjectField.autocapitalizationType = .sentences

        return [
            group(S.callbackNumberLabel, field(phoneField)),
            group(S.callbackSubjectLabel, field(subjectField)),
            group(S.callbackMessageLabel, textArea(height: 96))
        ]
    }

    private func ticketFields() -> [UIView] {
        subjectField.placeholder = S.ticketSubjectHint
        subjectField.autocapitalizationType = .sentences

        priorityRow.setValue(Self.priorities[priorityIndex].label)
        priorityRow.onTap = { [weak self] in self?.pickPriority() }

        var views: [UIView] = [group(S.ticketSubjectLabel, field(subjectField))]

        // Topic is optional; an empty picker would be a control that cannot be used.
        if !categories.isEmpty {
            topicRow.onTap = { [weak self] in self?.pickTopic() }
            views.append(group(S.ticketTopicLabel, topicRow))
        }

        views.append(group(S.ticketPriorityLabel, priorityRow))
        messageView.text = ""
        views.append(group(S.ticketMessageLabel, textArea(height: 110,
                                                          placeholder: S.ticketMessageHint)))
        return views
    }

    private func group(_ title: String, _ content: UIView) -> UIView {
        let label = UILabel.make(title, font: AppFonts.bold(AppMetrics.textCaption),
                                 color: AppColors.textPrimary)
        let stack = UIStackView.vertical(spacing: 6, alignment: .fill)
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(content)
        return stack
    }

    private func field(_ textField: UITextField) -> UIView {
        textField.font = AppFonts.regular(14)
        textField.textColor = AppColors.textPrimary
        textField.backgroundColor = AppColors.surfaceVariant
        textField.layer.cornerRadius = AppMetrics.radiusMD
        textField.layer.borderWidth = 1
        textField.layer.borderColor = AppColors.border.cgColor
        // A plain UITextField draws its text hard against the border.
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        textField.rightViewMode = .always
        textField.constrainHeight(46)
        return textField
    }

    private func textArea(height: CGFloat, placeholder: String? = nil) -> UIView {
        messageView.font = AppFonts.regular(14)
        messageView.textColor = AppColors.textPrimary
        messageView.backgroundColor = AppColors.surfaceVariant
        messageView.layer.cornerRadius = AppMetrics.radiusMD
        messageView.layer.borderWidth = 1
        messageView.layer.borderColor = AppColors.border.cgColor
        messageView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        messageView.constrainHeight(height)
        guard let placeholder = placeholder else { return messageView }

        let hint = UILabel.make(placeholder, font: AppFonts.regular(14),
                                color: AppColors.textSecondary, lines: 0)
        hint.forAutoLayout()
        messageView.addSubview(hint)
        NSLayoutConstraint.activate([
            hint.topAnchor.constraint(equalTo: messageView.topAnchor, constant: 12),
            hint.leadingAnchor.constraint(equalTo: messageView.leadingAnchor, constant: 15),
            hint.trailingAnchor.constraint(equalTo: messageView.trailingAnchor, constant: -15)
        ])
        messagePlaceholder = hint
        messageView.delegate = self
        return messageView
    }

    private func buttonRow() -> UIView {
        let cancel = UIButton(type: .system)
        StyleKit.styleOutlinedButton(cancel)
        cancel.setTitle(S.cancel, for: .normal)
        cancel.constrainHeight(46)
        cancel.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)

        StyleKit.stylePrimaryButton(submitButton)
        submitButton.setTitle(mode == .callback ? S.callbackSubmit : S.ticketSubmit, for: .normal)
        submitButton.constrainHeight(46)
        submitButton.addAction(UIAction { [weak self] _ in self?.submit() }, for: .touchUpInside)

        let row = UIStackView.horizontal(spacing: 12, alignment: .fill)
        row.distribution = .fillEqually
        row.addArrangedSubview(cancel)
        row.addArrangedSubview(submitButton)
        return row
    }

    // MARK: Pickers

    private func pickPriority() {
        presentPicker(options: Self.priorities.map { $0.label }, title: S.ticketPriorityLabel,
                      anchor: priorityRow) { [weak self] value in
            guard let self = self,
                  let index = Self.priorities.firstIndex(where: { $0.label == value }) else { return }
            self.priorityIndex = index
            self.priorityRow.setValue(value)
        }
    }

    private func pickTopic() {
        presentPicker(options: categories.map { $0.name ?? "" }, title: S.ticketTopicLabel,
                      anchor: topicRow) { [weak self] value in
            guard let self = self else { return }
            self.topic = self.categories.first { $0.name == value }
            self.topicRow.setValue(value)
        }
    }

    private func presentPicker(options: [String], title: String, anchor: UIView,
                               onPick: @escaping (String) -> Void) {
        let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for option in options {
            sheet.addAction(UIAlertAction(title: option, style: .default) { _ in onPick(option) })
        }
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        sheet.popoverPresentationController?.sourceView = anchor   // iPad anchor
        sheet.popoverPresentationController?.sourceRect = anchor.bounds
        present(sheet, animated: true)
    }

    // MARK: Submit

    private func submit() {
        var form: [String: String]

        if mode == .callback {
            let number = text(phoneField)
            guard !number.isEmpty else {
                presentAlert(S.errCallbackNumber)
                return
            }
            let title = text(subjectField)
            form = [
                "channel": "callback",
                "callback_phone": number,
                // The subject is optional on screen but the ticket needs a title, so an
                // empty one becomes the same default the API uses for call-backs.
                "subject": title.isEmpty ? S.callbackDefaultSubject : title,
                "message": messageText()
            ]
        } else {
            let title = text(subjectField)
            guard !title.isEmpty else {
                presentAlert(S.errTicketSubject)
                return
            }
            let body = messageText()
            guard !body.isEmpty else {
                presentAlert(S.errTicketMessage)
                return
            }
            form = [
                "channel": "web",
                "subject": title,
                "message": body,
                "priority": Self.priorities[priorityIndex].value
            ]
            if let id = topic?.id { form["category"] = id }
        }

        submitButton.isEnabled = false
        submitButton.setTitle(mode == .callback ? S.requestingCall : S.sendingRequest, for: .normal)

        ApiClient.shared.createSupportTicket(form: form) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                let number = data.ticket?.ticketNumber ?? ""
                let message = number.isEmpty ? S.ticketLogged : S.ticketLoggedNumbered(number)
                self.dismiss(animated: true) { self.onSubmitted?(message) }
            case .failure(let error):
                self.submitButton.isEnabled = true
                self.submitButton.setTitle(
                    self.mode == .callback ? S.callbackSubmit : S.ticketSubmit, for: .normal)
                self.presentAlert(error.message)
            }
        }
    }

    private func presentAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.ok, style: .default))
        present(alert, animated: true)
    }

    private func text(_ field: UITextField) -> String {
        (field.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func messageText() -> String {
        (messageView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Placeholder handling

extension SupportRequestViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        messagePlaceholder?.isHidden = !(textView.text ?? "").isEmpty
    }
}

// MARK: - Tappable value row

/// A read-only field that opens a picker — the sheet's Topic and Urgency rows.
final class ValueRow: UIControl {

    var onTap: (() -> Void)?

    private let valueLabel = UILabel()
    private let placeholder: String

    init(placeholder: String) {
        self.placeholder = placeholder
        super.init(frame: .zero)
        backgroundColor = AppColors.surfaceVariant
        layer.cornerRadius = AppMetrics.radiusMD
        layer.borderWidth = 1
        layer.borderColor = AppColors.border.cgColor

        valueLabel.font = AppFonts.regular(14)
        valueLabel.textColor = AppColors.textSecondary
        valueLabel.text = placeholder
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.forAutoLayout()

        let chevron = UIImageView(image: UIImage(systemName: "chevron.down"))
        chevron.tintColor = AppColors.textSecondary
        chevron.contentMode = .scaleAspectFit
        chevron.forAutoLayout()

        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.isUserInteractionEnabled = false
        row.addArrangedSubview(valueLabel)
        row.addArrangedSubview(chevron)
        row.forAutoLayout()
        addSubview(row)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 46),
            chevron.widthAnchor.constraint(equalToConstant: 16),
            chevron.heightAnchor.constraint(equalToConstant: 16),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// A nil or empty value falls back to the placeholder, in the muted colour.
    func setValue(_ value: String?) {
        let text = (value ?? "").trimmingCharacters(in: .whitespaces)
        valueLabel.text = text.isEmpty ? placeholder : text
        valueLabel.textColor = text.isEmpty ? AppColors.textSecondary : AppColors.textPrimary
    }
}
