import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
public struct PillPalLiveActivityWidget: Widget {
  public init() {}

  private func expandedDoseBadgeText(_ state: MedicationLiveActivityAttributes.ContentState) -> String {
    let countText = state.remainingDoseCount == 1 ? "1 Left" : "\(state.remainingDoseCount) Left"
    if let name = state.profileName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
      return "\(name) • \(countText)"
    }
    return countText
  }

  public var body: some WidgetConfiguration {
    ActivityConfiguration(for: MedicationLiveActivityAttributes.self) { context in
      MedicationLockScreenLiveActivityView(
        batchId: context.attributes.batchId,
        state: context.state
      )
      .activityBackgroundTint(Color(red: 0.07, green: 0.13, blue: 0.16))
      .activitySystemActionForegroundColor(.white)
      .widgetURL(URL(string: "pillpal://schedule"))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.bottom) {
          VStack(spacing: 12) {
            // Row 1: Countdown clock (with circular ring to its left) on the left, "X Left" badge on the right
            HStack(alignment: .center) {
              HStack(alignment: .center, spacing: 10) {
                // Circular clock countdown visual right next to the countdown clock (to its left)
                ZStack {
                  Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 3.5)
                    .frame(width: 34, height: 34)

                  ProgressView(
                    timerInterval: context.state.timerRange,
                    countsDown: true
                  ) {
                    EmptyView()
                  } currentValueLabel: {
                    EmptyView()
                  }
                  .progressViewStyle(.circular)
                  .tint(Color(red: 0.18, green: 0.83, blue: 0.75))
                  .frame(width: 34, height: 34)
                }

                // Numerical clock countdown + subtitle
                VStack(alignment: .leading, spacing: 1) {
                  Text(
                    timerInterval: context.state.timerRange,
                    countsDown: true
                  )
                  .font(.system(size: 30, weight: .bold, design: .rounded))
                  .monospacedDigit()
                  .minimumScaleFactor(0.85)
                  .lineLimit(1)
                  .foregroundColor(Color(red: 0.18, green: 0.83, blue: 0.75))

                  Text("Snooze Countdown")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
                    .lineLimit(1)
                }
              }

              Spacer()

              // "X Left" badge: enlarged, aligned in row with the countdown, right-centered
              Text(expandedDoseBadgeText(context.state))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                  Capsule()
                    .fill(Color(red: 0.91, green: 0.27, blue: 0.30).opacity(0.92))
                )
                .overlay(
                  Capsule()
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.8)
                )
                .fixedSize(horizontal: true, vertical: true)
            }
            .padding(.horizontal, 10)

            // Row 2: Action buttons scaled so outer edges are even with inner edges & gap
            LiveActivityActionButtonsRow(
              batchId: context.attributes.batchId,
              totalDurationSeconds: context.state.totalDurationSeconds
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
          }
        }
      } compactLeading: {
        // Leading compact: Clean circular ring indicator draining counter-clockwise
        ProgressView(
          timerInterval: context.state.timerRange,
          countsDown: true
        ) {
          EmptyView()
        } currentValueLabel: {
          EmptyView()
        }
        .progressViewStyle(.circular)
        .tint(Color(red: 0.18, green: 0.83, blue: 0.75))
        .frame(width: 18, height: 18)
      } compactTrailing: {
        // Trailing compact: Remaining doses count badge
        Text("\(context.state.remainingDoseCount)")
          .font(.system(size: 11, weight: .heavy, design: .rounded))
          .monospacedDigit()
          .foregroundColor(.white)
          .lineLimit(1)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(
            Capsule()
              .fill(Color(red: 0.91, green: 0.27, blue: 0.30).opacity(0.90))
          )
          .overlay(
            Capsule()
              .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.8)
          )
          .fixedSize(horizontal: true, vertical: true)
      } minimal: {
        // Minimal: Clean circular ring indicator draining counter-clockwise
        ProgressView(
          timerInterval: context.state.timerRange,
          countsDown: true
        ) {
          EmptyView()
        } currentValueLabel: {
          EmptyView()
        }
        .progressViewStyle(.circular)
        .tint(Color(red: 0.18, green: 0.83, blue: 0.75))
        .frame(width: 18, height: 18)
      }
      .keylineTint(Color(red: 0.18, green: 0.83, blue: 0.75))
      .widgetURL(URL(string: "pillpal://schedule"))
    }
  }
}

@available(iOS 16.1, *)
private struct MedicationLockScreenLiveActivityView: View {
  let batchId: String
  let state: MedicationLiveActivityAttributes.ContentState

