import UIKit

// MARK: - Hirt & Carter Library

/// Hirt & Carter Library — browse and search the national product catalogue
/// (api/distributor/products/hc-library), as on the portal.
///
/// Search (debounced 350 ms), a brand filter and "With images only" (on by default) drive the
/// query. Pages of 24 load as the list scrolls. Tapping a card fetches the full record
/// (external-lookup) and pushes `HcProductViewController`; "Not this product" there pops back
/// here with the search and filters untouched.
final class HcLibraryViewController: BaseSecondaryViewController, UICollectionViewDataSource,
        UICollectionViewDelegateFlowLayout, UITextFieldDelegate {

    override var screenTitle: String { "Hirt & Carter Library" }

    var onSaved: (() -> Void)?

    private static let pageSize = 24
    private let sectionInset = UIEdgeInsets(top: 12, left: 12, bottom: 24, right: 12)
    private let gap: CGFloat = 10

    private let searchField = UITextField()
    private let brandButton = UIButton(type: .system)
    private let brandIcon = UIImageView()
    private let imagesSwitch = UISwitch()
    private let countLabel = UILabel.make(font: AppFonts.semibold(13), color: AppColors.textSecondary)
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = gap
        layout.minimumInteritemSpacing = gap
        layout.sectionInset = sectionInset
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = AppColors.background
        cv.alwaysBounceVertical = true
        cv.keyboardDismissMode = .onDrag
        cv.dataSource = self
        cv.delegate = self
        cv.register(HcLibraryCell.self, forCellWithReuseIdentifier: HcLibraryCell.reuseId)
        cv.register(HcLibraryFooter.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                    withReuseIdentifier: HcLibraryFooter.reuseId)
        return cv
    }()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let stateView = UIStackView.vertical(spacing: 6, alignment: .fill)
    private let stateTitle = UILabel.make(font: AppFonts.bold(15), color: AppColors.textPrimary, align: .center, lines: 0)
    private let stateText = UILabel.make(font: AppFonts.regular(13), color: AppColors.textSecondary, align: .center, lines: 0)
    private let stateActions = UIStackView.vertical(spacing: 10, alignment: .center)

    // Query
    private var search = ""
    private var brand: String?
    private var imagesOnly = true

    // Result
    private var items: [HcLibraryData.Item] = []
    private var brands: [String] = []
    private var page = 1
    private var total = 0
    private var hasMore = false
    private var loadedOnce = false
    private var available = true
    private var libraryReady = true
    private var errorMessage: String?
    private var loadingFirst = false
    private var loadingMore = false
    /// Bumped on every new query so late responses for an older query are dropped.
    private var generation = 0
    private var lookupGtin: String?
    private var searchWork: DispatchWorkItem?

    override func setupContent(in container: UIView) {
        let chrome = buildToolbar()
        let divider = ListScreenLayout.hairline()
        chrome.forAutoLayout()
        divider.forAutoLayout()
        collectionView.forAutoLayout()
        spinner.forAutoLayout()
        spinner.color = AddProductFlow.Palette.violet
        spinner.hidesWhenStopped = true
        container.addSubviews(chrome, divider, collectionView, spinner)

        let stateIcon = UIImageView(image: UIImage(systemName: "tray",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 40, weight: .light)))
        stateIcon.tintColor = AddProductFlow.Palette.placeholder
        stateIcon.contentMode = .center
        stateIcon.constrainHeight(56)
        stateView.addArrangedSubview(stateIcon)
        stateView.addArrangedSubview(stateTitle)
        stateView.addArrangedSubview(stateText)
        stateView.setCustomSpacing(16, after: stateText)
        stateView.addArrangedSubview(stateActions)
        stateView.forAutoLayout()
        stateView.isHidden = true
        container.addSubview(stateView)

        NSLayoutConstraint.activate([
            chrome.topAnchor.constraint(equalTo: container.topAnchor),
            chrome.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.topAnchor.constraint(equalTo: chrome.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            spinner.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            stateView.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            stateView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            stateView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24)
        ])
    }

    override func loadData() { load(reset: true) }

    // MARK: Toolbar

    private func buildToolbar() -> UIView {
        let chrome = UIView()
        chrome.backgroundColor = AppColors.background
        let stack = UIStackView.vertical(spacing: 10, alignment: .fill)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 10, right: 16)
        stack.forAutoLayout()
        chrome.addSubview(stack)
        stack.pinEdges(to: chrome)

        StyleKit.styleInput(searchField)
        searchField.placeholder = "Search by name, brand or barcode"
        searchField.returnKeyType = .search
        searchField.clearButtonMode = .whileEditing
        searchField.autocorrectionType = .no
        searchField.delegate = self
        let glass = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        glass.tintColor = AppColors.textSecondary
        glass.contentMode = .center
        glass.frame = CGRect(x: 0, y: 0, width: 36, height: 20)
        searchField.leftView = glass
        searchField.leftViewMode = .always
        searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        stack.addArrangedSubview(searchField)

        var config = UIButton.Configuration.bordered()
        config.baseForegroundColor = AppColors.textTertiary
        config.background.backgroundColor = AppColors.surface
        config.background.strokeColor = AppColors.border
        config.background.cornerRadius = AppMetrics.radiusSM
        config.cornerStyle = .fixed
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 32)
        config.titleLineBreakMode = .byTruncatingTail
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.regular(14); return out
        }
        brandButton.configuration = config
        brandButton.contentHorizontalAlignment = .leading
        brandButton.constrainHeight(44)
        brandButton.addTarget(self, action: #selector(brandTapped), for: .touchUpInside)
        brandIcon.tintColor = AppColors.textSecondary
        brandIcon.contentMode = .center
        brandIcon.forAutoLayout()
        brandButton.addSubview(brandIcon)
        NSLayoutConstraint.activate([
            brandIcon.trailingAnchor.constraint(equalTo: brandButton.trailingAnchor, constant: -10),
            brandIcon.centerYAnchor.constraint(equalTo: brandButton.centerYAnchor)
        ])

        imagesSwitch.isOn = imagesOnly
        imagesSwitch.onTintColor = AppColors.purplePrimary
        imagesSwitch.addTarget(self, action: #selector(imagesToggled), for: .valueChanged)
        imagesSwitch.setContentHuggingPriority(.required, for: .horizontal)
        let imagesLabel = UILabel.make("With images only", font: AppFonts.regular(13), color: AppColors.textPrimary)
        imagesLabel.setContentHuggingPriority(.required, for: .horizontal)
        imagesLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.addArrangedSubview(brandButton)
        row.addArrangedSubview(imagesSwitch)
        row.addArrangedSubview(imagesLabel)
        stack.addArrangedSubview(row)

        countLabel.constrainHeight(18)
        stack.addArrangedSubview(countLabel)
        renderBrand()
        return chrome
    }

    @objc private func searchChanged() {
        searchWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.applySearch(self?.searchField.text ?? "") }
        searchWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        searchWork?.cancel()
        applySearch(textField.text ?? "")
        textField.resignFirstResponder()
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        searchWork?.cancel()
        DispatchQueue.main.async { [weak self] in self?.applySearch("") }
        return true
    }

    private func applySearch(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard trimmed != search else { return }
        search = trimmed
        load(reset: true)
    }

    @objc private func imagesToggled() {
        guard imagesSwitch.isOn != imagesOnly else { return }
        imagesOnly = imagesSwitch.isOn
        load(reset: true)
    }

    @objc private func brandTapped() {
        if brand != nil {
            brand = nil   // the field's "×" clears the filter
            renderBrand()
            load(reset: true)
            return
        }
        guard !brands.isEmpty else { toast("No brands"); return }
        let picker = HcBrandPickerViewController(brands: brands)
        picker.onPick = { [weak self] picked in
            guard let self = self else { return }
            self.brand = picked
            self.renderBrand()
            self.load(reset: true)
        }
        let nav = UINavigationController(rootViewController: picker)
        nav.modalPresentationStyle = .pageSheet
        nav.sheetPresentationController?.detents = [.medium(), .large()]
        present(nav, animated: true)
    }

    private func renderBrand() {
        let selected = brand != nil
        brandButton.configuration?.title = brand ?? "All brands"
        brandButton.configuration?.baseForegroundColor = selected ? AppColors.textPrimary : AppColors.textTertiary
        brandIcon.image = UIImage(systemName: selected ? "xmark.circle.fill" : "chevron.down",
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: selected ? 15 : 12,
                                                                                 weight: .semibold))
    }

    private func clearFilters() {
        searchWork?.cancel()
        search = ""
        searchField.text = ""
        brand = nil
        renderBrand()
        imagesOnly = false
        imagesSwitch.setOn(false, animated: true)
        load(reset: true)
    }

    private var hasFilters: Bool { !search.isEmpty || brand != nil || imagesOnly }

    // MARK: Loading

    private func load(reset: Bool) {
        generation += 1
        let gen = generation
        if reset {
            page = 1
            hasMore = false
            loadingFirst = true
            loadingMore = false
            errorMessage = nil
        } else {
            loadingMore = true
        }
        render()

        ApiClient.shared.getHcLibrary(search: search, brand: brand, imagesOnly: imagesOnly, page: page,
                                      perPage: Self.pageSize) { [weak self] result in
            guard let self = self, gen == self.generation else { return }
            self.loadingFirst = false
            self.loadingMore = false
            switch result {
            case .success(let data):
                self.loadedOnce = true
                self.available = data.available
                self.libraryReady = data.libraryReady
                self.total = data.total
                if !data.brands.isEmpty { self.brands = data.brands }
                if reset { self.items = [] }
                self.items.append(contentsOf: data.items)
                self.hasMore = !data.items.isEmpty && self.items.count < data.total
                self.collectionView.reloadData()
                if reset, !self.items.isEmpty {
                    self.collectionView.setContentOffset(CGPoint(x: 0, y: -self.collectionView.adjustedContentInset.top),
                                                         animated: false)
                }
            case .failure(let error):
                let message = error.message.isEmpty ? "Could not load the library. Please try again." : error.message
                if reset {
                    self.errorMessage = message
                    self.items = []
                    self.collectionView.reloadData()
                } else {
                    self.page = max(1, self.page - 1)   // the next scroll retries this page
                    self.toast(message)
                }
            }
            self.render()
        }
    }

    private func render() {
        if loadedOnce && available && libraryReady && errorMessage == nil {
            countLabel.text = loadingFirst ? "Searching…"
                : "\(AddProductFlow.count(total)) \(total == 1 ? "product" : "products")"
        } else {
            countLabel.text = loadingFirst ? "Searching…" : " "
        }

        if loadingFirst { spinner.startAnimating() } else { spinner.stopAnimating() }
        let showList = !loadingFirst && errorMessage == nil && available && libraryReady && !items.isEmpty
        collectionView.isHidden = !showList
        collectionView.collectionViewLayout.invalidateLayout()

        stateActions.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stateText.isHidden = true
        guard !loadingFirst, !showList else { stateView.isHidden = true; return }
        stateView.isHidden = false

        if let error = errorMessage {
            stateTitle.text = "We couldn't load the library."
            showStateText(error)
            addStateButton("Retry", primary: true) { [weak self] in self?.load(reset: true) }
        } else if !available {
            stateTitle.text = "The Hirt & Carter library is currently unavailable."
            addStateButton("Back", primary: false) { [weak self] in self?.navigationController?.popViewController(animated: true) }
        } else if !libraryReady {
            stateTitle.text = "The library is being prepared. Please try again later."
            showStateText("In the meantime you can add a product by entering its barcode.")
            addStateButton("Enter or scan a barcode", primary: true) { [weak self] in
                guard let self = self else { return }
                let barcode = BarcodeVerifyViewController()
                barcode.onSaved = self.onSaved
                self.navigationController?.pushViewController(barcode, animated: true)
            }
        } else {
            stateTitle.text = "No products match your search"
            if hasFilters {
                addStateButton("Clear filters", primary: false) { [weak self] in self?.clearFilters() }
            }
            if AddProductFlow.isBarcode(search) {
                let barcode = search
                addStateButton("Look this barcode up at Hirt & Carter", primary: true) { [weak self] in
                    self?.openProduct(barcode, button: nil)
                }
            }
        }
    }

    private func showStateText(_ text: String) {
        stateText.text = text
        stateText.isHidden = false
    }

    private func addStateButton(_ title: String, primary: Bool, action: @escaping () -> Void) {
        let button = primary ? AddProductFlow.primaryButton(title, height: 42)
                             : AddProductFlow.secondaryButton(title, height: 42)
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        stateActions.addArrangedSubview(button)
    }

    // MARK: Product lookup

    /// Fetch the full Hirt & Carter record for a card (or a typed barcode) and open it.
    private func openProduct(_ gtin: String, button: UIButton?) {
        guard lookupGtin == nil, !gtin.isEmpty else { return }
        lookupGtin = gtin
        collectionView.reloadData()
        ApiClient.shared.hcLookup(barcode: gtin) { [weak self] result in
            guard let self = self else { return }
            self.lookupGtin = nil
            self.collectionView.reloadData()
            switch result {
            case .success(let data):
                if data.found, let product = data.product {
                    let detail = HcProductViewController()
                    detail.product = product
                    detail.source = .library
                    detail.onSaved = self.onSaved
                    self.navigationController?.pushViewController(detail, animated: true)
                } else {
                    self.toast(data.available ? "This product was not found in the Hirt & Carter catalogue."
                                              : "The Hirt & Carter catalogue is currently unavailable.")
                }
            case .failure:
                self.toast("Could not load the product details. Please try again.")
            }
        }
    }

    // MARK: Collection view

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HcLibraryCell.reuseId,
                                                      for: indexPath) as! HcLibraryCell
        let item = items[indexPath.item]
        cell.configure(item, busy: lookupGtin == item.gtin, dimmed: lookupGtin != nil && lookupGtin != item.gtin)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < items.count else { return }
        openProduct(items[indexPath.item].gtin, button: nil)
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        guard hasMore, !loadingFirst, !loadingMore, errorMessage == nil,
              indexPath.item >= items.count - 6 else { return }
        page += 1
        load(reset: false)
        collectionView.collectionViewLayout.invalidateLayout()
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
            withReuseIdentifier: HcLibraryFooter.reuseId, for: indexPath) as! HcLibraryFooter
        footer.configure(loading: loadingMore)
        return footer
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForFooterInSection section: Int) -> CGSize {
        items.isEmpty ? .zero : CGSize(width: collectionView.bounds.width, height: 64)
    }

    private var columns: Int {
        // Two columns on phones, more as the screen widens (portal: 150 pt minimum card width).
        max(2, Int((collectionView.bounds.width - sectionInset.left - sectionInset.right) / 170))
    }

    private var itemWidth: CGFloat {
        let usable = collectionView.bounds.width - sectionInset.left - sectionInset.right
            - gap * CGFloat(columns - 1)
        return floor(usable / CGFloat(columns))
    }

    /// Cards in a row share the tallest card's height so the grid stays even.
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = itemWidth
        let cols = columns
        let rowStart = (indexPath.item / cols) * cols
        let rowEnd = min(rowStart + cols, items.count)
        var height: CGFloat = 0
        for i in rowStart..<rowEnd {
            height = max(height, HcLibraryCell.height(for: items[i], width: width))
        }
        return CGSize(width: width, height: height)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in self.collectionView.collectionViewLayout.invalidateLayout() })
    }
}

