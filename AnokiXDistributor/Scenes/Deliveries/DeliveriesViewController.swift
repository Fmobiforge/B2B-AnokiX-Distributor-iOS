import UIKit

/// Port of DeliveriesActivity — scroll segment tabs, date range + driver filters, delivery cards.
final class DeliveriesViewController: BaseSecondaryViewController {

    override var screenTitle: String { S.deliveries }

    private var listContainer = UIStackView.vertical(spacing: 12, alignment: .fill)
    private let segments = ["all", "in_transit", "delivered", "delayed"]
    private var statusFilter = "all"
    private var selectedDriver = MockData.filterDrivers[0]
    private var statusFiltered: [DeliveryItem] = []

    override func setupContent(in container: UIView) {
        let titleBlock = ListScreenLayout.surfaceSection(
            [UILabel.make(S.deliveries, font: AppFonts.bold(AppMetrics.textHeadline), color: AppColors.textPrimary)],
            insets: UIEdgeInsets(top: 16, left: 16, bottom: 12, right: 16)
        )

        let segment = ScrollSegmentBar(
            titles: [S.tabAll, S.inTransit, S.delivered, S.delayed],
            selectedIndex: 0
        ) { [weak self] index in
            self?.statusFilter = self?.segments[index] ?? "all"
            self?.applyStatusFilter()
        }

        let defaultRange = FilterUiHelper.defaultWeekRange()
        let datePill = DateRangePillView(text: FilterUiHelper.formatDateRange(start: defaultRange.start, end: defaultRange.end))
        let driverPill = FilterPillButton(title: S.driverLabel)
        driverPill.titleLabel.text = selectedDriver

        let filterRow = UIStackView.horizontal(spacing: 8, alignment: .fill)
        datePill.forAutoLayout()
        filterRow.addArrangedSubview(datePill)
        filterRow.addArrangedSubview(driverPill)

        FilterUiHelper.bindDateRangePicker(
            on: datePill,
            label: datePill.rangeLabel,
            from: self,
            start: defaultRange.start,
            end: defaultRange.end
        ) { _, _, _ in }

        FilterUiHelper.bindDropdown(
            on: driverPill,
            label: driverPill.titleLabel,
            options: MockData.filterDrivers,
            selectedIndex: 0,
            title: S.driverLabel,
            from: self
        ) { [weak self] _, value in
            self?.selectedDriver = value
            self?.applyDriverFilter()
        }

        let filterBlock = ListScreenLayout.surfaceSection([filterRow], insets: UIEdgeInsets(top: 0, left: 16, bottom: 12, right: 16))

        let chrome = UIStackView.vertical(spacing: 0, alignment: .fill)
        chrome.addArrangedSubview(titleBlock)
        chrome.addArrangedSubview(segment)
        chrome.addArrangedSubview(filterBlock)
        chrome.addArrangedSubview(ListScreenLayout.hairline())

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.backgroundColor = AppColors.surface
        listContainer.forAutoLayout()
        scroll.addSubview(listContainer)
        NSLayoutConstraint.activate([
            listContainer.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
            listContainer.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            listContainer.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            listContainer.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            listContainer.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32)
        ])

        chrome.forAutoLayout()
        scroll.forAutoLayout()
        container.addSubviews(chrome, scroll)
        NSLayoutConstraint.activate([
            chrome.topAnchor.constraint(equalTo: container.topAnchor),
            chrome.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: chrome.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    override func loadData() {
        applyStatusFilter()
    }

    private func applyStatusFilter() {
        statusFiltered = repository.getDeliveries(statusFilter: statusFilter)
        applyDriverFilter()
    }

    private func applyDriverFilter() {
        reload(with: selectedDriver == MockData.filterDrivers[0]
            ? statusFiltered
            : statusFiltered.filter { $0.driverName == selectedDriver })
    }

    private func reload(with items: [DeliveryItem]) {
        listContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for delivery in items {
            listContainer.addArrangedSubview(card(delivery))
        }
    }

    private func card(_ d: DeliveryItem) -> UIView {
        let card = StyleKit.cardView()
        card.layer.shadowOpacity = 0.06
        card.layer.shadowRadius = 4
        card.layer.shadowOffset = CGSize(width: 0, height: 2)

        let iconTile = StyleKit.iconTile(color: AppColors.purpleLight)
        iconTile.constrainSize(44)
        let icon = UIImageView(image: AppIcons.symbol("ic_deliveries"))
        icon.tintColor = AppColors.purplePrimary
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        iconTile.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22)
        ])

        let idLabel = UILabel.make("DEL-ID: \(d.id)", font: AppFonts.bold(12), color: AppColors.textPrimary)
        let status = StyleKit.badgeLabel()
        applyDeliveryBadge(status, status: d.status)
        status.setContentHuggingPriority(.required, for: .horizontal)
        let idRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        idRow.addArrangedSubview(idLabel)
        idRow.addArrangedSubview(UIView())
        idRow.addArrangedSubview(status)

        let details = UIStackView.vertical(spacing: 10, alignment: .fill)
        details.addArrangedSubview(idRow)
        details.addArrangedSubview(deliveryInfoRow(S.traderLabel, d.traderName, S.driverLabel, d.driverName))
        details.addArrangedSubview(labeledValue(S.etaLabel, d.eta))

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = AppColors.textSecondary
        chevron.contentMode = .scaleAspectFit
        chevron.constrainSize(18)

        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.forAutoLayout()
        row.addArrangedSubview(iconTile)
        row.addArrangedSubview(details)
        row.addArrangedSubview(chevron)
        card.addSubview(row)
        row.pinEdges(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        return card
    }

    private func deliveryInfoRow(_ l1: String, _ v1: String, _ l2: String, _ v2: String) -> UIStackView {
        let col1 = labeledColumn(l1, v1)
        let col2 = labeledColumn(l2, v2)
        let row = UIStackView.horizontal(spacing: 8, alignment: .top)
        row.distribution = .fillEqually
        row.addArrangedSubview(col1)
        row.addArrangedSubview(col2)
        return row
    }

    private func labeledColumn(_ label: String, _ value: String) -> UIStackView {
        let stack = UIStackView.vertical(spacing: 2, alignment: .leading)
        stack.addArrangedSubview(UILabel.make(label, font: AppFonts.light(10), color: AppColors.textSecondary))
        stack.addArrangedSubview(UILabel.make(value, font: AppFonts.regular(11), color: AppColors.textPrimary))
        return stack
    }

    private func labeledValue(_ label: String, _ value: String) -> UIStackView {
        let stack = UIStackView.vertical(spacing: 2, alignment: .leading)
        stack.addArrangedSubview(UILabel.make(label, font: AppFonts.light(10), color: AppColors.textSecondary))
        stack.addArrangedSubview(UILabel.make(value, font: AppFonts.regular(10), color: AppColors.textPrimary))
        return stack
    }

    private func applyDeliveryBadge(_ badge: PaddingLabel, status: String) {
        switch status.lowercased() {
        case "delivered":
            badge.text = S.delivered
            badge.textColor = AppColors.success
            badge.backgroundColor = AppColors.successBg
        case "delayed":
            badge.text = S.delayed
            badge.textColor = AppColors.danger
            badge.backgroundColor = AppColors.dangerBg
        default:
            badge.text = S.inTransit
            badge.textColor = AppColors.warning
            badge.backgroundColor = AppColors.warningBg
        }
    }
}
