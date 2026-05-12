import Foundation
import WorkoutKit
import HealthKit

final class DefaultWorkoutScheduler: WorkoutSchedulerProtocol, @unchecked Sendable {

    private let scheduler = WorkoutScheduler.shared

    func authorizationState() async -> WorkoutSchedulerAuthState {
        mapAuthState(scheduler.authorizationState)
    }

    func requestAuthorization() async -> WorkoutSchedulerAuthState {
        let result = await scheduler.requestAuthorization()
        return mapAuthState(result)
    }

    func schedule(
        id: UUID,
        workoutType: String,
        exercises: [SnapshotExercise],
        at date: Date,
        useLbs: Bool
    ) async throws {
        let customWorkout = buildCustomWorkout(
            workoutType: workoutType,
            exercises: exercises,
            useLbs: useLbs
        )

        let plan = WorkoutPlan(.custom(customWorkout), id: id)
        var dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        dateComponents.calendar = Calendar.current
        await scheduler.schedule(plan, at: dateComponents)
    }

    func removePlan(id: UUID) async throws {
        let scheduled = await scheduler.scheduledWorkouts
        guard let match = scheduled.first(where: { $0.plan.id == id }) else { return }
        await scheduler.remove(match.plan, at: match.date)
    }

    func scheduledPlans() async -> [ScheduledPlanInfo] {
        let scheduled = await scheduler.scheduledWorkouts
        return scheduled.map { plan in
            let date = Calendar.current.date(from: plan.date) ?? Date()
            return ScheduledPlanInfo(id: plan.plan.id, scheduledDate: date)
        }
    }

    // MARK: - Plan Composition

    private func buildCustomWorkout(
        workoutType: String,
        exercises: [SnapshotExercise],
        useLbs: Bool
    ) -> CustomWorkout {
        let activityType = resolveActivityType(workoutType)
        let blocks = exercises.map { exercise in
            buildIntervalBlock(for: exercise, useLbs: useLbs)
        }
        return CustomWorkout(
            activity: activityType,
            location: .indoor,
            displayName: nil,
            blocks: blocks
        )
    }

    private func buildIntervalBlock(
        for exercise: SnapshotExercise,
        useLbs: Bool
    ) -> IntervalBlock {
        let isTime = exercise.displayAsTime ?? ExerciseSuggestionService.isIsometric(exercise.exerciseName)
        var steps: [IntervalStep] = []

        for setIndex in 0..<exercise.sets {
            let workGoal: WorkoutGoal = isTime
                ? .time(Double(exercise.reps), .seconds)
                : .open

            let displayName = stepDisplayName(
                exerciseName: exercise.exerciseName,
                reps: exercise.reps,
                weightKg: exercise.weightKg,
                isTime: isTime,
                useLbs: useLbs
            )

            let workStep = WorkoutStep(goal: workGoal, displayName: displayName)
            steps.append(IntervalStep(.work, step: workStep))

            let isLastSet = setIndex == exercise.sets - 1
            if !isLastSet, let restSeconds = exercise.restSeconds, restSeconds > 0 {
                let recoveryGoal = WorkoutGoal.time(Double(restSeconds), .seconds)
                let recoveryStep = WorkoutStep(goal: recoveryGoal, displayName: "Rest")
                steps.append(IntervalStep(.recovery, step: recoveryStep))
            }
        }

        return IntervalBlock(steps: steps, iterations: 1)
    }

    private func stepDisplayName(
        exerciseName: String,
        reps: Int,
        weightKg: Double?,
        isTime: Bool,
        useLbs: Bool
    ) -> String {
        let valueStr: String
        if isTime {
            valueStr = "\(reps)s"
        } else {
            valueStr = "\(reps) reps"
        }

        if let kg = weightKg {
            let weightStr: String
            if useLbs {
                let lbs = Int(round(kg * 2.205))
                weightStr = "\(lbs) lb"
            } else {
                weightStr = "\(Int(round(kg))) kg"
            }
            return "\(exerciseName) · \(valueStr) @ \(weightStr)"
        }
        return "\(exerciseName) · \(valueStr)"
    }

    private func resolveActivityType(_ workoutType: String) -> HKWorkoutActivityType {
        switch workoutType {
        case "Strength Training": return .traditionalStrengthTraining
        case "HIIT": return .highIntensityIntervalTraining
        default: return .traditionalStrengthTraining
        }
    }

    // MARK: - Helpers

    private func mapAuthState(
        _ state: WorkoutScheduler.AuthorizationState
    ) -> WorkoutSchedulerAuthState {
        switch state {
        case .notDetermined: return .notDetermined
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }
}
