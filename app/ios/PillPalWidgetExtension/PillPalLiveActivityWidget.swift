#if canImport(ActivityKit) && canImport(WidgetKit)
import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
private enum AdherenceStatusFormatter {
  static func parseBatch(_ batchId: String) -> (periodName: String, slotLabel: String?) {
    let parts = batchId.split(separator: "_")
    guard parts.count == 3,
          parts[0] == "batch",
          let hour = Int(parts[1]),
          let minute = Int(parts[2]),
          (0...23).contains(hour),
          (0...59).contains(minute) else {
      return ("Medication Routine", nil)
    }

    let totalMinutes = hour * 60 + minute
    let periodName: String
    if totalMinutes >= 5 * 60 && totalMinutes < 11 * 60 + 30 {
      periodName = "Morning"
    } else if totalMinutes >= 11 * 60 + 30 && totalMinutes < 14 * 60 {
      periodName = "Midday"
    } else if totalMinutes >= 14 * 60 && totalMinutes < 17 * 60 {
      periodName = "Afternoon"
    } else if totalMinutes >= 17 * 60 && totalMinutes < 21 * 60 {
      periodName = "Evening"
    } else {
      periodName = "Bedtime"
    }

    let displayHour = hour % 12 == 0 ? 12 : hour % 12
    let period = hour < 12 ? "AM" : "PM"
    let slotLabel = String(format: "%d:%02d %@", displayHour, minute, period)
    return (periodName, slotLabel)
  }

  static func headerLabel(forBatchId batchId: String) -> String {
    let parsed = parseBatch(batchId)
    if let slotLabel = parsed.slotLabel {
      return "\(parsed.periodName) • \(slotLabel)"
    }
    return parsed.periodName
  }

  static func doseBadgeText(_ state: MedicationLiveActivityAttributes.ContentState) -> String {
    let countText = state.remainingDoseCount == 1 ? "1 Left" : "\(state.remainingDoseCount) Left"
    if let name = state.profileName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
      return "\(name) • \(countText)"
    }
    return countText
  }

  static func isCountdownActive(
    _ state: MedicationLiveActivityAttributes.ContentState,
    isStale: Bool
  ) -> Bool {
    !isStale && state.snoozeEndTime > Date()
  }
}

@available(iOS 16.1, *)
private func isActivityContextStale(
  _ context: ActivityViewContext<MedicationLiveActivityAttributes>
) -> Bool {
  if #available(iOS 16.2, *) {
    return context.isStale
  }
  return false
}

@available(iOS 16.1, *)
public struct PillPalLiveActivityWidget: Widget {
  public init() {}

  private var tealAccent: Color {
    Color(red: 0.18, green: 0.83, blue: 0.75)
  }

  private var coralBadge: Color {
    Color(red: 0.91, green: 0.27, blue: 0.30)
  }

