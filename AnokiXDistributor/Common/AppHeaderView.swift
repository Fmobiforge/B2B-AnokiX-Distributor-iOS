import UIKit

/// The purple top bar used across the app. Mirrors include_secondary_header.xml and the
/// logo/page-title headers: a leading button (back chevron or hamburger), a title +
/// optional subtitle, and an optional trailing action (e.g. "Add Store").
final class AppHeaderView: UIView {

    enum Leading { case back, menu, none }

    private let titleLabel = UILabel.make(font: AppFonts.bold(AppMetrics.textHeadline), color: .white)
    private let subtitleLabel = UILabel.make(font: AppFonts.light(AppMetrics.textBodySM), color: .white)
    private let leadingButton = UIButton(type: .system)
    private let trailingButton = UIButton(type: .system)

    var onLeading: (() -> Void)?
    var onTrailing: (() -> Void)?

    init(title: String,
         subtitle: String? = nil,
         leading: Leading = .back,
         trailingTitle: String? = nil,
         trailingIcon: String? = nil,
         background: UIColor = AppColors.purpleDark) {
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

        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.forAutoLayout()

        if leading != .none {
            let symbol = leading == .back ? "chevron.left" : "line.3.horizontal"
            leadingButton.setImage(UIImage(systemName: symbol), for: .normal)
            leadingButton.tintColor = .white
            leadingButton.constrainSize(40)
            leadingButton.addTarget(self, action: #selector(leadingTapped), for: .touchUpInside)
            row.addArrangedSubview(leadingButton)
        }
        row.addArrangedSubview(textStack)

        if trailingTitle != nil || trailingIcon != nil {
            var config = UIButton.Configuration.filled()
            config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.18)
            config.baseForegroundColor = .white
            config.cornerStyle = .medium
            config.title = trailingTitle
            config.titleTextAttributesTransformer = .init { incoming in
                var out = incoming; out.font = AppFonts.bold(13); return out
            }
            if let icon = trailingIcon { config.image = AppIcons.symbol(icon) }
            config.imagePadding = 6
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            trailingButton.configuration = config
            trailingButton.addTarget(self, action: #selector(trailingTapped), for: .touchUpInside)
            row.addArrangedSubview(trailingButton)
        }

        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            row.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }

    @objc private func leadingTapped() { onLeading?() }
    @objc private func trailingTapped() { onTrailing?() }
}
