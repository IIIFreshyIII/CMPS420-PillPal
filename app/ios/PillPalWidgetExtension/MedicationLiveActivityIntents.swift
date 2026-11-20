import Foundation

@available(iOS 16.1, *)
public enum LiveReminderIntentBridge {
  public static let actionNotification = Notification.Name("com.pillpal.app.liveReminderAction")
}

#if canImport(ActivityKit) && canImport(AppIntents)
import ActivityKit
import AppIntents
import UserNotifications

/// Matches Dart's `notificationIdForSnooze` (32-bit FNV-1a over `"snooze_slot\0<batchId>"`)
/// so `CancelSnoozeLiveActivityIntent` can remove the pending local notification
/// directly from `UNUserNotificationCenter` even if Flutter is suspended.
private func snoozeNotificationIdentifier(forBatchId batchId: String) -> String {
  let combined = "snooze_slot\u{0000}\(batchId)"
  var hash: UInt32 = 0x811c9dc5
  for codeUnit in combined.utf16 {
    hash ^= UInt32(codeUnit)
    hash = hash &* 0x01000193
  }
  return String(Int(hash & 0x7FFFFFFF))
}

@available(iOS 16.1, *)
public struct RequestCancelSnoozeLiveActivityIntent: LiveActivityIntent {
  public static var title: LocalizedStringResource = "Request Cancel Snooze"
  public static var description = IntentDescription("Asks for inline confirmation before cancelling an active snooze countdown.")
  public static var openAppWhenRun: Bool = false

  @Parameter(title: "Batch ID")
  public var batchId: String

  public init() {
    self.batchId = ""
  }

  public init(batchId: String) {
    self.batchId = batchId
  }

  public func perform() async throws -> some IntentResult {
    let targetBatchId = batchId
    let now = Date()

    for activity in Activity<MedicationLiveActivityAttributes>.activities
    where targetBatchId.isEmpty || activity.attributes.batchId == targetBatchId {
      let currentState = activity.contentState
      let updatedState = MedicationLiveActivityAttributes.ContentState(
        snoozeEndTime: currentState.snoozeEndTime,
        totalDurationSeconds: currentState.totalDurationSeconds,
        remainingDoseCount: currentState.remainingDoseCount,
        profileName: currentState.profileName,
        snoozeNotificationId: currentState.snoozeNotificationId,
        pendingCancelConfirmation: true
      )
      if #available(iOS 16.2, *) {
        let staleDate: Date? = currentState.snoozeEndTime > now ? currentState.snoozeEndTime : nil
        await activity.update(ActivityContent(state: updatedState, staleDate: staleDate))
      } else {
        await activity.update(using: updatedState)
      }
    }

    return .result()
  }
}

@available(iOS 16.1, *)
public struct KeepSnoozeLiveActivityIntent: LiveActivityIntent {
  public static var title: LocalizedStringResource = "Keep Snooze"
  public static var description = IntentDescription("Keeps the active snooze countdown running and clears cancel confirmation.")
  public static var openAppWhenRun: Bool = false

  @Parameter(title: "Batch ID")
  public var batchId: String

  public init() {
    self.batchId = ""
  }

  public init(batchId: String) {
    self.batchId = batchId
  }

  public func perform() async throws -> some IntentResult {
    let targetBatchId = batchId
    let now = Date()

    for activity in Activity<MedicationLiveActivityAttributes>.activities
    where targetBatchId.isEmpty || activity.attributes.batchId == targetBatchId {
      let currentState = activity.contentState
      let updatedState = MedicationLiveActivityAttributes.ContentState(
        snoozeEndTime: currentState.snoozeEndTime,
        totalDurationSeconds: currentState.totalDurationSeconds,
        remainingDoseCount: currentState.remainingDoseCount,
        profileName: currentState.profileName,
        snoozeNotificationId: currentState.snoozeNotificationId,
        pendingCancelConfirmation: false
      )
      if #available(iOS 16.2, *) {
        let staleDate: Date? = currentState.snoozeEndTime > now ? currentState.snoozeEndTime : nil
        await activity.update(ActivityContent(state: updatedState, staleDate: staleDate))
      } else {
        await activity.update(using: updatedState)
      }
    }

    return .result()
  }
}

@available(iOS 16.1, *)
public struct CancelSnoozeLiveActivityIntent: LiveActivityIntent {
  public static var title: LocalizedStringResource = "Cancel Snooze"
  public static var description = IntentDescription("Cancels the active snooze timer, removes its pending snooze alert, and dismisses the Live Activity.")
  public static var openAppWhenRun: Bool = false

  @Parameter(title: "Batch ID")
  public var batchId: String

  public init() {
    self.batchId = ""
  }

  public init(batchId: String) {
    self.batchId = batchId
  }