// MARK: - Library card

/// Hirt & Carter library card: square image, BRAND, name, size + GTIN, tags.
final class HcLibraryCell: UICollectionViewCell {

    static let reuseId = "HcLibraryCell"

    private static let padding: CGFloat = 12
    private static let brandHeight: CGFloat = 14
    private static let nameHeight: CGFloat = 38
    private static let metaHeight: CGFloat = 16
    private static let tagHeight: CGFloat = 20

    private let card = UIView()
    private let well = UIView()
    private let thumb = UIImageView()
    private let placeholder = UIImageView(image: UIImage(systemName: "photo",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 34, weight: .light)))
    private let brandLabel = UILabel()
    private let nameLabel = UILabel()
    private let sizeLabel = UILabel()
    private let gtinLabel = UILabel()
    private let noImageTag = PaddingLabel(insets: UIEdgeInsets(top: 2, left: 7, bottom: 2, right: 7))
    private let addedTag = PaddingLabel(insets: UIEdgeInsets(top: 2, left: 7, bottom: 2, right: 7))
    private let overlay = UIView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let body = UIStackView.vertical(spacing: 0, alignment: .fill)
    private var task: URLSessionDataTask?
    private var boundURL: URL?

    /// Height of a card for `item` at `width` (all rows are fixed-height except the tags).
    static func height(for item: HcLibraryData.Item, width: CGFloat) -> CGFloat {
        let tags = (item.hasImages ? 0 : 1) + (item.alreadyAdded ? 1 : 0)
        return padding + (width - padding * 2) + 10 + brandHeight + 4 + nameHeight + 4 + metaHeight
            + CGFloat(tags) * (6 + tagHeight) + padding
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        isAccessibilityElement = true
        accessibilityTraits = .button
        card.backgroundColor = AppColors.surface
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 1
        card.layer.borderColor = AppColors.border.cgColor
        card.forAutoLayout()
        contentView.addSubview(card)
        card.pinEdges(to: contentView)

        body.forAutoLayout()
        card.addSubview(body)
        NSLayoutConstraint.activate([
            body.topAnchor.constraint(equalTo: card.topAnchor, constant: Self.padding),
            body.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Self.padding),
            body.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Self.padding)
        ])

        well.backgroundColor = AddProductFlow.Palette.slateBg
        well.layer.cornerRadius = 10
        well.clipsToBounds = true
        well.heightAnchor.constraint(equalTo: well.widthAnchor).isActive = true
        thumb.contentMode = .scaleAspectFit
        thumb.backgroundColor = AppColors.surface
        thumb.forAutoLayout()
        well.addSubview(thumb)
        thumb.pinEdges(to: well)
        placeholder.tintColor = AddProductFlow.Palette.placeholder
        placeholder.contentMode = .center
        placeholder.forAutoLayout()
        well.addSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.centerXAnchor.constraint(equalTo: well.centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: well.centerYAnchor)
        ])
        body.addArrangedSubview(well)
        body.setCustomSpacing(10, after: well)

        brandLabel.font = AppFonts.bold(11)
        brandLabel.textColor = AppColors.textSecondary
        brandLabel.constrainHeight(Self.brandHeight)
        body.addArrangedSubview(brandLabel)
        body.setCustomSpacing(4, after: brandLabel)

        nameLabel.font = AppFonts.semibold(14)
        nameLabel.textColor = AppColors.textPrimary
        nameLabel.numberOfLines = 2
        nameLabel.lineBreakMode = .byTruncatingTail
        let nameBox = UIView()
        nameBox.constrainHeight(Self.nameHeight)
        nameLabel.forAutoLayout()
        nameBox.addSubview(nameLabel)
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: nameBox.topAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: nameBox.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: nameBox.trailingAnchor),
            nameLabel.bottomAnchor.constraint(lessThanOrEqualTo: nameBox.bottomAnchor)
        ])
        body.addArrangedSubview(nameBox)
        body.setCustomSpacing(4, after: nameBox)

        sizeLabel.font = AppFonts.regular(12)
        sizeLabel.textColor = AppColors.textSecondary
        sizeLabel.setContentHuggingPriority(.required, for: .horizontal)
        sizeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        gtinLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        gtinLabel.textColor = AppColors.textSecondary
        gtinLabel.lineBreakMode = .byTruncatingTail
        let meta = UIStackView.horizontal(spacing: 8, alignment: .center)
        meta.addArrangedSubview(sizeLabel)
        meta.addArrangedSubview(gtinLabel)
        meta.constrainHeight(Self.metaHeight)
        body.addArrangedSubview(meta)

        styleTag(noImageTag, "No image", fg: AddProductFlow.Palette.slate,
                 bg: AddProductFlow.Palette.slateBg, border: AddProductFlow.Palette.slateBorder)
        styleTag(addedTag, "Already in your catalogue", fg: AddProductFlow.Palette.tagPurple,
                 bg: AddProductFlow.Palette.tagPurpleBg, border: AddProductFlow.Palette.tagPurpleBorder)
        for tag in [noImageTag, addedTag] {
            let row = UIStackView.horizontal(spacing: 0, alignment: .center)
            row.addArrangedSubview(tag)
            row.addArrangedSubview(UIView())
            tag.constrainHeight(Self.tagHeight)
            body.setCustomSpacing(6, after: body.arrangedSubviews.last!)
            body.addArrangedSubview(row)
        }

        overlay.backgroundColor = UIColor.white.withAlphaComponent(0.75)
        overlay.layer.cornerRadius = 14
        overlay.isHidden = true
        overlay.forAutoLayout()
        card.addSubview(overlay)
        overlay.pinEdges(to: card)
        spinner.color = AddProductFlow.Palette.violet
        spinner.forAutoLayout()
        overlay.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
        ])
    }

    private func styleTag(_ tag: PaddingLabel, _ text: String, fg: UIColor, bg: UIColor, border: UIColor) {
        tag.text = text
        tag.font = AppFonts.regular(11)
        tag.textColor = fg
        tag.backgroundColor = bg
        tag.layer.cornerRadius = 4
        tag.layer.borderWidth = 1
        tag.layer.borderColor = border.cgColor
        tag.layer.masksToBounds = true
        tag.lineBreakMode = .byTruncatingTail
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        task?.cancel()
        task = nil
        boundURL = nil
        thumb.image = nil
    }

    func configure(_ item: HcLibraryData.Item, busy: Bool, dimmed: Bool) {
        let brand = (item.brand ?? "").trimmingCharacters(in: .whitespaces)
        brandLabel.attributedText = NSAttributedString(string: brand.uppercased(), attributes: [
            .kern: 0.66, .font: AppFonts.bold(11), .foregroundColor: AppColors.textSecondary])
        nameLabel.text = item.name
        let size = ((item.size ?? "") + (item.uom ?? "")).trimmingCharacters(in: .whitespaces)
        sizeLabel.text = size
        sizeLabel.isHidden = size.isEmpty
        gtinLabel.text = item.gtin
        noImageTag.superview?.isHidden = item.hasImages
        addedTag.superview?.isHidden = !item.alreadyAdded

        // Products already in the catalogue stay selectable but read as secondary.
        card.backgroundColor = item.alreadyAdded ? AddProductFlow.Palette.page : AppColors.surface
        body.alpha = item.alreadyAdded ? 0.7 : 1
        accessibilityLabel = (brand.isEmpty ? "" : brand + " ") + (item.name ?? "")
            + (item.alreadyAdded ? " (already in your catalogue)" : "")

        overlay.isHidden = !busy
        if busy { spinner.startAnimating() } else { spinner.stopAnimating() }
        contentView.alpha = dimmed ? 0.85 : 1

        if let s = item.thumbUrl, let url = URL(string: s) {
            boundURL = url
            placeholder.isHidden = true
            thumb.isHidden = false
            task = ImageLoader.load(url) { [weak self] image in
                guard let self = self, self.boundURL == url else { return }
                if let image = image {
                    self.thumb.image = image
                } else {
                    // Broken image: show the placeholder, as the portal does.
                    self.thumb.isHidden = true
                    self.placeholder.isHidden = false
                }
            }
        } else {
            thumb.isHidden = true
            placeholder.isHidden = false
        }
    }
}

