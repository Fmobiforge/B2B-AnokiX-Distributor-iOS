import UIKit

/// item_inventory.xml — product swatch, name, SKU · category, on-hand units against
/// capacity, stock value, plus the view / more actions from the web layout.
final class InventoryItemCell: UICollectionViewCell {

    var onView: (() -> Void)?
    var onMore: ((UIView) -> Void)?

    private let cardView = UIView()
    private let swatch = UIView()
    private let nameLabel = UILabel()
    private let metaLabel = UILabel()
    private let statusBadge = PaddingLabel(insets: UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
    private let unitsLabel = UILabel()
    private let warehouseLabel = UILabel()
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private var progressWidth: NSLayoutConstraint!
    private let valueLabel = UILabel()
    private let viewButton = UIButton(type: .system)
    private let moreButton = UIButton(type: .system)
    private var didBuild = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        build()
    }

    private func build() {
        guard !didBuild else { return }
        didBuild = true
        backgroundColor = .clear

        StyleKit.styleCard(cardView)
        cardView.forAutoLayout()
        contentView.addSubview(cardView)

        swatch.layer.cornerRadius = AppMetrics.radiusSM
        swatch.backgroundColor = AppColors.purplePrimary
        swatch.forAutoLayout()

        nameLabel.font = AppFonts.bold(AppMetrics.textBody)
        nameLabel.textColor = AppColors.textPrimary
        nameLabel.numberOfLines = 2
        metaLabel.font = AppFonts.regular(AppMetrics.textCaption)
        metaLabel.textColor = AppColors.textSecondary
        metaLabel.numberOfLines = 1

        StyleKit.styleBadge(statusBadge)
        statusBadge.font = AppFonts.regular(AppMetrics.textMicro)
        statusBadge.setContentHuggingPriority(.required, for: .horizontal)
        statusBadge.setContentCompressionResistancePriority(.required, for: .horizontal)

        let titleStack = UIStackView.vertical(spacing: 2, alignment: .fill)
        titleStack.addArrangedSubview(nameLabel)
        titleStack.addArrangedSubview(metaLabel)

        let headerRow = UIStackView.horizontal(spacing: 8, alignment: .top)
        headerRow.addArrangedSubview(titleStack)
        headerRow.addArrangedSubview(statusBadge)

        unitsLabel.font = AppFonts.bold(AppMetrics.textCaption)
        unitsLabel.textColor = AppColors.textPrimary
        warehouseLabel.font = AppFonts.regular(AppMetrics.textMicro)
        warehouseLabel.textColor = AppColors.textTertiary
        warehouseLabel.setContentHuggingPriority(.required, for: .horizontal)

        let unitsRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        unitsRow.addArrangedSubview(unitsLabel)
        unitsRow.addArrangedSubview(UIView())
        unitsRow.addArrangedSubview(warehouseLabel)

        progressTrack.backgroundColor = AppColors.borderLight
        progressTrack.layer.cornerRadius = 3
        progressTrack.forAutoLayout()
        progressFill.backgroundColor = AppColors.success
        progressFill.layer.cornerRadius = 3
        progressFill.forAutoLayout()
        progressTrack.addSubview(progressFill)

        valueLabel.font = AppFonts.bold(AppMetrics.textBody)
        valueLabel.textColor = AppColors.purplePrimary

        configureIconButton(viewButton, systemName: "eye")
        viewButton.addTarget(self, action: #selector(viewTapped), for: .touchUpInside)
        configureIconButton(moreButton, systemName: "ellipsis")
        moreButton.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)

        let actionRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        actionRow.addArrangedSubview(valueLabel)
        actionRow.addArrangedSubview(UIView())
        actionRow.addArrangedSubview(viewButton)
        actionRow.addArrangedSubview(moreButton)

        let textStack = UIStackView.vertical(spacing: 10, alignment: .fill)
        textStack.addArrangedSubview(headerRow)
        textStack.addArrangedSubview(unitsRow)
        textStack.addArrangedSubview(progressTrack)
        textStack.addArrangedSubview(actionRow)
        textStack.setCustomSpacing(6, after: unitsRow)
        textStack.forAutoLayout()

        cardView.addSubview(swatch)
        cardView.addSubview(textStack)

        progressWidth = progressFill.widthAnchor.constraint(equalTo: progressTrack.widthAnchor, multiplier: 1)
        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            swatch.widthAnchor.constraint(equalToConstant: 40),
            swatch.heightAnchor.constraint(equalToConstant: 40),
            swatch.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            swatch.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),

            textStack.leadingAnchor.constraint(equalTo: swatch.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            textStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),

            progressTrack.heightAnchor.constraint(equalToConstant: 6),
            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressWidth
        ])
    }

    private func configureIconButton(_ button: UIButton, systemName: String) {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: systemName)
        config.baseForegroundColor = AppColors.textSecondary
        config.background.backgroundColor = AppColors.surfaceVariant
        config.background.strokeColor = AppColors.border
        config.background.strokeWidth = 1
        config.background.cornerRadius = AppMetrics.radiusMD
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        button.configuration = config
        button.forAutoLayout()
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 36),
            button.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    @objc private func viewTapped() { onView?() }
    @objc private func moreTapped() { onMore?(moreButton) }

    func configure(_ row: InventoryPageData.Row) {
        nameLabel.text = row.name
        metaLabel.text = [row.sku, row.category]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: "  ·  ")
        swatch.backgroundColor = UIColor.fromHexString(row.imageColor, fallback: AppColors.purplePrimary)

        unitsLabel.text = "\(format(row.unitsOnHand)) / \(format(row.capacity ?? 0)) units"
        let warehouse = row.warehouse ?? ""
        warehouseLabel.text = warehouse == "—" ? "" : warehouse
        warehouseLabel.isHidden = warehouseLabel.text?.isEmpty != false
        valueLabel.text = String(format: "R%@", format(Int64(row.stockValue ?? 0)))

        let color: UIColor
        let background: UIColor
        if row.isOutOfStock {
            color = AppColors.danger; background = AppColors.dangerBg
        } else if row.isLowStock {
            color = AppColors.warning; background = AppColors.warningBg
        } else {
            color = AppColors.success; background = AppColors.successBg
        }
        statusBadge.text = row.statusLabel
        statusBadge.textColor = color
        statusBadge.backgroundColor = background
        progressFill.backgroundColor = color

        // How full the shelf is; without a capacity figure a stocked row reads as full.
        let capacity = row.capacity ?? 0
        let ratio: CGFloat
        if row.unitsOnHand <= 0 {
            ratio = 0.001
        } else if capacity <= 0 {
            ratio = 1
        } else {
            ratio = max(0.02, min(1, CGFloat(row.unitsOnHand) / CGFloat(capacity)))
        }
        progressWidth.isActive = false
        progressWidth = progressFill.widthAnchor.constraint(equalTo: progressTrack.widthAnchor, multiplier: ratio)
        progressWidth.isActive = true
    }

    private func format(_ value: Int64) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }
}

extension UIColor {
    /// Parses a "#rrggbb" from the API, falling back when it is missing or malformed.
    static func fromHexString(_ hex: String?, fallback: UIColor) -> UIColor {
        guard var value = hex?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return fallback }
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = Int(value, radix: 16) else { return fallback }
        return UIColor(hex: rgb)
    }
}
