import Foundation
import SwiftData

/// One record per calendar day. Captured by the Training Load algorithm's Daily Snapshot
/// Capture path at midnight rollover and on cascade events that mutate today's TL inputs.
/// Powers the Trends `trainingLoadTrend` chart's snapshot-aware rendering — historical
/// days render from snapshot values, today's value is recomputed live.
/// See PRD.md § Data Model, SERVICES.md § Training Load Algorithm → Daily Snapshot Capture.
@Model
final class DailyTrainingLoadSnapshot {
    var id: UUID
    /// Calendar day the snapshot represents (time component zeroed). Lookup key — unique per day.
    var date: Date
    /// Training Load score (0–100) captured at midnight rollover for this day.
    var score: Int
    /// `true` if the score was computed using the sleep-adjusted decay path
    /// (Recovery Status linked to Training Load at capture time); `false` for baseline.
    var wasSleepAdjusted: Bool
    /// Wall-clock timestamp when the snapshot was written.
    var capturedDate: Date

    init(
        id: UUID = UUID(),
        date: Date,
        score: Int,
        wasSleepAdjusted: Bool = false,
        capturedDate: Date = .now
    ) {
        self.id = id
        self.date = date
        self.score = score
        self.wasSleepAdjusted = wasSleepAdjusted
        self.capturedDate = capturedDate
    }
}
