import UIKit

/// Inventory KPI card — tinted icon tile + title, the headline number, then a coloured
/// caption (InventoryKpiCard styles on Android).
final class InventoryKpiCard: UIView {

    private let valueLabel = UILabel()
    private let captionLabel = UILabel()

    init(title: String, icon: String, tint: UIColor, tile: UIColor, caption: String) {
        super.init(frame: .zero)
        StyleKit.styleCard(self)

        let iconTile = StyleKit.iconTile(color: tile, radius: AppMetrics.radiusSM)
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

        let titleLabel = UILabel.make(title, font: AppFonts.bold(AppMetrics.textCaption),
                                      color: AppColors.textPrimary, lines: 2)
        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        header.addArrangedSubview(iconTile)
        header.addArrangedSubview(titleLabel)

        valueLabel.font = AppFonts.bold(20)
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

    func set(_ text: String) { valueLabel.text = text }
}
