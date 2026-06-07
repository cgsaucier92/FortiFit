import Foundation
import SwiftData

struct ExerciseLoadService {

    /// The result of a load calculation.
    struct LoadResult {
        let score: Double
        let zone: String
        let zoneColor: String  // hex color
        let advisory: String
        /// Whether the user has logged at least one workout today. Drives readiness vs.
        /// post-training advisory variants in `classifyZone`, and is consumed by
        /// `RecoveryStatusService.computeLinkedAdvisory` to pick the right joint copy
        /// when Recovery Status is linked.
        let trainedToday: Bool

        init(score: Double, zone: String, zoneColor: String, advisory: String, trainedToday: Bool = false) {
            self.score = score
            self.zone = zone
            self.zoneColor = zoneColor
            self.advisory = advisory
            self.trainedToday = trainedToday
        }
    }

    // MARK: - Experience-Based Constants

    /// τ (tau): Exponential decay constant in days.
    /// Beginner (0) = 3.0, Intermediate (1) = 2.0, Advanced (2) = 1.5.
    static func decayConstant(for experienceLevel: Int) -> Double {
        switch experienceLevel {
        case 0: return 3.0   // Beginner: stress lingers longest
        case 1: return 2.0   // Intermediate: moderate recovery
        case 2: return 1.5   // Advanced: fastest recovery
        default: return 2.0
        }
    }

    /// Stress capacity: the accumulated stress that represents a fully fatigued state.
    /// Beginner (0) = 15, Intermediate (1) = 20, Advanced (2) = 25.
    static func stressCapacity(for experienceLevel: Int) -> Double {
        switch experienceLevel {
        case 0: return 15.0
        case 1: return 20.0
        case 2: return 25.0
        default: return 20.0
        }
    }

    // MARK: - Per-Session Factors

    /// Returns the workout type modifier for a given workout type string.
    static func typeModifier(for workoutType: String) -> Double {
        return AppConstants.workoutTypeModifiers[workoutType] ?? 1.0
    }

    /// Returns the volume modifier for a workout.
    /// Strength Training / HIIT: clamp(0.5 + totalSets/20, 0.5, 1.5).
    /// All other types: 1.0.
    static func volumeModifier(for workout: Workout) -> Double {
        let strengthTypes = ["Strength Training", "HIIT"]
        guard strengthTypes.contains(workout.workoutType) else { return 1.0 }
        let totalSets = workout.exerciseSets.reduce(0) { $0 + $1.sets }
        let raw = 0.5 + Double(totalSets) / 20.0
        return min(max(raw, 0.5), 1.5)
    }

    /// Calculates the per-session stress for a single workout.
    /// session_stress = RPE × (duration_minutes / 60) × type_modifier × volume_modifier
    static func sessionStress(for workout: Workout, targetMinutesPerWorkout: Int) -> Double {
        let rpe = Double(workout.rpe ?? 5)
        let duration = Double(workout.durationMinutes ?? targetMinutesPerWorkout)
        let typeMod = typeModifier(for: workout.workoutType)
        let volMod = volumeModifier(for: workout)
        return rpe * (duration / 60.0) * typeMod * volMod
    }

    // MARK: - Consecutive Training Days

    /// Counts consecutive calendar days ending on today or yesterday that each have ≥1 workout.
    /// If the most recent workout was 2 or more days ago, returns 0.
    static func consecutiveDays(workouts: [Workout], now: Date) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let workoutDates = Set(workouts.map { calendar.startOfDay(for: $0.date) })

        // The streak must end on today or yesterday
        guard workoutDates.contains(today) || workoutDates.contains(yesterday) else {
            return 0
        }

        var day = workoutDates.contains(today) ? today : yesterday
        var count = 0
        while workoutDates.contains(day) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    /// Returns the consecutive training days multiplier.
    /// 1.0 + max(consecutiveDays - 1, 0) × 0.08, capped at 1.32 (5+ days).
    static func consecutiveDaysMultiplier(workouts: [Workout], now: Date) -> Double {
        let days = consecutiveDays(workouts: workouts, now: now)
        let raw = 1.0 + Double(max(days - 1, 0)) * 0.08
        return min(raw, 1.32)
    }

