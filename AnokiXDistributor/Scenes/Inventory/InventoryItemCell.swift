import UIKit

/// item_inventory.xml — product swatch, name, SKU / category, the capacity bar with its
/// fill percentage, stock value and the view / more actions from the web layout.
final class InventoryItemCell: UICollectionViewCell {

    var onView: (() -> Void)?
    var onMore: ((UIView) -> Void)?

    private let cardView = UIView()
    private let swatch = UIView()
    private let nameLabel = UILabel()
    private let skuChip = PaddingLabel(insets: UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8))
    private let categoryLabel = UILabel()
    private let statusBadge = PaddingLabel(insets: UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
    private let onHandLabel = UILabel()
    private let percentLabel = UILabel()
    private let unitsLabel = UILabel()
    private let warehouseLabel = UILabel()
    private let warehouseIcon = UIImageView()
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

        swatch.layer.cornerRadius = AppMetrics.radiusMD
        swatch.backgroundColor = AppColors.purplePrimary
        swatch.forAutoLayout()
        let swatchIcon = UIImageView(image: AppIcons.symbol("ic_package"))
        swatchIcon.tintColor = .white
        swatchIcon.alpha = 0.9
        swatchIcon.contentMode = .scaleAspectFit
        swatchIcon.forAutoLayout()
        swatch.addSubview(swatchIcon)

        nameLabel.font = AppFonts.bold(AppMetrics.textBody)
        nameLabel.textColor = AppColors.textPrimary
        nameLabel.numberOfLines = 2

        skuChip.font = AppFonts.regular(AppMetrics.textMicro)
        skuChip.textColor = AppColors.textSecondary
        skuChip.backgroundColor = AppColors.borderLight
        skuChip.layer.cornerRadius = 9
        skuChip.layer.masksToBounds = true
        skuChip.layer.borderWidth = 1
        skuChip.layer.borderColor = AppColors.border.cgColor
        skuChip.setContentHuggingPriority(.required, for: .horizontal)

        categoryLabel.font = AppFonts.regular(AppMetrics.textMicro)
        categoryLabel.textColor = AppColors.textTertiary
        categoryLabel.numberOfLines = 1

        let metaRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        metaRow.addArrangedSubview(skuChip)
        metaRow.addArrangedSubview(categoryLabel)

        let titleStack = UIStackView.vertical(spacing: 4, alignment: .leading)
        titleStack.addArrangedSubview(nameLabel)
        titleStack.addArrangedSubview(metaRow)

        StyleKit.styleBadge(statusBadge)
        statusBadge.font = AppFonts.bold(AppMetrics.textMicro)
        statusBadge.setContentHuggingPriority(.required, for: .horizontal)
        statusBadge.setContentCompressionResistancePriority(.required, for: .horizontal)

        let headerRow = UIStackView.horizontal(spacing: 8, alignment: .top)
        headerRow.addArrangedSubview(titleStack)
        headerRow.addArrangedSubview(statusBadge)

        onHandLabel.attributedText = Self.columnLabel("On hand")
        percentLabel.font = AppFonts.bold(AppMetrics.textMicro)
        percentLabel.textColor = AppColors.success
        percentLabel.setContentHuggingPriority(.required, for: .horizontal)

        let capacityRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        capacityRow.addArrangedSubview(onHandLabel)
        capacityRow.addArrangedSubview(UIView())
        capacityRow.addArrangedSubview(percentLabel)

        unitsLabel.font = AppFonts.bold(AppMetrics.textTitle)
        unitsLabel.textColor = AppColors.textPrimary

        warehouseIcon.image = AppIcons.symbol("ic_location_pin")
        warehouseIcon.tintColor = AppColors.textTertiary
        warehouseIcon.contentMode = .scaleAspectFit
        warehouseIcon.forAutoLayout()
        NSLayoutConstraint.activate([
            warehouseIcon.widthAnchor.constraint(equalToConstant: 11),
            warehouseIcon.heightAnchor.constraint(equalToConstant: 11)
        ])
        warehouseLabel.font = AppFonts.regular(AppMetrics.textMicro)
        warehouseLabel.textColor = AppColors.textTertiary

        let warehouseRow = UIStackView.horizontal(spacing: 4, alignment: .center)
        warehouseRow.addArrangedSubview(warehouseIcon)
        warehouseRow.addArrangedSubview(warehouseLabel)
        warehouseRow.setContentHuggingPriority(.required, for: .horizontal)

        let unitsRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        unitsRow.addArrangedSubview(unitsLabel)
        unitsRow.addArrangedSubview(UIView())
        unitsRow.addArrangedSubview(warehouseRow)

        progressTrack.backgroundColor = AppColors.borderLight
        progressTrack.layer.cornerRadius = 3
        progressTrack.forAutoLayout()
        progressFill.backgroundColor = AppColors.success
        progressFill.layer.cornerRadius = 3
        progressFill.forAutoLayout()
        progressTrack.addSubview(progressFill)

        let divider = ListScreenLayout.hairline()

        let valueColumn = UIStackView.vertical(spacing: 2, alignment: .leading)
        let valueTitle = UILabel()
        valueTitle.attributedText = Self.columnLabel("Stock value")
        valueLabel.font = AppFonts.bold(AppMetrics.textBody)
        valueLabel.textColor = AppColors.purplePrimary
        valueColumn.addArrangedSubview(valueTitle)
        valueColumn.addArrangedSubview(valueLabel)

        configureIconButton(viewButton, systemName: "eye", tint: AppColors.purplePrimary)
        viewButton.addTarget(self, action: #selector(viewTapped), for: .touchUpInside)
        configureIconButton(moreButton, systemName: "ellipsis", tint: AppColors.textSecondary)
        moreButton.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)

        let actionRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        actionRow.addArrangedSubview(valueColumn)
        actionRow.addArrangedSubview(UIView())
        actionRow.addArrangedSubview(viewButton)
        actionRow.addArrangedSubview(moreButton)

        let stack = UIStackView.vertical(spacing: 0, alignment: .fill)
        stack.addArrangedSubview(headerRow)
        stack.addArrangedSubview(capacityRow)
        stack.addArrangedSubview(unitsRow)
        stack.addArrangedSubview(progressTrack)
        stack.addArrangedSubview(divider)
        stack.addArrangedSubview(actionRow)
        stack.setCustomSpacing(14, after: headerRow)
        stack.setCustomSpacing(2, after: capacityRow)
        stack.setCustomSpacing(8, after: unitsRow)
        stack.setCustomSpacing(14, after: progressTrack)
        stack.setCustomSpacing(12, after: divider)
        stack.forAutoLayout()
        cardView.addSubview(stack)

        progressWidth = progressFill.widthAnchor.constraint(equalTo: progressTrack.widthAnchor, multiplier: 1)
        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            swatch.widthAnchor.constraint(equalToConstant: 44),
            swatch.heightAnchor.constraint(equalToConstant: 44),
            swatch.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            swatch.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            swatchIcon.centerXAnchor.constraint(equalTo: swatch.centerXAnchor),
            swatchIcon.centerYAnchor.constraint(equalTo: swatch.centerYAnchor),
            swatchIcon.widthAnchor.constraint(equalToConstant: 20),
            swatchIcon.heightAnchor.constraint(equalToConstant: 20),

            stack.leadingAnchor.constraint(equalTo: swatch.trailingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),

            progressTrack.heightAnchor.constraint(equalToConstant: 6),
            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressWidth
        ])
    }

    /// Small uppercase column label with a touch of tracking (InventoryStatLabel).
    private static func columnLabel(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text.uppercased(), attributes: [
            .font: AppFonts.regular(AppMetrics.textMicro),
            .foregroundColor: AppColors.textTertiary,
            .kern: 0.6
        ])
    }

    private func configureIconButton(_ button: UIButton, systemName: String, tint: UIColor) {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: systemName)
        config.baseForegroundColor = tint
        config.background.backgroundColor = AppColors.surfaceVariant
        config.background.strokeColor = AppColors.border
        config.background.strokeWidth = 1
        config.background.cornerRadius = 17
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        button.configuration = config
        button.forAutoLayout()
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 34),
            button.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    @objc private func viewTapped() { onView?() }
    @objc private func moreTapped() { onMore?(moreButton) }

    func configure(_ row: InventoryPageData.Row) {
        nameLabel.text = row.name
        skuChip.text = row.sku
        skuChip.isHidden = row.sku?.isEmpty != false
        categoryLabel.text = row.category
        categoryLabel.isHidden = row.category?.isEmpty != false
        swatch.backgroundColor = UIColor.fromHexString(row.imageColor, fallback: AppColors.purplePrimary)

        unitsLabel.text = "\(format(row.unitsOnHand)) / \(format(row.capacity ?? 0)) units"
        let warehouse = row.warehouse ?? ""
        warehouseLabel.text = warehouse == "—" ? "" : warehouse
        let hideWarehouse = warehouseLabel.text?.isEmpty != false
        warehouseLabel.isHidden = hideWarehouse
        warehouseIcon.isHidden = hideWarehouse
        valueLabel.text = "R" + format(Int64(row.stockValue ?? 0))

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
        percentLabel.textColor = color

        // How full the shelf is; without a capacity figure a stocked row reads as full.
        let capacity = row.capacity ?? 0
        let fraction: Double
        if row.unitsOnHand <= 0 {
            fraction = 0
        } else if capacity <= 0 {
            fraction = 1
        } else {
            fraction = min(1, Double(row.unitsOnHand) / Double(capacity))
        }
        let percent = Int((fraction * 100).rounded())
        let showPercent = capacity > 0 && row.unitsOnHand > 0
        percentLabel.text = showPercent ? "\(percent)% of capacity" : ""
        percentLabel.isHidden = !showPercent

        progressWidth.isActive = false
        progressWidth = progressFill.widthAnchor.constraint(
            equalTo: progressTrack.widthAnchor,
            multiplier: max(0.001, CGFloat(fraction < 0.02 && fraction > 0 ? 0.02 : fraction)))
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
