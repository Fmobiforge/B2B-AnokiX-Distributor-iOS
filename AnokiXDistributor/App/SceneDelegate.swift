import UIKit

/// Mirrors the Android launcher: Main.storyboard initial scene is SplashViewController.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        window = windowScene.windows.first
    }

    static func setRoot(_ viewController: UIViewController, animated: Bool = true) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }

        let window = windowScene.windows.first { $0.isKeyWindow } ?? windowScene.windows.first
        guard let window = window else { return }

        if animated {
            UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve, animations: {
                window.rootViewController = viewController
            })
        } else {
            window.rootViewController = viewController
        }
    }
}