    // MARK: - Main Calculation

    /// Returns true if the workout is an empty shell (no exercises, no RPE, no duration)
    /// and should be excluded from Training Load calculations.
    static func isEmptyWorkout(_ workout: Workout) -> Bool {
        return workout.exerciseSets.isEmpty && workout.rpe == nil && workout.durationMinutes == nil
    }

    /// Calculates the daily training load score (0–100) using a 10-day exponential decay model.
    ///
    /// - Parameters:
    ///   - workouts: All workouts within the 10-day lookback window
    ///   - experienceLevel: 0=Beginner, 1=Intermediate, 2=Advanced
    ///   - targetMinutesPerWorkout: Fallback duration when workout.durationMinutes is nil
    ///   - now: Reference date for decay calculation (defaults to current time)
    static func calculateLoad(
        workouts: [Workout],
        experienceLevel: Int,
        targetMinutesPerWorkout: Int,
        now: Date = Date()
    ) -> LoadResult {
        // Pre-Filter: exclude empty workouts (no exercises, no RPE, no duration)
        let qualifyingWorkouts = workouts.filter { !isEmptyWorkout($0) }

        guard !qualifyingWorkouts.isEmpty else {
            return classifyZone(score: 0)
        }

        let tau = decayConstant(for: experienceLevel)
        let capacity = stressCapacity(for: experienceLevel)

        // Sum time-decayed stress for all workouts in the window
        let rawStress = qualifyingWorkouts.reduce(0.0) { sum, workout in
            let stress = sessionStress(for: workout, targetMinutesPerWorkout: targetMinutesPerWorkout)
            let daysAgo = now.timeIntervalSince(workout.date) / 86400.0
            let decayed = stress * exp(-daysAgo / tau)
            return sum + decayed
        }

        // Apply consecutive training days multiplier
        let consecutiveMultiplier = consecutiveDaysMultiplier(workouts: qualifyingWorkouts, now: now)
        let adjustedStress = rawStress * consecutiveMultiplier

        // Step 8 — Normalize to 0–100
        let score = min(max((adjustedStress / capacity) * 100.0, 0.0), 100.0)

        // Step 9 — Same-Day Training Floor
        // Prevents the score from understating fatigue on a day the user has already trained.
        // floor = clamp((today_stress / stress_capacity) × 150, 0, 80)
        // Cap at 80 so a single day's training can never push into Peak on its own.
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        let todayStress = qualifyingWorkouts
            .filter { calendar.startOfDay(for: $0.date) == todayStart }
            .reduce(0.0) { $0 + sessionStress(for: $1, targetMinutesPerWorkout: targetMinutesPerWorkout) }
        let floor = min(max((todayStress / capacity) * 150.0, 0.0), 80.0)
        let finalScore = max(score, floor)
        let trainedToday = todayStress > 0

        return classifyZone(score: finalScore, trainedToday: trainedToday)
    }

    // MARK: - Zone Classification

