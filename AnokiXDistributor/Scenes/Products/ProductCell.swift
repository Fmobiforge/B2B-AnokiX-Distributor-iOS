import UIKit

/// item_product.xml — 70×70 image/placeholder, name, "SKU: …", "Category: …", price,
/// top-right stock badge + chevron. Shared by the Products tab and the standalone Products screen.
final class ProductCell: UICollectionViewCell {

    private let cardView = UIView()
    private let imageContainer = UIView()
    private let placeholderIcon = UIImageView()
    private let thumbImageView = UIImageView()
    private let nameLabel = UILabel()
    private let skuLabel = UILabel()
    private let categoryLabel = UILabel()
    private let priceLabel = UILabel()
    private let statusBadge = PaddingLabel(insets: UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
    private let chevronView = UIImageView()
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
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        imageContainer.backgroundColor = AppColors.surfaceVariant
        imageContainer.layer.cornerRadius = AppMetrics.radiusLG
        imageContainer.layer.masksToBounds = true
        imageContainer.translatesAutoresizingMaskIntoConstraints = false

        placeholderIcon.image = UIImage(systemName: "bag")
        placeholderIcon.tintColor = AppColors.purplePrimary
        placeholderIcon.contentMode = .scaleAspectFit
        placeholderIcon.translatesAutoresizingMaskIntoConstraints = false

        thumbImageView.contentMode = .scaleAspectFit
        thumbImageView.layer.masksToBounds = true
        thumbImageView.isHidden = true
        thumbImageView.translatesAutoresizingMaskIntoConstraints = false

        imageContainer.addSubview(placeholderIcon)
        imageContainer.addSubview(thumbImageView)

        nameLabel.font = AppFonts.bold(13)
        nameLabel.textColor = AppColors.textPrimary
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail

        skuLabel.font = AppFonts.regular(AppMetrics.textCaption)
        skuLabel.textColor = AppColors.textSecondary
        skuLabel.numberOfLines = 1
        skuLabel.lineBreakMode = .byTruncatingTail

        categoryLabel.font = AppFonts.regular(AppMetrics.textCaption)
        categoryLabel.textColor = AppColors.textSecondary
        categoryLabel.numberOfLines = 1
        categoryLabel.lineBreakMode = .byTruncatingTail

        priceLabel.font = AppFonts.bold(13)
        priceLabel.textColor = AppColors.purplePrimary

        let textStack = UIStackView(arrangedSubviews: [nameLabel, skuLabel, categoryLabel, priceLabel])
        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = 2
        textStack.setCustomSpacing(4, after: categoryLabel)
        textStack.translatesAutoresizingMaskIntoConstraints = false

        StyleKit.styleBadge(statusBadge)

        chevronView.image = UIImage(systemName: "chevron.right")
        chevronView.tintColor = AppColors.textTertiary
        chevronView.contentMode = .scaleAspectFit
        chevronView.translatesAutoresizingMaskIntoConstraints = false

        let rightStack = UIStackView(arrangedSubviews: [statusBadge, chevronView])
        rightStack.axis = .vertical
        rightStack.alignment = .trailing
        rightStack.spacing = 8
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        rightStack.setContentHuggingPriority(.required, for: .horizontal)
        rightStack.setContentCompressionResistancePriority(.required, for: .horizontal)

        cardView.addSubview(imageContainer)
        cardView.addSubview(textStack)
        cardView.addSubview(rightStack)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            imageContainer.widthAnchor.constraint(equalToConstant: 70),
            imageContainer.heightAnchor.constraint(equalToConstant: 70),
            imageContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            imageContainer.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            imageContainer.topAnchor.constraint(greaterThanOrEqualTo: cardView.topAnchor, constant: 12),
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
            textStack.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: cardView.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -12),

            rightStack.leadingAnchor.constraint(equalTo: textStack.trailingAnchor, constant: 8),
            rightStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            rightStack.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            rightStack.topAnchor.constraint(greaterThanOrEqualTo: cardView.topAnchor, constant: 12),
            rightStack.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -12),

            chevronView.widthAnchor.constraint(equalToConstant: 16),
            chevronView.heightAnchor.constraint(equalToConstant: 16)
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
        categoryLabel.text = "Category: \(product.category)"
        priceLabel.text = product.price
        StyleKit.applyStatusBadge(statusBadge, status: product.stockStatus)

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
