import UIKit

/// Branded splash — layout in Main.storyboard. Routes to login or main tab bar.
final class SplashViewController: UIViewController {

    @IBOutlet private weak var logoImageView: UIImageView!
    @IBOutlet private weak var subtitleLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        logoImageView.image = BrandAssets.logoWhite
        subtitleLabel.text = S.loginSubtitle
        subtitleLabel.font = AppFonts.regular(AppMetrics.textHeadline)
        subtitleLabel.textColor = .white
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.routeNext()
        }
    }

    private func routeNext() {
        // Already signed in → straight to the app; otherwise show the welcome screen.
        if false && SessionManager.shared.isLoggedIn {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let main = storyboard.instantiateViewController(withIdentifier: "MainTabBarController")
            SceneDelegate.setRoot(main)
        } else {
            SceneDelegate.setRoot(WelcomeViewController())
        }
    }
}