    /// Classifies a score (0–100) into a zone with color and advisory text.
    /// - Parameter trainedToday: Pass `true` if the user has logged at least one workout today.
    ///   Shows post-training advisory variants instead of readiness variants.
    static func classifyZone(score: Double, trainedToday: Bool = false) -> LoadResult {
        let rounded = score.rounded()

        if rounded <= 0 {
            return LoadResult(
                score: score,
                zone: "Resting",
                zoneColor: "737373",
                advisory: "No recent training stress. Ready for a full session.",
                trainedToday: trainedToday
            )
        } else if rounded <= 30 {
            return LoadResult(
                score: score,
                zone: "Low",
                zoneColor: "10b981",
                advisory: trainedToday
                    ? "Session logged. You have more capacity to train again if you choose."
                    : "Well recovered. Ready to train.",
                trainedToday: trainedToday
            )
        } else if rounded <= 55 {
            return LoadResult(
                score: score,
                zone: "Moderate",
                zoneColor: "C4F648",
                advisory: trainedToday
                    ? "Good work today. Rest up."
                    : "Some muscle fatigue. A moderate session would be ideal.",
                trainedToday: trainedToday
            )
        } else if rounded <= 80 {
            return LoadResult(
                score: score,
                zone: "High",
                zoneColor: "B7FF00",
                advisory: trainedToday
                    ? "Recovery is the priority."
                    : "Significant muscle fatigue. Consider a lighter session or active recovery.",
                trainedToday: trainedToday
            )
        } else {
            return LoadResult(
                score: score,
                zone: "Peak",
                zoneColor: "ef4444",
                advisory: trainedToday
                    ? "You've been pushing hard. Time to rest."
                    : "High physical stress. Rest or very light activity recommended.",
                trainedToday: trainedToday
            )
        }
    }

    // MARK: - Detail Sheet Helpers (Phase 8.8)

    struct TrainingLoadDailyScore: Hashable {
        let date: Date
        let score: Int
        let zone: String
        let zoneColor: String
    }

    struct TrainingLoadContributor: Hashable, Identifiable {
        let workoutId: UUID
        let workoutName: String
        let date: Date
        let tssContribution: Double
        let percentOfWeeklyLoad: Int

        var id: UUID { workoutId }
    }

    struct TrainingLoadWeekComparison {
        let currentWeekTss: Int
        let previousWeekTss: Int
        let deltaPct: Int
        /// Inclusive day count of the matched window (Mon through current weekday).
        /// 1 on Monday, 4 on Thursday, 7 on Sunday. Callers use this to render a
        /// "Not enough data" treatment when the window is too short to be meaningful.
        let matchedDayCount: Int
    }

