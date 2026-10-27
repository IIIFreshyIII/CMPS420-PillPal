import ActivityKit
import AppIntents
import Foundation

@available(iOS 16.1, *)
public enum LiveReminderIntentBridge {
  public static let actionNotification = Notification.Name("com.pillpal.app.liveReminderAction")
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
          profileName: currentState.profileName
        )
        await activity.update(using: updatedState)
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
    self.durationSeconds = 540
  }

  public init(batchId: String, durationSeconds: Double = 540) {
    self.batchId = batchId
    self.durationSeconds = durationSeconds
  }

  public func perform() async throws -> some IntentResult {
    let targetBatchId = batchId
    let requestedDuration = durationSeconds > 0 ? durationSeconds : 540
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
          profileName: currentState.profileName
        )
        await activity.update(using: updatedState)
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
