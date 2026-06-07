import Foundation
import SwiftData

/// Gating state for the Recovery Status widget. Derivation rules live in
/// SCREENS.md § Home Screen → Recovery Status widget → States and
/// SERVICES.md § RecoveryStatusService → Derived State.
enum RecoveryStatusGatingState {
    /// `UserSettings.healthKitEnabled == false`. CTA navigates to in-app Settings.
    case connectAppleHealth
    /// HK is enabled but the user has explicitly denied sleep scope.
    /// CTA deep-links to iOS Settings via `UIApplication.openSettingsURLString`.
    /// NOTE: HealthKit does not expose read-scope denial to apps, so this state
    /// is currently unreachable from the protocol alone. Reserved for a future
    /// signal — see BUG-048 follow-up and SERVICES.md § HealthKitClient.
    case sleepAccessDenied
    /// HK enabled, sleep scope granted, but no `.asleep*` samples within the last 14 days.
    /// Source-agnostic — Apple Watch, Oura, Whoop, etc.
    case noSleepTracker
    /// HK enabled, sleep scope granted, recent sleep data present. Full widget renders.
    /// May enter the no-sleep-last-night sub-state when last night's window is empty.
    case live
}

/// Single owner of all sleep data orchestration: 30-day cache, gating, sleep efficiency,
/// sleep-load correlation, smart workout suggestions, and the Sleep Cascade entry point.
/// Sits between `HealthKitClient` (sleep methods) and the widget / detail-sheet view layer.
///
/// See SERVICES.md § RecoveryStatusService, § Sleep Cascade, HEALTHKIT.md § 21,
/// SCREENS.md § Home Screen → Recovery Status widget.
@MainActor
@Observable
final class RecoveryStatusService {
    private let client: HealthKitClient
    private let settings = UserSettings.shared
    private weak var activeContext: ModelContext?

    /// Weak singleton handle so `static struct` services (e.g., `WorkoutService`)
    /// can reach the live instance from cascade entry points without an explicit
    /// dependency. Set by the initializer; cleared when the instance is deallocated.
    /// Phase 11 — bridges the Workout Cascade to the timer-line / suggestion refresh.
    @MainActor static weak var current: RecoveryStatusService?

    /// Set externally by `HomeWidgetService.isLinkedActive(widgets:settings:)` (Step 5).
    /// Until then, defaults to `false` so snapshots are captured on the baseline path.
    var isLinkedActive: Bool = false

    // MARK: - Derived State (read-only, reactive)

    var currentGatingState: RecoveryStatusGatingState = .connectAppleHealth
    var todaysSnapshot: DailySleepSnapshot?
    var recent30DaySleep: [DailySleepSnapshot] = []
    var timeSinceLastWorkoutFormatted: String = ""
    /// Bare-value variant of `timeSinceLastWorkoutFormatted` for the Recovery Status widget's
    /// SINCE LAST WORKOUT hero column (e.g. `4h 12m`, `1d 5h`, `NO DATA`). Refreshed on the
    /// same cascade events as `timeSinceLastWorkoutFormatted`.
    var lastWorkoutHeroFormatted: String = ""
    /// Latest workout's `name` (falls back to `workoutType` when name is empty; `""` when
    /// no workout has ever been logged). Powers the caption line beneath the SINCE LAST
    /// WORKOUT hero value. Refreshed on the same cascade events as `lastWorkoutHeroFormatted`.
    var lastWorkoutNameHeroFormatted: String = ""
    var currentSleepEfficiencyPercent: Int?

    /// Last toast message produced by `importSleepGoalFromAppleHealth()`. The view
    /// layer can observe and surface a Toast Style toast on change.
    var lastToastMessage: String?

    // MARK: - Sleep Cascade Debounce

    /// 500ms debounce timer per SERVICES.md § Sleep Cascade. Reset on each trigger;
    /// cascade body runs at the trailing edge.
    private var debounceTask: Task<Void, Never>?
    private let debounceNanoseconds: UInt64 = 500_000_000

    // MARK: - Init

    init(client: HealthKitClient) {
        self.client = client
        Self.current = self
    }

    func setContext(_ context: ModelContext) {
        self.activeContext = context
    }

    // MARK: - Refresh Triggers

    /// App launch / 6pm catch-up. Anchored sleep query covering the rolling 30-day window,
    /// rebuilds the in-memory cache, re-evaluates `currentGatingState`.
    func refresh(forceCatchUp: Bool = false) async {
        currentGatingState = await computeGatingState()
        guard let context = activeContext else { return }
        guard settings.healthKitEnabled else { return }

        let now = Date()
        let calendar = Calendar.current
        guard let windowStart = calendar.date(byAdding: .day, value: -30, to: now) else { return }

        await ingestSamples(from: windowStart, to: now, context: context)
        reloadCacheFromStore(context: context, lookbackDays: 30)
        recomputeDerivedFromCache()

        if forceCatchUp {
            settings.lastSleepCatchUpDate = .now
        }
    }