    /// Returns 14 daily training-load scores, oldest first → most recent last (today inclusive).
    /// Phase 11: historical days prefer the persisted `DailyTrainingLoadSnapshot` when one
    /// exists (immutable record of the score the user saw on that day); today is always
    /// computed live so the chart's latest point matches the hero. Pre-feature-launch days
    /// without snapshots fall back to the live recompute.
    ///
    /// When `sleepSnapshotsByDay` is provided, today's live recompute uses
    /// `computeCurrentScore` (the sleep-adjusted path) so the chart's latest point matches
    /// the linked detail sheet's hero. When omitted, today uses the baseline `calculateLoad`
    /// (correct unlinked behavior). BUG-067.
    static func fourteenDayDailyScores(
        context: ModelContext,
        sleepSnapshotsByDay: [Date: DailySleepSnapshot]? = nil,
        targetSleepHours: Double? = nil,
        now: Date = Date()
    ) -> [TrainingLoadDailyScore] {
        let settings = UserSettings.shared
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        // Pre-fetch snapshots for the 14-day window in one query.
        let windowStart = calendar.date(byAdding: .day, value: -13, to: today) ?? today
        let snapshots = snapshots(
            for: DateInterval(start: windowStart, end: today),
            context: context
        )
        let snapshotsByDay: [Date: DailyTrainingLoadSnapshot] = snapshots.reduce(into: [:]) { acc, snap in
            acc[calendar.startOfDay(for: snap.date)] = snap
        }

        var results: [TrainingLoadDailyScore] = []
        for offset in (0..<14).reversed() {
            guard let dayStart = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }

            // Today is always live so the latest point matches the hero (BUG-045).
            // BUG-067 — always route today through `computeCurrentScore`. When no sleep
            // map is supplied (unlinked path), pass an empty map so every day falls
            // through to `sleepFactor = 1.0` → same algorithm shape as the linked path,
            // just sleep-neutral. This unifies the decay shape across the home widget
            // bar, unlinked detail sheet hero, chart latest point, and chip baseline.
            if offset == 0 {
                let lookbackStart = calendar.date(byAdding: .day, value: -10, to: dayStart) ?? dayStart
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                let windowWorkouts = WorkoutService.fetchWorkouts(from: lookbackStart, to: dayEnd, context: context)
                    .filter { $0.date <= now }
                let result = computeCurrentScore(
                    workouts: windowWorkouts,
                    sleepSnapshotsByDay: sleepSnapshotsByDay ?? [:],
                    targetSleepHours: targetSleepHours ?? settings.targetSleepHours,
                    experienceLevel: settings.experienceLevel,
                    targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
                    now: now
                )
                results.append(TrainingLoadDailyScore(
                    date: dayStart,
                    score: Int(result.score.rounded()),
                    zone: result.zone,
                    zoneColor: result.zoneColor
                ))
                continue
            }

            // Historical day — prefer the persisted snapshot.
            if let snapshot = snapshotsByDay[dayStart] {
                let zone = classifyZone(score: Double(snapshot.score))
                results.append(TrainingLoadDailyScore(
                    date: dayStart,
                    score: snapshot.score,
                    zone: zone.zone,
                    zoneColor: zone.zoneColor
                ))
                continue
            }

            // Pre-snapshot fallback — compute live with the baseline algorithm.
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let referenceTime = calendar.date(byAdding: .second, value: -1, to: dayEnd) ?? dayStart
            let lookbackStart = calendar.date(byAdding: .day, value: -10, to: dayStart) ?? dayStart
            let windowWorkouts = WorkoutService.fetchWorkouts(from: lookbackStart, to: dayEnd, context: context)
                .filter { $0.date <= referenceTime }
            let result = calculateLoad(
                workouts: windowWorkouts,
                experienceLevel: settings.experienceLevel,
                targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
                now: referenceTime
            )
            results.append(TrainingLoadDailyScore(
                date: dayStart,
                score: Int(result.score.rounded()),
                zone: result.zone,
                zoneColor: result.zoneColor
            ))
        }
        return results
    }

    // MARK: - Backdated Snapshot Invalidation (Phase 11)

    /// Invalidates `DailyTrainingLoadSnapshot` records within ±14 days of `affectedDate`.
    /// Called from the Workout Cascade when a workout is logged at a past date, edited
    /// to a different date, or deleted — snapshots within the 10-day decay window of the
    /// edited day are no longer accurate and need to recompute on next access.
    /// Today's snapshot is never invalidated here (it's rewritten by `captureTodaySnapshot`
    /// after the cascade); only historical days are removed.
    static func invalidateSnapshotsAroundDate(_ affectedDate: Date, context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let windowStart = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: affectedDate)),
              let windowEnd = calendar.date(byAdding: .day, value: 14, to: calendar.startOfDay(for: affectedDate))
        else { return }

        let predicate = #Predicate<DailyTrainingLoadSnapshot> {
            $0.date >= windowStart && $0.date <= windowEnd && $0.date != today
        }
        let descriptor = FetchDescriptor<DailyTrainingLoadSnapshot>(predicate: predicate)
        let affected = (try? context.fetch(descriptor)) ?? []
        for snapshot in affected {
            context.delete(snapshot)
        }
        try? context.save()
    }

    /// Returns up to `limit` workouts from the last `daysBack` days that contribute to today's score,
    /// sorted by descending stress-load contribution (rendered as "training load" in user-facing copy).
    static func contributingWorkouts(
        context: ModelContext,
        now: Date = Date(),
        daysBack: Int = 7,
        limit: Int = 5
    ) -> [TrainingLoadContributor] {
        let settings = UserSettings.shared
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -daysBack, to: today) else { return [] }

        // Use the 10-day window for the algorithm; filter by the configurable lookback for contributor display.
        let lookbackStart = calendar.date(byAdding: .day, value: -10, to: now) ?? now
        let windowWorkouts = WorkoutService.fetchWorkouts(from: lookbackStart, to: now, context: context)
            .filter { !isEmptyWorkout($0) }

        let tau = decayConstant(for: settings.experienceLevel)

        // Per-workout decayed contribution (matches Step 5 of algorithm)
        let contributions: [(Workout, Double)] = windowWorkouts.map { workout in
            let stress = sessionStress(for: workout, targetMinutesPerWorkout: settings.targetMinutesPerWorkout)
            let daysAgo = now.timeIntervalSince(workout.date) / 86400.0
            let decayed = stress * exp(-daysAgo / tau)
            return (workout, decayed)
        }

        // For "Contributing this week" we surface only workouts within the daysBack lookback.
        let recentContributions = contributions.filter { $0.0.date >= windowStart }
        let weeklyTotal = recentContributions.reduce(0.0) { $0 + $1.1 }

        let sorted = recentContributions.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return lhs.0.date > rhs.0.date
        }

        return sorted.prefix(limit).map { workout, tss in
            let percent = weeklyTotal > 0 ? Int((tss / weeklyTotal * 100).rounded()) : 0
            return TrainingLoadContributor(
                workoutId: workout.id,
                workoutName: workout.name,
                date: workout.date,
                tssContribution: tss,
                percentOfWeeklyLoad: percent
            )
        }
    }

    /// Linked-sheet variant of `contributingWorkouts`: applies the same per-day product
    /// (`1 − λ · sleepFactor(d)`) that `computeCurrentScore` uses, so each row's share
    /// reflects the sleep-adjusted view of the week. Empty `sleepSnapshotsByDay` →
    /// per-day factor collapses to 1.0 on every day → result matches `contributingWorkouts`
    /// within rounding.
    static func sleepAdjustedContributingWorkouts(
        context: ModelContext,
        sleepSnapshotsByDay: [Date: DailySleepSnapshot],
        targetSleepHours: Double,
        now: Date = Date(),
        daysBack: Int = 7,
        limit: Int = 5
    ) -> [TrainingLoadContributor] {
        let settings = UserSettings.shared
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -daysBack, to: today) else { return [] }

        let lookbackStart = calendar.date(byAdding: .day, value: -10, to: now) ?? now
        let windowWorkouts = WorkoutService.fetchWorkouts(from: lookbackStart, to: now, context: context)
            .filter { !isEmptyWorkout($0) }

        let tau = decayConstant(for: settings.experienceLevel)
        let lambda = 1.0 - exp(-1.0 / tau)

        // Per-workout sleep-adjusted contribution — discrete per-day product across
        // (logDay+1)…today. Mirrors the inner sum in `computeCurrentScore` so the rows'
        // shares are commensurate with the hero, the chart's latest point, and the chip.
        let contributions: [(Workout, Double)] = windowWorkouts.map { workout in
            let baselineStress = sessionStress(for: workout, targetMinutesPerWorkout: settings.targetMinutesPerWorkout)
            let logDay = calendar.startOfDay(for: workout.date)
            var contribution = baselineStress
            var d = calendar.date(byAdding: .day, value: 1, to: logDay) ?? today
            while d <= today {
                let factor = perDayFactor(for: d, snapshotsByDay: sleepSnapshotsByDay, targetSleepHours: targetSleepHours)
                contribution *= (1.0 - lambda * factor)
                guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
                d = next
            }
            return (workout, contribution)
        }

        let recentContributions = contributions.filter { $0.0.date >= windowStart }
        let weeklyTotal = recentContributions.reduce(0.0) { $0 + $1.1 }

        let sorted = recentContributions.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return lhs.0.date > rhs.0.date
        }

        return sorted.prefix(limit).map { workout, tss in
            let percent = weeklyTotal > 0 ? Int((tss / weeklyTotal * 100).rounded()) : 0
            return TrainingLoadContributor(
                workoutId: workout.id,
                workoutName: workout.name,
                date: workout.date,
                tssContribution: tss,
                percentOfWeeklyLoad: percent
            )
        }
    }

    // MARK: - Sleep-Adjusted Decay (Phase 11)

    /// Per-day sleep factor — slows decay when last night fell below target.
    /// `sleepFactor = clamp(0.60 + 0.40 × min(sleepRatio, 1.0), 0.60, 1.0)`
    /// See SERVICES.md § Training Load Algorithm → Sleep-Adjusted Decay.
    static func sleepFactor(sleepRatio: Double) -> Double {
        let clampedRatio = min(max(sleepRatio, 0.0), 1.0)
        let value = 0.60 + 0.40 * clampedRatio
        return min(max(value, 0.60), 1.0)
    }

    /// Sleep-adjusted equivalent of `calculateLoad`. When `sleepSnapshotsByDay` is nil
    /// (i.e., `HomeWidgetService.isLinkedActive == false`), behavior is identical to
    /// `calculateLoad`. When non-nil, per-workout contribution uses a discrete per-day
    /// product where each intervening day's decay rate is multiplied by `sleepFactor(d)`.
    ///
    /// Days without a `DailySleepSnapshot` use `sleepFactor = 1.0` (missing-data fallback).
    /// SERVICES.md § Training Load Algorithm → Sleep-Adjusted Decay.
    static func computeCurrentScore(
        workouts: [Workout],
        sleepSnapshotsByDay: [Date: DailySleepSnapshot]?,
        targetSleepHours: Double,
        experienceLevel: Int,
        targetMinutesPerWorkout: Int,
        now: Date = Date()
    ) -> LoadResult {
        guard let sleepSnapshotsByDay else {
            return calculateLoad(
                workouts: workouts,
                experienceLevel: experienceLevel,
                targetMinutesPerWorkout: targetMinutesPerWorkout,
                now: now
            )
        }

        let qualifyingWorkouts = workouts.filter { !isEmptyWorkout($0) }
        guard !qualifyingWorkouts.isEmpty else { return classifyZone(score: 0) }

        let tau = decayConstant(for: experienceLevel)
        let capacity = stressCapacity(for: experienceLevel)
        // Discrete-day decay rate equivalent to the continuous τ.
        // When sleepFactor = 1.0 on all days, the per-day product equals
        // exp(-daysAgo/τ), matching baseline decay to within day-rounding error.
        let lambda = 1.0 - exp(-1.0 / tau)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        let rawStress = qualifyingWorkouts.reduce(0.0) { sum, workout in
            let baselineStress = sessionStress(for: workout, targetMinutesPerWorkout: targetMinutesPerWorkout)
            let logDay = calendar.startOfDay(for: workout.date)

            // Per-day decay product across (logDay+1)…today.
            var contribution = baselineStress
            var d = calendar.date(byAdding: .day, value: 1, to: logDay) ?? today
            while d <= today {
                let factor = perDayFactor(for: d, snapshotsByDay: sleepSnapshotsByDay, targetSleepHours: targetSleepHours)
                contribution *= (1.0 - lambda * factor)
                guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
                d = next
            }
            return sum + contribution
        }

        let consecutiveMultiplier = consecutiveDaysMultiplier(workouts: qualifyingWorkouts, now: now)
        let adjustedStress = rawStress * consecutiveMultiplier
        let score = min(max((adjustedStress / capacity) * 100.0, 0.0), 100.0)

        // Same-Day Floor (unchanged from baseline algorithm — sleep doesn't affect today's
        // contribution since the decay loop runs (logDay+1)…today, which is empty for today's logs).
        let todayStart = calendar.startOfDay(for: now)
        let todayStress = qualifyingWorkouts
            .filter { calendar.startOfDay(for: $0.date) == todayStart }
            .reduce(0.0) { $0 + sessionStress(for: $1, targetMinutesPerWorkout: targetMinutesPerWorkout) }
        let floor = min(max((todayStress / capacity) * 150.0, 0.0), 80.0)
        let finalScore = max(score, floor)
        let trainedToday = todayStress > 0
        return classifyZone(score: finalScore, trainedToday: trainedToday)
    }

    /// Resolves the sleep factor for a single calendar day. Missing snapshot → 1.0 (baseline).
    private static func perDayFactor(
        for day: Date,
        snapshotsByDay: [Date: DailySleepSnapshot],
        targetSleepHours: Double
    ) -> Double {
        guard let snapshot = snapshotsByDay[day], targetSleepHours > 0 else { return 1.0 }
        let sleepHours = Double(snapshot.totalSleepMinutes) / 60.0
        let ratio = sleepHours / targetSleepHours
        return sleepFactor(sleepRatio: ratio)
    }

    // MARK: - Daily Snapshot Capture (Phase 11)

    /// Upserts a `DailyTrainingLoadSnapshot` for today by computing the current score.
    /// Sleep-adjusted iff `wasSleepAdjusted == true` (caller passes the current
    /// `HomeWidgetService.isLinkedActive(...)` value). Historical days are immutable;
    /// only today's record is rewritten.
    ///
    /// Idempotency: if a snapshot for `date` already exists with the same `score` AND
    /// `wasSleepAdjusted`, no write occurs.
    @discardableResult
    static func captureDailySnapshot(
        date: Date = .now,
        score: Int,
        wasSleepAdjusted: Bool,
        context: ModelContext
    ) -> DailyTrainingLoadSnapshot? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let predicate = #Predicate<DailyTrainingLoadSnapshot> { $0.date == dayStart }
        let descriptor = FetchDescriptor<DailyTrainingLoadSnapshot>(predicate: predicate)

        if let existing = (try? context.fetch(descriptor))?.first {
            if existing.score == score && existing.wasSleepAdjusted == wasSleepAdjusted {
                return existing // idempotent — no SwiftData churn
            }
            existing.score = score
            existing.wasSleepAdjusted = wasSleepAdjusted
            existing.capturedDate = .now
            try? context.save()
            return existing
        }

        let snapshot = DailyTrainingLoadSnapshot(date: dayStart, score: score, wasSleepAdjusted: wasSleepAdjusted)
        context.insert(snapshot)
        try? context.save()
        return snapshot
    }

    /// Convenience wrapper: computes today's score from current workouts + sleep data
    /// and upserts the snapshot. Caller passes `sleepAdjusted` reflecting the current
    /// linking state (Phase 11 Step 5 wires this from `HomeWidgetService.isLinkedActive`).
    @discardableResult
    static func captureTodaySnapshot(
        context: ModelContext,
        sleepAdjusted: Bool = false,
        sleepSnapshotsByDay: [Date: DailySleepSnapshot]? = nil,
        targetSleepHours: Double = 7.0,
        now: Date = Date()
    ) -> DailyTrainingLoadSnapshot? {
        let settings = UserSettings.shared
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -10, to: now) ?? now
        let workouts = WorkoutService.fetchWorkouts(from: cutoff, to: now, context: context)
        let result: LoadResult
        if sleepAdjusted, let map = sleepSnapshotsByDay {
            result = computeCurrentScore(
                workouts: workouts,
                sleepSnapshotsByDay: map,
                targetSleepHours: targetSleepHours,
                experienceLevel: settings.experienceLevel,
                targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
                now: now
            )
        } else {
            result = calculateLoad(
                workouts: workouts,
                experienceLevel: settings.experienceLevel,
                targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
                now: now
            )
        }
        return captureDailySnapshot(
            date: now,
            score: Int(result.score.rounded()),
            wasSleepAdjusted: sleepAdjusted,
            context: context
        )
    }

    /// Reads persisted snapshots covering the inclusive date interval, oldest first.
    /// Days without a snapshot are not represented — callers treat gaps as nil.
    /// Powers the Trends `trainingLoadTrend` chart and the linked detail sheet 14-day chart.
    static func snapshots(for range: DateInterval, context: ModelContext) -> [DailyTrainingLoadSnapshot] {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: range.start)
        let endDay = calendar.startOfDay(for: range.end)
        let predicate = #Predicate<DailyTrainingLoadSnapshot> { $0.date >= startDay && $0.date <= endDay }
        var descriptor = FetchDescriptor<DailyTrainingLoadSnapshot>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.date, order: .forward)]
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Compares this-week-so-far stress-load sum to the same Mon-through-current-weekday
    /// span of the prior ISO week, returning rounded values and delta percent.
    ///
    /// Uses **raw** `sessionStress` (no time decay) per window so the comparison reflects
    /// actual workload performed — not residual fatigue. Time decay is appropriate for
    /// live readiness/fatigue (the Training Load score), but applying it here makes the
    /// prior week's contributions arbitrarily small relative to this week's purely because
    /// of the 7–13 day age offset, producing absurd deltas (BUG-057, e.g. "↑ 51843%").
    ///
    /// Both windows are clipped to the same day-of-week offset from their respective ISO
    /// Mondays (Mon–Thu vs Mon–Thu on a Thursday, etc.). On Sunday this collapses to a
    /// full-week-vs-full-week comparison. Without this clip a partial in-progress week was
    /// being divided into a full prior week, producing structurally biased deltas (BUG-066).
    static func weekOverWeekComparison(context: ModelContext, now: Date = Date()) -> TrainingLoadWeekComparison {
        let settings = UserSettings.shared
        let isoCalendar = Calendar(identifier: .iso8601)
        let calendar = Calendar.current

        let currentWeekStart = now.startOfWeek

        guard let prevWeekStart = isoCalendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) else {
            return TrainingLoadWeekComparison(currentWeekTss: 0, previousWeekTss: 0, deltaPct: 0, matchedDayCount: 0)
        }

        // Day offset from this week's Monday to `now` (0 on Mon … 6 on Sun).
        let dayOffset = max(0, min(6, calendar.dateComponents([.day], from: currentWeekStart, to: now).day ?? 0))
        let matchedDayCount = dayOffset + 1

        // Prior-week endpoint matched to the same day-of-week as `now`, at end-of-day.
        guard let prevMatchedDay = isoCalendar.date(byAdding: .day, value: dayOffset, to: prevWeekStart),
              let prevMatchedEnd = isoCalendar.date(bySettingHour: 23, minute: 59, second: 59, of: prevMatchedDay) else {
            return TrainingLoadWeekComparison(currentWeekTss: 0, previousWeekTss: 0, deltaPct: 0, matchedDayCount: matchedDayCount)
        }

        let totalLookbackStart = calendar.date(byAdding: .day, value: -10, to: prevWeekStart) ?? prevWeekStart
        let workouts = WorkoutService.fetchWorkouts(from: totalLookbackStart, to: now, context: context)
            .filter { !isEmptyWorkout($0) }

        func rawSum(in range: ClosedRange<Date>) -> Double {
            workouts
                .filter { range.contains($0.date) }
                .reduce(0.0) { sum, workout in
                    sum + sessionStress(for: workout, targetMinutesPerWorkout: settings.targetMinutesPerWorkout)
                }
        }

        let currentTss = rawSum(in: currentWeekStart...now)
        let previousTss = rawSum(in: prevWeekStart...prevMatchedEnd)

        let deltaPct: Int
        if previousTss > 0 {
            deltaPct = Int(((currentTss - previousTss) / previousTss * 100).rounded())
        } else {
            deltaPct = 0
        }

        return TrainingLoadWeekComparison(
            currentWeekTss: Int(currentTss.rounded()),
            previousWeekTss: Int(previousTss.rounded()),
            deltaPct: deltaPct,
            matchedDayCount: matchedDayCount
        )
    }
}