  public var body: some WidgetConfiguration {
    ActivityConfiguration(for: MedicationLiveActivityAttributes.self) { context in
      MedicationLockScreenLiveActivityView(
        batchId: context.attributes.batchId,
        state: context.state,
        isStale: isActivityContextStale(context)
      )
      .activityBackgroundTint(Color(red: 0.07, green: 0.13, blue: 0.16))
      .activitySystemActionForegroundColor(.white)
      .widgetURL(URL(string: "pillpal://schedule"))
    } dynamicIsland: { context in
      let stale = isActivityContextStale(context)
      let isCountingDown = AdherenceStatusFormatter.isCountdownActive(
        context.state,
        isStale: stale
      )
      return DynamicIsland {
        DynamicIslandExpandedRegion(.bottom) {
          VStack(spacing: 12) {
            LiveActivityHeaderView(
              batchId: context.attributes.batchId,
              state: context.state,
              isCountingDown: isCountingDown,
              tealAccent: tealAccent,
              coralBadge: coralBadge
            )

            LiveActivityActionButtonsRow(
              batchId: context.attributes.batchId,
              isCountingDown: isCountingDown,
              isPendingCancelConfirmation: context.state.pendingCancelConfirmation
            )
          }
          .padding(.horizontal, 12)
          .padding(.bottom, 6)
        }
      } compactLeading: {
        ZStack {
          Circle()
            .fill(tealAccent.opacity(0.20))
            .frame(width: 20, height: 20)
          Image(systemName: "pills.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(tealAccent)
        }
      } compactTrailing: {
        Text("\(context.state.remainingDoseCount)")
          .font(.system(size: 11, weight: .heavy, design: .rounded))
          .monospacedDigit()
          .foregroundColor(.white)
          .lineLimit(1)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(
            Capsule()
              .fill(coralBadge.opacity(0.90))
          )
          .overlay(
            Capsule()
              .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.8)
          )
          .fixedSize(horizontal: true, vertical: true)
      } minimal: {
        ZStack {
          Circle()
            .fill(tealAccent.opacity(0.20))
            .frame(width: 20, height: 20)
          Image(systemName: "pills.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(tealAccent)
        }
      }
      .keylineTint(tealAccent)
      .widgetURL(URL(string: "pillpal://schedule"))
    }
  }
}

@available(iOS 16.1, *)
private struct LiveActivityHeaderView: View {
  let batchId: String
  let state: MedicationLiveActivityAttributes.ContentState
  let isCountingDown: Bool
  let tealAccent: Color
  let coralBadge: Color

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      // Native circular countdown ring (unwinds counterclockwise automatically) while
      // counting down; transitions to a calm pill icon once ready to log.
      if isCountingDown {
        ZStack {
          Circle()
            .fill(tealAccent.opacity(0.12))
            .frame(width: 44, height: 44)
          ProgressView(
            timerInterval: state.timerRange,
            countsDown: true,
            label: { EmptyView() },
            currentValueLabel: { EmptyView() }
          )
          .progressViewStyle(.circular)
          .tint(tealAccent)
          .frame(width: 44, height: 44)
        }
        .fixedSize()
      } else {
        ZStack {
          Circle()
            .fill(tealAccent.opacity(0.20))
            .frame(width: 44, height: 44)
          Circle()
            .strokeBorder(tealAccent.opacity(0.65), lineWidth: 2)
            .frame(width: 44, height: 44)
          Image(systemName: "pills.fill")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(tealAccent)
        }
        .fixedSize()
      }

      // Line 1: "Morning • 8:00 AM"
      // Line 2: Large accessible countdown timer (or "Ready to log" once expired)
      VStack(alignment: .leading, spacing: 1) {
        Text(AdherenceStatusFormatter.headerLabel(forBatchId: batchId))
          .font(.system(size: 14, weight: .semibold, design: .rounded))
          .foregroundColor(.white.opacity(0.86))
          .lineLimit(1)
          .minimumScaleFactor(0.85)

        if isCountingDown {
          Text(timerInterval: state.timerRange, countsDown: true)
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(tealAccent)
            .multilineTextAlignment(.leading)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        } else {
          Text("Ready to log")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(tealAccent)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      // Trailing badge flush-aligned with the right edge of the bottom action button
      Text(AdherenceStatusFormatter.doseBadgeText(state))
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundColor(.white)
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
          Capsule()
            .fill(coralBadge.opacity(0.92))
        )
        .overlay(
          Capsule()
            .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.8)
        )
        .fixedSize(horizontal: true, vertical: true)
    }
    .frame(maxWidth: .infinity)
  }
}

@available(iOS 16.1, *)
private struct MedicationLockScreenLiveActivityView: View {
  let batchId: String
  let state: MedicationLiveActivityAttributes.ContentState
  let isStale: Bool

  private var tealAccent: Color {
    Color(red: 0.18, green: 0.83, blue: 0.75)
  }

  private var coralBadge: Color {
    Color(red: 0.91, green: 0.27, blue: 0.30)
  }

