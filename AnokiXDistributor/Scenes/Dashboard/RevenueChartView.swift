import UIKit

/// Revenue Overview chart — a smooth gradient area curve with a labelled Y axis
/// (compact-currency gridlines anchored at 0) and X axis (date labels). Parity with
/// the Android LineChartView; used only by the dashboard revenue card.
final class RevenueChartView: UIView {
    var values: [Double] = [] { didSet { setNeedsDisplay() } }
    var labels: [String] = [] { didSet { setNeedsDisplay() } }
    var currencySymbol = "R" { didSet { setNeedsDisplay() } }
    /// Portal: revenue series is violet with a fading fill.
    var lineColor: UIColor = AppColors.chartViolet

    private let axisColor = AppColors.textTertiary
    private let gridColor = AppColors.borderLight

    override func draw(_ rect: CGRect) {
        guard values.count > 1, let ctx = UIGraphicsGetCurrentContext() else { return }

        let leftPad: CGFloat = 40
        let bottomPad: CGFloat = labels.isEmpty ? 10 : 20
        let topPad: CGFloat = 10
        let rightPad: CGFloat = 8

        let chartLeft = leftPad
        let chartRight = rect.width - rightPad
        let chartTop = topPad
        let chartBottom = rect.height - bottomPad
        let chartW = chartRight - chartLeft
        let chartH = chartBottom - chartTop

        let dataMax = values.max() ?? 0
        let step = Self.niceStep(dataMax)
        let niceMax = step <= 0 ? 1 : ceil(dataMax / step) * step

        // Y gridlines + labels.
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: AppFonts.regular(9), .foregroundColor: axisColor
        ]
        gridColor.setStroke()
        var tick: Double = 0
        while tick <= niceMax + 0.5 {
            let norm = niceMax == 0 ? 0 : CGFloat(tick / niceMax)
            let y = chartBottom - norm * chartH
            let grid = UIBezierPath()
            grid.move(to: CGPoint(x: chartLeft, y: y))
            grid.addLine(to: CGPoint(x: chartRight, y: y))
            grid.lineWidth = 1
            grid.setLineDash([3, 3], count: 2, phase: 0)
            grid.stroke()

            let text = compact(tick) as NSString
            let size = text.size(withAttributes: labelAttrs)
            text.draw(at: CGPoint(x: chartLeft - 6 - size.width, y: y - size.height / 2), withAttributes: labelAttrs)
            tick += step
        }

        let n = values.count
        let stepX = chartW / CGFloat(n - 1)
        var xs = [CGFloat](), ys = [CGFloat]()
        for (i, v) in values.enumerated() {
            xs.append(chartLeft + stepX * CGFloat(i))
            let norm = niceMax == 0 ? 0 : CGFloat(v / niceMax)
            ys.append(chartBottom - norm * chartH)
        }

        // Smooth curve.
        let line = UIBezierPath()
        line.move(to: CGPoint(x: xs[0], y: ys[0]))
        for i in 1..<n {
            let midX = (xs[i - 1] + xs[i]) / 2
            line.addCurve(to: CGPoint(x: xs[i], y: ys[i]),
                          controlPoint1: CGPoint(x: midX, y: ys[i - 1]),
                          controlPoint2: CGPoint(x: midX, y: ys[i]))
        }

        // Gradient fill under the curve.
        let fill = line.copy() as! UIBezierPath
        fill.addLine(to: CGPoint(x: xs[n - 1], y: chartBottom))
        fill.addLine(to: CGPoint(x: xs[0], y: chartBottom))
        fill.close()
        ctx.saveGState()
        fill.addClip()
        let colors = [lineColor.withAlphaComponent(0.28).cgColor, lineColor.withAlphaComponent(0.0).cgColor]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: chartTop),
                                   end: CGPoint(x: 0, y: chartBottom), options: [])
        }
        ctx.restoreGState()

        lineColor.setStroke()
        line.lineWidth = 2.5
        line.lineJoinStyle = .round
        line.stroke()

        // Point markers.
        for i in 0..<n {
            let dot = UIBezierPath(arcCenter: CGPoint(x: xs[i], y: ys[i]), radius: 4,
                                   startAngle: 0, endAngle: .pi * 2, clockwise: true)
            lineColor.setFill(); dot.fill()
            let core = UIBezierPath(arcCenter: CGPoint(x: xs[i], y: ys[i]), radius: 2,
                                    startAngle: 0, endAngle: .pi * 2, clockwise: true)
            UIColor.white.setFill(); core.fill()
        }

        // X labels under each point (thinned to avoid overlap).
        guard !labels.isEmpty else { return }
        let count = min(labels.count, n)
        let skip = max(1, Int(ceil(Double(count) / Double(max(1, Int(chartW / 34))))))
        for i in 0..<count where i % skip == 0 || i == count - 1 {
            let text = labels[i] as NSString
            let size = text.size(withAttributes: labelAttrs)
            var x = xs[i] - size.width / 2
            x = max(chartLeft, min(chartRight - size.width, x))
            text.draw(at: CGPoint(x: x, y: rect.height - size.height), withAttributes: labelAttrs)
        }
    }

    // MARK: - Nice axis maths (mirrors Android LineChartView)

    /// A gridline step (1/2/5 × 10ⁿ) sized so the axis shows ~5 rounded lines.
    private static func niceStep(_ dataMax: Double) -> Double {
        guard dataMax > 0 else { return 1 }
        return niceNum(dataMax / 5, round: true)
    }

    /// Nearest "nice" number (1/2/5 × 10ⁿ) to `value`; rounds up when `round` is false.
    private static func niceNum(_ value: Double, round: Bool) -> Double {
        let exp = floor(log10(value))
        let base = pow(10, exp)
        let frac = value / base
        let niceFrac: Double
        if round {
            niceFrac = frac < 1.5 ? 1 : frac < 3 ? 2 : frac < 7 ? 5 : 10
        } else {
            niceFrac = frac <= 1 ? 1 : frac <= 2 ? 2 : frac <= 5 ? 5 : 10
        }
        return niceFrac * base
    }

    private func compact(_ value: Double) -> String {
        let abs = Swift.abs(value)
        if abs >= 1_000_000 { return trim(value / 1_000_000, "M") }
        if abs >= 1_000 { return trim(value / 1_000, "K") }
        return "\(currencySymbol)\(Int(value))"
    }

    private func trim(_ v: Double, _ suffix: String) -> String {
        if v == v.rounded() { return "\(currencySymbol)\(Int(v))\(suffix)" }
        return String(format: "%@%.1f%@", currencySymbol, v, suffix)
    }
}
