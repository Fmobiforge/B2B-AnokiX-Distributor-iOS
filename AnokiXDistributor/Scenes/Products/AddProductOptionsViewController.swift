import UIKit

/// "How would you like to add this product?" — the portal's add-method chooser
/// (/products/create), opened from the Products screen's Add Product action.
///
/// Methods: Enter or Scan Barcode (default) · Create New Product · Hirt & Carter Library.
/// The library card only appears once a one-row library request confirms the integration is
/// available; until then a placeholder card holds its place. While the first catalogue sync is
/// still running the card is shown disabled, and once ready it carries the product count.
final class AddProductOptionsViewController: BaseSecondaryViewController {

    override var screenTitle: String { "Add New Product" }

    /// Called after a product is created so the list can refresh.
    var onSaved: (() -> Void)?

    private enum Method { case barcode, create, library }

    private var selected: Method = .barcode
    private let cardsStack = UIStackView.vertical(spacing: 14, alignment: .fill)

    // Library card state: loading → (hidden | shown); shown cards are ready or still preparing.
    private var libraryLoading = true
    private var libraryShown = false
    private var libraryReady = false
    private var libraryTotal = 0

    override func setupContent(in container: UIView) {
        let stack = AddProductFlow.scrollStack(in: container,
                                               insets: UIEdgeInsets(top: 24, left: 16, bottom: 32, right: 16))
        let heading = UILabel.make("How would you like to add this product?", font: AppFonts.bold(22),
                                   color: AppColors.textPrimary, align: .center, lines: 0)
        stack.addArrangedSubview(heading)
        stack.setCustomSpacing(28, after: heading)
        stack.addArrangedSubview(cardsStack)
        stack.setCustomSpacing(28, after: cardsStack)

        let continueButton = AddProductFlow.primaryButton("Continue")
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        continueButton.layer.shadowColor = AddProductFlow.Palette.violet.cgColor
        continueButton.layer.shadowOpacity = 0.28
        continueButton.layer.shadowRadius = 7
        continueButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        let row = UIStackView.horizontal(spacing: 0, alignment: .center)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(continueButton)
        row.addArrangedSubview(UIView())
        row.arrangedSubviews.first!.widthAnchor.constraint(equalTo: row.arrangedSubviews.last!.widthAnchor).isActive = true
        continueButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        stack.addArrangedSubview(row)

        renderCards()
    }

    /// One-row library request: tells us whether to show the card, its readiness and size.
    override func loadData() {
        ApiClient.shared.getHcLibrary(search: "", brand: nil, imagesOnly: false, page: 1, perPage: 1) { [weak self] result in
            guard let self = self else { return }
            self.libraryLoading = false
            if case .success(let data) = result, data.available {
                self.libraryShown = true
                self.libraryReady = data.libraryReady
                self.libraryTotal = data.total
            }
            // On failure the card simply stays hidden, as on the portal.
            self.renderCards()
        }
    }

    // MARK: Cards

    private func renderCards() {
        cardsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        cardsStack.addArrangedSubview(card(.barcode, symbol: "barcode", title: "Enter or Scan Barcode",
            description: "Type, paste or scan a barcode number with a scanner", badge: nil, disabled: false))
        cardsStack.addArrangedSubview(card(.create, symbol: "plus.circle", title: "Create New Product",
            description: "Create a completely new product", badge: nil, disabled: false))
        if libraryShown {
            let badge = libraryReady
                ? (libraryTotal > 0 ? "\(AddProductFlow.count(libraryTotal)) products" : "NEW")
                : nil
            cardsStack.addArrangedSubview(card(.library, symbol: "book", title: "Hirt & Carter Library",
                description: libraryReady
                    ? "Browse and search the national product catalogue, with images and details"
                    : "Library is being prepared — please try again later",
                badge: badge, disabled: !libraryReady))
        } else if libraryLoading {
            cardsStack.addArrangedSubview(skeletonCard())
        }
    }

