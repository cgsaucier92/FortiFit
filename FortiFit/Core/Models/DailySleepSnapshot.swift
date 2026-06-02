import Foundation
import SwiftData

/// One record per wake-up date. Written by `RecoveryStatusService` after each anchored
/// sleep query or observer fire; deduplicated by `wakeUpDate`. Drives the 30-day cache
/// and the Recovery Status Detail Sheet's sparkline + last-7-nights stat row.
/// See HEALTHKIT.md § 21, PRD.md § Data Model.
@Model
final class DailySleepSnapshot {
    var id: UUID
    /// Calendar day the user woke up (time component zeroed). Lookup key — unique per day.
    var wakeUpDate: Date
    /// Σ duration of all `.asleep*` HK samples for the 6pm-to-6pm wake-up window.
    var totalSleepMinutes: Int
    /// Σ duration of `.asleepDeep` samples.
    var deepSleepMinutes: Int
    /// Σ duration of `.asleepREM` samples.
    var remSleepMinutes: Int
    /// Σ duration of `.asleepCore` + `.asleepUnspecified` samples.
    var coreSleepMinutes: Int
    /// Σ duration of `.awake` samples within the sleep window.
    var awakeMinutes: Int
    /// Σ duration of `.inBed` samples when the source writes them. When the source emits
    /// only stage samples (Apple Watch's native sleep tracker on watchOS 9+ is the common
    /// case), falls back to `totalSleepMinutes + awakeMinutes` as a session-TIB proxy so
    /// efficiency surfaces for Apple-Watch-only users (BUG-059). Nil only if neither path
    /// produced data (e.g., zero asleep minutes).
    var inBedMinutes: Int?
    /// `round((totalSleepMinutes / inBedMinutes) × 100)`. Nil when `inBedMinutes` is nil.
    var sleepEfficiencyPercent: Int?
    /// Bundle ID of the writing app (Apple Health, Oura, Whoop, etc.).
    var sourceBundleID: String?
    /// Wall-clock timestamp when the snapshot was written.
    var capturedDate: Date

    init(
        id: UUID = UUID(),
        wakeUpDate: Date,
        totalSleepMinutes: Int = 0,
        deepSleepMinutes: Int = 0,
        remSleepMinutes: Int = 0,
        coreSleepMinutes: Int = 0,
        awakeMinutes: Int = 0,
        inBedMinutes: Int? = nil,
        sleepEfficiencyPercent: Int? = nil,
        sourceBundleID: String? = nil,
        capturedDate: Date = .now
    ) {
        self.id = id
        self.wakeUpDate = wakeUpDate
        self.totalSleepMinutes = totalSleepMinutes
        self.deepSleepMinutes = deepSleepMinutes
        self.remSleepMinutes = remSleepMinutes
        self.coreSleepMinutes = coreSleepMinutes
        self.awakeMinutes = awakeMinutes
        self.inBedMinutes = inBedMinutes
        self.sleepEfficiencyPercent = sleepEfficiencyPercent
        self.sourceBundleID = sourceBundleID
        self.capturedDate = capturedDate
    }

    // MARK: - Sparkline Y-Axis Adaptation (BUG-069)

    /// Adaptive Y-axis domain for the 14-day sleep sparkline. Anchors to the typical
    /// 4–10h range when actual sleep falls inside that band; expands outward only when
    /// data exceeds those bounds so values like 1h 37m or 12+h remain inside the visible
    /// plot area instead of swooping outside it. Zero-sleep snapshots are excluded from
    /// the min/max calculation so a missing night doesn't drag the chart's floor to 0.
    /// Empty snapshot set → returns the default `4...10`.
    static func sparklineDomain(for snapshots: [DailySleepSnapshot]) -> ClosedRange<Double> {
        let hours = snapshots.compactMap { snap -> Double? in
            guard snap.totalSleepMinutes > 0 else { return nil }
            return Double(snap.totalSleepMinutes) / 60.0
        }
        guard !hours.isEmpty else { return 4...10 }

        let dataMin = hours.min() ?? 4
        let dataMax = hours.max() ?? 10
        // Only expand the bounds outward — the anchor stays at 4...10 whenever the
        // data is comfortably inside it, so charts look consistent for the typical user.
        let lower = dataMin < 4 ? max(0, floor(dataMin - 0.5)) : 4
        let upper = dataMax > 10 ? min(14, ceil(dataMax + 0.5)) : 10
        return lower...upper
    }

    /// Three evenly spaced axis tick values for the sparkline domain. Picks
    /// `[lower + 1, midpoint, upper - 1]` so the labels stay one tick inside the
    /// plot frame (no labels right on the edges) and so a default `4...10` domain
    /// reproduces the prior hardcoded `[5, 7, 9]` exactly.
    static func sparklineAxisValues(for domain: ClosedRange<Double>) -> [Double] {
        let lower = domain.lowerBound
        let upper = domain.upperBound
        let mid = ((lower + upper) / 2.0).rounded()
        return [lower + 1, mid, upper - 1]
    }
}
