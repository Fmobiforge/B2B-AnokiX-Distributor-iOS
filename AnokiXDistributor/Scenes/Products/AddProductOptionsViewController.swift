import UIKit

/// "How would you like to add this product?" chooser (Create-Product1.jpg).
/// Only "Create New Product" is wired today; the barcode / library options are
/// coming later. Continue pushes the `CreateProductViewController` wizard.
final class AddProductOptionsViewController: BaseSecondaryViewController {

    override var screenTitle: String { "Add New Product" }

    /// Called after a product is created so the list can refresh.
    var onSaved: (() -> Void)?

    private struct Option { let icon, title, sub: String }
    private let options: [Option] = [
        Option(icon: "barcode.viewfinder", title: "Scan Barcode", sub: "Scan product barcode using camera"),
        Option(icon: "barcode", title: "Enter Barcode Manually", sub: "Type or paste barcode number"),
        Option(icon: "magnifyingglass", title: "Search Product Library", sub: "Search by product name, brand or category"),
        Option(icon: "plus.circle", title: "Create New Product", sub: "Create a completely new product")
    ]
    private let createIndex = 3
    private var cards: [UIView] = []
    private var radios: [UIImageView] = []
    private var selected = 3

    override func setupContent(in container: UIView) {
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.forAutoLayout()
        container.addSubview(scroll)
        scroll.pinEdges(to: container)

        let content = UIStackView.vertical(spacing: 12, alignment: .fill)
        content.isLayoutMarginsRelativeArrangement = true
        content.layoutMargins = UIEdgeInsets(top: 24, left: 16, bottom: 24, right: 16)
        content.forAutoLayout()
        scroll.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor)
        ])

        let heading = UILabel.make("How would you like to add this product?",
                                   font: AppFonts.semibold(24), color: AppColors.topTitle, align: .center, lines: 0)
        content.addArrangedSubview(heading)
        content.setCustomSpacing(24, after: heading)

        // A single-column list of full-width rows reads cleaner than a 2-col grid
        // (no ragged heights or wrapped titles). Each row is icon · text · radio.
        for index in 0..<options.count {
            let card = buildCard(options[index])
            card.tag = index
            card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:))))
            cards.append(card)
            content.addArrangedSubview(card)
        }

        let continueButton = UIButton(type: .system)
        StyleKit.stylePrimaryButton(continueButton)
        continueButton.setTitle("Continue", for: .normal)
        continueButton.constrainHeight(48)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        // The content stack is alignment .fill, so adding the button directly makes it
        // span the full width (matching the option cards above it).
        content.setCustomSpacing(28, after: content.arrangedSubviews.last!)
        content.addArrangedSubview(continueButton)

        applySelection()
    }

    private func buildCard(_ option: Option) -> UIView {
        let card = UIView()
        card.backgroundColor = AppColors.surface
        card.layer.cornerRadius = AppMetrics.radiusMD
        card.layer.borderWidth = 1
        card.layer.borderColor = AppColors.border.cgColor

        let iconBox = UIView()
        iconBox.backgroundColor = AppColors.purpleLight
        iconBox.layer.cornerRadius = 22
        iconBox.constrainSize(44)
        let icon = UIImageView(image: UIImage(systemName: option.icon))
        icon.tintColor = AppColors.purplePrimary
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        iconBox.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22)
        ])

        let title = UILabel.make(option.title, font: AppFonts.bold(15), color: AppColors.textPrimary, lines: 0)
        let sub = UILabel.make(option.sub, font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 0)
        let texts = UIStackView.vertical(spacing: 3, alignment: .leading)
        texts.addArrangedSubview(title)
        texts.addArrangedSubview(sub)

        let radio = UIImageView(image: UIImage(systemName: "circle"))
        radio.tintColor = AppColors.border
        radio.contentMode = .scaleAspectFit
        radio.constrainSize(22)
        radio.setContentHuggingPriority(.required, for: .horizontal)
        radios.append(radio)

        let row = UIStackView.horizontal(spacing: 14, alignment: .center)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        row.forAutoLayout()
        row.addArrangedSubview(iconBox)
        row.addArrangedSubview(texts)
        row.addArrangedSubview(radio)
        card.addSubview(row)
        row.pinEdges(to: card)
        return card
    }

    @objc private func cardTapped(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag else { return }
        if index != createIndex {
            toast("Coming soon")
            return
        }
        selected = index
        applySelection()
    }

    private func applySelection() {
        for (i, card) in cards.enumerated() {
            let isSelected = i == selected
            card.layer.borderColor = (isSelected ? AppColors.purplePrimary : AppColors.border).cgColor
            card.layer.borderWidth = isSelected ? 1.5 : 1
            card.backgroundColor = isSelected ? AppColors.purpleLight.withAlphaComponent(0.25) : AppColors.surface
            radios[i].image = UIImage(systemName: isSelected ? "largecircle.fill.circle" : "circle")
            radios[i].tintColor = isSelected ? AppColors.purplePrimary : AppColors.border
        }
    }

    @objc private func continueTapped() {
        guard selected == createIndex else { toast("Coming soon"); return }
        let wizard = CreateProductViewController()
        wizard.onSaved = onSaved
        wizard.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(wizard, animated: true)
    }
}