/// Grid footer: spinner while the next page loads, otherwise the data attribution.
final class HcLibraryFooter: UICollectionReusableView {

    static let reuseId = "HcLibraryFooter"

    private let spinner = UIActivityIndicatorView(style: .medium)
    private let attribution = UILabel.make("Product data and images supplied by Hirt & Carter Digital",
                                           font: AppFonts.regular(12), color: AppColors.textSecondary,
                                           align: .center, lines: 0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        spinner.color = AddProductFlow.Palette.violet
        spinner.hidesWhenStopped = true
        let stack = UIStackView.vertical(spacing: 6, alignment: .center)
        stack.addArrangedSubview(spinner)
        stack.addArrangedSubview(attribution)
        stack.forAutoLayout()
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(loading: Bool) {
        if loading { spinner.startAnimating() } else { spinner.stopAnimating() }
        attribution.isHidden = loading
    }
}

/// Searchable single-choice brand list ("All brands" first).
final class HcBrandPickerViewController: UITableViewController, UISearchResultsUpdating {

    var onPick: ((String?) -> Void)?

    private let brands: [String]
    private var filtered: [String]
    private let allBrands = "All brands"

    init(brands: [String]) {
        self.brands = brands
        self.filtered = brands
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Brand"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self,
                                                           action: #selector(cancel))
        let search = UISearchController(searchResultsController: nil)
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Search brands"
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "brand")
    }

