import UIKit

/// item_product.xml — 64×64 image/placeholder, name + status badge, SKU, category chip,
/// brand, price and the stock count + stock badge. Shared by the Products tab and the
/// standalone Products screen.
final class ProductCell: UICollectionViewCell {

    private let cardView = UIView()
    private let imageContainer = UIView()
    private let placeholderIcon = UIImageView()
    private let thumbImageView = UIImageView()
    private let nameLabel = UILabel()
    private let statusBadge = PaddingLabel(insets: UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8))
    private let skuLabel = UILabel()
    private let categoryChip = PaddingLabel(insets: UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
    private let brandLabel = UILabel()
    private let priceLabel = UILabel()
    private let stockLabel = UILabel()
    private let stockBadge = PaddingLabel(insets: UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
    private var imageTask: URLSessionDataTask?
    private var didBuild = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        build()
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        build()
    }

    private func build() {
        guard !didBuild else { return }
        didBuild = true
        backgroundColor = .clear

        StyleKit.styleCard(cardView)
        cardView.forAutoLayout()
        contentView.addSubview(cardView)

        imageContainer.backgroundColor = AppColors.purpleLight
        imageContainer.layer.cornerRadius = AppMetrics.radiusMD
        imageContainer.layer.masksToBounds = true
        imageContainer.forAutoLayout()

        placeholderIcon.image = UIImage(systemName: "bag")
        placeholderIcon.tintColor = AppColors.purplePrimary
        placeholderIcon.contentMode = .scaleAspectFit
        placeholderIcon.forAutoLayout()

        thumbImageView.contentMode = .scaleAspectFill
        thumbImageView.layer.masksToBounds = true
        thumbImageView.isHidden = true
        thumbImageView.forAutoLayout()

        imageContainer.addSubview(placeholderIcon)
        imageContainer.addSubview(thumbImageView)

        nameLabel.font = AppFonts.bold(AppMetrics.textBody)
        nameLabel.textColor = AppColors.textPrimary
        nameLabel.numberOfLines = 2
        nameLabel.lineBreakMode = .byTruncatingTail

        StyleKit.styleBadge(statusBadge)
        statusBadge.font = AppFonts.semibold(AppMetrics.textMicro)
        statusBadge.setContentHuggingPriority(.required, for: .horizontal)
        statusBadge.setContentCompressionResistancePriority(.required, for: .horizontal)

        let titleRow = UIStackView.horizontal(spacing: 8, alignment: .top)
        titleRow.addArrangedSubview(nameLabel)
        titleRow.addArrangedSubview(statusBadge)

        skuLabel.font = AppFonts.regular(AppMetrics.textCaption)
        skuLabel.textColor = AppColors.textSecondary
        skuLabel.numberOfLines = 1
        skuLabel.lineBreakMode = .byTruncatingTail

        categoryChip.font = AppFonts.regular(AppMetrics.textMicro)
        categoryChip.textColor = AppColors.textSecondary
        categoryChip.backgroundColor = AppColors.borderLight
        categoryChip.isPill = true
        categoryChip.layer.borderWidth = 1
        categoryChip.layer.borderColor = AppColors.border.cgColor
        categoryChip.layer.masksToBounds = true
        categoryChip.setContentHuggingPriority(.required, for: .horizontal)

        brandLabel.font = AppFonts.regular(AppMetrics.textMicro)
        brandLabel.textColor = AppColors.textTertiary
        brandLabel.numberOfLines = 1
        brandLabel.lineBreakMode = .byTruncatingTail

        let metaRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        metaRow.addArrangedSubview(categoryChip)
        metaRow.addArrangedSubview(brandLabel)

        priceLabel.font = AppFonts.bold(AppMetrics.textBody)
        priceLabel.textColor = AppColors.purplePrimary
        priceLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        stockLabel.font = AppFonts.bold(AppMetrics.textCaption)
        stockLabel.textColor = AppColors.textPrimary
        stockLabel.setContentHuggingPriority(.required, for: .horizontal)

        StyleKit.styleBadge(stockBadge)
        stockBadge.font = AppFonts.semibold(AppMetrics.textMicro)
        stockBadge.setContentHuggingPriority(.required, for: .horizontal)
        stockBadge.setContentCompressionResistancePriority(.required, for: .horizontal)

        let priceRow = UIStackView.horizontal(spacing: 6, alignment: .center)
        priceRow.addArrangedSubview(priceLabel)
        priceRow.addArrangedSubview(stockLabel)
        priceRow.addArrangedSubview(stockBadge)

        let textStack = UIStackView.vertical(spacing: 3, alignment: .fill)
        textStack.addArrangedSubview(titleRow)
        textStack.addArrangedSubview(skuLabel)
        textStack.addArrangedSubview(metaRow)
        textStack.addArrangedSubview(priceRow)
        textStack.setCustomSpacing(6, after: skuLabel)
        textStack.setCustomSpacing(8, after: metaRow)
        textStack.forAutoLayout()

        cardView.addSubview(imageContainer)
        cardView.addSubview(textStack)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            imageContainer.widthAnchor.constraint(equalToConstant: 64),
            imageContainer.heightAnchor.constraint(equalToConstant: 64),
            imageContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            imageContainer.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            imageContainer.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -12),

            placeholderIcon.widthAnchor.constraint(equalToConstant: 24),
            placeholderIcon.heightAnchor.constraint(equalToConstant: 24),
            placeholderIcon.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
            placeholderIcon.centerYAnchor.constraint(equalTo: imageContainer.centerYAnchor),

            thumbImageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            thumbImageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            thumbImageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            thumbImageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),

            textStack.leadingAnchor.constraint(equalTo: imageContainer.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            textStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        thumbImageView.image = nil
        thumbImageView.isHidden = true
    }

    func configure(_ product: ProductItem) {
        nameLabel.text = product.name
        skuLabel.text = "SKU: \(product.sku)"

        categoryChip.text = product.category
        categoryChip.isHidden = product.category.isEmpty
        brandLabel.text = product.brand
        brandLabel.isHidden = product.brand.isEmpty

        priceLabel.text = product.price
        stockLabel.text = NumberFormatter.localizedString(
            from: NSNumber(value: product.stockQty), number: .decimal)
        StyleKit.applyStatusBadge(stockBadge, status: product.stockStatus)

        let statusText = product.status.isEmpty ? "Active" : product.status
        statusBadge.text = statusText
        statusBadge.textColor = product.isActive ? AppColors.success : AppColors.textSecondary
        statusBadge.backgroundColor = product.isActive ? AppColors.successBg : AppColors.borderLight

        thumbImageView.isHidden = true
        if let urlString = product.imageUrl, let url = URL(string: urlString) {
            imageTask = ImageLoader.load(url) { [weak self] image in
                guard let self = self, let image = image else { return }
                self.thumbImageView.image = image
                self.thumbImageView.isHidden = false
            }
        }
    }
}

/// Minimal async image loader (Glide stand-in) with an in-memory cache.
enum ImageLoader {
    private static let cache = NSCache<NSURL, UIImage>()

    static func clearCache() { cache.removeAllObjects() }

    @discardableResult
    static func load(_ url: URL, completion: @escaping (UIImage?) -> Void) -> URLSessionDataTask? {
        if let cached = cache.object(forKey: url as NSURL) { completion(cached); return nil }
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            let image = data.flatMap { UIImage(data: $0) }
            if let image = image { cache.setObject(image, forKey: url as NSURL) }
            DispatchQueue.main.async { completion(image) }
        }
        task.resume()
        return task
    }
}
