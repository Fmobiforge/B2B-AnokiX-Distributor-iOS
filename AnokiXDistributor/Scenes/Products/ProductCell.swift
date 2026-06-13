import UIKit

/// item_product.xml — image/placeholder, name, SKU, category, price, stock pill.
/// Shared by the Products tab (ProductsFragment) and the Products secondary screen.
/// Layout lives in `ProductCell.xib`; theme styling is applied in `awakeFromNib`.
final class ProductCell: UICollectionViewCell {

    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var thumbImageView: UIImageView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var metaLabel: UILabel!
    @IBOutlet private weak var priceLabel: UILabel!
    @IBOutlet private weak var statusBadge: PaddingLabel!
    private var imageTask: URLSessionDataTask?

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear

        StyleKit.styleCard(cardView)

        thumbImageView.backgroundColor = AppColors.surfaceVariant
        thumbImageView.layer.cornerRadius = AppMetrics.radiusMD
        thumbImageView.layer.masksToBounds = true
        thumbImageView.contentMode = .scaleAspectFill
        thumbImageView.tintColor = AppColors.textTertiary

        nameLabel.font = AppFonts.bold(13)
        nameLabel.textColor = AppColors.textPrimary
        nameLabel.numberOfLines = 1
        metaLabel.font = AppFonts.regular(11)
        metaLabel.textColor = AppColors.textSecondary
        priceLabel.font = AppFonts.bold(13)
        priceLabel.textColor = AppColors.purplePrimary

        StyleKit.styleBadge(statusBadge)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        thumbImageView.image = UIImage(systemName: "shippingbox")
    }

    func configure(_ product: ProductItem) {
        nameLabel.text = product.name
        metaLabel.text = "\(product.sku) · \(product.category)"
        priceLabel.text = product.price
        StyleKit.applyStatusBadge(statusBadge, status: product.stockStatus)
        thumbImageView.image = UIImage(systemName: "shippingbox")
        if let urlString = product.imageUrl, let url = URL(string: urlString) {
            imageTask = ImageLoader.load(url) { [weak self] image in self?.thumbImageView.image = image ?? UIImage(systemName: "shippingbox") }
        }
    }
}

/// Minimal async image loader (Glide stand-in) with an in-memory cache.
enum ImageLoader {
    private static let cache = NSCache<NSURL, UIImage>()

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