    /// Sleep observer fire — refresh today's wake-up day and trigger the Sleep Cascade.
    func handleSleepObserverFire() async {
        guard let context = activeContext else { return }
        guard settings.healthKitEnabled else { return }

        let now = Date()
        let windowStart = observerFetchWindowStart(now: now)
        await ingestSamples(from: windowStart, to: now, context: context)
        reloadCacheFromStore(context: context, lookbackDays: 30)
        scheduleCascade()
    }

    /// `BGAppRefreshTask` path — same as observer fire.
    func refreshFromBackground() async {
        guard let context = activeContext else { return }
        guard settings.healthKitEnabled else { return }

        let now = Date()
        let windowStart = observerFetchWindowStart(now: now)
        await ingestSamples(from: windowStart, to: now, context: context)
        reloadCacheFromStore(context: context, lookbackDays: 30)
        scheduleCascade()
    }

    /// Returns the fetch-window start for incremental sleep ingest (`handleSleepObserverFire`
    /// and `refreshFromBackground`). Anchored to *yesterday's* wake-up window start (6pm
    /// two days ago) with a 2-hour buffer for late-arriving Apple Watch writes — guaranteeing
    /// the fetch fully covers both today's and yesterday's `wakeUpDate` windows regardless
    /// of the current hour. BUG-068.
    ///
    /// Previously hardcoded to 36 hours, which fell short any time the observer fired in
    /// the afternoon/evening. With `now` at 4pm and a 36-hour window, the fetch started
    /// at 4am the prior day — missing the 10 hours of evening-into-overnight samples that
    /// belong to yesterday's 6pm-to-6pm wake-up window. `upsertSnapshot` then overwrote
    /// the previously-correct snapshot with the partial aggregate.
    func observerFetchWindowStart(now: Date = Date()) -> Date {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) ?? now
        let (yesterdayWindowStart, _) = wakeUpWindow(forDay: yesterday)
        return calendar.date(byAdding: .hour, value: -2, to: yesterdayWindowStart) ?? yesterdayWindowStart
    }

    /// Local-midnight rollover trigger. Re-derives today's snapshot pointer from the cache.
    func handleMidnightRollover() {
        recomputeDerivedFromCache()
    }

    /// Workout Cascade hook — bump the timer line + last-workout hero value.
    /// Sleep is untouched.
    /// SERVICES.md § Workout Cascade → Phase 11 bullets.
    func refreshTimerLine(context: ModelContext) {
        timeSinceLastWorkoutFormatted = timeSinceLastWorkout(context: context)
        lastWorkoutHeroFormatted = lastWorkoutHero(context: context)
        lastWorkoutNameHeroFormatted = lastWorkoutNameHero(context: context)
    }

    /// Exposes the 30-day cache as a `[wakeUpDate: snapshot]` lookup. Used by
    /// `ExerciseLoadService.captureTodaySnapshot(...)` from the Workout Cascade.
    func cachedSnapshotsByDay() -> [Date: DailySleepSnapshot] {
        var map: [Date: DailySleepSnapshot] = [:]
        for snapshot in recent30DaySleep {
            map[snapshot.wakeUpDate] = snapshot
        }
        return map
    }

    // MARK: - Derived-state computation

    func computeGatingState() async -> RecoveryStatusGatingState {
        guard settings.healthKitEnabled else { return .connectAppleHealth }
        // HealthKit does not expose read-scope denial to apps. Until a heuristic is
        // wired (see BUG-048 follow-up), treat granted-or-not-prompted as 'access OK'
        // and discriminate Live vs No-Tracker via `hasRecentSleepData`.
        let hasRecent = (try? await client.hasRecentSleepData(within: 14)) ?? false
        return hasRecent ? .live : .noSleepTracker
    }

    // MARK: - Snapshot Upsert + Ingest

    /// Fetches sleep samples from the client for the range, then upserts one
    /// `DailySleepSnapshot` per wake-up day touched by those samples.
    ///
    /// `fetchWindowStart` is threaded into `upsertSnapshot` so it can skip wake-up days
    /// whose 6pm-to-6pm window isn't fully inside the fetch range — preventing the
    /// observer/background path from overwriting a previously-correct snapshot with a
    /// partial aggregate. Defaults to `start` so existing callers don't need to change.
    func ingestSamples(from start: Date, to end: Date, context: ModelContext) async {
        let samples: [HKSleepSampleSnapshot]
        do {
            samples = try await client.fetchSleepSamples(from: start, to: end)
        } catch {
            return
        }
        guard !samples.isEmpty else { return }

        // Group samples by wake-up day.
        var grouped: [Date: [HKSleepSampleSnapshot]] = [:]
        for sample in samples {
            let day = wakeUpDate(for: sample.endDate)
            grouped[day, default: []].append(sample)
        }
        for (day, daySamples) in grouped {
            upsertSnapshot(for: day, samples: daySamples, fetchWindowStart: start, context: context)
        }
        try? context.save()
    }

    /// Computes aggregates from the given samples and upserts a `DailySleepSnapshot`
    /// keyed by `wakeUpDate`. Filters the samples to only those whose `endDate` falls
    /// within the 6pm-to-6pm window for the given wake-up day.
    ///
    /// BUG-068: When `fetchWindowStart` is provided and the wake-up day's window starts
    /// before it, skip the upsert entirely. This protects against overwriting a previously
    /// correct snapshot (built from a full 30-day fetch) with a partial aggregate when the
    /// observer fire's narrower window doesn't cover the full prior wake-up window. The
    /// guard is conservative — it skips ALL days the fetch can't fully cover, even if the
    /// fetched samples happen to be complete for that day (e.g., no actual sleep in the
    /// uncovered hours), trading off a small chance of stale data for a hard guarantee
    /// against data loss.
    func upsertSnapshot(
        for wakeUpDate: Date,
        samples: [HKSleepSampleSnapshot],
        fetchWindowStart: Date? = nil,
        context: ModelContext
    ) {
        let (windowStart, windowEnd) = wakeUpWindow(forDay: wakeUpDate)

        // Skip days whose wake-up window isn't fully inside the fetch range.
        if let fetchStart = fetchWindowStart, windowStart < fetchStart {
            return
        }

        // Per HEALTHKIT.md § 21: include samples whose endDate ∈ (windowStart, windowEnd].
        let inWindow = samples.filter { $0.endDate > windowStart && $0.endDate <= windowEnd }
        let aggregate = aggregate(samples: inWindow)

        if aggregate.totalSleepMinutes == 0 && aggregate.inBedMinutes == nil && aggregate.awakeMinutes == 0 {
            return
        }

        let predicate = #Predicate<DailySleepSnapshot> { $0.wakeUpDate == wakeUpDate }
        let descriptor = FetchDescriptor<DailySleepSnapshot>(predicate: predicate)
        if let existing = try? context.fetch(descriptor).first {
            existing.totalSleepMinutes = aggregate.totalSleepMinutes
            existing.deepSleepMinutes = aggregate.deepSleepMinutes
            existing.remSleepMinutes = aggregate.remSleepMinutes
            existing.coreSleepMinutes = aggregate.coreSleepMinutes
            existing.awakeMinutes = aggregate.awakeMinutes
            existing.inBedMinutes = aggregate.inBedMinutes
            existing.sleepEfficiencyPercent = aggregate.sleepEfficiencyPercent
            existing.sourceBundleID = aggregate.sourceBundleID
            existing.capturedDate = .now
        } else {
            let snapshot = DailySleepSnapshot(
                wakeUpDate: wakeUpDate,
                totalSleepMinutes: aggregate.totalSleepMinutes,
                deepSleepMinutes: aggregate.deepSleepMinutes,
                remSleepMinutes: aggregate.remSleepMinutes,
                coreSleepMinutes: aggregate.coreSleepMinutes,
                awakeMinutes: aggregate.awakeMinutes,
                inBedMinutes: aggregate.inBedMinutes,
                sleepEfficiencyPercent: aggregate.sleepEfficiencyPercent,
                sourceBundleID: aggregate.sourceBundleID
            )
            context.insert(snapshot)
        }
    }

    // MARK: - Aggregation

    struct SleepAggregate {
        var totalSleepMinutes: Int = 0
        var deepSleepMinutes: Int = 0
        var remSleepMinutes: Int = 0
        var coreSleepMinutes: Int = 0
        var awakeMinutes: Int = 0
        var inBedMinutes: Int?
        var sleepEfficiencyPercent: Int?
        var sourceBundleID: String?
    }

    /// Sums per-stage durations and computes efficiency. Pure function — easy to test.
    ///
    /// Accumulates raw seconds per stage and rounds once at the end so the daily
    /// total matches Apple Health's `TIME ASLEEP`. Per-sample rounding (the prior
    /// approach) drifted by several minutes across a typical 30–60-sample night.
    /// `totalSleepMinutes` additionally credits small gaps between consecutive
    /// non-`.inBed` samples — Apple Watch leaves 1–2s transition gaps that Apple
    /// Health silently counts (it computes asleep as session-span minus awake),
    /// and across a night that's another ~30–60 seconds. See BUG-052.
    func aggregate(samples: [HKSleepSampleSnapshot]) -> SleepAggregate {
        var agg = SleepAggregate()
        var deepSec: TimeInterval = 0
        var remSec: TimeInterval = 0
        var coreSec: TimeInterval = 0
        var awakeSec: TimeInterval = 0
        var inBedSec: TimeInterval = 0
        var sawInBed = false

        for sample in samples {
            let seconds = sample.durationSeconds
            switch sample.stage {
            case .asleepDeep:
                deepSec += seconds
            case .asleepREM:
                remSec += seconds
            case .asleepCore:
                coreSec += seconds
            case .asleepUnspecified:
                // Per PRD § Data Model → DailySleepSnapshot: `coreSleepMinutes`
                // sums `.asleepCore` + `.asleepUnspecified`.
                coreSec += seconds
            case .awake:
                awakeSec += seconds
            case .inBed:
                inBedSec += seconds
                sawInBed = true
            }
        }
        agg.deepSleepMinutes = Int((deepSec / 60.0).rounded())
        agg.remSleepMinutes = Int((remSec / 60.0).rounded())
        agg.coreSleepMinutes = Int((coreSec / 60.0).rounded())
        agg.awakeMinutes = Int((awakeSec / 60.0).rounded())
        let transitionGapSec = inSessionTransitionGapSeconds(samples: samples)
        agg.totalSleepMinutes = Int(((deepSec + remSec + coreSec + transitionGapSec) / 60.0).rounded())
        if sawInBed {
            agg.inBedMinutes = Int((inBedSec / 60.0).rounded())
        } else if agg.totalSleepMinutes > 0 {
            // BUG-059: Apple Watch's native sleep tracker (watchOS 9+) emits only stage
            // samples — `.asleepDeep/REM/Core/Unspecified` + `.awake` — and never writes
            // `.inBed` category samples. Without a fallback, `sleepEfficiencyPercent` was
            // permanently nil and the detail-sheet efficiency caption stayed hidden for
            // the most common sleep source. Approximate session TIB as `asleep + awake`;
            // within rounding this matches Apple Health's session-span derivation
            // (the only difference is small in-session transition gaps already credited
            // toward `totalSleepMinutes`).
            agg.inBedMinutes = agg.totalSleepMinutes + agg.awakeMinutes
        }
        agg.sleepEfficiencyPercent = computeSleepEfficiency(asleepMinutes: agg.totalSleepMinutes, inBedMinutes: agg.inBedMinutes)
        agg.sourceBundleID = samples.map(\.sourceBundleID).mostFrequent()
        return agg
    }

    /// In-session gaps to credit toward `totalSleepMinutes`. Sums positive gaps
    /// shorter than `transitionGapThreshold` between consecutive non-`.inBed`
    /// samples (sorted by `startDate`). Tiny gaps come from Apple Watch's
    /// per-transition sample writes — they're invisible to the user but to
    /// Apple Health they're part of the sleep session, not unaccounted-for time.
    /// Gaps ≥ the threshold are treated as between-session boundaries (e.g., a
    /// daytime nap and an overnight session) and excluded.
    private func inSessionTransitionGapSeconds(samples: [HKSleepSampleSnapshot]) -> TimeInterval {
        let transitionGapThreshold: TimeInterval = 300 // 5 minutes
        let sorted = samples
            .filter { $0.stage != .inBed }
            .sorted { $0.startDate < $1.startDate }
        guard sorted.count >= 2 else { return 0 }
        var total: TimeInterval = 0
        for i in 1..<sorted.count {
            let gap = sorted[i].startDate.timeIntervalSince(sorted[i - 1].endDate)
            if gap > 0 && gap < transitionGapThreshold {
                total += gap
            }
        }
        return total
    }

    func computeSleepEfficiency(asleepMinutes: Int, inBedMinutes: Int?) -> Int? {
        guard let inBed = inBedMinutes, inBed > 0 else { return nil }
        let ratio = Double(asleepMinutes) / Double(inBed)
        return Int((ratio * 100).rounded())
    }

    // MARK: - Wake-Up Date Attribution (6pm-to-6pm)

    /// Returns the calendar day (time component zeroed in local timezone) that the
    /// sample's `endDate` belongs to under the 6pm-to-6pm wake-up window. Samples
    /// ending at exactly 6pm belong to the *prior* day (HEALTHKIT.md § 21).
    func wakeUpDate(for endDate: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: endDate)
        let minute = calendar.component(.minute, from: endDate)
        let second = calendar.component(.second, from: endDate)
        let endsAfter6pm = hour > 18 || (hour == 18 && (minute > 0 || second > 0))
        let baseDay = calendar.startOfDay(for: endDate)
        if endsAfter6pm {
            return calendar.date(byAdding: .day, value: 1, to: baseDay) ?? baseDay
        }
        return baseDay
    }

    /// Returns the (start, end) of the 6pm-to-6pm wake-up window for the given day.
    func wakeUpWindow(forDay wakeUp: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: wakeUp)
        let prevDayStart = calendar.date(byAdding: .day, value: -1, to: dayStart) ?? dayStart
        let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: prevDayStart) ?? prevDayStart
        let end = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: dayStart) ?? dayStart
        return (start, end)
    }

    // MARK: - 30-day Cache

    /// Loads the rolling 30-day snapshot set from the SwiftData store. Called on app
    /// launch and after each cascade fire.
    func reloadCacheFromStore(context: ModelContext, lookbackDays: Int = 30) {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -(lookbackDays - 1), to: calendar.startOfDay(for: Date())) else { return }
        let predicate = #Predicate<DailySleepSnapshot> { $0.wakeUpDate >= cutoff }
        var descriptor = FetchDescriptor<DailySleepSnapshot>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.wakeUpDate, order: .forward)]
        let snapshots = (try? context.fetch(descriptor)) ?? []
        backfillInBedMinutesIfNeeded(snapshots, context: context)
        recent30DaySleep = snapshots
        recomputeDerivedFromCache()
    }

    /// BUG-059 backfill. Snapshots written before the asleep+awake fallback shipped have
    /// `inBedMinutes == nil` / `sleepEfficiencyPercent == nil` for Apple-Watch-only users
    /// even though the underlying aggregate data is sufficient to derive both. Rewriting
    /// only here (rather than at write time) means the next HK observer fire or anchored
    /// query for the same wake-up day still overwrites with the authoritative value from
    /// the explicit `.inBed` samples when a source eventually provides them. Idempotent —
    /// snapshots already carrying a non-nil `inBedMinutes` are left untouched.
    private func backfillInBedMinutesIfNeeded(_ snapshots: [DailySleepSnapshot], context: ModelContext) {
        var dirty = false
        for snapshot in snapshots where snapshot.inBedMinutes == nil && snapshot.totalSleepMinutes > 0 {
            let fallbackInBed = snapshot.totalSleepMinutes + snapshot.awakeMinutes
            snapshot.inBedMinutes = fallbackInBed
            snapshot.sleepEfficiencyPercent = computeSleepEfficiency(
                asleepMinutes: snapshot.totalSleepMinutes,
                inBedMinutes: fallbackInBed
            )
            dirty = true
        }
        if dirty { try? context.save() }
    }

    private func recomputeDerivedFromCache() {
        // `wakeUpDate(for:)` is the sample-attribution helper (rolls past-6pm end-dates
        // forward to tomorrow's wake-up window). For the cache lookup we want today's
        // calendar startOfDay regardless of the current hour — the user already woke up
        // today, so the most recent snapshot is keyed to today. See BUG-051.
        let today = Calendar.current.startOfDay(for: Date())
        todaysSnapshot = recent30DaySleep.first(where: { Calendar.current.isDate($0.wakeUpDate, inSameDayAs: today) })
        currentSleepEfficiencyPercent = todaysSnapshot?.sleepEfficiencyPercent
    }

    // MARK: - Sleep Cascade

    /// Schedules the Sleep Cascade body to run after a 500ms debounce window. Each
    /// call resets the timer; only the trailing call's body runs.
    private func scheduleCascade() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: self?.debounceNanoseconds ?? 0)
            if Task.isCancelled { return }
            self?.fireCascadeNow()
        }
    }

    /// Cascade body. Steps 1–5 per SERVICES.md § Sleep Cascade.
    /// Step 4 (TL recompute when linked) writes today's `DailyTrainingLoadSnapshot` with
    /// `wasSleepAdjusted = true`. The linked advisory copy is no longer cached on the
    /// service — call sites compute it on demand via `computeLinkedAdvisory(...)` because
    /// the joint output depends on the live TL zone + trainedToday signal as well as
    /// sleep, neither of which the service holds.
    private func fireCascadeNow() {
        recomputeDerivedFromCache()
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.currentGatingState = await self.computeGatingState()
        }
        // Step 4 — Training Load sleep-adjusted recompute + today's snapshot rewrite.
        if isLinkedActive, let context = activeContext {
            ExerciseLoadService.captureTodaySnapshot(
                context: context,
                sleepAdjusted: true,
                sleepSnapshotsByDay: cachedSnapshotsByDay(),
                targetSleepHours: settings.targetSleepHours
            )
        }
    }

    // MARK: - Time Since Last Workout (Phase 11 Step 3)

    /// Reads the most recent `Workout.date` and formats per CONSTANTS.md § Recovery
    /// Status Widget → Timer Meta Line. All 6 workout types count.
    func timeSinceLastWorkout(context: ModelContext) -> String {
        var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        let workout = (try? context.fetch(descriptor))?.first
        return formatTimeSinceLastWorkout(latestDate: workout?.date, now: Date())
    }

    /// Per-type variant for the detail sheet's per-type rows.
    func timeSinceLastWorkout(for type: String, context: ModelContext) -> String {
        let predicate = #Predicate<Workout> { $0.workoutType == type }
        var descriptor = FetchDescriptor<Workout>(predicate: predicate, sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        let workout = (try? context.fetch(descriptor))?.first
        return formatTimeSinceLastWorkout(latestDate: workout?.date, now: Date())
    }

    /// Pure formatter — extracted so it's testable without a SwiftData context.
    /// Graceful precision degradation per CONSTANTS.md § Recovery Status Widget → Timer Meta Line.
    func formatTimeSinceLastWorkout(latestDate: Date?, now: Date) -> String {
        guard let latest = latestDate else { return "No workouts logged yet" }
        let elapsed = max(now.timeIntervalSince(latest), 0)
        let minutes = Int(elapsed / 60)
        let hours = elapsed / 3600
        let days = hours / 24

        if elapsed < 3600 { // < 1 hour
            return "\(minutes) min since your last workout"
        }
        if hours < 24 { // 1–23 hours
            let h = Int(hours)
            let m = minutes - h * 60
            return "\(h)h \(String(format: "%02d", m))m since your last workout"
        }
        if hours < 72 { // 24–72 hours
            let d = Int(days)
            let remainderHours = Int(hours) - d * 24
            return "\(d)d \(remainderHours)h since your last workout"
        }
        // > 72 hours
        return "\(Int(days)) days since your last workout"
    }

    /// Bare-value variant of `timeSinceLastWorkout(context:)` for the Recovery Status
    /// widget's SINCE LAST WORKOUT hero column.
    func lastWorkoutHero(context: ModelContext) -> String {
        var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        let workout = (try? context.fetch(descriptor))?.first
        return formatLastWorkoutHero(latestDate: workout?.date, now: Date())
    }

    /// Latest workout's display name for the caption beneath the SINCE LAST WORKOUT
    /// hero value. Prefers user-entered `name`; falls back to `workoutType` (raw enum
    /// rawValue) when `name` is empty; returns `""` when no workout has been logged so
    /// the widget can suppress the caption row entirely.
    func lastWorkoutNameHero(context: ModelContext) -> String {
        var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let workout = (try? context.fetch(descriptor))?.first else { return "" }
        let trimmedName = workout.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? workout.workoutType : trimmedName
    }

    /// Pure formatter for the SINCE LAST WORKOUT hero value. Same time-bucket boundaries
    /// as `formatTimeSinceLastWorkout` but without the trailing "since your last workout"
    /// descriptor (the label above the value supplies that context). Returns `NO DATA`
    /// when no workouts have ever been logged, matching the SLEEP hero's no-data treatment.
    func formatLastWorkoutHero(latestDate: Date?, now: Date) -> String {
        guard let latest = latestDate else { return "NO DATA" }
        let elapsed = max(now.timeIntervalSince(latest), 0)
        let minutes = Int(elapsed / 60)
        let hours = elapsed / 3600
        let days = hours / 24

        if elapsed < 3600 { // < 1 hour
            return "\(minutes) min"
        }
        if hours < 24 { // 1–23 hours
            let h = Int(hours)
            let m = minutes - h * 60
            return "\(h)h \(String(format: "%02d", m))m"
        }
        if hours < 72 { // 24–72 hours
            let d = Int(days)
            let remainderHours = Int(hours) - d * 24
            return "\(d)d \(remainderHours)h"
        }
        // > 72 hours
        return "\(Int(days)) days"
    }

    // MARK: - Linked Advisory (Phase 11 — BUG-061)

    /// Joint Training Load + sleep advisory used by the linked Recovery & Load composite
    /// (widget body + Recovery Readiness callout in the Linked Recovery & Load Detail
    /// Sheet). Returns a single coherent sentence keyed off the TL zone, whether the user
    /// trained today, and the sleep-to-target ratio bucket. Met-target and missing-data
    /// nights fall through to the unchanged `baseAdvisory` so a missing sleep night never
    /// alters the recommendation.
    ///
    /// The standalone Training Load widget and its detail sheet do not call this — they
    /// continue to render `LoadResult.advisory` directly. See INFO_COPY.md and
    /// CONSTANTS.md § Training Load Zones → Linked Advisory Copy.
    func computeLinkedAdvisory(
        baseAdvisory: String,
        zone: String,
        trainedToday: Bool,
        sleepHours: Double?,
        targetSleepHours: Double
    ) -> String {
        guard let hours = sleepHours, targetSleepHours > 0 else {
            return baseAdvisory
        }
        let ratio = hours / targetSleepHours
        let sleepBucket: String
        switch ratio {
        case 1.0...:
            sleepBucket = "strong"
        case 0.85..<1.0:
            return baseAdvisory
        case 0.70..<0.85:
            sleepBucket = "moderatelyBelow"
        default:
            sleepBucket = "significantlyBelow"
        }
        let trainedKey = trainedToday ? "trained" : "untrained"
        let key = "\(zone)|\(trainedKey)|\(sleepBucket)"
        return AppConstants.TrainingLoad.linkedAdvisoryText[key] ?? baseAdvisory
    }

    // MARK: - Sleep-Load Correlation (Phase 11 Step 3)

    // MARK: - Sleep Week-over-Week Comparison

    /// Mean nightly sleep minutes for the current ISO Mon–Sun week vs the prior ISO
    /// Mon–Sun week, with a rounded `deltaPct`. Averages are taken over **days present
    /// in each window only** (missing nights are skipped, not zero-filled), so a single
    /// untracked night doesn't drag the mean down.
    ///
    /// Aligned with `ExerciseLoadService.weekOverWeekComparison` so both rows of the
    /// linked Recovery & Load Detail Sheet's window-comparison block share the same
    /// "vs last week" definition (BUG-058). Day-of-week matched window (BUG-066) —
    /// both ranges run Mon through the current weekday so the prior week isn't
    /// structurally over-represented.
    struct SleepWeekComparison {
        let currentWeekMeanMinutes: Int
        let previousWeekMeanMinutes: Int
        /// (current - previous) / previous × 100, rounded. 0 when the prior week has no
        /// snapshots (parallels `TrainingLoadWeekComparison.deltaPct == 0` when the
        /// prior week has no qualifying workouts).
        let deltaPct: Int
        /// Number of present sleep snapshots in each window. Useful for "Not enough
        /// data" treatments and for tests that need to verify gap handling.
        let currentWeekSnapshotCount: Int
        let previousWeekSnapshotCount: Int
        /// Inclusive day count of the matched window (Mon through current weekday).
        /// 1 on Monday, 4 on Thursday, 7 on Sunday. Independent of how many of those
        /// days actually have snapshots.
        let matchedDayCount: Int
    }

    func sleepWeekOverWeekComparison(now: Date = Date()) -> SleepWeekComparison {
        let isoCalendar = Calendar(identifier: .iso8601)
        let calendar = Calendar.current
        let currentWeekStart = now.startOfWeek

        guard let prevWeekStart = isoCalendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) else {
            return SleepWeekComparison(
                currentWeekMeanMinutes: 0,
                previousWeekMeanMinutes: 0,
                deltaPct: 0,
                currentWeekSnapshotCount: 0,
                previousWeekSnapshotCount: 0,
                matchedDayCount: 0
            )
        }

        let dayOffset = max(0, min(6, calendar.dateComponents([.day], from: currentWeekStart, to: now).day ?? 0))
        let matchedDayCount = dayOffset + 1

        guard let prevMatchedDay = isoCalendar.date(byAdding: .day, value: dayOffset, to: prevWeekStart),
              let prevMatchedEnd = isoCalendar.date(bySettingHour: 23, minute: 59, second: 59, of: prevMatchedDay) else {
            return SleepWeekComparison(
                currentWeekMeanMinutes: 0,
                previousWeekMeanMinutes: 0,
                deltaPct: 0,
                currentWeekSnapshotCount: 0,
                previousWeekSnapshotCount: 0,
                matchedDayCount: matchedDayCount
            )
        }

        func snapshots(in range: ClosedRange<Date>) -> [DailySleepSnapshot] {
            recent30DaySleep.filter { range.contains($0.wakeUpDate) }
        }

        func mean(of snaps: [DailySleepSnapshot]) -> Double {
            guard !snaps.isEmpty else { return 0 }
            return Double(snaps.reduce(0) { $0 + $1.totalSleepMinutes }) / Double(snaps.count)
        }

        let currentSnaps = snapshots(in: currentWeekStart...now)
        let previousSnaps = snapshots(in: prevWeekStart...prevMatchedEnd)
        let currentMean = mean(of: currentSnaps)
        let previousMean = mean(of: previousSnaps)

        let deltaPct: Int
        if previousMean > 0 {
            deltaPct = Int(((currentMean - previousMean) / previousMean * 100).rounded())
        } else {
            deltaPct = 0
        }

        return SleepWeekComparison(
            currentWeekMeanMinutes: Int(currentMean.rounded()),
            previousWeekMeanMinutes: Int(previousMean.rounded()),
            deltaPct: deltaPct,
            currentWeekSnapshotCount: currentSnaps.count,
            previousWeekSnapshotCount: previousSnaps.count,
            matchedDayCount: matchedDayCount
        )
    }

    /// Median-split the user's last N days of paired (sleep, next-day-score) data at
    /// the 7h sleep mark. Returns `(delta, copyVariantKey)` where:
    ///   - `delta = mean(highSleepScores) - mean(lowSleepScores)`
    ///   - copy key selected by sign + magnitude:
    ///     `delta <= -5` → `highSleepBetter`; `delta >= +5` → `lowSleepWorse`; else `noPattern`.
    /// Returns nil when fewer than 14 paired days exist.
    ///
    /// BUG-070 — the next-day score is recomputed from raw workouts via
    /// `ExerciseLoadService.calculateLoad(..., now: nextDay)` rather than read from
    /// `DailyTrainingLoadSnapshot`. Persisted snapshots may be sleep-adjusted (when
    /// captured while the linked composite was active), which would partially derive
    /// the score from the sleep input being correlated and make `highSleepBetter`
    /// partly tautological. Baseline scores keep the correlation honest regardless of
    /// the user's linking history.
    func computeSleepLoadCorrelation(context: ModelContext) -> (delta: Double, copyVariant: String)? {
        let calendar = Calendar.current
        let snapshotsByDay = cachedSnapshotsByDay()
        let now = Date()
        let today = calendar.startOfDay(for: now)
        // Pairing window: 45 days back from today. For each paired (D, D+1), the
        // baseline load on D+1 uses workouts within (D+1 − 10 days, D+1]. So we
        // fetch raw workouts spanning 45 + 10 = 55 days to cover the oldest pair.
        let workoutsFetchStart = calendar.date(byAdding: .day, value: -55, to: today) ?? today
        let allWorkouts = WorkoutService.fetchWorkouts(from: workoutsFetchStart, to: now, context: context)
        let settings = UserSettings.shared

        // Build paired data: for each sleep snapshot, compute the *next* day's
        // baseline TL score from raw workouts. "Score at the end of nextDay" — so
        // workouts done any time during nextDay are included, matching the snapshot
        // capture semantics it replaces.
        var highSleepScores: [Int] = []
        var lowSleepScores: [Int] = []
        for (wakeUpDay, sleep) in snapshotsByDay {
            let nextDayStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: wakeUpDay) ?? wakeUpDay)
            // Skip pairs whose `nextDay` is in the future — matches the original
            // behavior (which couldn't find a future-day snapshot anyway).
            guard nextDayStart <= today else { continue }
            let endOfNextDay = calendar.date(byAdding: .day, value: 1, to: nextDayStart) ?? nextDayStart
            let windowStart = calendar.date(byAdding: .day, value: -10, to: nextDayStart) ?? nextDayStart
            let workoutsInWindow = allWorkouts.filter { $0.date > windowStart && $0.date < endOfNextDay }
            let result = ExerciseLoadService.calculateLoad(
                workouts: workoutsInWindow,
                experienceLevel: settings.experienceLevel,
                targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
                now: endOfNextDay
            )
            let score = Int(result.score.rounded())
            let sleepHours = Double(sleep.totalSleepMinutes) / 60.0
            if sleepHours >= 7.0 {
                highSleepScores.append(score)
            } else {
                lowSleepScores.append(score)
            }
        }
        let paired = highSleepScores.count + lowSleepScores.count
        guard paired >= 14 else { return nil }

        // Both buckets need data to compute a delta; otherwise fall back to noPattern.
        guard !highSleepScores.isEmpty, !lowSleepScores.isEmpty else {
            return (0, "noPattern")
        }
        let highMean = Double(highSleepScores.reduce(0, +)) / Double(highSleepScores.count)
        let lowMean = Double(lowSleepScores.reduce(0, +)) / Double(lowSleepScores.count)
        let delta = highMean - lowMean
        let variant: String
        if delta <= -5 {
            variant = "highSleepBetter"
        } else if delta >= 5 {
            variant = "lowSleepWorse"
        } else {
            variant = "noPattern"
        }
        return (delta, variant)
    }

    // MARK: - Apple Health Sleep Goal Import

    /// Reads `HealthKitClient.fetchSleepDurationGoal()`. If non-nil, writes the value
    /// (rounded to the nearest 0.5 hr increment, clamped to 4.0–12.0) into
    /// `UserSettings.targetSleepHours`. If nil, emits a Toast Style toast.
    /// NOTE: HealthKit does not currently expose the sleep duration goal (BUG-048).
    /// The toast fires unconditionally in this build.
    func importSleepGoalFromAppleHealth() async {
        let goal = try? await client.fetchSleepDurationGoal()
        guard let interval = goal, interval > 0 else {
            lastToastMessage = "No sleep goal set in Apple Health."
            return
        }
        let hours = interval / 3600.0
        let snapped = (hours * 2.0).rounded() / 2.0
        let clamped = min(max(snapped, 4.0), 12.0)
        settings.targetSleepHours = clamped
    }
}

private extension Array where Element: Hashable {
    /// Returns the value with the highest occurrence, or nil for empty arrays.
    /// Used by `RecoveryStatusService.aggregate(samples:)` to pick a representative
    /// source bundle ID for diagnostic surfacing.
    func mostFrequent() -> Element? {
        guard !isEmpty else { return nil }
        var counts: [Element: Int] = [:]
        for element in self {
            counts[element, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}
