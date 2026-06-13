import UIKit

/// Port of ReturnsActivity — summary counts, Pending/Approved/Rejected tabs, return cards with actions.
final class ReturnsViewController: BaseSecondaryViewController {

    override var screenTitle: String { S.returns }

    private var listContainer = UIStackView.vertical(spacing: 10, alignment: .fill)
    private let segments = ["pending", "approved", "rejected"]
    private var statusFilter = "pending"

    override func setupContent(in container: UIView) {
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.backgroundColor = AppColors.background

        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.forAutoLayout()
        scroll.addSubview(stack)

        let counts = repository.getReturnSummaryCounts()
        stack.addArrangedSubview(summaryRow(counts))
        stack.addArrangedSubview(ReturnStatusTabBar(
            titles: [S.pending, S.approved, S.rejected],
            selectedIndex: 0
        ) { [weak self] index in
            self?.statusFilter = self?.segments[index] ?? "pending"
            self?.reload()
        })
        stack.addArrangedSubview(ListScreenLayout.hairline())

        listContainer.forAutoLayout()
        stack.addArrangedSubview(listContainer)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -24)
        ])

        scroll.forAutoLayout()
        container.addSubview(scroll)
        scroll.pinEdges(to: container)
    }

    override func loadData() { reload() }

    private func summaryRow(_ counts: [String: Int]) -> UIStackView {
        let row = UIStackView.horizontal(spacing: 6, alignment: .fill)
        row.distribution = .fillEqually
        row.addArrangedSubview(summaryChip(S.pending, counts["pending"] ?? 0, AppColors.purplePrimary))
        row.addArrangedSubview(summaryChip(S.approved, counts["approved"] ?? 0, AppColors.success))
        row.addArrangedSubview(summaryChip(S.rejected, counts["rejected"] ?? 0, AppColors.danger))
        return row
    }

    private func reload() {
        listContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for item in repository.getReturns(statusFilter: statusFilter) {
            listContainer.addArrangedSubview(card(item))
        }
    }

    private func summaryChip(_ title: String, _ value: Int, _ color: UIColor) -> UIView {
        let card = StyleKit.cardView()
        let valueLabel = UILabel.make("\(value)", font: AppFonts.bold(22), color: color, align: .center)
        let titleLabel = UILabel.make(title, font: AppFonts.light(11), color: AppColors.textSecondary, align: .center)
        let stack = UIStackView.vertical(spacing: 4, alignment: .center)
        stack.forAutoLayout()
        stack.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(titleLabel)
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8))
        return card
    }

    private func card(_ r: ReturnItem) -> UIView {
        let card = StyleKit.cardView()
        let iconTile = StyleKit.iconTile(color: AppColors.purpleLight)
        iconTile.constrainSize(44)
        let icon = UIImageView(image: AppIcons.symbol("ic_package"))
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

        let idLabel = UILabel.make(r.id, font: AppFonts.bold(13), color: AppColors.purplePrimary)
        let trader = UILabel.make(r.traderName, font: AppFonts.regular(12), color: AppColors.textPrimary)
        let reason = UILabel.make(r.reason, font: AppFonts.light(10), color: AppColors.textSecondary)
        let textStack = UIStackView.vertical(spacing: 2, alignment: .leading)
        textStack.addArrangedSubview(idLabel)
        textStack.addArrangedSubview(trader)
        textStack.addArrangedSubview(reason)

        let amount = UILabel.make(r.amount, font: AppFonts.bold(16), color: AppColors.textPrimary)
        amount.setContentHuggingPriority(.required, for: .horizontal)

        let topRow = UIStackView.horizontal(spacing: 12, alignment: .center)
        topRow.addArrangedSubview(iconTile)
        topRow.addArrangedSubview(textStack)
        topRow.addArrangedSubview(amount)

        let timestamp = UILabel.make(r.timestamp, font: AppFonts.light(10), color: AppColors.textSecondary)
        let approve = actionButton(S.approve, color: AppColors.success, icon: "checkmark")
        let reject = actionButton(S.reject, color: AppColors.danger, icon: "xmark.circle")
        approve.addAction(UIAction { [weak self] _ in self?.toast("Approved \(r.id)") }, for: .touchUpInside)
        reject.addAction(UIAction { [weak self] _ in self?.toast("Rejected \(r.id)") }, for: .touchUpInside)

        let actionRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        actionRow.addArrangedSubview(timestamp)
        actionRow.addArrangedSubview(UIView())
        actionRow.addArrangedSubview(approve)
        actionRow.addArrangedSubview(reject)
        actionRow.isHidden = r.status.lowercased() != "pending"

        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.forAutoLayout()
        stack.addArrangedSubview(topRow)
        stack.addArrangedSubview(actionRow)
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        return card
    }

    private func actionButton(_ title: String, color: UIColor, icon: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.image = UIImage(systemName: icon)
        config.imagePadding = 4
        config.baseForegroundColor = color
        config.background.strokeColor = color.withAlphaComponent(0.35)
        config.background.backgroundColor = color.withAlphaComponent(0.08)
        config.background.strokeWidth = 1
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        let button = UIButton(configuration: config)
        button.titleLabel?.font = AppFonts.bold(12)
        button.constrainHeight(34)
        return button
    }
}