  public func perform() async throws -> some IntentResult {
    let targetBatchId = batchId
    var notificationIdsToCancel: [String] = []
    if !targetBatchId.isEmpty {
      notificationIdsToCancel.append(snoozeNotificationIdentifier(forBatchId: targetBatchId))
    }

    for activity in Activity<MedicationLiveActivityAttributes>.activities
    where targetBatchId.isEmpty || activity.attributes.batchId == targetBatchId {
      if let explicitId = activity.contentState.snoozeNotificationId {
        let idStr = String(explicitId)
        if !notificationIdsToCancel.contains(idStr) {
          notificationIdsToCancel.append(idStr)
        }
      }
      let fallbackId = snoozeNotificationIdentifier(forBatchId: activity.attributes.batchId)
      if !notificationIdsToCancel.contains(fallbackId) {
        notificationIdsToCancel.append(fallbackId)
      }
      await activity.end(dismissalPolicy: .immediate)
    }

    if !notificationIdsToCancel.isEmpty {
      UNUserNotificationCenter.current().removePendingNotificationRequests(
        withIdentifiers: notificationIdsToCancel
      )
    }

    await MainActor.run {
      NotificationCenter.default.post(
        name: LiveReminderIntentBridge.actionNotification,
        object: nil,
        userInfo: [
          "action": "cancelSnooze",
          "batchId": targetBatchId,
        ]
      )
    }

    return .result()
  }
}

@available(iOS 16.1, *)
public struct LogTakenLiveActivityIntent: LiveActivityIntent {
  public static var title: LocalizedStringResource = "Log Taken"
  public static var description = IntentDescription("Logs the pending medication dose batch as taken.")
  public static var openAppWhenRun: Bool = false

  @Parameter(title: "Batch ID")
  public var batchId: String

  public init() {
    self.batchId = ""
  }

  public init(batchId: String) {
    self.batchId = batchId
  }

  public func perform() async throws -> some IntentResult {
    let targetBatchId = batchId
    var finalRemainingCount = 0

    for activity in Activity<MedicationLiveActivityAttributes>.activities
    where targetBatchId.isEmpty || activity.attributes.batchId == targetBatchId {
      let currentState = activity.contentState
      if currentState.remainingDoseCount <= 1 {
        finalRemainingCount = 0
        await activity.end(dismissalPolicy: .immediate)
      } else {
        finalRemainingCount = currentState.remainingDoseCount - 1
        let updatedState = MedicationLiveActivityAttributes.ContentState(
          snoozeEndTime: currentState.snoozeEndTime,
          totalDurationSeconds: currentState.totalDurationSeconds,
          remainingDoseCount: finalRemainingCount,
          profileName: currentState.profileName,
          snoozeNotificationId: currentState.snoozeNotificationId,
          pendingCancelConfirmation: false
        )
        if #available(iOS 16.2, *) {
          let staleDate: Date? = currentState.snoozeEndTime > Date() ? currentState.snoozeEndTime : nil
          await activity.update(ActivityContent(state: updatedState, staleDate: staleDate))
        } else {
          await activity.update(using: updatedState)
        }
      }
    }

    await MainActor.run {
      NotificationCenter.default.post(
        name: LiveReminderIntentBridge.actionNotification,
        object: nil,
        userInfo: [
          "action": "logTaken",
          "batchId": targetBatchId,
          "remainingDoseCount": finalRemainingCount,
          "remainingCount": finalRemainingCount,
        ]
      )
    }

    return .result()
  }
}

@available(iOS 16.1, *)
public struct SnoozeLiveActivityIntent: LiveActivityIntent {
  public static var title: LocalizedStringResource = "Snooze"
  public static var description = IntentDescription("Restarts the snooze countdown for this medication batch.")
  public static var openAppWhenRun: Bool = false

  @Parameter(title: "Batch ID")
  public var batchId: String

  @Parameter(title: "Duration Seconds")
  public var durationSeconds: Double

  public init() {
    self.batchId = ""
    self.durationSeconds = 900
  }

  public init(batchId: String, durationSeconds: Double = 900) {
    self.batchId = batchId
    self.durationSeconds = durationSeconds
  }

  public func perform() async throws -> some IntentResult {
    let targetBatchId = batchId
    let requestedDuration = durationSeconds > 0 ? durationSeconds : 900
    let now = Date()
    var hasActiveCountdown = false

    for activity in Activity<MedicationLiveActivityAttributes>.activities
    where targetBatchId.isEmpty || activity.attributes.batchId == targetBatchId {
      let currentState = activity.contentState
      // If a countdown is already running (snoozeEndTime is in the future), do not reset or alter snoozeEndTime.
      if currentState.snoozeEndTime > now {
        hasActiveCountdown = true
        // Leave the existing timer interval running undisturbed.
      } else {
        // Countdown has expired (reached zero); restart a fresh snooze interval.
        let effectiveDuration =
          currentState.totalDurationSeconds > 0 ? currentState.totalDurationSeconds : requestedDuration
        let newEndTime = now.addingTimeInterval(effectiveDuration)
        let updatedState = MedicationLiveActivityAttributes.ContentState(
          snoozeEndTime: newEndTime,
          totalDurationSeconds: effectiveDuration,
          remainingDoseCount: currentState.remainingDoseCount,
          profileName: currentState.profileName,
          snoozeNotificationId: currentState.snoozeNotificationId,
          pendingCancelConfirmation: false
        )
        if #available(iOS 16.2, *) {
          await activity.update(ActivityContent(state: updatedState, staleDate: newEndTime))
        } else {
          await activity.update(using: updatedState)
        }
      }
    }

    await MainActor.run {
      NotificationCenter.default.post(
        name: LiveReminderIntentBridge.actionNotification,
        object: nil,
        userInfo: [
          "action": "snooze",
          "batchId": targetBatchId,
          "durationSeconds": requestedDuration,
          "alreadyActive": hasActiveCountdown,
        ]
      )
    }

    return .result()
  }
}
#endif
