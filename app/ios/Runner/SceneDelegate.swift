import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var privacyBlurView: UIView?

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    let targetWindow = self.window ?? (scene as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) ?? (scene as? UIWindowScene)?.windows.first
    if let window = targetWindow {
      showPrivacyBlur(on: window)
    }
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    super.sceneDidEnterBackground(scene)
    let targetWindow = self.window ?? (scene as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) ?? (scene as? UIWindowScene)?.windows.first
    if let window = targetWindow {
      showPrivacyBlur(on: window)
    }
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    hidePrivacyBlur()
  }

  private func showPrivacyBlur(on window: UIWindow) {
    guard privacyBlurView == nil else { return }

    let container = UIView(frame: window.bounds)
    container.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    let blurEffect = UIBlurEffect(style: .systemMaterial)
    let blurEffectView = UIVisualEffectView(effect: blurEffect)
    blurEffectView.frame = container.bounds
    blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    container.addSubview(blurEffectView)

    // Center icon for a polished privacy card in the app switcher
    let iconView = UIImageView()
    if #available(iOS 16.0, *), let pillImage = UIImage(systemName: "pills.fill") {
      iconView.image = pillImage
    } else {
      iconView.image = UIImage(systemName: "cross.fill")
    }
    iconView.tintColor = UIColor(red: 0.08, green: 0.44, blue: 0.45, alpha: 0.45)
    iconView.contentMode = .scaleAspectFit
    iconView.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(iconView)

    NSLayoutConstraint.activate([
      iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      iconView.widthAnchor.constraint(equalToConstant: 54),
      iconView.heightAnchor.constraint(equalToConstant: 54),
    ])

    window.addSubview(container)
    window.bringSubviewToFront(container)
    self.privacyBlurView = container
  }

  private func hidePrivacyBlur() {
    guard let blurView = privacyBlurView else { return }
    UIView.animate(
      withDuration: 0.22,
      delay: 0,
      options: [.curveEaseOut, .beginFromCurrentState],
      animations: {
        blurView.alpha = 0
      },
      completion: { [weak self] _ in
        blurView.removeFromSuperview()
        self?.privacyBlurView = nil
      }
    )
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    guard #available(iOS 16.1, *) else { return }

    for context in URLContexts {
      let url = context.url
      guard url.scheme == "pillpal" else { continue }

      if url.host == "schedule" {
        NotificationCenter.default.post(
          name: LiveReminderIntentBridge.actionNotification,
          object: nil,
          userInfo: [
            "action": "openSchedule",
            "batchId": "",
          ]
        )
      } else if url.host == "live_reminder" {
        let action = url.lastPathComponent
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let batchId =
          components?.queryItems?.first(where: { $0.name == "batchId" })?.value ?? ""

        NotificationCenter.default.post(
          name: LiveReminderIntentBridge.actionNotification,
          object: nil,
          userInfo: [
            "action": action,
            "batchId": batchId,
          ]
        )
      }
    }
  }
}
