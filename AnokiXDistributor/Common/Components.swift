import UIKit

/// Rounded search field with a leading magnifier — mirrors the search bars in the list screens.
final class SearchBarView: UIView {
    let textField = UITextField()
    var onChange: ((String) -> Void)?

    init(placeholder: String, height: CGFloat = AppMetrics.searchBarHeight) {
        super.init(frame: .zero)
        backgroundColor = AppColors.surface
        layer.cornerRadius = AppMetrics.radiusSM
        layer.borderWidth = 1
        layer.borderColor = AppColors.border.cgColor

        let glass = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        glass.tintColor = AppColors.textSecondary
        glass.contentMode = .scaleAspectFit
        glass.forAutoLayout()

        textField.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [
            .foregroundColor: AppColors.textTertiary, .font: AppFonts.regular(AppMetrics.textBody)])
        textField.font = AppFonts.regular(AppMetrics.textBody)
        textField.textColor = AppColors.textPrimary
        textField.clearButtonMode = .whileEditing
        textField.addTarget(self, action: #selector(changed), for: .editingChanged)
        textField.forAutoLayout()

        addSubviews(glass, textField)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: height),
            glass.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            glass.centerYAnchor.constraint(equalTo: centerYAnchor),
            glass.widthAnchor.constraint(equalToConstant: 18),
            glass.heightAnchor.constraint(equalToConstant: 18),
            textField.leadingAnchor.constraint(equalTo: glass.trailingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func changed() { onChange?(textField.text ?? "") }
}

extension UIViewController {
    /// Adds a vertical UIScrollView+UIStackView to a container and returns the stack to fill.
    @discardableResult
    func makeScrollStack(in container: UIView,
                         spacing: CGFloat = 12,
                         insets: UIEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)) -> UIStackView {
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = false
        scroll.forAutoLayout()
        container.addSubview(scroll)
        scroll.pinEdges(to: container)

        let stack = UIStackView.vertical(spacing: spacing, alignment: .fill)
        stack.forAutoLayout()
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: insets.top),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: insets.left),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -insets.right),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -insets.bottom)
        ])
        return stack
    }
}

/// A KPI card (icon tile + value + title) — item_kpi_card.xml.
final class KpiCardView: UIView {
    init(title: String, value: String, icon: String, iconBg: UIColor, valueColor: UIColor, tint: UIColor) {
        super.init(frame: .zero)
        backgroundColor = AppColors.surface
        layer.cornerRadius = AppMetrics.radiusLG
        layer.borderWidth = 1
        layer.borderColor = AppColors.border.cgColor

        let tile = StyleKit.iconTile(color: iconBg)
        tile.constrainSize(32)
        let iconView = UIImageView(image: AppIcons.symbol(icon))
        iconView.tintColor = tint
        iconView.contentMode = .scaleAspectFit
        iconView.forAutoLayout()
        tile.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18)
        ])

        let titleLabel = UILabel.make(title, font: AppFonts.medium(AppMetrics.textBodySM), color: AppColors.textSecondary)
        let topRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        topRow.addArrangedSubview(tile)
        topRow.addArrangedSubview(titleLabel)

        // Portal KPI: the value is always navy; colour meaning lives in the icon tile.
        _ = valueColor
        let valueLabel = UILabel.make(nil, font: AppFonts.semibold(AppMetrics.textKpiValue), color: AppColors.topTitle)
        valueLabel.attributedText = NSAttributedString(string: value, attributes: [.kern: -0.5])

        let stack = UIStackView.vertical(spacing: 8, alignment: .leading)
        stack.forAutoLayout()
        stack.addArrangedSubview(topRow)
        stack.addArrangedSubview(valueLabel)
        addSubview(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// A titled white card section ("Revenue Overview", "Recent Orders", ...).
final class SectionCard: UIView {
    let body = UIStackView.vertical(spacing: 10, alignment: .fill)

    init(title: String, actionTitle: String? = nil, onAction: (() -> Void)? = nil) {
        super.init(frame: .zero)
        backgroundColor = AppColors.surface
        layer.cornerRadius = AppMetrics.radiusLG
        layer.borderWidth = 1
        layer.borderColor = AppColors.border.cgColor

        let titleLabel = UILabel.title(title)
        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        header.addArrangedSubview(titleLabel)
        if let actionTitle = actionTitle {
            let action = UIButton(type: .system)
            action.setTitle(actionTitle, for: .normal)
            action.setTitleColor(AppColors.purplePrimary, for: .normal)
            action.titleLabel?.font = AppFonts.semibold(AppMetrics.textBodySM)
            action.setContentHuggingPriority(.required, for: .horizontal)
            self.actionHandler = onAction
            action.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
            let spacer = UIView()
            header.addArrangedSubview(spacer)
            header.addArrangedSubview(action)
        }

        let root = UIStackView.vertical(spacing: 12, alignment: .fill)
        root.forAutoLayout()
        root.addArrangedSubview(header)
        root.addArrangedSubview(body)
        addSubview(root)
        root.pinEdges(to: self, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var actionHandler: (() -> Void)?
    @objc private func actionTapped() { actionHandler?() }
}
