import ActivityKit
import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var liveRemindersChannel: FlutterMethodChannel?
  private var intentObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      registerChannels(with: controller.binaryMessenger)
    }
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
    }
  }

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

    let state = MedicationLiveActivityAttributes.ContentState(
      snoozeEndTime: snoozeEndTime,
      totalDurationSeconds: totalDurationSeconds,
      remainingDoseCount: remainingDoseCount,
      profileName: effectiveProfileName
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
        await existing.update(using: state)
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
        let activity = try Activity<MedicationLiveActivityAttributes>.request(
          attributes: attributes,
          contentState: state,
          pushType: nil
        )
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
            profileName: effectiveProfile
          )
          await activity.update(using: updated)
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
}