  var body: some View {
    let isCountingDown = AdherenceStatusFormatter.isCountdownActive(
      state,
      isStale: isStale
    )

    VStack(alignment: .leading, spacing: 12) {
      LiveActivityHeaderView(
        batchId: batchId,
        state: state,
        isCountingDown: isCountingDown,
        tealAccent: tealAccent,
        coralBadge: coralBadge
      )

      LiveActivityActionButtonsRow(
        batchId: batchId,
        isCountingDown: isCountingDown,
        isPendingCancelConfirmation: state.pendingCancelConfirmation
      )
    }
    .padding(16)
    .widgetURL(URL(string: "pillpal://schedule"))
  }
}

@available(iOS 16.1, *)
private struct LiveActivityActionButtonsRow: View {
  let batchId: String
  let isCountingDown: Bool
  let isPendingCancelConfirmation: Bool

  private var tealAccent: Color {
    Color(red: 0.18, green: 0.83, blue: 0.75)
  }

  private var destructiveCoral: Color {
    Color(red: 0.91, green: 0.27, blue: 0.30)
  }

  var body: some View {
    HStack(spacing: 10) {
      if #available(iOS 17.0, *), isCountingDown && isPendingCancelConfirmation {
        Button(intent: KeepSnoozeLiveActivityIntent(batchId: batchId)) {
          Label("Keep Snooze", systemImage: "arrow.uturn.backward.circle.fill")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .foregroundColor(.white)
        .background(
          Capsule()
            .fill(Color.white.opacity(0.18))
        )
        .overlay(
          Capsule()
            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.8)
        )
        .contentShape(Capsule())

        Button(intent: CancelSnoozeLiveActivityIntent(batchId: batchId)) {
          Label("Confirm Cancel", systemImage: "xmark.circle.fill")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .foregroundColor(.white)
        .background(
          Capsule()
            .fill(destructiveCoral)
        )
        .overlay(
          Capsule()
            .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8)
        )
        .contentShape(Capsule())
      } else {
        Link(destination: URL(string: "pillpal://schedule")!) {
          Label("Open to Log", systemImage: "arrow.up.forward.circle.fill")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .foregroundColor(Color(red: 0.04, green: 0.16, blue: 0.17))
            .background(
              Capsule()
                .fill(tealAccent)
            )
            .contentShape(Capsule())
        }
        .frame(maxWidth: .infinity)

        if #available(iOS 17.0, *) {
          if isCountingDown {
            Button(intent: RequestCancelSnoozeLiveActivityIntent(batchId: batchId)) {
              Label("Cancel Snooze", systemImage: "xmark.circle.fill")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .foregroundColor(.white)
            .background(
              Capsule()
                .fill(Color.white.opacity(0.18))
            )
            .overlay(
              Capsule()
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.8)
            )
            .contentShape(Capsule())
          } else {
            Button(intent: CancelSnoozeLiveActivityIntent(batchId: batchId)) {
              Label("Dismiss", systemImage: "xmark.circle.fill")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .foregroundColor(.white)
            .background(
              Capsule()
                .fill(Color.white.opacity(0.18))
            )
            .overlay(
              Capsule()
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.8)
            )
            .contentShape(Capsule())
          }
        } else {
          Link(destination: URL(string: "pillpal://live_reminder/cancelSnooze?batchId=\(batchId)")!) {
            Label(isCountingDown ? "Cancel Snooze" : "Dismiss", systemImage: "xmark.circle.fill")
              .font(.system(size: 13, weight: .bold, design: .rounded))
              .lineLimit(1)
              .minimumScaleFactor(0.85)
              .frame(maxWidth: .infinity)
              .frame(height: 38)
              .foregroundColor(.white)
              .background(
                Capsule()
                  .fill(Color.white.opacity(0.18))
              )
              .overlay(
                Capsule()
                  .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.8)
              )
              .contentShape(Capsule())
          }
          .frame(maxWidth: .infinity)
        }
      }
    }
    .frame(maxWidth: .infinity)
  }
}
#endif
