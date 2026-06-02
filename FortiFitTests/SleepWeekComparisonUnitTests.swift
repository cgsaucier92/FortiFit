import Testing
import Foundation
@testable import FortiFit

/// BUG-058 regression suite for `RecoveryStatusService.sleepWeekOverWeekComparison(now:)`.
/// See SERVICES.md / SCREENS.md § Linked Recovery & Load Detail Sheet → Window Comparison.
@MainActor
struct SleepWeekComparisonUnitTests {

    /// Thursday 2026-05-28 noon — picked so both the current ISO week (Mon May 25 –
    /// Sun May 31) and the prior ISO week (Mon May 18 – Sun May 24) have headroom for
    /// snapshots in either direction, and to keep DST-stability deterministic.
    private var fixedNow: Date {
        let isoCalendar = Calendar(identifier: .iso8601)
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 28
        components.hour = 12
        return isoCalendar.date(from: components) ?? Date()
    }

    private func wakeUpDate(daysAgo: Int, from now: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now
    }

    private func snapshot(daysAgo: Int, from now: Date, totalMinutes: Int) -> DailySleepSnapshot {
        DailySleepSnapshot(
            wakeUpDate: wakeUpDate(daysAgo: daysAgo, from: now),
            totalSleepMinutes: totalMinutes,
            deepSleepMinutes: 60,
            remSleepMinutes: 90,
            coreSleepMinutes: 240,
            awakeMinutes: 10,
            inBedMinutes: totalMinutes + 30,
            sleepEfficiencyPercent: 92,
            sourceBundleID: "com.apple.health"
        )
    }

    /// BUG-058: identical mean nightly sleep across both ISO weeks should yield 0%, not
    /// the inflated/deflated number the rolling-by-record helper produced when missing
    /// nights shifted the window across week boundaries.
    @Test func test_sleepWeekOverWeekComparison_identicalSleep_returnsZeroDelta() async {
        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        let now = fixedNow
        // Current week (Mon May 25, Tue May 26, Wed May 27, Thu May 28) — 3, 2, 1, 0 days ago.
        // Prior week (Mon–Sun, May 18–24) — 10, 9, 8 days ago.
        svc.recent30DaySleep = [
            snapshot(daysAgo: 10, from: now, totalMinutes: 420),
            snapshot(daysAgo: 9, from: now, totalMinutes: 420),
            snapshot(daysAgo: 8, from: now, totalMinutes: 420),
            snapshot(daysAgo: 3, from: now, totalMinutes: 420),
            snapshot(daysAgo: 2, from: now, totalMinutes: 420),
            snapshot(daysAgo: 1, from: now, totalMinutes: 420),
            snapshot(daysAgo: 0, from: now, totalMinutes: 420),
        ]

        let cmp = svc.sleepWeekOverWeekComparison(now: now)
        #expect(cmp.currentWeekMeanMinutes == cmp.previousWeekMeanMinutes)
        #expect(cmp.deltaPct == 0)
    }

    /// BUG-058: halving the current week's mean nightly sleep should yield ~-50%.
    @Test func test_sleepWeekOverWeekComparison_halvedThisWeek_returnsRoughly50PctDecrease() async {
        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        let now = fixedNow
        // Prior week: 8h nights. Current week: 4h nights.
        svc.recent30DaySleep = [
            snapshot(daysAgo: 10, from: now, totalMinutes: 480),
            snapshot(daysAgo: 9, from: now, totalMinutes: 480),
            snapshot(daysAgo: 8, from: now, totalMinutes: 480),
            snapshot(daysAgo: 3, from: now, totalMinutes: 240),
            snapshot(daysAgo: 2, from: now, totalMinutes: 240),
            snapshot(daysAgo: 1, from: now, totalMinutes: 240),
        ]

        let cmp = svc.sleepWeekOverWeekComparison(now: now)
        #expect(cmp.deltaPct == -50)
    }

    /// BUG-058: a missing night in the current week should not zero-fill — the helper
    /// averages only the days present in each window. With 3 nights of 7h this week and
    /// 3 nights of 7h last week, the delta must be 0, not skewed by an imaginary 0h.
    @Test func test_sleepWeekOverWeekComparison_missingNightInCurrentWeek_averagesPresentDaysOnly() async {
        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        let now = fixedNow
        // Current week has only 3 present snapshots (Mon, Tue, Thu — Wed missing).
        // Prior week has 3 matching snapshots.
        svc.recent30DaySleep = [
            snapshot(daysAgo: 10, from: now, totalMinutes: 420),
            snapshot(daysAgo: 9, from: now, totalMinutes: 420),
            snapshot(daysAgo: 8, from: now, totalMinutes: 420),
            snapshot(daysAgo: 3, from: now, totalMinutes: 420),
            snapshot(daysAgo: 2, from: now, totalMinutes: 420),
            snapshot(daysAgo: 0, from: now, totalMinutes: 420),
        ]

        let cmp = svc.sleepWeekOverWeekComparison(now: now)
        #expect(cmp.currentWeekSnapshotCount == 3)
        #expect(cmp.previousWeekSnapshotCount == 3)
        #expect(cmp.currentWeekMeanMinutes == 420)
        #expect(cmp.previousWeekMeanMinutes == 420)
        #expect(cmp.deltaPct == 0)
    }

