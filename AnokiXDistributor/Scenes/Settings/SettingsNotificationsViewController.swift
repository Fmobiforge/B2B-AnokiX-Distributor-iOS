import UIKit

final class SettingsNotificationsViewController: BaseSettingsFormViewController {

    override var screenTitle: String { S.notificationPreferences }
    override var screenSubtitle: String? { S.settingsNotificationsSub }

    private let orderSwitch = UISwitch()
    private let lowStockSwitch = UISwitch()
    private let deliverySwitch = UISwitch()
    private let promotionSwitch = UISwitch()
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
        stack.addArrangedSubview(preferenceRow(S.notifPromotionTitle, S.notifPromotionSub, promotionSwitch))
        stack.addArrangedSubview(divider())
        stack.addArrangedSubview(preferenceRow(S.notifFinanceTitle, S.notifFinanceSub, financeSwitch))
        stack.addArrangedSubview(divider())
        stack.addArrangedSubview(preferenceRow(S.notifReportTitle, S.notifReportSub, reportSwitch))

        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
    }

    private var isSaving = false

    override func loadData() {
        [orderSwitch, lowStockSwitch, deliverySwitch, promotionSwitch, financeSwitch, reportSwitch]
            .forEach { $0.onTintColor = AppColors.purplePrimary }

        ApiClient.shared.getPreferences { [weak self] result in
            guard let self = self else { return }
            let p = (try? result.get())?.preferences
            self.orderSwitch.isOn = p?.notif(.orderAlerts) ?? true
            self.lowStockSwitch.isOn = p?.notif(.lowStockAlerts) ?? true
            self.deliverySwitch.isOn = p?.notif(.deliveryUpdates) ?? true
            self.promotionSwitch.isOn = p?.notif(.promotionAlerts) ?? true
            self.financeSwitch.isOn = p?.notif(.financeReminders) ?? true
            self.reportSwitch.isOn = p?.notif(.reportReady) ?? true
        }
    }

    override func onSave() {
        if isSaving { return }
        isSaving = true
        ApiClient.shared.updateNotificationPrefs(
            orderAlerts: orderSwitch.isOn,
            lowStockAlerts: lowStockSwitch.isOn,
            deliveryUpdates: deliverySwitch.isOn,
            promotionAlerts: promotionSwitch.isOn,
            financeReminders: financeSwitch.isOn,
            reportReady: reportSwitch.isOn) { [weak self] result in
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
