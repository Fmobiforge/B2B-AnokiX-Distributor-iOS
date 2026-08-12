import UIKit

/// Adaptive card-list layout — the iOS analogue of a RecyclerView `GridLayoutManager`
/// whose span count depends on screen width. One column on phones (compact width),
/// two or three on iPad (regular width), so the existing horizontal card is simply
/// laid out N-per-row without changing the card design.
///
/// Spacing that used to live inside each cell (16pt side margins, 8pt gap between
/// cards) is provided here instead, so the same cell works at any column count.
///
/// Do **not** also set horizontal `UICollectionView.contentInset` — that stacks with
/// `section.contentInsets` and produces uneven left/right margins on phone.
enum AdaptiveGridLayout {

    /// Horizontal gap between the list and the screen edges (matches the old card inset).
    static let edgeInset: CGFloat = 16
    /// Gap between rows (matches the old top+bottom 4pt card margins).
    static let lineSpacing: CGFloat = 8
    /// Gap between columns on iPad.
    static let columnSpacing: CGFloat = 16

    /// Picks a column count from the available width. Tuned so phone = 1 column and
    /// iPad (portrait/landscape, full screen or split) gets a comfortable card width.
    static func columns(for width: CGFloat) -> Int {
        switch width {
        case ..<600:   return 1   // iPhone, narrow split view
        case ..<1000:  return 2   // iPad portrait / 2-up split
        default:       return 3   // iPad landscape full screen
        }
    }

    /// A compositional layout whose section recomputes its column count on every
    /// layout pass, so rotation and iPad multitasking resize correctly.
    /// - Parameters:
    ///   - estimatedHeight: a rough row height used for self-sizing.
    ///   - headerEstimatedHeight: when set, the section gets a self-sizing top header —
    ///     used to scroll page summaries with the list instead of pinning them above it.
    static func make(estimatedHeight: CGFloat = 96,
                     headerEstimatedHeight: CGFloat?) -> UICollectionViewCompositionalLayout {
        let base = make(estimatedHeight: estimatedHeight)
        guard let headerHeight = headerEstimatedHeight else { return base }

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .vertical

        return UICollectionViewCompositionalLayout(sectionProvider: { _, environment in
            let available = environment.container.effectiveContentSize.width
            let columns = columns(for: available)

            let item = NSCollectionLayoutItem(layoutSize: .init(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalHeight(1.0)))

            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                                  heightDimension: .estimated(estimatedHeight)),
                repeatingSubitem: item,
                count: columns)
            group.interItemSpacing = .fixed(columnSpacing)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = lineSpacing
            section.contentInsets = NSDirectionalEdgeInsets(
                top: 0, leading: edgeInset, bottom: lineSpacing, trailing: edgeInset)
            section.boundarySupplementaryItems = [
                NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                                      heightDimension: .estimated(headerHeight)),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top)
            ]
            return section
        }, configuration: config)
    }

    static func make(estimatedHeight: CGFloat = 96) -> UICollectionViewCompositionalLayout {
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .vertical

        return UICollectionViewCompositionalLayout(sectionProvider: { _, environment in
            let available = environment.container.effectiveContentSize.width
            let columns = columns(for: available)

            let item = NSCollectionLayoutItem(layoutSize: .init(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalHeight(1.0)))

            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                                  heightDimension: .estimated(estimatedHeight)),
                repeatingSubitem: item,
                count: columns)
            group.interItemSpacing = .fixed(columnSpacing)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = lineSpacing
            section.contentInsets = NSDirectionalEdgeInsets(
                top: 0, leading: edgeInset, bottom: lineSpacing, trailing: edgeInset)
            return section
        }, configuration: config)
    }
}