    /// BUG-058: when the prior week has no snapshots, the helper returns `deltaPct == 0`
    /// (parallels `TrainingLoadWeekComparison.deltaPct == 0` when prior week has no
    /// qualifying workouts) so the UI can render a neutral state instead of dividing
    /// by zero.
    @Test func test_sleepWeekOverWeekComparison_noPriorWeekSnapshots_returnsZeroDelta() async {
        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        let now = fixedNow
        svc.recent30DaySleep = [
            snapshot(daysAgo: 3, from: now, totalMinutes: 420),
            snapshot(daysAgo: 2, from: now, totalMinutes: 420),
            snapshot(daysAgo: 1, from: now, totalMinutes: 420),
        ]

        let cmp = svc.sleepWeekOverWeekComparison(now: now)
        #expect(cmp.previousWeekSnapshotCount == 0)
        #expect(cmp.previousWeekMeanMinutes == 0)
        #expect(cmp.deltaPct == 0)
    }

    /// BUG-066: on Thursday the prior matched window runs Mon May 18 – Thu May 21,
    /// NOT through Sun May 24. A weekend night in the prior window should therefore
    /// be excluded from the prior-week mean. Setup: prior has 4 weekday nights at
    /// 420 (Mon-Thu = days 10/9/8/7) plus a deliberately huge Sat-night outlier at
    /// day 5 (Sat May 23, 8h = 480). The current week has 4 nights at 420 (matching
    /// the prior weekday baseline). If the prior window were still full-Mon–Sun
    /// (the BUG-066 bug), the prior mean would be inflated by the Saturday night
    /// and the delta would be < 0. With the matched-window clip the Saturday night
    /// is excluded, prior mean stays at 420, and the delta is exactly 0.
    @Test func test_sleepWeekOverWeekComparison_priorWindowClippedToMatchedWeekday() async {
        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        let now = fixedNow
        svc.recent30DaySleep = [
            snapshot(daysAgo: 10, from: now, totalMinutes: 420), // Mon last week
            snapshot(daysAgo: 9, from: now, totalMinutes: 420),  // Tue last week
            snapshot(daysAgo: 8, from: now, totalMinutes: 420),  // Wed last week
            snapshot(daysAgo: 7, from: now, totalMinutes: 420),  // Thu last week
            snapshot(daysAgo: 5, from: now, totalMinutes: 600),  // Sat last week (outside matched window)
            snapshot(daysAgo: 3, from: now, totalMinutes: 420),  // Mon this week
            snapshot(daysAgo: 2, from: now, totalMinutes: 420),  // Tue this week
            snapshot(daysAgo: 1, from: now, totalMinutes: 420),  // Wed this week
            snapshot(daysAgo: 0, from: now, totalMinutes: 420),  // Thu this week
        ]

        let cmp = svc.sleepWeekOverWeekComparison(now: now)
        #expect(cmp.matchedDayCount == 4)
        #expect(cmp.previousWeekSnapshotCount == 4)
        #expect(cmp.previousWeekMeanMinutes == 420)
        #expect(cmp.currentWeekMeanMinutes == 420)
        #expect(cmp.deltaPct == 0)
    }

    /// BUG-066: matched window collapses to a single Monday when `now` is Monday.
    /// Callers use `matchedDayCount < 2` to render "Not enough data" — this test
    /// asserts the field is wired correctly so the UI can gate.
    @Test func test_sleepWeekOverWeekComparison_mondayReportsMatchedDayCountOne() async throws {
        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 25 // Monday
        components.hour = 7
        let now = try #require(Calendar(identifier: .iso8601).date(from: components))

        svc.recent30DaySleep = [
            snapshot(daysAgo: 7, from: now, totalMinutes: 420), // Mon last week
            snapshot(daysAgo: 0, from: now, totalMinutes: 420), // Mon this week
        ]

        let cmp = svc.sleepWeekOverWeekComparison(now: now)
        #expect(cmp.matchedDayCount == 1)
    }

    /// BUG-066: on Sunday the matched window collapses to the full Mon–Sun on
    /// both sides, restoring the original behavior. `matchedDayCount` should be 7.
    @Test func test_sleepWeekOverWeekComparison_sundayReportsMatchedDayCountSeven() async throws {
        let svc = RecoveryStatusService(client: FoundationStubHealthKitClient())
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 31 // Sunday
        components.hour = 22
        let now = try #require(Calendar(identifier: .iso8601).date(from: components))

        let cmp = svc.sleepWeekOverWeekComparison(now: now)
        #expect(cmp.matchedDayCount == 7)
    }
}
