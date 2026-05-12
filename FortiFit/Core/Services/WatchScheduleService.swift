import Foundation
import SwiftData

// MARK: - WorkoutScheduler Protocol Types

enum WorkoutSchedulerAuthState {
    case notDetermined
    case granted
    case denied
}

struct ScheduledPlanInfo {
    let id: UUID
    let scheduledDate: Date
}

protocol WorkoutSchedulerProtocol: Sendable {
    func authorizationState() async -> WorkoutSchedulerAuthState
    func requestAuthorization() async -> WorkoutSchedulerAuthState
    func schedule(id: UUID, workoutType: String, exercises: [SnapshotExercise], at date: Date, useLbs: Bool) async throws
    func removePlan(id: UUID) async throws
    func scheduledPlans() async -> [ScheduledPlanInfo]
}

final class NoOpWorkoutScheduler: WorkoutSchedulerProtocol, @unchecked Sendable {
    func authorizationState() async -> WorkoutSchedulerAuthState { .notDetermined }
    func requestAuthorization() async -> WorkoutSchedulerAuthState { .notDetermined }
    func schedule(id: UUID, workoutType: String, exercises: [SnapshotExercise], at date: Date, useLbs: Bool) async throws {}
    func removePlan(id: UUID) async throws {}
    func scheduledPlans() async -> [ScheduledPlanInfo] { [] }
}

// MARK: - Outbound HK Mapping

enum OutboundHKMapping {
    static let workoutTypeToActivityType: [String: String] = [
        "Strength Training": "Traditional Strength Training",
        "HIIT": "HIIT"
    ]

    static func activityTypeDisplayString(for workoutType: String) -> String? {
        workoutTypeToActivityType[workoutType]
    }
}

// MARK: - WatchScheduleService

@MainActor
@Observable
final class WatchScheduleService {

    private let scheduler: WorkoutSchedulerProtocol
    private let settings = UserSettings.shared
    var authState: WorkoutSchedulerAuthState = .notDetermined
    var lastError: String?

    var onError: ((String) -> Void)?

    init(scheduler: WorkoutSchedulerProtocol) {
        self.scheduler = scheduler
    }

    // MARK: - Auth

    func refreshAuthState() async {
        authState = await scheduler.authorizationState()
    }

    func requestAuthorization() async -> WorkoutSchedulerAuthState {
        let result = await scheduler.requestAuthorization()
        authState = result
        return result
    }

    // MARK: - Sync Gates

    func gatesPass(for sw: ScheduledWorkout) -> Bool {
        guard settings.syncPlanToAppleWatchEnabled else { return false }
        guard authState == .granted else { return false }
        guard sw.scheduledDate >= Calendar.current.startOfDay(for: Date()) else { return false }
        guard let data = sw.scheduledWorkoutSnapshot,
              !PlanService.decodeSnapshot(data: data).isEmpty else { return false }
        return true
    }

    enum GateFailure: Equatable {
        case masterOff
        case authDenied
        case pastDate
        case noExercises
    }

    func gateFailureReason(for sw: ScheduledWorkout) -> GateFailure? {
        if !settings.syncPlanToAppleWatchEnabled { return .masterOff }
        if authState != .granted { return .authDenied }
        if sw.scheduledDate < Calendar.current.startOfDay(for: Date()) { return .pastDate }
        if let data = sw.scheduledWorkoutSnapshot,
           PlanService.decodeSnapshot(data: data).isEmpty { return .noExercises }
        if sw.scheduledWorkoutSnapshot == nil { return .noExercises }
        return nil
    }

    // MARK: - Schedule

    func schedule(_ sw: ScheduledWorkout, context: ModelContext) async {
        guard gatesPass(for: sw) else { return }

        if sw.appleWorkoutPlanId == nil {
            sw.appleWorkoutPlanId = UUID()
            try? context.save()
        }

        guard let planId = sw.appleWorkoutPlanId,
              let snapshotData = sw.scheduledWorkoutSnapshot else { return }

        let exercises = PlanService.decodeSnapshot(data: snapshotData)
        guard !exercises.isEmpty else { return }

        let scheduleDate: Date
        if let scheduledTime = sw.scheduledTime {
            scheduleDate = combineDateAndTime(date: sw.scheduledDate, time: scheduledTime)
        } else {
            scheduleDate = noonOnDate(sw.scheduledDate)
        }

        do {
            try await scheduler.schedule(
                id: planId,
                workoutType: sw.workoutType,
                exercises: exercises,
                at: scheduleDate,
                useLbs: settings.useLbs
            )
        } catch {
            let message = "Couldn't sync to Apple Watch. Try again later."
            lastError = message
            onError?(message)
        }
    }

    // MARK: - Remove Plan

    func removePlan(uuid: UUID?) async {
        guard let uuid else { return }
        do {
            try await scheduler.removePlan(id: uuid)
        } catch {
            let message = "Couldn't sync to Apple Watch. Try again later."
            lastError = message
            onError?(message)
        }
    }

    // MARK: - Resync (edit path)

    func resync(_ sw: ScheduledWorkout, context: ModelContext) async {
        if let planId = sw.appleWorkoutPlanId {
            await removePlan(uuid: planId)
        }
        if sw.syncToAppleWatch && gatesPass(for: sw) {
            await schedule(sw, context: context)
        }
    }

    // MARK: - Master Toggle

    func handleMasterToggleOff(context: ModelContext) async {
        let predicate = #Predicate<ScheduledWorkout> { sw in
            sw.syncToAppleWatch == true
        }
        let descriptor = FetchDescriptor<ScheduledWorkout>(predicate: predicate)
        guard let synced = try? context.fetch(descriptor) else { return }

        for sw in synced {
            await removePlan(uuid: sw.appleWorkoutPlanId)
        }
    }

    func handleMasterToggleOn(context: ModelContext) async {
        if authState == .notDetermined {
            let result = await requestAuthorization()
            if result != .granted { return }
        } else if authState != .granted {
            return
        }
        await reconcile(context: context)
    }

    // MARK: - Reconciliation

    func reconcile(context: ModelContext) async {
        guard settings.syncPlanToAppleWatchEnabled else { return }
        guard authState == .granted else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let plannedStatus = "planned"

        let registeredPlans = await scheduler.scheduledPlans()
        let registeredIds = Set(registeredPlans.map { $0.id })

        let syncedPredicate = #Predicate<ScheduledWorkout> { sw in
            sw.syncToAppleWatch == true
        }
        let descriptor = FetchDescriptor<ScheduledWorkout>(predicate: syncedPredicate)
        guard let syncedWorkouts = try? context.fetch(descriptor) else { return }

        var expectedIds = Set<UUID>()

        for sw in syncedWorkouts {
            // Past-dated sweep
            if sw.scheduledDate < today && sw.status == plannedStatus {
                await removePlan(uuid: sw.appleWorkoutPlanId)
                continue
            }

            guard gatesPass(for: sw) else { continue }
            guard let planId = sw.appleWorkoutPlanId else {
                await schedule(sw, context: context)
                if let newId = sw.appleWorkoutPlanId {
                    expectedIds.insert(newId)
                }
                continue
            }

            expectedIds.insert(planId)

            if !registeredIds.contains(planId) {
                await schedule(sw, context: context)
            }
        }

        // Orphan cleanup
        for plan in registeredPlans {
            if !expectedIds.contains(plan.id) {
                await removePlan(uuid: plan.id)
            }
        }
    }

    // MARK: - Helpers

    private func noonOnDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }

    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        return calendar.date(from: combined) ?? date
    }
}