    private func card(_ method: Method, symbol: String, title: String, description: String,
                      badge: String?, disabled: Bool) -> UIView {
        let isSelected = !disabled && method == selected
        let palette = AddProductFlow.Palette.self

        let card = UIControl()
        card.backgroundColor = disabled ? palette.page : (isSelected ? palette.violetWash : AppColors.surface)
        card.layer.cornerRadius = 14
        card.layer.borderWidth = isSelected ? 1.5 : 1
        card.layer.borderColor = (isSelected ? palette.violet : AppColors.border).cgColor
        card.alpha = disabled ? 0.6 : 1
        card.isEnabled = !disabled
        card.accessibilityLabel = title
        card.accessibilityTraits = isSelected ? [.button, .selected] : .button
        if !disabled {
            card.addAction(UIAction { [weak self] _ in
                self?.selected = method
                self?.renderCards()
            }, for: .touchUpInside)
        }

        let iconBox = UIView()
        iconBox.backgroundColor = isSelected ? palette.violetTint : palette.slateBg
        iconBox.layer.cornerRadius = 12
        iconBox.constrainSize(52)
        let icon = UIImageView(image: UIImage(systemName: symbol,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)))
        icon.tintColor = isSelected ? palette.violet : palette.slate
        icon.contentMode = .center
        icon.forAutoLayout()
        iconBox.addSubview(icon)
        icon.pinEdges(to: iconBox)

        let texts = UIStackView.vertical(spacing: 4, alignment: .leading)
        texts.addArrangedSubview(UILabel.make(title, font: AppFonts.bold(16),
                                              color: isSelected ? palette.violet : AppColors.textPrimary, lines: 0))
        if let badge = badge {
            let pill = PaddingLabel(insets: UIEdgeInsets(top: 1, left: 8, bottom: 1, right: 8))
            pill.text = badge
            pill.font = AppFonts.semibold(11)
            pill.textColor = palette.violetDark
            pill.backgroundColor = palette.violetTint
            pill.layer.masksToBounds = true
            pill.isPill = true
            texts.addArrangedSubview(pill)
        }
        texts.addArrangedSubview(UILabel.make(description, font: AppFonts.regular(13),
                                              color: AppColors.textSecondary, lines: 0))

        let row = UIStackView.horizontal(spacing: 16, alignment: .center)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        row.isUserInteractionEnabled = false
        row.addArrangedSubview(iconBox)
        row.addArrangedSubview(texts)
        row.forAutoLayout()
        card.addSubview(row)
        row.pinEdges(to: card)
        return card
    }

    /// Placeholder for the library card while its availability is being checked.
    private func skeletonCard() -> UIView {
        let card = UIView()
        StyleKit.styleCard(card, radius: 14)
        card.accessibilityLabel = "Loading Hirt & Carter Library"

        func bar(_ width: CGFloat, _ height: CGFloat) -> UIView {
            let v = UIView()
            v.backgroundColor = AddProductFlow.Palette.slateBg
            v.layer.cornerRadius = height / 2
            v.constrainHeight(height)
            v.widthAnchor.constraint(equalToConstant: width).isActive = true
            return v
        }
        let icon = UIView()
        icon.backgroundColor = AddProductFlow.Palette.slateBg
        icon.layer.cornerRadius = 12
        icon.constrainSize(52)
        let lines = UIStackView.vertical(spacing: 8, alignment: .leading)
        lines.addArrangedSubview(bar(150, 16))
        lines.addArrangedSubview(bar(84, 16))
        lines.addArrangedSubview(bar(200, 11))
        lines.addArrangedSubview(bar(140, 11))
        let row = UIStackView.horizontal(spacing: 16, alignment: .center)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        row.addArrangedSubview(icon)
        row.addArrangedSubview(lines)
        row.addArrangedSubview(UIView())
        row.forAutoLayout()
        card.addSubview(row)
        row.pinEdges(to: card)

        UIView.animate(withDuration: 0.7, delay: 0, options: [.autoreverse, .repeat, .allowUserInteraction],
                       animations: { row.alpha = 0.45 })
        return card
    }

    // MARK: Continue

    @objc private func continueTapped() {
        let next: UIViewController
        switch selected {
        case .barcode:
            let barcode = BarcodeVerifyViewController()
            barcode.onSaved = onSaved
            next = barcode
        case .create:
            let wizard = CreateProductViewController()
            wizard.onSaved = onSaved
            next = wizard
        case .library:
            let library = HcLibraryViewController()
            library.onSaved = onSaved
            next = library
        }
        next.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(next, animated: true)
    }
}
