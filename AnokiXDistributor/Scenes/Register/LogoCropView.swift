import UIKit

/// Square logo cropper for the Create Account flow — mirrors Android `LogoCropView`.
/// Supports scale, rotation, and drag-to-pan; `croppedImage()` renders the centred
/// square viewport to a new bitmap for upload.
final class LogoCropView: UIView {

    private var sourceImage: UIImage?
    private var baseScale: CGFloat = 1
    private var userScale: CGFloat = 1
    private var rotationDegrees: CGFloat = 0
    private var offsetX: CGFloat = 0
    private var offsetY: CGFloat = 0

    private var lastPanLocation: CGPoint = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        backgroundColor = AppColors.textTertiary
        contentMode = .redraw
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setImage(_ image: UIImage) {
        sourceImage = image.normalizedForEditing()
        userScale = 1
        rotationDegrees = 0
        offsetX = 0
        offsetY = 0
        recomputeBaseScale()
        setNeedsDisplay()
    }

    func setUserScale(_ scale: CGFloat) {
        userScale = scale
        clampOffsets()
        setNeedsDisplay()
    }

    func setRotationDegrees(_ degrees: CGFloat) {
        rotationDegrees = degrees
        clampOffsets()
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        recomputeBaseScale()
        clampOffsets()
    }

    private var viewportSide: CGFloat {
        min(bounds.width, bounds.height)
    }

    private var sourcePixelSize: CGSize {
        guard let image = sourceImage, let cg = image.cgImage else { return .zero }
        return CGSize(width: cg.width, height: cg.height)
    }

    private func recomputeBaseScale() {
        let size = sourcePixelSize
        let side = viewportSide
        guard size.width > 0, size.height > 0, side > 0 else { return }
        baseScale = max(side / size.width, side / size.height)
        clampOffsets()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard sourceImage != nil else { return }
        switch gesture.state {
        case .began:
            lastPanLocation = gesture.location(in: self)
            gesture.cancelsTouchesInView = true
        case .changed:
            let location = gesture.location(in: self)
            offsetX += location.x - lastPanLocation.x
            offsetY += location.y - lastPanLocation.y
            clampOffsets()
            lastPanLocation = location
            setNeedsDisplay()
        default:
            break
        }
    }

    private func clampOffsets() {
        let size = sourcePixelSize
        let side = viewportSide
        guard size.width > 0, size.height > 0, side > 0 else {
            offsetX = 0
            offsetY = 0
            return
        }
        let scale = baseScale * userScale
        let halfSide = side / 2
        let hw = size.width * scale / 2
        let hh = size.height * scale / 2

        let rad = rotationDegrees * .pi / 180
        let cos = abs(cos(rad))
        let sin = abs(sin(rad))
        let boundW = hw * cos + hh * sin
        let boundH = hw * sin + hh * cos

        let maxOffsetX = max(0, boundW - halfSide)
        let maxOffsetY = max(0, boundH - halfSide)
        offsetX = min(maxOffsetX, max(-maxOffsetX, offsetX))
        offsetY = min(maxOffsetY, max(-maxOffsetY, offsetY))
    }

    override func draw(_ rect: CGRect) {
        guard let image = sourceImage, let ctx = UIGraphicsGetCurrentContext() else { return }

        let side = viewportSide
        let cropOrigin = CGPoint(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2)
        let cropRect = CGRect(origin: cropOrigin, size: CGSize(width: side, height: side))

        ctx.saveGState()
        ctx.clip(to: cropRect)
        applyTransform(to: ctx, centerX: bounds.midX, centerY: bounds.midY, outputRatio: 1)
        image.draw(in: CGRect(x: -sourcePixelSize.width / 2,
                              y: -sourcePixelSize.height / 2,
                              width: sourcePixelSize.width,
                              height: sourcePixelSize.height))
        ctx.restoreGState()

        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.35).cgColor)
        ctx.setLineWidth(1)
        ctx.stroke(cropRect)
    }

    private func applyTransform(to ctx: CGContext, centerX: CGFloat, centerY: CGFloat, outputRatio: CGFloat) {
        let scale = baseScale * userScale * outputRatio
        ctx.translateBy(x: centerX + offsetX * outputRatio, y: centerY + offsetY * outputRatio)
        ctx.rotate(by: rotationDegrees * .pi / 180)
        ctx.scaleBy(x: scale, y: scale)
    }

    func croppedImage() -> UIImage? {
        let side = viewportSide
        guard side > 0, sourceImage != nil else { return nil }

        let out = min(side, 1024)
        let ratio = out / side
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: out, height: out), format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.saveGState()
            cg.clip(to: CGRect(x: 0, y: 0, width: out, height: out))
            applyTransform(to: cg, centerX: out / 2, centerY: out / 2, outputRatio: ratio)
            sourceImage?.draw(in: CGRect(x: -sourcePixelSize.width / 2,
                                         y: -sourcePixelSize.height / 2,
                                         width: sourcePixelSize.width,
                                         height: sourcePixelSize.height))
            cg.restoreGState()
        }
    }
}

private extension UIImage {
    /// Upright pixel image so crop math matches Android's raw bitmap dimensions.
    func normalizedForEditing() -> UIImage {
        guard let cgImage = cgImage else { return self }
        if imageOrientation == .up, scale == 1 { return self }
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIImage(cgImage: cgImage, scale: 1, orientation: .up)
                .draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
