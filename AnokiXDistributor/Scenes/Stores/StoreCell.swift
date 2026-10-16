import UIKit

/// item_store.xml — store icon tile, name, address, Followers / Reviews stat chips and tag chips.
/// Layout lives in `StoreCell.xib`; theme styling is applied in `awakeFromNib`.
final class StoreCell: UICollectionViewCell {

    /// Tag chips beyond this are collapsed into a "+N" chip so cards stay one line.
    private static let maxVisibleTags = 3

    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var iconTile: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var addressIcon: UIImageView!
    @IBOutlet private weak var addressLabel: UILabel!
    @IBOutlet private weak var statsRow: UIStackView!
    @IBOutlet private weak var tagsRow: UIStackView!

    private let followerChip = StatChipView(icon: "ic_traders", tint: AppColors.info,
                                            background: AppColors.infoBg, caption: S.followersLabel)
    private let reviewChip = StatChipView(icon: "ic_chat", tint: AppColors.warning,
                                          background: AppColors.warningBg, caption: S.reviewsLabel)

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.layoutMargins = .zero

        StyleKit.styleCard(cardView)

        iconTile.backgroundColor = AppColors.purpleLight
        iconTile.layer.cornerRadius = AppMetrics.radiusMD
        iconImageView.image = AppIcons.symbol("ic_stores")
        iconImageView.tintColor = AppColors.purplePrimary

        nameLabel.font = AppFonts.bold(AppMetrics.textTitle)
        nameLabel.textColor = AppColors.textPrimary
        addressIcon.image = AppIcons.symbol("ic_location_pin")
        addressIcon.tintColor = AppColors.textTertiary
        addressLabel.font = AppFonts.regular(AppMetrics.textCaption)
        addressLabel.textColor = AppColors.textSecondary
        addressLabel.numberOfLines = 2

        statsRow.addArrangedSubview(followerChip)
        statsRow.addArrangedSubview(reviewChip)
        statsRow.addArrangedSubview(UIView())   // spacer keeps the chips left-aligned
    }

    func configure(_ item: StoreItem) {
        nameLabel.text = item.name
        addressLabel.text = item.address
        addressLabel.superview?.isHidden = item.address.trimmingCharacters(in: .whitespaces).isEmpty
        followerChip.setValue("\(item.followerCount)")
        reviewChip.setValue("\(item.reviewCount)")
        renderTags(item.tags)
    }

    private func renderTags(_ tags: [String]) {
        tagsRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        tagsRow.isHidden = tags.isEmpty
        guard !tags.isEmpty else { return }
        for tag in tags.prefix(Self.maxVisibleTags) {
            tagsRow.addArrangedSubview(tagChip(tag))
        }
        let overflow = tags.count - Self.maxVisibleTags
        if overflow > 0 {
            tagsRow.addArrangedSubview(tagChip("+\(overflow)"))
        }
        tagsRow.addArrangedSubview(UIView())    // spacer keeps the chips left-aligned
    }

    private func tagChip(_ text: String) -> UIView {
        let chip = PaddingLabel(insets: UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10))
        chip.text = text
        chip.font = AppFonts.medium(AppMetrics.textCaption)
        chip.textColor = AppColors.purplePrimary
        chip.backgroundColor = AppColors.purpleLight
        chip.layer.cornerRadius = AppMetrics.radiusSM
        chip.isPill = true
        chip.layer.masksToBounds = true
        chip.setContentHuggingPriority(.required, for: .horizontal)
        return chip
    }
}

/// Tinted pill holding an icon, a count and its caption — the Followers / Reviews
/// chips on a store card (bg_badge_info / bg_badge_warning on Android).
final class StatChipView: UIView {

    private let valueLabel = UILabel()

    init(icon: String, tint: UIColor, background: UIColor, caption: String) {
        super.init(frame: .zero)
        backgroundColor = background
        layer.cornerRadius = AppMetrics.radiusSM

        let iconView = UIImageView(image: AppIcons.symbol(icon))
        iconView.tintColor = tint
        iconView.contentMode = .scaleAspectFit
        iconView.forAutoLayout()

        valueLabel.font = AppFonts.bold(AppMetrics.textBodySM)
        valueLabel.textColor = AppColors.textPrimary
        valueLabel.text = "0"

        let captionLabel = UILabel.make(caption, font: AppFonts.regular(AppMetrics.textLabel),
                                        color: AppColors.textSecondary)

        let row = UIStackView.horizontal(spacing: 5, alignment: .center)
        row.isUserInteractionEnabled = false
        row.addArrangedSubview(iconView)
        row.addArrangedSubview(valueLabel)
        row.addArrangedSubview(captionLabel)
        row.forAutoLayout()
        addSubview(row)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
        setContentHuggingPriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setValue(_ value: String) { valueLabel.text = value }
}
