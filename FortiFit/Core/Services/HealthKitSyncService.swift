import Foundation
import SwiftData
import BackgroundTasks

@MainActor
@Observable
final class HealthKitSyncService {
    static let backgroundTaskIdentifier = "com.fortifit.healthkit.refresh"

    private let client: HealthKitClient
    private let matcher: WorkoutMatcher
    private let settings = UserSettings.shared
    private(set) var isSyncing = false

    init(client: HealthKitClient, matcher: WorkoutMatcher) {
        self.client = client
        self.matcher = matcher
    }

    // MARK: - Lifecycle

    func startObserving() {
        guard settings.healthKitEnabled else { return }
        client.observeWorkoutChanges { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                guard let context = self.activeContext else { return }
                await self.importPendingWorkouts(context: context)
            }
        }
        client.observeEffortScoreChanges { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                guard let context = self.activeContext else { return }
                await self.backfillMissingEffortScores(context: context)
            }
        }
    }

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.backgroundTaskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor [weak self] in
                guard let self, let context = self.activeContext else {
                    refreshTask.setTaskCompleted(success: false)
                    return
                }
                await self.importPendingWorkouts(context: context)
                refreshTask.setTaskCompleted(success: true)
                self.scheduleBackgroundRefresh()
            }
        }
        scheduleBackgroundRefresh()
    }

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Enable / Disable

    func enable(context: ModelContext) async {
        settings.healthKitEnabled = true
        do {
            try await client.requestAuthorization()
        } catch {
            return
        }
        await importPendingWorkouts(context: context)
        startObserving()
        registerBackgroundTask()
    }

    func disable() {
        settings.healthKitEnabled = false
    }

    // MARK: - Import Pipeline

    private var activeContext: ModelContext?

    func setContext(_ context: ModelContext) {
        self.activeContext = context
    }

    func importPendingWorkouts(context: ModelContext) async {
        guard settings.healthKitEnabled else { return }
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let result = try await client.fetchWorkouts(since: settings.healthKitAnchor)

            for deletedUUID in result.deletedUUIDs {
                handleUpstreamDelete(healthKitUUID: deletedUUID, context: context)
            }

            for snapshot in result.workouts {
                await processSnapshot(snapshot, context: context)
            }

            settings.healthKitAnchor = result.newAnchor
            settings.healthKitLastSyncDate = .now
            try? context.save()

            await backfillMissingEffortScores(context: context)
        } catch {
            // Anchor not updated on failure; next sync retries from last good anchor
        }
    }

    private func processSnapshot(_ snapshot: HealthKitWorkoutSnapshot, context: ModelContext) async {
        if let existing = fetchWorkoutByHKUUID(snapshot.uuid, context: context) {
            await handleUpstreamUpdate(existing: existing, snapshot: snapshot, context: context)
            return
        }

        let matchResult = matcher.findMatch(forIncomingHKWorkout: snapshot, context: context)

        switch matchResult {
        case .highConfidence(let workoutId):
            if let workout = fetchWorkoutById(workoutId, context: context) {
                WorkoutMatcher.applyLink(workout: workout, snapshot: snapshot)
                await applyEffortScoreIfNeeded(workout: workout, snapshot: snapshot)
                try? context.save()
            }
        case .lowerConfidence(let workoutId):
            matcher.queuePendingMatch(workoutId: workoutId, snapshot: snapshot)
        case .noMatch:
            if snapshot.durationMinutes < 2 { return }
            autoCreate(from: snapshot, context: context)
            await applyEffortScoreIfNeeded(snapshot: snapshot, context: context)
        }
    }

    // MARK: - Auto-Create

    private func autoCreate(from snapshot: HealthKitWorkoutSnapshot, context: ModelContext) {
        let mapping = snapshot.mapping
        let name = mapping.displayString

        let workout = Workout(
            name: name,
            date: snapshot.startDate,
            workoutType: mapping.workoutType,
            durationMinutes: snapshot.durationMinutes,
            distanceKm: snapshot.distanceKm,
            time: snapshot.startDate,
            healthKitUUID: snapshot.uuid,
            healthKitSourceBundleID: snapshot.sourceBundleID,
            healthKitActivityType: mapping.displayString,
            avgHeartRate: snapshot.avgHeartRate,
            maxHeartRate: snapshot.maxHeartRate,
            activeEnergyKcal: snapshot.activeEnergyKcal,
            totalEnergyBurnedKcal: snapshot.totalEnergyBurnedKcal,
            elevationAscendedMeters: snapshot.elevationAscendedMeters,
            exerciseMinutes: snapshot.exerciseMinutes,
            indoor: snapshot.indoor
        )

        WorkoutService.logWorkout(workout, context: context)
        WorkoutTypeOrderService.ensureOrderExists(for: mapping.workoutType, context: context)
        GoalService.recalculateGoals(
            affectedExerciseNames: [],
            affectedWorkoutTypes: [mapping.workoutType],
            workout: workout,
            context: context
        )
    }

    // MARK: - Upstream Update

    private func handleUpstreamUpdate(existing: Workout, snapshot: HealthKitWorkoutSnapshot, context: ModelContext) async {
        existing.date = snapshot.startDate
        existing.durationMinutes = snapshot.durationMinutes
        existing.distanceKm = snapshot.distanceKm
        existing.avgHeartRate = snapshot.avgHeartRate
        existing.maxHeartRate = snapshot.maxHeartRate
        existing.activeEnergyKcal = snapshot.activeEnergyKcal
        existing.totalEnergyBurnedKcal = snapshot.totalEnergyBurnedKcal
        existing.elevationAscendedMeters = snapshot.elevationAscendedMeters
        existing.exerciseMinutes = snapshot.exerciseMinutes
        existing.indoor = snapshot.indoor
        existing.healthKitActivityType = snapshot.mapping.displayString
        existing.lastModifiedDate = .now
        await applyEffortScoreIfNeeded(workout: existing, snapshot: snapshot)
        try? context.save()
    }

    // MARK: - Upstream Delete

    private func handleUpstreamDelete(healthKitUUID: UUID, context: ModelContext) {
        guard let workout = fetchWorkoutByHKUUID(healthKitUUID, context: context) else { return }
        workout.healthKitUUID = nil
        workout.healthKitSourceBundleID = nil
        workout.healthKitActivityType = nil
        workout.lastModifiedDate = .now
        try? context.save()
    }

    // MARK: - Effort Score

    private func applyEffortScoreIfNeeded(workout: Workout, snapshot: HealthKitWorkoutSnapshot) async {
        guard workout.rpe == nil else { return }
        guard let score = try? await client.fetchEffortScore(for: snapshot.uuid) else { return }
        workout.rpe = score
    }

    private func applyEffortScoreIfNeeded(snapshot: HealthKitWorkoutSnapshot, context: ModelContext) async {
        guard let workout = fetchWorkoutByHKUUID(snapshot.uuid, context: context) else { return }
        await applyEffortScoreIfNeeded(workout: workout, snapshot: snapshot)
    }

    // MARK: - Effort Score Backfill

    func backfillMissingEffortScores(context: ModelContext) async {
        let predicate = #Predicate<Workout> { workout in
            workout.healthKitUUID != nil && workout.rpe == nil
        }
        let descriptor = FetchDescriptor<Workout>(predicate: predicate)
        guard let workouts = try? context.fetch(descriptor) else { return }

        var changed = false
        for workout in workouts {
            guard let hkUUID = workout.healthKitUUID else { continue }
            guard let score = try? await client.fetchEffortScore(for: hkUUID) else { continue }
            workout.rpe = score
            changed = true
        }
        if changed {
            try? context.save()
        }
    }

    // MARK: - Queries

    private func fetchWorkoutByHKUUID(_ uuid: UUID, context: ModelContext) -> Workout? {
        let predicate = #Predicate<Workout> { workout in
            workout.healthKitUUID == uuid
        }
        let descriptor = FetchDescriptor<Workout>(predicate: predicate)
        return (try? context.fetch(descriptor))?.first
    }

    private func fetchWorkoutById(_ id: UUID, context: ModelContext) -> Workout? {
        let predicate = #Predicate<Workout> { workout in
            workout.id == id
        }
        let descriptor = FetchDescriptor<Workout>(predicate: predicate)
        return (try? context.fetch(descriptor))?.first
    }
}
