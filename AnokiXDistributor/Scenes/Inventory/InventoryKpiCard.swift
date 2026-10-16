import UIKit

/// Inventory KPI card — tinted icon tile + title, the headline number, then a coloured
/// caption (InventoryKpiCard styles on Android).
final class InventoryKpiCard: UIView {

    private let valueLabel = UILabel()
    private let captionLabel = UILabel()

    init(title: String, icon: String, tint: UIColor, tile: UIColor, caption: String) {
        super.init(frame: .zero)
        StyleKit.styleCard(self)

        let iconTile = StyleKit.iconTile(color: tile, radius: AppMetrics.radiusMD)
        iconTile.forAutoLayout()
        let iconView = UIImageView(image: AppIcons.symbol(icon))
        iconView.tintColor = tint
        iconView.contentMode = .scaleAspectFit
        iconView.forAutoLayout()
        iconTile.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconTile.widthAnchor.constraint(equalToConstant: 32),
            iconTile.heightAnchor.constraint(equalToConstant: 32),
            iconView.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 17),
            iconView.heightAnchor.constraint(equalToConstant: 17)
        ])

        // Portal KPI: label in secondary grey, value navy, meaning in the tinted tile + caption.
        let titleLabel = UILabel.make(title, font: AppFonts.semibold(AppMetrics.textCaption),
                                      color: AppColors.textSecondary, lines: 2)
        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        header.addArrangedSubview(iconTile)
        header.addArrangedSubview(titleLabel)

        valueLabel.font = AppFonts.semibold(20)
        valueLabel.textColor = AppColors.topTitle
        valueLabel.text = "0"

        captionLabel.font = AppFonts.regular(AppMetrics.textMicro)
        captionLabel.textColor = tint
        captionLabel.numberOfLines = 2
        captionLabel.text = caption

        let stack = UIStackView.vertical(spacing: 3, alignment: .fill)
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(captionLabel)
        stack.setCustomSpacing(10, after: header)
        stack.forAutoLayout()
        addSubview(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        widthAnchor.constraint(equalToConstant: 172).isActive = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func set(_ text: String) { setValue(text) }

    /// KPI values carry the portal's tight tracking (-0.02em ≈ kern -0.5).
    private func setValue(_ text: String) {
        valueLabel.attributedText = NSAttributedString(string: text, attributes: [.kern: -0.5])
    }

    /// Cards whose caption changes with the data (Traders KPIs) pass it in here; a nil or
    /// empty caption collapses the line rather than leaving a gap.
    func set(_ text: String, caption: String?) {
        setValue(text)
        let trimmed = (caption ?? "").trimmingCharacters(in: .whitespaces)
        captionLabel.text = trimmed
        captionLabel.isHidden = trimmed.isEmpty
    }
}
