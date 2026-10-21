import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    setupAccessibilityChannel()
    setupPermissionsChannel()
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func setupAccessibilityChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    let channel = FlutterMethodChannel(
      name: "com.pillpal.app/accessibility",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "isReduceTransparencyEnabled":
        result(UIAccessibility.isReduceTransparencyEnabled)
      case "isIncreaseContrastEnabled":
        result(UIAccessibility.isDarkerSystemColorsEnabled)
      case "isReduceMotionEnabled":
        result(UIAccessibility.isReduceMotionEnabled)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setupPermissionsChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    let channel = FlutterMethodChannel(
      name: "com.cmps420.pillpal/permissions",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "requestCamera", "requestCameraPermission":
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
          result(true)
        } else if status == .notDetermined {
          AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
              result(granted)
            }
          }
        } else {
          result(false)
        }
      case "checkCamera", "getCameraPermissionStatus":
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
          result("granted")
        case .denied, .restricted:
          result("denied")
        case .notDetermined:
          result("notDetermined")
        @unknown default:
          result("notDetermined")
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
