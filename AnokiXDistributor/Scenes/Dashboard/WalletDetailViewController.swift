import UIKit

/// Bottom-sheet panel showing the anokiX (IMB) wallet detail — Available / Current /
/// Pending balances with an "as of" timestamp and a refresh button. Mirrors the web
/// portal wallet dropdown (dashboard_new2.png). Parity with the Android wallet sheet.
final class WalletDetailViewController: UIViewController {

    private var wallet: WalletData
    private let currencySymbol: String
    private let onUpdated: (WalletData) -> Void

    private let availableLabel = UILabel()
    private let currentLabel = UILabel()
    private let pendingLabel = UILabel()
    private let asOfLabel = UILabel()
    private let refreshIcon = UIImageView(image: UIImage(systemName: "arrow.clockwise"))

    init(wallet: WalletData, currencySymbol: String, onUpdated: @escaping (WalletData) -> Void) {
        self.wallet = wallet
        self.currencySymbol = currencySymbol
        self.onUpdated = onUpdated
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.surface
        buildLayout()
        apply()
    }

    private func buildLayout() {
        // Header: icon + title/subtitle + refresh.
        let tile = UIView()
        tile.backgroundColor = AppColors.purplePrimary
        tile.layer.cornerRadius = AppMetrics.radiusLG
        tile.constrainSize(40)
        let icon = UIImageView(image: UIImage(systemName: "creditcard.fill"))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        tile.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20)
        ])

        let title = UILabel.make("anokiX wallet", font: AppFonts.bold(16), color: AppColors.textPrimary)
        let subtitle = UILabel.make("Powered by IMB", font: AppFonts.light(11), color: AppColors.textSecondary)
        let titleStack = UIStackView.vertical(spacing: 1, alignment: .leading)
        titleStack.addArrangedSubview(title)
        titleStack.addArrangedSubview(subtitle)

        let refreshButton = UIControl()
        refreshButton.constrainSize(40)
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        refreshIcon.tintColor = AppColors.purplePrimary
        refreshIcon.contentMode = .scaleAspectFit
        refreshIcon.forAutoLayout()
        refreshButton.addSubview(refreshIcon)
        NSLayoutConstraint.activate([
            refreshIcon.centerXAnchor.constraint(equalTo: refreshButton.centerXAnchor),
            refreshIcon.centerYAnchor.constraint(equalTo: refreshButton.centerYAnchor),
            refreshIcon.widthAnchor.constraint(equalToConstant: 20),
            refreshIcon.heightAnchor.constraint(equalToConstant: 20)
        ])

        let header = UIStackView.horizontal(spacing: 12, alignment: .center)
        header.addArrangedSubview(tile)
        header.addArrangedSubview(titleStack)
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(refreshButton)

        let divider = UIView()
        divider.backgroundColor = AppColors.borderLight
        divider.constrainHeight(1)

        [availableLabel, currentLabel, pendingLabel].forEach {
            $0.font = AppFonts.bold(16)
            $0.textColor = AppColors.textPrimary
        }
        availableLabel.textColor = AppColors.purplePrimary
        currentLabel.font = AppFonts.bold(14)
        pendingLabel.font = AppFonts.bold(14)

        let rows = UIStackView.vertical(spacing: 0, alignment: .fill)
        rows.addArrangedSubview(detailRow("Available", availableLabel))
        rows.addArrangedSubview(hairline())
        rows.addArrangedSubview(detailRow("Current", currentLabel))
        rows.addArrangedSubview(hairline())
        rows.addArrangedSubview(detailRow("Pending", pendingLabel))

        asOfLabel.font = AppFonts.light(11)
        asOfLabel.textColor = AppColors.textTertiary

        let content = UIStackView.vertical(spacing: 14, alignment: .fill)
        content.isLayoutMarginsRelativeArrangement = true
        content.layoutMargins = UIEdgeInsets(top: 24, left: 20, bottom: 20, right: 20)
        content.addArrangedSubview(header)
        content.addArrangedSubview(divider)
        content.addArrangedSubview(rows)
        content.addArrangedSubview(asOfLabel)
        content.forAutoLayout()
        view.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func detailRow(_ title: String, _ value: UILabel) -> UIView {
        let key = UILabel.make(title, font: AppFonts.regular(14), color: AppColors.textSecondary)
        value.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.layoutMargins = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        row.isLayoutMarginsRelativeArrangement = true
        row.addArrangedSubview(key)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(value)
        return row
    }

    private func hairline() -> UIView {
        let v = UIView()
        v.backgroundColor = AppColors.borderLight
        v.constrainHeight(1)
        return v
    }

    private func apply() {
        let b = wallet.balance
        availableLabel.text = WalletFormat.money(currencySymbol, b?.available)
        currentLabel.text = WalletFormat.money(currencySymbol, b?.current)
        pendingLabel.text = WalletFormat.money(currencySymbol, b?.pending)
        let time = WalletFormat.asOfTime(b?.asOf)
        asOfLabel.isHidden = time.isEmpty
        asOfLabel.text = time.isEmpty ? nil : "as of \(time)"
    }

    @objc private func refreshTapped() {
        let spin = CABasicAnimation(keyPath: "transform.rotation")
        spin.fromValue = 0
        spin.toValue = 2 * Double.pi
        spin.duration = 0.6
        refreshIcon.layer.add(spin, forKey: "spin")

        ApiClient.shared.getWallet { [weak self] result in
            guard let self = self, case .success(let data) = result else { return }
            self.wallet = data
            self.apply()
            self.onUpdated(data)
        }
    }
}

/// Shared wallet value formatting used by the dashboard card and this detail sheet.
enum WalletFormat {
    private static let money: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        f.decimalSeparator = "."
        return f
    }()

    static func money(_ symbol: String, _ value: Double?) -> String {
        let v = value ?? 0
        let s = money.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
        return symbol + s
    }

    /// ZA money: `R 40 168,50` — space thousands, comma decimals, sign kept.
    /// Used by the Settings → Business wallet step, which mirrors the web portal.
    static func zaMoney(_ value: Double?) -> String {
        let v = value ?? 0
        let digits = money.string(from: NSNumber(value: abs(v)))
            ?? String(format: "%.2f", abs(v))
        let za = digits.replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ".", with: ",")
        return (v < 0 ? "R -" : "R ") + za
    }

    /// ISO-8601 ledger timestamp → "15 Jul 2026, 15:58"; falls back to the raw value.
    static func ledgerDate(_ iso: String?) -> String {
        guard let iso = iso, !iso.isEmpty else { return "" }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        guard let date = parser.date(from: iso) else { return iso }
        let out = DateFormatter()
        out.dateFormat = "dd MMM yyyy, HH:mm"
        out.locale = Locale(identifier: "en_US_POSIX")
        return out.string(from: date)
    }

    /// "HH:mm" (device-local) from an ISO-8601 timestamp; "" if unparseable.
    static func asOfTime(_ iso: String?) -> String {
        guard let iso = iso, !iso.isEmpty else { return "" }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        guard let date = parser.date(from: iso) else { return "" }
        let out = DateFormatter()
        out.dateFormat = "HH:mm"
        return out.string(from: date)
    }
}
