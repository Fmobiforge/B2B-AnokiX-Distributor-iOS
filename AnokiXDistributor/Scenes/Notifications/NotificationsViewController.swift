import UIKit

/// Port of NotificationsActivity — unread header, mark all read, underline tabs, notification cards.
final class NotificationsViewController: BaseSecondaryViewController {

    override var screenTitle: String { S.notifications }

    private var listContainer = UIStackView.vertical(spacing: 8, alignment: .fill)
    private let segments = ["all", "unread", "orders"]
    private var filter = "all"
    private var unreadLabel: UILabel!

    override func setupContent(in container: UIView) {
        unreadLabel = UILabel.make("3 unread", font: AppFonts.bold(AppMetrics.textBodySM), color: AppColors.purplePrimary)

        let markAllButton = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "checkmark.circle")
        config.title = S.markAllRead
        config.imagePadding = 6
        config.baseForegroundColor = AppColors.purplePrimary
        config.background.strokeColor = AppColors.purplePrimary.withAlphaComponent(0.35)
        config.background.strokeWidth = 1
        config.background.backgroundColor = AppColors.purpleLight
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        markAllButton.configuration = config
        markAllButton.titleLabel?.font = AppFonts.regular(AppMetrics.textBodySM)
        markAllButton.addTarget(self, action: #selector(markAllTapped), for: .touchUpInside)

        let headerRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        headerRow.addArrangedSubview(unreadLabel)
        headerRow.addArrangedSubview(UIView())
        headerRow.addArrangedSubview(markAllButton)

        let tabs = UnderlineTabBar(titles: ["All", "Unread", "Orders"], selectedIndex: 0) { [weak self] index in
            guard let self = self else { return }
            self.filter = self.segments[index]
            self.reload()
        }

        let chrome = ListScreenLayout.surfaceSection(
            [headerRow, tabs],
            spacing: 4,
            insets: UIEdgeInsets(top: 16, left: 16, bottom: 0, right: 16)
        )

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = false
        listContainer.forAutoLayout()
        scroll.addSubview(listContainer)
        NSLayoutConstraint.activate([
            listContainer.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
            listContainer.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            listContainer.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            listContainer.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            listContainer.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32)
        ])

        _ = embedSecondaryListChrome(in: container, chrome: chrome, listView: scroll)
    }

    override func loadData() { reload() }

    @objc private func markAllTapped() {
        repository.markAllNotificationsRead()
        reload()
        toast("All notifications marked as read")
    }

    private func reload() {
        let items = repository.getNotifications(filter: filter)
        let unread = repository.getNotifications(filter: "unread").count
        unreadLabel.text = S.unreadCount(unread)
        listContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for item in items {
            listContainer.addArrangedSubview(card(item))
        }
    }

    private func card(_ n: NotificationItem) -> UIView {
        let card = StyleKit.cardView()
        if n.unread { card.layer.borderColor = AppColors.purplePrimary.withAlphaComponent(0.4).cgColor }

        let tile = StyleKit.iconTile(color: n.iconBg)
        tile.constrainSize(40)
        let icon = UIImageView(image: AppIcons.symbol(n.icon))
        icon.tintColor = n.iconTint
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        tile.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18)
        ])

        let title = UILabel.make(n.title, font: AppFonts.bold(13), color: AppColors.textPrimary)
        let message = UILabel.make(n.message, font: AppFonts.regular(11), color: AppColors.textSecondary, lines: 0)
        let time = UILabel.make(n.relativeTime, font: AppFonts.light(10), color: AppColors.textTertiary)
        let textStack = UIStackView.vertical(spacing: 3, alignment: .leading)
        [title, message, time].forEach { textStack.addArrangedSubview($0) }
        if !n.actionLabel.isEmpty {
            textStack.addArrangedSubview(UILabel.make(n.actionLabel, font: AppFonts.medium(12), color: AppColors.purplePrimary))
        }

        let row = UIStackView.horizontal(spacing: 12, alignment: .top)
        row.forAutoLayout()
        row.addArrangedSubview(tile)
        row.addArrangedSubview(textStack)
        card.addSubview(row)
        row.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        return card
    }
}