    private var isSearching: Bool {
        !(navigationItem.searchController?.searchBar.text ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    func updateSearchResults(for searchController: UISearchController) {
        let q = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        filtered = q.isEmpty ? brands : brands.filter { $0.lowercased().contains(q) }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        isSearching ? max(filtered.count, 1) : filtered.count + 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "brand", for: indexPath)
        var content = cell.defaultContentConfiguration()
        if isSearching && filtered.isEmpty {
            content.text = "No brands"
            content.textProperties.color = AppColors.textTertiary
            cell.selectionStyle = .none
        } else {
            content.text = brand(at: indexPath.row) ?? allBrands
            content.textProperties.color = AppColors.textPrimary
            cell.selectionStyle = .default
        }
        content.textProperties.font = AppFonts.regular(15)
        cell.contentConfiguration = content
        return cell
    }

    /// nil for the "All brands" row.
    private func brand(at row: Int) -> String? {
        if isSearching { return row < filtered.count ? filtered[row] : nil }
        return row == 0 ? nil : filtered[row - 1]
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isSearching && filtered.isEmpty { return }
        let picked = brand(at: indexPath.row)
        let handler = onPick
        dismiss(animated: true) { handler?(picked) }
    }

    @objc private func cancel() { dismiss(animated: true) }
}

// MARK: - Hirt & Carter product

/// "Found in the Hirt & Carter catalogue" — one catalogue record with its images and product
/// content, reached from the library or from a barcode lookup.
///
/// The highlighted thumbnail is the image the server will import as the product picture.
/// "Use this product" opens the Create Product wizard prefilled from the record.
final class HcProductViewController: BaseSecondaryViewController {

