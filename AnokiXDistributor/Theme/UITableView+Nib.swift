import UIKit

/// Android-style "inflate a row layout" helpers. Each list row is defined in its own
/// `.xib` (the iOS analogue of an `item_*.xml` layout) and registered / dequeued by its
/// class name — so adapters here read like a RecyclerView adapter referencing a layout.
extension UITableView {

    /// Registers a cell whose layout lives in `<CellClass>.xib`, keyed by the class name.
    func registerNib<T: UITableViewCell>(_ type: T.Type) {
        let id = String(describing: type)
        register(UINib(nibName: id, bundle: nil), forCellReuseIdentifier: id)
    }

    /// Dequeues a XIB-backed cell by its class name.
    func dequeue<T: UITableViewCell>(_ type: T.Type, for indexPath: IndexPath) -> T {
        let id = String(describing: type)
        guard let cell = dequeueReusableCell(withIdentifier: id, for: indexPath) as? T else {
            fatalError("Dequeued cell is not \(id) — check the XIB's reuseIdentifier and custom class.")
        }
        return cell
    }
}

extension UICollectionView {

    /// Registers a collection cell whose layout lives in `<CellClass>.xib`.
    func registerNib<T: UICollectionViewCell>(_ type: T.Type) {
        let id = String(describing: type)
        register(UINib(nibName: id, bundle: nil), forCellWithReuseIdentifier: id)
    }

    /// Dequeues a XIB-backed collection cell by its class name.
    func dequeue<T: UICollectionViewCell>(_ type: T.Type, for indexPath: IndexPath) -> T {
        let id = String(describing: type)
        guard let cell = dequeueReusableCell(withReuseIdentifier: id, for: indexPath) as? T else {
            fatalError("Dequeued cell is not \(id) — check the XIB's reuseIdentifier and custom class.")
        }
        return cell
    }
}
