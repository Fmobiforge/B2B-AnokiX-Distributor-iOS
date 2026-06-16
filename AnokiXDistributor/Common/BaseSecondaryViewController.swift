import UIKit

/// Port of BaseSecondaryActivity: a purple header with back navigation, access to the
/// shared repository, and a content container the subclass fills.
class BaseSecondaryViewController: UIViewController {

    let repository = RepositoryProvider.get()
    let contentView = UIView()
    private(set) var header: AppHeaderView!

    /// Overridden by subclasses.
    var screenTitle: String { "" }
    var screenSubtitle: String? { nil }
    var trailingTitle: String? { nil }
    var trailingIcon: String? { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        hidesBottomBarWhenPushed = true
        view.backgroundColor = AppColors.background
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupHeader()
        setupContentContainer()
        setupContent(in: contentView)
        loadData()
    }

    private func setupHeader() {
        header = AppHeaderView(title: screenTitle, subtitle: screenSubtitle, leading: .back,
                               trailingTitle: trailingTitle, trailingIcon: trailingIcon)
        header.onLeading = { [weak self] in self?.navigationController?.popViewController(animated: true) }
        header.onTrailing = { [weak self] in self?.trailingTapped() }
        header.forAutoLayout()
        view.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupContentContainer() {
        contentView.forAutoLayout()
        view.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: header.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    /// White chrome block + optional divider — matches Android secondary list screens.
    func embedSecondaryListChrome(in container: UIView,
                                  chrome: UIView,
                                  listView: UIView,
                                  topInset: CGFloat = 0) -> NSLayoutConstraint {
        let divider = ListScreenLayout.hairline()
        chrome.forAutoLayout()
        divider.forAutoLayout()
        listView.forAutoLayout()
        container.addSubviews(chrome, divider, listView)
        let listTop = listView.topAnchor.constraint(equalTo: divider.bottomAnchor)
        NSLayoutConstraint.activate([
            chrome.topAnchor.constraint(equalTo: container.topAnchor, constant: topInset),
            chrome.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.topAnchor.constraint(equalTo: chrome.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            listTop,
            listView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            listView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return listTop
    }

    /// Purple header sits under the status bar — use white status bar content (Android windowLightStatusBar=false).
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
    }

    /// Subclass hooks.
    func setupContent(in container: UIView) {}
    func loadData() {}
    func trailingTapped() {}

    func toast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { alert.dismiss(animated: true) }
    }

    /// Non-blocking success banner: a green pill with a checkmark that slides in just
    /// under the header, then fades out on its own. Used for confirmations where an
    /// alert would be too heavy (e.g. returning to a list after a successful save).
    func successBanner(_ message: String) {
        let banner = UIView()
        banner.backgroundColor = AppColors.success
        banner.layer.cornerRadius = 10
        banner.layer.shadowColor = UIColor.black.cgColor
        banner.layer.shadowOpacity = 0.18
        banner.layer.shadowRadius = 6
        banner.layer.shadowOffset = CGSize(width: 0, height: 3)
        banner.forAutoLayout()

        let icon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()

        let label = UILabel.make(message, font: AppFonts.bold(14), color: .white, lines: 2)
        let row = UIStackView(arrangedSubviews: [icon, label])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        row.forAutoLayout()
        banner.addSubview(row)
        view.addSubview(banner)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),
            row.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -14),
            row.topAnchor.constraint(equalTo: banner.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -12),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            banner.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12)
        ])

        banner.alpha = 0
        banner.transform = CGAffineTransform(translationX: 0, y: -16)
        UIView.animate(withDuration: 0.3) {
            banner.alpha = 1
            banner.transform = .identity
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            UIView.animate(withDuration: 0.3, animations: {
                banner.alpha = 0
                banner.transform = CGAffineTransform(translationX: 0, y: -16)
            }, completion: { _ in banner.removeFromSuperview() })
        }
    }
}
