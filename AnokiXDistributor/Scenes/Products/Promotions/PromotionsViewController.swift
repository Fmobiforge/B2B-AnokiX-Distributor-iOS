import UIKit

/// Port of PromotionsActivity. Promotion cards + bottom Create Promotion button.
final class PromotionsViewController: BaseSecondaryViewController {

    override var screenTitle: String { S.promotions }
    override var screenSubtitle: String? { "Manage campaigns and track performance" }

    override func setupContent(in container: UIView) {
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.backgroundColor = AppColors.surface

        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.forAutoLayout()
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -80),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32)
        ])

        scroll.forAutoLayout()
        container.addSubview(scroll)

        let create = UIButton(type: .system)
        StyleKit.stylePrimaryButton(create)
        create.setTitle(S.createPromotion, for: .normal)
        create.setImage(UIImage(systemName: "plus"), for: .normal)
        create.tintColor = .white
        create.addTarget(self, action: #selector(createTapped), for: .touchUpInside)
        create.forAutoLayout()
        container.addSubview(create)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: container.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            create.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            create.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            create.bottomAnchor.constraint(equalTo: container.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            create.heightAnchor.constraint(equalToConstant: 48)
        ])

        self.promoStack = stack
    }

    private var promoStack: UIStackView!

    override func loadData() {
        promoStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for promo in repository.getPromotions() {
            promoStack.addArrangedSubview(makeCard(promo))
        }
    }

    private func makeCard(_ promo: PromotionItem) -> UIView {
        let card = StyleKit.cardView()

        let banner = UIView()
        banner.backgroundColor = promo.bannerColor
        banner.layer.cornerRadius = AppMetrics.radiusMD
        banner.constrainHeight(80)
        let bannerLabel = UILabel.make(promo.bannerLabel, font: AppFonts.bold(15), color: .white, align: .center)
        bannerLabel.forAutoLayout()
        banner.addSubview(bannerLabel)
        bannerLabel.pinEdges(to: banner, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))

        let title = UILabel.make(promo.title, font: AppFonts.bold(14), color: AppColors.textPrimary)
        let status = StyleKit.badgeLabel()
        StyleKit.applyStatusBadge(status, status: promo.status)
        status.setContentHuggingPriority(.required, for: .horizontal)
        let titleRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        titleRow.addArrangedSubview(title)
        titleRow.addArrangedSubview(UIView())
        titleRow.addArrangedSubview(status)

        let metrics = UIStackView.horizontal(spacing: 24, alignment: .fill)
        metrics.distribution = .fillEqually
        metrics.addArrangedSubview(metric("Impressions", promo.impressions))
        metrics.addArrangedSubview(metric("CTR", promo.ctr))

        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.forAutoLayout()
        [banner, titleRow, metrics].forEach { stack.addArrangedSubview($0) }
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        return card
    }

    private func metric(_ title: String, _ value: String) -> UIStackView {
        let stack = UIStackView.vertical(spacing: 2, alignment: .leading)
        stack.addArrangedSubview(UILabel.make(value, font: AppFonts.bold(16), color: AppColors.textPrimary))
        stack.addArrangedSubview(UILabel.make(title, font: AppFonts.regular(10), color: AppColors.textSecondary))
        return stack
    }

    @objc private func createTapped() {
        toast(S.createPromotion)
    }
}
