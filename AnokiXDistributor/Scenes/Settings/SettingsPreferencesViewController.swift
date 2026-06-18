import UIKit

final class SettingsPreferencesViewController: BaseSettingsFormViewController {

    override var screenTitle: String { S.settingsPreferencesTitle }
    override var screenSubtitle: String? { S.settingsPreferencesSub }

    private let languages = ["English", "Afrikaans", "Zulu"]
    private let currencies = ["South African Rand (ZAR)", "US Dollar (USD)", "Euro (EUR)"]
    private let timezones = ["Africa/Johannesburg", "Africa/Cape_Town", "UTC"]
    private let dateFormats = ["19 May 2024", "2024-05-19", "05/19/2024"]

    private let languageButton = UIButton(type: .system)
    private let currencyButton = UIButton(type: .system)
    private let timezoneButton = UIButton(type: .system)
    private let dateFormatButton = UIButton(type: .system)

    private var selectedLanguage = ""
    private var selectedCurrency = ""
    private var selectedTimezone = ""
    private var selectedDateFormat = ""

    override func setupForm(in card: UIView) {
        stylePickerButton(languageButton)
        stylePickerButton(currencyButton)
        stylePickerButton(timezoneButton)
        stylePickerButton(dateFormatButton)

        languageButton.addAction(UIAction { [weak self] _ in self?.pick(from: self?.languages ?? [], key: "language") }, for: .touchUpInside)
        currencyButton.addAction(UIAction { [weak self] _ in self?.pick(from: self?.currencies ?? [], key: "currency") }, for: .touchUpInside)
        timezoneButton.addAction(UIAction { [weak self] _ in self?.pick(from: self?.timezones ?? [], key: "timezone") }, for: .touchUpInside)
        dateFormatButton.addAction(UIAction { [weak self] _ in self?.pick(from: self?.dateFormats ?? [], key: "dateFormat") }, for: .touchUpInside)

        let stack = UIStackView.vertical(spacing: 0, alignment: .fill)
        stack.addArrangedSubview(pickerGroup(S.languageLabel, languageButton))
        stack.addArrangedSubview(pickerGroup(S.currencyLabel, currencyButton))
        stack.addArrangedSubview(pickerGroup(S.timeZoneLabel, timezoneButton))
        stack.addArrangedSubview(pickerGroup(S.dateFormatLabel, dateFormatButton))

        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
    }

    override func loadData() {
        let data = repository.getAppPreferences()
        selectedLanguage = data.language
        selectedCurrency = data.currency
        selectedTimezone = data.timezone
        selectedDateFormat = data.dateFormat
        refreshButtons()
    }

    override func onSave() {
        repository.saveAppPreferences(AppPreferences(
            language: selectedLanguage,
            currency: selectedCurrency,
            timezone: selectedTimezone,
            dateFormat: selectedDateFormat
        ))
        settingsSavedToast()
        navigationController?.popViewController(animated: true)
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

    private func refreshButtons() {
        languageButton.setTitle(selectedLanguage, for: .normal)
        currencyButton.setTitle(selectedCurrency, for: .normal)
        timezoneButton.setTitle(selectedTimezone, for: .normal)
        dateFormatButton.setTitle(selectedDateFormat, for: .normal)
    }

    private func pick(from options: [String], key: String) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for option in options {
            alert.addAction(UIAlertAction(title: option, style: .default) { [weak self] _ in
                guard let self = self else { return }
                switch key {
                case "language": self.selectedLanguage = option
                case "currency": self.selectedCurrency = option
                case "timezone": self.selectedTimezone = option
                default: self.selectedDateFormat = option
                }
                self.refreshButtons()
            })
        }
        alert.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        present(alert, animated: true)
    }
}
