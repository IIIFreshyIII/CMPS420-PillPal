#if canImport(ActivityKit)
import ActivityKit
#endif
import AVFoundation
import Flutter
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var liveRemindersChannel: FlutterMethodChannel?
  private var intentObserver: NSObjectProtocol?
  private var activePhotoPickerDelegate: Any?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    observeLiveActivityIntents()
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerChannels(with: engineBridge.applicationRegistrar.messenger())
  }

  private func registerChannels(with messenger: FlutterBinaryMessenger) {
    setupAccessibilityChannel(messenger: messenger)
    setupPermissionsChannel(messenger: messenger)
    setupLiveRemindersChannel(messenger: messenger)
    setupPhotoPickerChannel(messenger: messenger)
    setupBadgeChannel(messenger: messenger)
  }

  private func setupBadgeChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.pillpal.app/badge",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard call.method == "setBadgeCount" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any]
      let count = max(0, (args?["count"] as? NSNumber)?.intValue ?? 0)
      DispatchQueue.main.async {
        if #available(iOS 16.0, *) {
          UNUserNotificationCenter.current().setBadgeCount(count) { error in
            if let error = error {
              result(FlutterError(code: "BADGE_ERROR", message: error.localizedDescription, details: nil))
            } else {
              result(nil)
            }
          }
        } else {
          UIApplication.shared.applicationIconBadgeNumber = count
          result(nil)
        }
      }
    }
  }

  private func observeLiveActivityIntents() {
    guard intentObserver == nil else { return }
    if #available(iOS 16.1, *) {
      intentObserver = NotificationCenter.default.addObserver(
        forName: LiveReminderIntentBridge.actionNotification,
        object: nil,
        queue: .main
      ) { [weak self] notification in
        guard
          let userInfo = notification.userInfo,
          let action = userInfo["action"] as? String
        else { return }
        let batchId = (userInfo["batchId"] as? String) ?? ""
        var payload: [String: Any] = ["batchId": batchId]
        if let duration = userInfo["durationSeconds"] as? Double {
          payload["durationSeconds"] = duration
        }
        if let remainingDoseCount = userInfo["remainingDoseCount"] as? Int {
          payload["remainingDoseCount"] = remainingDoseCount
          payload["remainingCount"] = remainingDoseCount
        } else if let remainingCount = userInfo["remainingCount"] as? Int {
          payload["remainingDoseCount"] = remainingCount
          payload["remainingCount"] = remainingCount
        }
        if let alreadyActive = userInfo["alreadyActive"] as? Bool {
          payload["alreadyActive"] = alreadyActive
        }
        self?.liveRemindersChannel?.invokeMethod(
          action,
          arguments: payload
        )
      }
    }
  }

  private func setupLiveRemindersChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.pillpal.app/live_reminders",
      binaryMessenger: messenger
    )
    self.liveRemindersChannel = channel

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else {
        result(nil)
        return
      }
      #if canImport(ActivityKit)
      guard #available(iOS 16.1, *) else {
        result(
          FlutterError(
            code: "UNSUPPORTED_IOS_VERSION",
            message: "ActivityKit requires iOS 16.1 or newer.",
            details: nil
          )
        )
        return
      }

      let args = call.arguments as? [String: Any] ?? [:]

      switch call.method {
      case "startSnoozeActivity":
        self.handleStartSnoozeActivity(args: args, result: result)
      case "updateRemainingDoses":
        self.handleUpdateRemainingDoses(args: args, result: result)
      case "dismissActivity":
        self.handleDismissActivity(args: args, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
      #else
      result(
        FlutterError(
          code: "ACTIVITYKIT_UNAVAILABLE",
          message: "ActivityKit is not supported or linked on this build configuration.",
          details: nil
        )
      )
      #endif
    }
  }

  #if canImport(ActivityKit)
  @available(iOS 16.1, *)
  private func handleStartSnoozeActivity(args: [String: Any], result: @escaping FlutterResult) {
    guard
      let batchId = args["batchId"] as? String,
      let snoozeDurationMinutes = (args["snoozeDurationMinutes"] as? NSNumber)?.intValue
    else {
      result(
        FlutterError(
          code: "INVALID_ARGUMENTS",
          message: "Missing required arguments for startSnoozeActivity.",
          details: nil
        )
      )
      return
    }

    let remainingDoseCount = (args["remainingDoseCount"] as? NSNumber)?.intValue
      ?? (args["remainingCount"] as? NSNumber)?.intValue
      ?? 1
    let totalDurationSeconds = max(Double(snoozeDurationMinutes * 60), 60.0)

    let snoozeEndTime: Date
    if let timestampMs = (args["snoozeEndTimestampMs"] as? NSNumber)?.doubleValue {
      snoozeEndTime = Date(timeIntervalSince1970: timestampMs / 1000.0)
    } else {
      snoozeEndTime = Date().addingTimeInterval(totalDurationSeconds)
    }

    let profileName = (args["profileName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let effectiveProfileName = (profileName?.isEmpty ?? true) ? nil : profileName
    let snoozeNotificationId = (args["snoozeNotificationId"] as? NSNumber)?.intValue

    let state = MedicationLiveActivityAttributes.ContentState(
      snoozeEndTime: snoozeEndTime,
      totalDurationSeconds: totalDurationSeconds,
      remainingDoseCount: remainingDoseCount,
      profileName: effectiveProfileName,
      snoozeNotificationId: snoozeNotificationId
    )

    Task {
      guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        await MainActor.run {
          result(
            FlutterError(
              code: "LIVE_ACTIVITIES_DISABLED",
              message: "Live Activities are disabled in iOS Settings.",
              details: nil
            )
          )
        }
        return
      }

      let existingActivities = Activity<MedicationLiveActivityAttributes>.activities.filter {
        $0.attributes.batchId == batchId
      }

      if let existing = existingActivities.first {
        if #available(iOS 16.2, *) {
          let content = ActivityContent(state: state, staleDate: snoozeEndTime)
          await existing.update(content)
        } else {
          await existing.update(using: state)
        }
        for duplicate in existingActivities.dropFirst() {
          await duplicate.end(dismissalPolicy: .immediate)
        }
        await MainActor.run {
          result(existing.id)
        }
        return
      }

      do {
        let attributes = MedicationLiveActivityAttributes(batchId: batchId)
        let activity: Activity<MedicationLiveActivityAttributes>
        if #available(iOS 16.2, *) {
          let content = ActivityContent(state: state, staleDate: snoozeEndTime)
          activity = try Activity<MedicationLiveActivityAttributes>.request(
            attributes: attributes,
            content: content,
            pushType: nil
          )
        } else {
          activity = try Activity<MedicationLiveActivityAttributes>.request(
            attributes: attributes,
            contentState: state,
            pushType: nil
          )
        }
        await MainActor.run {
          result(activity.id)
        }
      } catch {
        await MainActor.run {
          result(
            FlutterError(
              code: "LIVE_ACTIVITY_START_FAILED",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }

  @available(iOS 16.1, *)
  private func handleUpdateRemainingDoses(args: [String: Any], result: @escaping FlutterResult) {
    guard let batchId = args["batchId"] as? String else {
      result(
        FlutterError(
          code: "INVALID_ARGUMENTS",
          message: "Missing required arguments for updateRemainingDoses.",
          details: nil
        )
      )
      return
    }

    let remainingDoseCount = (args["remainingDoseCount"] as? NSNumber)?.intValue
      ?? (args["remainingCount"] as? NSNumber)?.intValue
      ?? 0

    let profileNameArg = (args["profileName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let effectiveProfileNameArg = (profileNameArg?.isEmpty ?? true) ? nil : profileNameArg

    Task {
      let matching = Activity<MedicationLiveActivityAttributes>.activities.filter {
        $0.attributes.batchId == batchId
      }

      for activity in matching {
        if remainingDoseCount <= 0 {
          await activity.end(dismissalPolicy: .immediate)
        } else {
          let current = activity.contentState
          let effectiveProfile = effectiveProfileNameArg ?? current.profileName
          let updated = MedicationLiveActivityAttributes.ContentState(
            snoozeEndTime: current.snoozeEndTime,
            totalDurationSeconds: current.totalDurationSeconds,
            remainingDoseCount: remainingDoseCount,
            profileName: effectiveProfile,
            snoozeNotificationId: current.snoozeNotificationId
          )
          if #available(iOS 16.2, *) {
            let staleDate: Date? = current.snoozeEndTime > Date() ? current.snoozeEndTime : nil
            await activity.update(ActivityContent(state: updated, staleDate: staleDate))
          } else {
            await activity.update(using: updated)
          }
        }
      }

      await MainActor.run {
        result(nil)
      }
    }
  }

  @available(iOS 16.1, *)
  private func handleDismissActivity(args: [String: Any], result: @escaping FlutterResult) {
    let batchId = (args["batchId"] as? String) ?? ""

    Task {
      let targets = Activity<MedicationLiveActivityAttributes>.activities.filter {
        batchId.isEmpty || $0.attributes.batchId == batchId
      }
      for activity in targets {
        await activity.end(dismissalPolicy: .immediate)
      }
      await MainActor.run {
        result(nil)
      }
    }
  }
  #endif

  private func setupAccessibilityChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.pillpal.app/accessibility",
      binaryMessenger: messenger
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

  private func setupPermissionsChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.cmps420.pillpal/permissions",
      binaryMessenger: messenger
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

  private func setupPhotoPickerChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "pillpal/zero_disk_photo_picker",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "pickImage":
        self.handlePickImage(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func handlePickImage(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        result(nil)
        return
      }
      guard self.activePhotoPickerDelegate == nil else {
        result(FlutterError(code: "BUSY", message: "A pick is already in progress", details: nil))
        return
      }

      var configuration = PHPickerConfiguration()
      configuration.filter = .images
      configuration.selectionLimit = 1

      let picker = PHPickerViewController(configuration: configuration)
      let coordinator = ZeroDiskPhotoPickerCoordinator { [weak self] (data: Data?) in
        self?.activePhotoPickerDelegate = nil
        if let data = data {
          result(FlutterStandardTypedData(bytes: data))
        } else {
          result(nil)
        }
      }

      self.activePhotoPickerDelegate = coordinator
      picker.delegate = coordinator
      picker.presentationController?.delegate = coordinator

      var rootVC = self.window?.rootViewController
      if rootVC == nil {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
          if let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
            rootVC = keyWindow.rootViewController
            if rootVC != nil { break }
          }
        }
      }

      if let rootVC = rootVC {
        var presenter: UIViewController = rootVC
        while let next = presenter.presentedViewController, !next.isBeingDismissed {
          presenter = next
        }
        presenter.present(picker, animated: true)
      } else {
        self.activePhotoPickerDelegate = nil
        result(nil)
      }
    }
  }
}

private class ZeroDiskPhotoPickerCoordinator: NSObject, PHPickerViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
  private let completion: (Data?) -> Void

  init(completion: @escaping (Data?) -> Void) {
    self.completion = completion
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    completion(nil)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)

    guard let provider = results.first?.itemProvider else {
      completion(nil)
      return
    }

    // Attempt direct in-memory load of raw image bytes (never written to disk)
    if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
      provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, error in
        if let data = data {
          DispatchQueue.main.async {
            self?.completion(data)
          }
          return
        }

        // Fallback: decode UIImage in memory and serialize to JPEG data
        self?.loadAsUIImage(provider: provider)
      }
    } else {
      loadAsUIImage(provider: provider)
    }
  }

  private func loadAsUIImage(provider: NSItemProvider) {
    if provider.canLoadObject(ofClass: UIImage.self) {
      provider.loadObject(ofClass: UIImage.self) { [weak self] (image, error) in
        DispatchQueue.main.async {
          if let uiImage = image as? UIImage,
             let jpegData = uiImage.jpegData(compressionQuality: 0.95) {
            self?.completion(jpegData)
          } else {
            self?.completion(nil)
          }
        }
      }
    } else {
      DispatchQueue.main.async {
        self.completion(nil)
      }
    }
  }
}
