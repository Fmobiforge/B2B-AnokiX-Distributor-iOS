import UIKit

extension UIView {

    /// Disables autoresizing-mask translation and returns self for chaining.
    @discardableResult
    func forAutoLayout() -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        return self
    }

    func addSubviews(_ views: UIView...) {
        views.forEach { addSubview($0) }
    }

    /// Pins all four edges to another view (or its safe area) with an optional inset.
    func pinEdges(to other: UIView, insets: UIEdgeInsets = .zero, useSafeArea: Bool = false) {
        translatesAutoresizingMaskIntoConstraints = false
        let top = useSafeArea ? other.safeAreaLayoutGuide.topAnchor : other.topAnchor
        let bottom = useSafeArea ? other.safeAreaLayoutGuide.bottomAnchor : other.bottomAnchor
        let leading = useSafeArea ? other.safeAreaLayoutGuide.leadingAnchor : other.leadingAnchor
        let trailing = useSafeArea ? other.safeAreaLayoutGuide.trailingAnchor : other.trailingAnchor
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: top, constant: insets.top),
            leadingAnchor.constraint(equalTo: leading, constant: insets.left),
            trailingAnchor.constraint(equalTo: trailing, constant: -insets.right),
            bottomAnchor.constraint(equalTo: bottom, constant: -insets.bottom)
        ])
    }

    func constrainHeight(_ value: CGFloat) {
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: value).isActive = true
    }
    func constrainSize(_ size: CGFloat) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size)
        ])
    }
}

extension UIStackView {
    static func vertical(spacing: CGFloat = 0, alignment: Alignment = .fill) -> UIStackView {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = spacing
        s.alignment = alignment
        return s
    }
    static func horizontal(spacing: CGFloat = 0, alignment: Alignment = .fill) -> UIStackView {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = spacing
        s.alignment = alignment
        return s
    }
}
