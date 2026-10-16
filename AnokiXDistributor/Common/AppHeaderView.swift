import UIKit

/// The top bar used across the secondary screens. Mirrors include_secondary_header.xml, restyled
/// as the portal TopHeader: white background, 1pt bottom hairline, navy semibold title,
/// secondary-grey subtitle, a bordered 40×40 back button and brand-blue trailing actions.
final class AppHeaderView: UIView {

    enum Leading { case back, menu, none }

    private let titleLabel = UILabel.make(font: AppFonts.semibold(AppMetrics.textHeadline), color: AppColors.topTitle)
    private let subtitleLabel = UILabel.make(font: AppFonts.regular(AppMetrics.textBody), color: AppColors.textSecondary)
    private let leadingButton = UIButton(type: .system)
    private let trailingButton = UIButton(type: .system)
    private let bottomHairline = UIView()

    var onLeading: (() -> Void)?
    var onTrailing: (() -> Void)?

    init(title: String,
         subtitle: String? = nil,
         leading: Leading = .back,
         trailingTitle: String? = nil,
         trailingIcon: String? = nil,
         background: UIColor = AppColors.surface) {
        super.init(frame: .zero)
        backgroundColor = background
        buildLayout(leading: leading, trailingTitle: trailingTitle, trailingIcon: trailingIcon)
        titleLabel.text = title
        if let subtitle = subtitle, !subtitle.isEmpty {
            subtitleLabel.text = subtitle
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.isHidden = true
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setTitle(_ text: String) { titleLabel.text = text }

    private func buildLayout(leading: Leading, trailingTitle: String?, trailingIcon: String?) {
        let textStack = UIStackView.vertical(spacing: 2, alignment: .leading)
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.forAutoLayout()

        if leading != .none {
            let symbol = leading == .back ? "chevron.left" : "line.3.horizontal"
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            leadingButton.setImage(UIImage(systemName: symbol, withConfiguration: symbolConfig), for: .normal)
            leadingButton.tintColor = AppColors.topTitle
            leadingButton.backgroundColor = AppColors.surface
            leadingButton.layer.cornerRadius = AppMetrics.radiusSM
            leadingButton.layer.borderWidth = 1
            leadingButton.layer.borderColor = AppColors.border.cgColor
            leadingButton.constrainSize(40)
            leadingButton.addTarget(self, action: #selector(leadingTapped), for: .touchUpInside)
            row.addArrangedSubview(leadingButton)
        }
        row.addArrangedSubview(textStack)

        if trailingTitle != nil || trailingIcon != nil {
            var config = UIButton.Configuration.filled()
            config.baseBackgroundColor = AppColors.purplePrimary
            config.baseForegroundColor = .white
            config.cornerStyle = .fixed
            config.background.cornerRadius = AppMetrics.radiusSM
            config.title = trailingTitle
            config.titleTextAttributesTransformer = .init { incoming in
                var out = incoming; out.font = AppFonts.semibold(13); return out
            }
            if let icon = trailingIcon { config.image = AppIcons.symbol(icon) }
            config.imagePadding = 6
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            trailingButton.configuration = config
            trailingButton.addTarget(self, action: #selector(trailingTapped), for: .touchUpInside)
            row.addArrangedSubview(trailingButton)
        }

        bottomHairline.backgroundColor = AppColors.border
        bottomHairline.forAutoLayout()

        addSubview(row)
        addSubview(bottomHairline)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            bottomHairline.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomHairline.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomHairline.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomHairline.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    @objc private func leadingTapped() { onLeading?() }
    @objc private func trailingTapped() { onTrailing?() }
}
