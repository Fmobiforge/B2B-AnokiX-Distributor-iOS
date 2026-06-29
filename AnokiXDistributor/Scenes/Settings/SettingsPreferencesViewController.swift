import UIKit

/// Preferences — language / currency / timezone / date format (5-Settings-Preferences.png).
/// Currencies + timezones come from GET api/common/base-info; the current selection from
/// GET api/common/preferences; saved via POST api/common/preferences/update. Picker labels
/// differ from the API values, so selection is tracked by index against parallel value lists.
final class SettingsPreferencesViewController: BaseSettingsFormViewController {

    override var screenTitle: String { S.settingsPreferencesTitle }
    override var screenSubtitle: String? { S.settingsPreferencesSub }

    private let languageLabels = ["English", "Afrikaans", "Zulu"]
    private let languageValues = ["en", "af", "zu"]
    private let dateLabels = ["19 May 2024", "05/19/2024", "2024-05-19"]
    private let dateValues = ["DD MMM YYYY", "MM/DD/YYYY", "YYYY-MM-DD"]

    private var currencyLabels: [String] = []
    private var currencyValues: [String] = []   // API value = currency id
    private var currencyCodes: [String] = []    // for matching the loaded code
    private var timezoneLabels: [String] = []
    private var timezoneValues: [String] = []   // API value = IANA name

    private var selLanguage = 0
    private var selCurrency = 0
    private var selTimezone = 0
    private var selDate = 0
    private var isSaving = false

    private let languageButton = UIButton(type: .system)
    private let currencyButton = UIButton(type: .system)
    private let timezoneButton = UIButton(type: .system)
    private let dateFormatButton = UIButton(type: .system)

    override func setupForm(in card: UIView) {
        [languageButton, currencyButton, timezoneButton, dateFormatButton].forEach(stylePickerButton)

        languageButton.addAction(UIAction { [weak self] _ in self?.pick(.language) }, for: .touchUpInside)
        currencyButton.addAction(UIAction { [weak self] _ in self?.pick(.currency) }, for: .touchUpInside)
        timezoneButton.addAction(UIAction { [weak self] _ in self?.pick(.timezone) }, for: .touchUpInside)
        dateFormatButton.addAction(UIAction { [weak self] _ in self?.pick(.date) }, for: .touchUpInside)

        let stack = UIStackView.vertical(spacing: 0, alignment: .fill)
        stack.addArrangedSubview(pickerGroup(S.languageLabel, languageButton))
        stack.addArrangedSubview(pickerGroup(S.currencyLabel, currencyButton))
        stack.addArrangedSubview(pickerGroup(S.timeZoneLabel, timezoneButton))
        stack.addArrangedSubview(pickerGroup(S.dateFormatLabel, dateFormatButton))

        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        refreshButtons()
    }

    override func loadData() {
        ApiClient.shared.getBaseInfo { [weak self] result in
            guard let self = self else { return }
            let data = try? result.get()
            self.buildCurrencies(data?.currencies)
            self.buildTimezones(data?.timezones)
            self.refreshButtons()
            self.loadPreferences()
        }
    }

    private func loadPreferences() {
        ApiClient.shared.getPreferences { [weak self] result in
            guard let self = self else { return }
            let p = (try? result.get())?.preferences
            self.selLanguage = self.indexOf(self.languageValues, p?.language) ?? 0
            self.selCurrency = self.indexOf(self.currencyCodes, p?.currency) ?? 0
            self.selTimezone = self.indexOf(self.timezoneValues, p?.timezone) ?? 0
            self.selDate = self.indexOf(self.dateValues, p?.dateFormat) ?? 0
            self.refreshButtons()
        }
    }

    private func buildCurrencies(_ currencies: [BaseInfoData.Currency]?) {
        currencyLabels = []; currencyValues = []; currencyCodes = []
        if let currencies = currencies, !currencies.isEmpty {
            for c in currencies {
                let symbol = c.symbol ?? c.code ?? ""
                currencyLabels.append("\(c.name ?? c.code ?? "") (\(symbol))")
                currencyValues.append(c.id ?? c.code ?? "")
                currencyCodes.append(c.code ?? "")
            }
        } else {
            currencyLabels = ["South African Rand (R)", "US Dollar ($)", "Euro (€)"]
            currencyValues = ["1", "2", "3"]
            currencyCodes = ["ZAR", "USD", "EUR"]
        }
    }

