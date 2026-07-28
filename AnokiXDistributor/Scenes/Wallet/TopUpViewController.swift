import UIKit

/// "Top up your wallet" sheet (newDesign/wallet/wallet03.png). Collects the ZAR amount —
/// via the quick-amount pills or free entry — and hands it to the wallet screen, which
/// opens the PayCloud checkout. Parity with the Android dialog_topup layout.
final class TopUpViewController: UIViewController {

    private static let quickAmounts: [Double] = [50, 100, 200, 500, 1000]

    /// Called with the entered amount; the host validates and runs the API call.
    private let onProceed: (Double, TopUpViewController) -> Void

    private let amountField = UITextField()
    private let errorLabel = UILabel.make("", font: AppFonts.regular(12), color: AppColors.danger, lines: 0)
    private let proceedButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var chips: [UIButton] = []

    init(onProceed: @escaping (Double, TopUpViewController) -> Void) {
        self.onProceed = onProceed
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.surface
        buildLayout()
    }

    private func buildLayout() {
        let title = UILabel.make(S.topupTitle, font: AppFonts.bold(18), color: AppColors.textPrimary)

        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark"), for: .normal)
        close.tintColor = AppColors.textSecondary
        close.setContentHuggingPriority(.required, for: .horizontal)
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        header.isLayoutMarginsRelativeArrangement = true
        header.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        header.addArrangedSubview(title)
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(close)

        let divider = UIView()
        divider.backgroundColor = AppColors.border
        divider.constrainHeight(1)

        let body = UILabel.make(S.topupBody, font: AppFonts.regular(13), color: AppColors.textSecondary, lines: 0)

        // Quick-amount pills — one equal-width row, as on the web dialog.
        let chipRow = UIStackView.horizontal(spacing: 7, alignment: .fill)
        chipRow.distribution = .fillEqually
        for amount in Self.quickAmounts {
            let chip = makeChip(amount)
            chips.append(chip)
            chipRow.addArrangedSubview(chip)
        }

        let amountLabel = UILabel.make(S.topupAmountLabel, font: AppFonts.bold(13), color: AppColors.textPrimary)

        amountField.placeholder = S.topupAmountHint
        amountField.keyboardType = .decimalPad
        amountField.font = AppFonts.regular(14)
        amountField.textColor = AppColors.textPrimary
        amountField.backgroundColor = AppColors.surfaceVariant
        amountField.layer.cornerRadius = AppMetrics.radiusMD
        amountField.layer.borderWidth = 1
        amountField.layer.borderColor = AppColors.border.cgColor
        amountField.constrainHeight(50)
        amountField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        amountField.leftViewMode = .always
        amountField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        amountField.rightViewMode = .always
        amountField.addTarget(self, action: #selector(amountChanged), for: .editingChanged)

        errorLabel.isHidden = true

        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = AppColors.purplePrimary
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        config.image = UIImage(systemName: "creditcard.fill")
        config.imagePadding = 8
        config.contentInsets = NSDirectionalEdgeInsets(top: 15, leading: 16, bottom: 15, trailing: 16)
        config.title = S.topupProceed
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.bold(14); return out
        }
        proceedButton.configuration = config
        proceedButton.addTarget(self, action: #selector(proceedTapped), for: .touchUpInside)

        spinner.hidesWhenStopped = true
        spinner.color = .white
        spinner.forAutoLayout()
        proceedButton.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: proceedButton.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: proceedButton.centerYAnchor)
        ])

        let content = UIStackView.vertical(spacing: 0, alignment: .fill)
        content.forAutoLayout()
        content.addArrangedSubview(header)
        content.setCustomSpacing(12, after: header)
        content.addArrangedSubview(divider)

        let inset = UIStackView.vertical(spacing: 0, alignment: .fill)
        inset.isLayoutMarginsRelativeArrangement = true
        inset.layoutMargins = UIEdgeInsets(top: 16, left: 20, bottom: 0, right: 20)
        inset.addArrangedSubview(body)
        inset.setCustomSpacing(16, after: body)
        inset.addArrangedSubview(chipRow)
        inset.setCustomSpacing(18, after: chipRow)
        inset.addArrangedSubview(amountLabel)
        inset.setCustomSpacing(8, after: amountLabel)
        inset.addArrangedSubview(amountField)
        inset.setCustomSpacing(6, after: amountField)
        inset.addArrangedSubview(errorLabel)
        inset.setCustomSpacing(18, after: errorLabel)
        inset.addArrangedSubview(proceedButton)
        content.addArrangedSubview(inset)

        view.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func makeChip(_ amount: Double) -> UIButton {
        let chip = UIButton(type: .system)
        chip.tag = Int(amount)
        chip.setTitle("R" + Self.pillText(amount), for: .normal)
        chip.titleLabel?.font = AppFonts.bold(13)
        chip.titleLabel?.adjustsFontSizeToFitWidth = true
        chip.titleLabel?.minimumScaleFactor = 0.8
        chip.layer.cornerRadius = 20
        chip.layer.borderWidth = 1
        chip.constrainHeight(40)
        chip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        styleChip(chip, selected: false)
        return chip
    }

    /// `1000` → `"1 000"` — space thousands, matching the web pills.
    private static func pillText(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? String(Int(amount))
    }

    private func styleChip(_ chip: UIButton, selected: Bool) {
        chip.backgroundColor = selected ? AppColors.purpleLight : AppColors.surface
        chip.layer.borderColor = (selected ? AppColors.purplePrimary : AppColors.border).cgColor
        chip.setTitleColor(selected ? AppColors.purplePrimary : AppColors.textPrimary, for: .normal)
    }

    /// Keeps a pill lit only while the field still matches it.
    private func syncChipSelection() {
        let typed = enteredAmount()
        for chip in chips {
            styleChip(chip, selected: abs(Double(chip.tag) - typed) < 0.005)
        }
    }

    // MARK: - Actions

    @objc private func chipTapped(_ sender: UIButton) {
        amountField.text = String(sender.tag)
        errorLabel.isHidden = true
        syncChipSelection()
    }

    @objc private func amountChanged() {
        errorLabel.isHidden = true
        syncChipSelection()
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func proceedTapped() {
        view.endEditing(true)
        onProceed(enteredAmount(), self)
    }

    /// Accepts "1 000,50", "1000.50" and "R1000" alike.
    private func enteredAmount() -> Double {
        var cleaned = (amountField.text ?? "")
            .filter { $0.isNumber || $0 == "." || $0 == "," }
        guard !cleaned.isEmpty else { return 0 }
        // A lone comma is the decimal separator in ZA formatting.
        if cleaned.contains(",") && !cleaned.contains(".") {
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        } else {
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        }
        return Double(cleaned) ?? 0
    }

    // MARK: - Host callbacks

    func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }

    func setBusy(_ busy: Bool) {
        proceedButton.isEnabled = !busy
        proceedButton.configuration?.title = busy ? "" : S.topupProceed
        proceedButton.configuration?.image = busy ? nil : UIImage(systemName: "creditcard.fill")
        if busy {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
    }
}