    enum Source {
        case library
        case barcode(String)
    }

    override var screenTitle: String { "Add New Product" }

    var product: HcLookupData.Product!
    var source: Source = .library
    var onSaved: (() -> Void)?

    private var images: [HcLookupData.Image] = []
    private var selected = 0
    private let mainImage = UIImageView()
    private let mainPlaceholder = UIView()
    private var thumbTiles: [UIView] = []
    private let hint = UILabel.make("The selected image will be imported as the product image.",
                                    font: AppFonts.regular(13), color: AppColors.textSecondary, lines: 0)
    private let contentList = UIStackView.vertical(spacing: 0, alignment: .fill)
    private let contentChevron = UIImageView(image: UIImage(systemName: "chevron.right",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
    private var contentOpen = false

    override func setupContent(in container: UIView) {
        guard let product = product else { return }
        images = product.previewImages

        let stack = AddProductFlow.scrollStack(in: container,
                                               insets: UIEdgeInsets(top: 16, left: 16, bottom: 32, right: 16))
        let panel = AddProductFlow.panel(border: AddProductFlow.Palette.greenBorder)
        let content = UIStackView.vertical(spacing: 0, alignment: .fill)
        content.forAutoLayout()
        panel.addSubview(content)
        content.pinEdges(to: panel)

        content.addArrangedSubview(AddProductFlow.banner("Found in the Hirt & Carter catalogue",
            symbol: "checkmark.circle.fill", textColor: AddProductFlow.Palette.green,
            iconColor: AddProductFlow.Palette.green, background: AddProductFlow.Palette.greenBg))
        content.addArrangedSubview(AddProductFlow.line(AddProductFlow.Palette.greenBorder))

        let body = UIStackView.vertical(spacing: 0, alignment: .fill)
        body.isLayoutMarginsRelativeArrangement = true
        body.layoutMargins = UIEdgeInsets(top: 20, left: 16, bottom: 16, right: 16)
        body.addArrangedSubview(buildMainImage())
        if images.isEmpty {
            let none = UILabel.make("No preview images are available for this product.",
                                    font: AppFonts.regular(13), color: AppColors.textSecondary, lines: 0)
            body.setCustomSpacing(12, after: body.arrangedSubviews.last!)
            body.addArrangedSubview(none)
        } else {
            body.setCustomSpacing(12, after: body.arrangedSubviews.last!)
            body.addArrangedSubview(buildThumbs())
        }

        let title = UILabel.make((product.name ?? "").isEmpty ? "Unnamed product" : product.name,
                                 font: AppFonts.bold(22), color: AppColors.textPrimary, lines: 0)
        body.setCustomSpacing(20, after: body.arrangedSubviews.last!)
        body.addArrangedSubview(title)
        body.setCustomSpacing(8, after: title)

        let size = [product.size, product.uom].compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: " ")
        let details: [(String, String?)] = [("Brand", product.brand), ("Size", size),
                                            ("GTIN", product.gtin), ("Article number", product.articleNumber)]
        for (label, value) in details {
            guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { continue }
            body.addArrangedSubview(detailRow(label, value))
            body.addArrangedSubview(AddProductFlow.line())
        }
        body.setCustomSpacing(14, after: body.arrangedSubviews.last!)
        body.addArrangedSubview(hint)
        content.addArrangedSubview(body)

        if !product.content.isEmpty { content.addArrangedSubview(buildContentSection(product.content)) }

        let attribution = UILabel.make("Product data supplied by Hirt & Carter Digital", font: AppFonts.regular(12),
                                       color: AppColors.textSecondary, align: .center, lines: 0)
        let attributionWrap = UIView()
        attribution.forAutoLayout()
        attributionWrap.addSubview(attribution)
        attribution.pinEdges(to: attributionWrap, insets: UIEdgeInsets(top: 14, left: 16, bottom: 0, right: 16))
        content.addArrangedSubview(attributionWrap)

        let actions = UIStackView.vertical(spacing: 12, alignment: .fill)
        actions.isLayoutMarginsRelativeArrangement = true
        actions.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        let use = AddProductFlow.primaryButton("Use this product")
        use.addTarget(self, action: #selector(useTapped), for: .touchUpInside)
        let reject = AddProductFlow.secondaryButton("Not this product")
        reject.addTarget(self, action: #selector(rejectTapped), for: .touchUpInside)
        actions.addArrangedSubview(use)
        actions.addArrangedSubview(reject)
        content.addArrangedSubview(actions)

        stack.addArrangedSubview(panel)
        renderSelection()
    }

    // MARK: Images

    private func buildMainImage() -> UIView {
        let box = UIView()
        box.backgroundColor = AppColors.surface
        box.layer.cornerRadius = 12
        box.layer.borderWidth = 1
        box.layer.borderColor = AppColors.border.cgColor
        box.clipsToBounds = true
        box.heightAnchor.constraint(equalTo: box.widthAnchor).isActive = true

        mainImage.contentMode = .scaleAspectFit
        mainImage.forAutoLayout()
        box.addSubview(mainImage)
        mainImage.pinEdges(to: box, insets: UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1))

        mainPlaceholder.backgroundColor = AddProductFlow.Palette.slateBg
        mainPlaceholder.forAutoLayout()
        box.addSubview(mainPlaceholder)
        mainPlaceholder.pinEdges(to: box)
        let icon = UIImageView(image: UIImage(systemName: "photo",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 36, weight: .light)))
        icon.tintColor = AddProductFlow.Palette.muted
        icon.forAutoLayout()
        mainPlaceholder.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: mainPlaceholder.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: mainPlaceholder.centerYAnchor)
        ])
        return box
    }

    private func buildThumbs() -> UIView {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        let row = UIStackView.horizontal(spacing: 10, alignment: .top)
        row.forAutoLayout()
        scroll.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            row.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
        scroll.constrainHeight(90)

        for (i, image) in images.enumerated() {
            let tile = UIView()
            tile.backgroundColor = AppColors.surface
            tile.layer.cornerRadius = 10
            tile.layer.borderWidth = 2
            tile.widthAnchor.constraint(equalToConstant: 76).isActive = true
            tile.heightAnchor.constraint(equalToConstant: 86).isActive = true
            tile.isAccessibilityElement = true
            tile.accessibilityLabel = imageAlt(image)
            tile.accessibilityTraits = .button

            let thumb = UIImageView()
            thumb.contentMode = .scaleAspectFit
            thumb.forAutoLayout()
            tile.addSubview(thumb)
            let caption = UILabel.make(image.angleName.isEmpty ? "Image \(i + 1)" : image.angleName,
                                       font: AppFonts.regular(11), color: AppColors.textSecondary,
                                       align: .center, lines: 1)
            caption.lineBreakMode = .byTruncatingTail
            caption.forAutoLayout()
            tile.addSubview(caption)
            NSLayoutConstraint.activate([
                thumb.topAnchor.constraint(equalTo: tile.topAnchor, constant: 4),
                thumb.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 4),
                thumb.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -4),
                thumb.heightAnchor.constraint(equalToConstant: 56),
                caption.topAnchor.constraint(equalTo: thumb.bottomAnchor, constant: 4),
                caption.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 4),
                caption.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -4)
            ])
            if let url = image.previewUrl.flatMap(URL.init(string:)) {
                ImageLoader.load(url) { [weak thumb] loaded in thumb?.image = loaded }
            }
            tile.tag = i
            tile.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(thumbTapped(_:))))
            row.addArrangedSubview(tile)
            thumbTiles.append(tile)
        }
        return scroll
    }

    @objc private func thumbTapped(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag, index < images.count else { return }
        selected = index
        renderSelection()
    }

    private var currentImage: HcLookupData.Image? { selected < images.count ? images[selected] : nil }

    private func renderSelection() {
        for (i, tile) in thumbTiles.enumerated() {
            let on = i == selected
            tile.layer.borderColor = (on ? AddProductFlow.Palette.violet : AppColors.border).cgColor
            tile.accessibilityTraits = on ? [.button, .selected] : .button
        }
        hint.isHidden = currentImage == nil
        guard let image = currentImage, let url = image.previewUrl.flatMap(URL.init(string:)) else {
            mainImage.isHidden = true
            mainPlaceholder.isHidden = false
            return
        }
        mainImage.accessibilityLabel = imageAlt(image)
        mainImage.isHidden = false
        mainPlaceholder.isHidden = true
        ImageLoader.load(url) { [weak self] loaded in
            guard let self = self, self.currentImage?.previewUrl == image.previewUrl else { return }
            if let loaded = loaded {
                self.mainImage.image = loaded
            } else {
                self.mainImage.isHidden = true
                self.mainPlaceholder.isHidden = false
            }
        }
    }

    private func imageAlt(_ image: HcLookupData.Image) -> String {
        let name = product?.name ?? ""
        return image.angleName.isEmpty ? name : "\(name) - \(image.angleName)"
    }

    // MARK: Details & content

    private func detailRow(_ label: String, _ value: String) -> UIView {
        let l = UILabel.make(label, font: AppFonts.regular(14), color: AppColors.textSecondary)
        l.widthAnchor.constraint(equalToConstant: 120).isActive = true
        let v = UILabel.make(value, font: AppFonts.semibold(14), color: AppColors.textPrimary, lines: 0)
        let row = UIStackView.horizontal(spacing: 12, alignment: .top)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 9, left: 0, bottom: 9, right: 0)
        row.addArrangedSubview(l)
        row.addArrangedSubview(v)
        return row
    }

    /// Collapsible "Product content (N)" section, closed by default as on the portal.
    private func buildContentSection(_ rows: [HcLookupData.Content]) -> UIView {
        let section = UIStackView.vertical(spacing: 0, alignment: .fill)
        section.addArrangedSubview(AddProductFlow.line())

        let header = UIControl()
        contentChevron.tintColor = AppColors.textPrimary
        contentChevron.contentMode = .center
        contentChevron.isUserInteractionEnabled = false
        let title = UILabel.make("Product content (\(rows.count))", font: AppFonts.regular(14), color: AppColors.textPrimary)
        let headerRow = UIStackView.horizontal(spacing: 12, alignment: .center)
        headerRow.isUserInteractionEnabled = false
        headerRow.addArrangedSubview(contentChevron)
        headerRow.addArrangedSubview(title)
        contentChevron.widthAnchor.constraint(equalToConstant: 14).isActive = true
        headerRow.forAutoLayout()
        header.addSubview(headerRow)
        headerRow.pinEdges(to: header, insets: UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))
        header.addTarget(self, action: #selector(toggleContent), for: .touchUpInside)
        section.addArrangedSubview(header)

        contentList.isLayoutMarginsRelativeArrangement = true
        contentList.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 4, right: 16)
        for row in rows {
            let item = UIStackView.vertical(spacing: 2, alignment: .fill)
            item.isLayoutMarginsRelativeArrangement = true
            item.layoutMargins = UIEdgeInsets(top: 9, left: 0, bottom: 9, right: 0)
            if !row.heading.isEmpty {
                item.addArrangedSubview(UILabel.make(row.heading.uppercased(), font: AppFonts.medium(11),
                                                     color: AppColors.textSecondary, lines: 0))
            }
            if !row.name.isEmpty {
                item.addArrangedSubview(UILabel.make(row.name, font: AppFonts.semibold(13),
                                                     color: AppColors.textPrimary, lines: 0))
            }
            let value = UILabel.make(row.value, font: AppFonts.regular(13), color: AppColors.textPrimary, lines: 0)
            item.setCustomSpacing(4, after: item.arrangedSubviews.last ?? value)
            item.addArrangedSubview(value)
            contentList.addArrangedSubview(item)
            contentList.addArrangedSubview(AddProductFlow.line())
        }
        contentList.isHidden = true
        section.addArrangedSubview(contentList)
        return section
    }

    @objc private func toggleContent() {
        contentOpen.toggle()
        UIView.animate(withDuration: 0.2) {
            self.contentList.isHidden = !self.contentOpen
            self.contentChevron.transform = self.contentOpen ? CGAffineTransform(rotationAngle: .pi / 2) : .identity
        }
    }

    // MARK: Actions

    /// Prefill the Create Product wizard from this record (the portal's "Use this product").
    @objc private func useTapped() {
        guard let product = product else { return }
        var fallback = ""
        if case .barcode(let b) = source { fallback = b }
        let gtin = product.gtin.isEmpty ? fallback : product.gtin
        var prefill = CreateProductViewController.Prefill(barcode: gtin, name: product.name,
                                                          brandName: product.brand, size: product.size,
                                                          uom: product.uom)
        if let image = currentImage, !image.fileName.isEmpty, !gtin.isEmpty {
            prefill.hcImage = CreateProductViewController.HcImage(gtin: gtin, fileName: image.fileName,
                                                                  previewUrl: image.previewUrl)
        }
        let wizard = CreateProductViewController()
        wizard.prefill = prefill
        wizard.onSaved = onSaved
        wizard.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(wizard, animated: true)
    }

    /// From the library: back to the list. From a barcode: the match was wrong, so the barcode
    /// counts as not found — without offering a data request for it.
    @objc private func rejectTapped() {
        guard let nav = navigationController else { return }
        switch source {
        case .library:
            nav.popViewController(animated: true)
        case .barcode(let barcode):
            let notFound = BarcodeNotFoundViewController()
            notFound.barcode = barcode
            notFound.canRequest = false
            notFound.onSaved = onSaved
            var stack = nav.viewControllers
            stack.removeLast()
            stack.append(notFound)
            nav.setViewControllers(stack, animated: true)
        }
    }
}