    private func buildTimezones(_ timezones: [BaseInfoData.Timezone]?) {
        timezoneLabels = []; timezoneValues = []
        if let timezones = timezones, !timezones.isEmpty {
            for t in timezones {
                let name = t.timeZone ?? t.name ?? ""
                timezoneLabels.append("\(name) (\(Self.gmt(t.timeOffset ?? 0)))")
                timezoneValues.append(name)
            }
        } else {
            timezoneLabels = ["Africa/Johannesburg (GMT+2)"]
            timezoneValues = ["Africa/Johannesburg"]
        }
    }

    private static func gmt(_ offsetSeconds: Int64) -> String {
        let hours = offsetSeconds / 3600
        let mins = abs(offsetSeconds % 3600) / 60
        let sign = hours >= 0 ? "+" : "-"
        return mins == 0 ? "GMT\(sign)\(abs(hours))"
                         : String(format: "GMT%@%d:%02d", sign, abs(hours), mins)
    }

    private func indexOf(_ values: [String], _ value: String?) -> Int? {
        guard let value = value else { return nil }
        return values.firstIndex { $0.caseInsensitiveCompare(value) == .orderedSame }
    }

    override func onSave() {
        guard !currencyValues.isEmpty, !timezoneValues.isEmpty else { return }
        if isSaving { return }
        let language = languageValues[safe: selLanguage] ?? "en"
        let currency = currencyValues[safe: selCurrency] ?? ""
        let timezone = timezoneValues[safe: selTimezone] ?? ""
        let dateFormat = dateValues[safe: selDate] ?? "DD MMM YYYY"

        isSaving = true
        ApiClient.shared.updatePreferences(language: language, currency: currency,
                                           timezone: timezone, dateFormat: dateFormat) { [weak self] result in
            guard let self = self else { return }
            self.isSaving = false
            switch result {
            case .success:
                self.settingsSavedToast()
                self.navigationController?.popViewController(animated: true)
            case .failure(let error):
                self.toast(error.message.isEmpty ? S.settingsGenericError : error.message)
            }
        }
    }

    // MARK: - Pickers

    private enum Field { case language, currency, timezone, date }

    private func pick(_ field: Field) {
        let labels: [String]
        switch field {
        case .language: labels = languageLabels
        case .currency: labels = currencyLabels
        case .timezone: labels = timezoneLabels
        case .date: labels = dateLabels
        }
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for (index, label) in labels.enumerated() {
            alert.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                guard let self = self else { return }
                switch field {
                case .language: self.selLanguage = index
                case .currency: self.selCurrency = index
                case .timezone: self.selTimezone = index
                case .date: self.selDate = index
                }
                self.refreshButtons()
            })
        }
        alert.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(alert, animated: true)
    }

    private func refreshButtons() {
        languageButton.setTitle(languageLabels[safe: selLanguage] ?? "", for: .normal)
        currencyButton.setTitle(currencyLabels[safe: selCurrency] ?? "", for: .normal)
        timezoneButton.setTitle(timezoneLabels[safe: selTimezone] ?? "", for: .normal)
        dateFormatButton.setTitle(dateLabels[safe: selDate] ?? "", for: .normal)
    }

    private func stylePickerButton(_ button: UIButton) {
        button.contentHorizontalAlignment = .leading
        button.setTitleColor(AppColors.textPrimary, for: .normal)
        button.titleLabel?.font = AppFonts.regular(13)
        button.backgroundColor = AppColors.surface
        button.layer.cornerRadius = AppMetrics.radiusMD
        button.layer.borderWidth = 1
        button.layer.borderColor = AppColors.border.cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        button.heightAnchor.constraint(equalToConstant: 45).isActive = true
    }

    private func pickerGroup(_ label: String, _ button: UIButton) -> UIStackView {
        let title = UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textPrimary)
        let stack = UIStackView.vertical(spacing: 5, alignment: .fill)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(button)
        return stack
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
