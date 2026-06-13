import UIKit

/// Lightweight line chart for the revenue overview — a slimmed port of LineChartView.
final class SparklineView: UIView {
    var values: [Double] = [] { didSet { setNeedsDisplay() } }
    var lineColor: UIColor = AppColors.purplePrimary

    override func draw(_ rect: CGRect) {
        guard values.count > 1,
              let context = UIGraphicsGetCurrentContext() else { return }
        let maxV = values.max() ?? 1
        let minV = values.min() ?? 0
        let range = max(maxV - minV, 0.0001)
        let stepX = rect.width / CGFloat(values.count - 1)

        let path = UIBezierPath()
        for (i, v) in values.enumerated() {
            let x = CGFloat(i) * stepX
            let y = rect.height - CGFloat((v - minV) / range) * (rect.height - 8) - 4
            let point = CGPoint(x: x, y: y)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }

        // Gradient fill under the line
        let fill = path.copy() as! UIBezierPath
        fill.addLine(to: CGPoint(x: rect.width, y: rect.height))
        fill.addLine(to: CGPoint(x: 0, y: rect.height))
        fill.close()
        context.saveGState()
        fill.addClip()
        let colors = [lineColor.withAlphaComponent(0.25).cgColor, lineColor.withAlphaComponent(0.0).cgColor]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: rect.height), options: [])
        }
        context.restoreGState()

        lineColor.setStroke()
        path.lineWidth = 2
        path.lineJoinStyle = .round
        path.stroke()
    }
}
