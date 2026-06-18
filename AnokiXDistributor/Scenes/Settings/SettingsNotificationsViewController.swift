import UIKit

final class SettingsNotificationsViewController: BaseSettingsFormViewController {

    override var screenTitle: String { S.notificationPreferences }
    override var screenSubtitle: String? { S.settingsNotificationsSub }

    private let orderSwitch = UISwitch()
    private let lowStockSwitch = UISwitch()
    private let deliverySwitch = UISwitch()
    private let financeSwitch = UISwitch()
    private let reportSwitch = UISwitch()

    override func setupForm(in card: UIView) {
        let stack = UIStackView.vertical(spacing: 0, alignment: .fill)
        stack.addArrangedSubview(preferenceRow(S.notifOrderAlertsTitle, S.notifOrderAlertsSub, orderSwitch))
        stack.addArrangedSubview(divider())
        stack.addArrangedSubview(preferenceRow(S.notifLowStockTitle, S.notifLowStockSub, lowStockSwitch))
        stack.addArrangedSubview(divider())
        stack.addArrangedSubview(preferenceRow(S.notifDeliveryTitle, S.notifDeliverySub, deliverySwitch))
        stack.addArrangedSubview(divider())
        stack.addArrangedSubview(preferenceRow(S.notifFinanceTitle, S.notifFinanceSub, financeSwitch))
        stack.addArrangedSubview(divider())
        stack.addArrangedSubview(preferenceRow(S.notifReportTitle, S.notifReportSub, reportSwitch))

        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
    }

    override func loadData() {
        setSwitch(orderSwitch, key: "order_alerts", defaultValue: true)
        setSwitch(lowStockSwitch, key: "low_stock", defaultValue: true)
        setSwitch(deliverySwitch, key: "delivery_updates", defaultValue: true)
        setSwitch(financeSwitch, key: "finance_reminders", defaultValue: true)
        setSwitch(reportSwitch, key: "report_ready", defaultValue: false)
    }

    override func onSave() {
        repository.saveNotificationPreferences([
            NotificationPreference(key: "order_alerts", title: S.notifOrderAlertsTitle,
                                   subtitle: S.notifOrderAlertsSub, enabled: orderSwitch.isOn),
            NotificationPreference(key: "low_stock", title: S.notifLowStockTitle,
                                   subtitle: S.notifLowStockSub, enabled: lowStockSwitch.isOn),
            NotificationPreference(key: "delivery_updates", title: S.notifDeliveryTitle,
                                   subtitle: S.notifDeliverySub, enabled: deliverySwitch.isOn),
            NotificationPreference(key: "finance_reminders", title: S.notifFinanceTitle,
                                   subtitle: S.notifFinanceSub, enabled: financeSwitch.isOn),
            NotificationPreference(key: "report_ready", title: S.notifReportTitle,
                                   subtitle: S.notifReportSub, enabled: reportSwitch.isOn)
        ])
        settingsSavedToast()
        navigationController?.popViewController(animated: true)
    }

    private func setSwitch(_ toggle: UISwitch, key: String, defaultValue: Bool) {
        toggle.onTintColor = AppColors.purplePrimary
        if let pref = repository.getNotificationPreferences().first(where: { $0.key == key }) {
            toggle.isOn = pref.enabled
        } else {
            toggle.isOn = defaultValue
        }
    }

    private func preferenceRow(_ title: String, _ subtitle: String, _ toggle: UISwitch) -> UIView {
        let titleLabel = UILabel.make(title, font: AppFonts.medium(14), color: AppColors.textPrimary)
        let subtitleLabel = UILabel.make(subtitle, font: AppFonts.regular(11), color: AppColors.textSecondary, lines: 0)
        let textStack = UIStackView.vertical(spacing: 2, alignment: .leading)
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.addArrangedSubview(textStack)
        row.addArrangedSubview(toggle)
        let wrapper = UIView()
        wrapper.addSubview(row)
        row.pinEdges(to: wrapper, insets: UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0))
        return wrapper
    }

    private func divider() -> UIView {
        let line = UIView()
        line.backgroundColor = AppColors.divider
        line.constrainHeight(1)
        return line
    }
}
