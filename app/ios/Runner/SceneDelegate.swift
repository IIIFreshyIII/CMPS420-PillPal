import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
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
