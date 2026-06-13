import UIKit

/// Port of DonutChartView.java — ring chart for the Inventory Summary card.
final class DonutChartView: UIView {
    var values: [CGFloat] = [1047, 86, 12] {
        didSet { setNeedsDisplay() }
    }
    var segmentColors: [UIColor] = [AppColors.success, AppColors.warning, AppColors.danger] {
        didSet { setNeedsDisplay() }
    }

    private let strokeWidth: CGFloat = 16

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }

    func setData(values: [CGFloat], colors: [UIColor]) {
        guard values.count == colors.count, !values.isEmpty else { return }
        self.values = values
        self.segmentColors = colors
    }

    override func draw(_ rect: CGRect) {
        let total = values.reduce(0, +)
        guard total > 0 else { return }

        let pad = strokeWidth / 2 + 2
        let size = min(rect.width, rect.height)
        let arcRect = CGRect(
            x: (rect.width - size) / 2 + pad,
            y: (rect.height - size) / 2 + pad,
            width: size - pad * 2,
            height: size - pad * 2
        )

        var startAngle: CGFloat = -.pi / 2
        let gap: CGFloat = 3 * .pi / 180

        for (index, value) in values.enumerated() {
            let sweep = (value / total) * 2 * .pi
            let drawSweep = max(0, sweep - gap)
            let path = UIBezierPath(
                arcCenter: CGPoint(x: arcRect.midX, y: arcRect.midY),
                radius: arcRect.width / 2,
                startAngle: startAngle + gap / 2,
                endAngle: startAngle + gap / 2 + drawSweep,
                clockwise: true
            )
            path.lineWidth = strokeWidth
            path.lineCapStyle = .butt
            (segmentColors[safe: index] ?? AppColors.border).setStroke()
            path.stroke()
            startAngle += sweep
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
