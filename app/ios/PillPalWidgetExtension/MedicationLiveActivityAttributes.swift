import ActivityKit
import Foundation

@available(iOS 16.1, *)
public struct MedicationLiveActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    public var snoozeEndTime: Date
    public var totalDurationSeconds: Double
    public var remainingDoseCount: Int
    public var profileName: String?

    public init(
      snoozeEndTime: Date,
      totalDurationSeconds: Double,
      remainingDoseCount: Int,
      profileName: String? = nil
    ) {
      self.snoozeEndTime = snoozeEndTime
      self.totalDurationSeconds = totalDurationSeconds
      self.remainingDoseCount = remainingDoseCount
      self.profileName = profileName
    }

    public init(
      snoozeEndTime: Date,
      totalDurationSeconds: Double,
      remainingCount: Int,
      profileName: String? = nil
    ) {
      self.snoozeEndTime = snoozeEndTime
      self.totalDurationSeconds = totalDurationSeconds
      self.remainingDoseCount = remainingCount
      self.profileName = profileName
    }

    /// Backwards-compatible accessor for remainingCount.
    public var remainingCount: Int {
      get { remainingDoseCount }
      set { remainingDoseCount = newValue }
    }

    public var snoozeStartTime: Date {
      let duration = max(totalDurationSeconds, 1.0)
      return snoozeEndTime.addingTimeInterval(-duration)
    }

    public var timerRange: ClosedRange<Date> {
      let start = snoozeStartTime
      let end = max(snoozeEndTime, start.addingTimeInterval(1))
      return start...end
    }

    enum CodingKeys: String, CodingKey {
      case snoozeEndTime
      case totalDurationSeconds
      case remainingDoseCount
      case remainingCount
      case profileName
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      snoozeEndTime = try container.decode(Date.self, forKey: .snoozeEndTime)
      totalDurationSeconds = try container.decode(Double.self, forKey: .totalDurationSeconds)
      if let count = try container.decodeIfPresent(Int.self, forKey: .remainingDoseCount) {
        remainingDoseCount = count
      } else if let count = try container.decodeIfPresent(Int.self, forKey: .remainingCount) {
        remainingDoseCount = count
      } else {
        remainingDoseCount = 1
      }
      profileName = try container.decodeIfPresent(String.self, forKey: .profileName)
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(snoozeEndTime, forKey: .snoozeEndTime)
      try container.encode(totalDurationSeconds, forKey: .totalDurationSeconds)
      try container.encode(remainingDoseCount, forKey: .remainingDoseCount)
      try container.encodeIfPresent(profileName, forKey: .profileName)
    }
  }

  public var batchId: String

  public init(batchId: String) {
    self.batchId = batchId
  }
}
