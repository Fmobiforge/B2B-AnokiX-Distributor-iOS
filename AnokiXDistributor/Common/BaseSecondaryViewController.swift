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
}
