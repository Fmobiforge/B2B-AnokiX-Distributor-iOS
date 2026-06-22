import UIKit

/// Modal crop editor for the company logo — mirrors Android `dialog_crop_logo.xml`.
final class LogoCropViewController: UIViewController {

    var onConfirm: ((UIImage) -> Void)?
    var onUploadNew: (() -> Void)?

    private let sourceImage: UIImage
    private let cropView = LogoCropView()
    private let scaleSlider = UISlider()
    private let rotationSlider = UISlider()

    init(image: UIImage) {
        sourceImage = image
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.surface
        buildUI()
        cropView.setImage(sourceImage)
    }

    private func buildUI() {
        let titleRow = UIStackView.horizontal(spacing: 8, alignment: .center)
        let title = UILabel.make(S.cropCompanyLogo, font: AppFonts.bold(16), color: AppColors.textPrimary)
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark"), for: .normal)
        close.tintColor = AppColors.textSecondary
        close.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        titleRow.addArrangedSubview(title)
        titleRow.addArrangedSubview(close)

        cropView.forAutoLayout()
        cropView.heightAnchor.constraint(equalToConstant: 260).isActive = true

        let dragHint = UILabel.make(S.cropDragHint, font: AppFonts.regular(12),
                                    color: AppColors.textSecondary, align: .center)

        configureSlider(scaleSlider, value: 50, maximum: 200)
        scaleSlider.addTarget(self, action: #selector(scaleChanged), for: .valueChanged)

        configureSlider(rotationSlider, value: 0, maximum: 360)
        rotationSlider.addTarget(self, action: #selector(rotationChanged), for: .valueChanged)

        let uploadNew = UIButton(type: .system)
        StyleKit.styleOutlinedButton(uploadNew)
        uploadNew.setTitle(S.cropUploadNew, for: .normal)
        uploadNew.constrainHeight(48)
        uploadNew.addTarget(self, action: #selector(uploadNewTapped), for: .touchUpInside)

        let cancel = UIButton(type: .system)
        StyleKit.styleOutlinedButton(cancel)
        cancel.setTitle(S.cancel, for: .normal)
        cancel.configuration?.baseForegroundColor = AppColors.textPrimary
        cancel.constrainHeight(44)
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let ok = GradientButton(title: S.ok)
        ok.constrainHeight(44)
        ok.widthAnchor.constraint(greaterThanOrEqualToConstant: 90).isActive = true
        ok.addTarget(self, action: #selector(okTapped), for: .touchUpInside)

        let actions = UIStackView.horizontal(spacing: 12, alignment: .center)
        actions.addArrangedSubview(UIView())
        actions.addArrangedSubview(cancel)
        actions.addArrangedSubview(ok)

        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.addArrangedSubview(titleRow)
        stack.addArrangedSubview(cropView)
        stack.addArrangedSubview(dragHint)
        stack.addArrangedSubview(label(S.cropScale))
        stack.addArrangedSubview(scaleSlider)
        stack.addArrangedSubview(label(S.cropRotation))
        stack.addArrangedSubview(rotationSlider)
        stack.addArrangedSubview(uploadNew)
        stack.addArrangedSubview(actions)

        stack.forAutoLayout()
        view.addSubview(stack)
        stack.pinEdges(to: view)
    }

    private func label(_ text: String) -> UILabel {
        UILabel.make(text, font: AppFonts.regular(14), color: AppColors.textPrimary)
    }

    private func configureSlider(_ slider: UISlider, value: Float, maximum: Float) {
        slider.minimumValue = 0
        slider.maximumValue = maximum
        slider.value = value
        slider.minimumTrackTintColor = AppColors.purplePrimary
    }

    @objc private func scaleChanged() {
        cropView.setUserScale(0.5 + CGFloat(scaleSlider.value) / 100)
    }

    @objc private func rotationChanged() {
        cropView.setRotationDegrees(CGFloat(rotationSlider.value))
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func uploadNewTapped() {
        dismiss(animated: true) { [weak self] in self?.onUploadNew?() }
    }

    @objc private func okTapped() {
        guard let cropped = cropView.croppedImage() else { return }
        dismiss(animated: true) { [weak self] in self?.onConfirm?(cropped) }
    }
}
