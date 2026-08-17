import Flutter
import UIKit
import UserNotifications

class SceneDelegate: FlutterSceneDelegate {

  // Sahne one gelince bildirim rozetini temizle — scene tabanli yasam
  // dongusunde AppDelegate.applicationDidBecomeActive cagrilmadigi icin
  // rozet sifirlama BURADA yapilmali
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(0)
    } else {
      UIApplication.shared.applicationIconBadgeNumber = 0
    }
  }
}