  private var contextLabel: String {
    let hour = Calendar.current.component(.hour, from: Date())
    if hour >= 5 && hour < 12 {
      return "Morning Routine"
    } else if hour >= 12 && hour < 17 {
      return "Afternoon Routine"
    } else if hour >= 17 && hour < 22 {
      return "Evening Routine"
    } else {
      return "Scheduled slot"
    }
  }

  private var lockScreenBadgeText: String {
    let countText = state.remainingDoseCount == 1 ? "1 Left" : "\(state.remainingDoseCount) Left"
    if let name = state.profileName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
      return "\(name) • \(countText)"
    }
    return state.remainingDoseCount == 1 ? "1 dose left" : "\(state.remainingDoseCount) doses left"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      // Header: App identity + top-right red badge ("X doses left" or "Name • X Left")
      HStack(alignment: .center) {
        HStack(spacing: 8) {
          ZStack {
            Circle()
              .fill(Color(red: 0.18, green: 0.83, blue: 0.75).opacity(0.18))
              .frame(width: 28, height: 28)
            Image(systemName: "pills.fill")
              .font(.system(size: 13, weight: .bold))
              .foregroundColor(Color(red: 0.18, green: 0.83, blue: 0.75))
          }

          Text("PillPal Snooze")
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(.white)
        }

        Spacer()

        Text(lockScreenBadgeText)
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundColor(.white)
          .lineLimit(1)
          .padding(.horizontal, 9)
          .padding(.vertical, 4)
          .background(
            Capsule()
              .fill(Color(red: 0.91, green: 0.27, blue: 0.30).opacity(0.90))
          )
          .overlay(
            Capsule()
              .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.8)
          )
          .fixedSize(horizontal: true, vertical: true)
      }

      // Middle: Clean progress ring + large countdown + clean context label ("Morning Routine" / "Scheduled slot")
      HStack(alignment: .center, spacing: 14) {
        ZStack {
          Circle()
            .stroke(Color.white.opacity(0.08), lineWidth: 4)
            .frame(width: 44, height: 44)

          ProgressView(
            timerInterval: state.timerRange,
            countsDown: true
          ) {
            EmptyView()
          } currentValueLabel: {
            EmptyView()
          }
          .progressViewStyle(.circular)
          .tint(Color(red: 0.18, green: 0.83, blue: 0.75))
          .frame(width: 44, height: 44)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(
            timerInterval: state.timerRange,
            countsDown: true
          )
          .font(.system(size: 32, weight: .bold, design: .rounded))
          .monospacedDigit()
          .minimumScaleFactor(0.85)
          .lineLimit(1)
          .foregroundColor(.white)

          Text(contextLabel)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.65))
        }

        Spacer()
      }
      .padding(.vertical, 2)
    }
    .padding(16)
    .widgetURL(URL(string: "pillpal://schedule"))
  }
}

@available(iOS 16.1, *)
private struct LiveActivityActionButtonsRow: View {
  let batchId: String
  let totalDurationSeconds: Double

  var body: some View {
    HStack(spacing: 10) {
      if #available(iOS 17.0, *) {
        Button(intent: LogTakenLiveActivityIntent(batchId: batchId)) {
          Label("Log Taken", systemImage: "checkmark.circle.fill")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
        }
        .buttonStyle(.plain)
        .foregroundColor(Color(red: 0.04, green: 0.16, blue: 0.17))
        .background(
          Capsule()
            .fill(Color(red: 0.18, green: 0.83, blue: 0.75))
        )

        Button(
          intent: SnoozeLiveActivityIntent(
            batchId: batchId,
            durationSeconds: totalDurationSeconds
          )
        ) {
          Label("Snooze", systemImage: "zzz")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
        }
        .buttonStyle(.plain)
        .foregroundColor(.white)
        .background(
          Capsule()
            .fill(Color.white.opacity(0.18))
        )
        .overlay(
          Capsule()
            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.8)
        )
      } else {
        Link(destination: URL(string: "pillpal://live_reminder/logTaken?batchId=\(batchId)")!) {
          Label("Log Taken", systemImage: "checkmark.circle.fill")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .foregroundColor(Color(red: 0.04, green: 0.16, blue: 0.17))
            .background(
              Capsule()
                .fill(Color(red: 0.18, green: 0.83, blue: 0.75))
            )
        }

        Link(destination: URL(string: "pillpal://live_reminder/snooze?batchId=\(batchId)")!) {
          Label("Snooze", systemImage: "zzz")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .lineLimit(1)
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
        }
      }
    }
  }
}
