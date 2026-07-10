import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  // Capture-protection spec 2026-07-10: wrapping the window's layer inside a
  // secure UITextField layer makes system screenshots and screen recordings
  // capture a blank frame (the standard banking/OTT technique). Debug builds
  // stay capturable for QA. Re-verify on every major iOS release: this rides
  // on unofficial-but-stable UIKit behavior.
  private let secureField = UITextField()
  private var secured = false

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    #if !DEBUG
    guard !secured, let window else { return }
    secured = true
    makeSecure(window)
    #endif
  }

  private func makeSecure(_ window: UIWindow) {
    secureField.isSecureTextEntry = true
    window.addSubview(secureField)
    window.layer.superlayer?.addSublayer(secureField.layer)
    if #available(iOS 17.0, *) {
      secureField.layer.sublayers?.last?.addSublayer(window.layer)
    } else {
      secureField.layer.sublayers?.first?.addSublayer(window.layer)
    }
  }
}
