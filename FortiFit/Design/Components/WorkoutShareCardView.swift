import SwiftUI

struct WorkoutShareCardView: View {
    let workout: Workout
    let userSettings: UserSettings

    private var isStrengthOrHIIT: Bool {
        workout.workoutType == "Strength Training" || workout.workoutType == "HIIT"
    }

    private var isCardioOrSprints: Bool {
        workout.workoutType == "Cardio"
    }

    private var sortedExerciseSets: [ExerciseSet] {
        workout.exerciseSets.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Groups exercises by name, preserving sort order, and returns (name, sets) tuples.
    private var groupedExercises: [(name: String, sets: [ExerciseSet])] {
        let sorted = sortedExerciseSets
        let grouped = Dictionary(grouping: sorted, by: { $0.exerciseName })
        var seen = Set<String>()
        var result: [(name: String, sets: [ExerciseSet])] = []
        for set in sorted {
            if seen.insert(set.exerciseName).inserted {
                result.append((name: set.exerciseName, sets: grouped[set.exerciseName] ?? []))
            }
        }
        return result
    }

    private let maxExercises = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Workout name
            Text(workout.name)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(FortiFitColors.primaryAccent)
                .lineLimit(2)
                .truncationMode(.tail)

            // Signature divider
            FortiFitDivider()

            // Date/time line
            Text(dateTimeLine)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FortiFitColors.primaryAccent)

            // Workout type
            Text(workout.workoutType)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FortiFitColors.secondaryText)

            // Summary pills
            if hasSummaryPills {
                summaryPillsRow
            }

            // Exercises section (Strength/HIIT only)
            if isStrengthOrHIIT && !workout.exerciseSets.isEmpty {
                exercisesSection
            }

            // Footer divider + branding
            Rectangle()
                .fill(FortiFitColors.border)
                .frame(height: 1)
                .padding(.top, 4)

            Text("✦ FitNavi")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(FortiFitColors.primaryAccent)
                .kerning(2)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(20)
        .background(FortiFitColors.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FortiFitColors.border, lineWidth: 1)
        )
        .frame(width: 390)
    }

    // MARK: - Date/Time

    private var dateTimeLine: String {
        let dateStr = workout.date.shortFormatted
        if let time = workout.time {
            return "\(dateStr) · \(time.timeFormatted)"
        }
        return dateStr
    }

    // MARK: - Summary Pills

    private var hasSummaryPills: Bool {
        workout.rpe != nil || workout.durationMinutes != nil || (isCardioOrSprints && workout.distanceKm != nil)
    }

    private var summaryPillsRow: some View {
        HStack(spacing: 8) {
            if let rpe = workout.rpe {
                summaryPill(label: "EFFORT", value: "\(rpe)", field: "RPE")
            }
            if let duration = workout.durationMinutes {
                summaryPill(label: "DURATION", value: "\(duration) min", field: "Duration")
            }
            if isCardioOrSprints, let distance = workout.distanceKm {
                summaryPill(label: "DISTANCE", value: UnitConversion.displayDistance(distance, useMiles: userSettings.useMiles), field: "Distance")
            }
        }
    }

    private func summaryPill(label: String, value: String, field: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                if let symbolName = AppConstants.summaryFieldSymbols[field] {
                    Image(systemName: symbolName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(FortiFitColors.mutedText)
                }
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FortiFitColors.mutedText)
                    .kerning(1)
            }
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(FortiFitColors.primaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(FortiFitColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(FortiFitColors.border, lineWidth: 1)
        )
    }

    // MARK: - Exercises

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section divider
            Rectangle()
                .fill(FortiFitColors.border)
                .frame(height: 1)

            Text("EXERCISES")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(FortiFitColors.primaryAccent)
                .kerning(2)

            let exercises = groupedExercises
            let displayCount = min(exercises.count, maxExercises)
            let overflow = exercises.count - maxExercises

            ForEach(0..<displayCount, id: \.self) { index in
                let exercise = exercises[index]
                exerciseRow(name: exercise.name, sets: exercise.sets)
            }

            if overflow > 0 {
                Text("+\(overflow) more exercises")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FortiFitColors.mutedText)
                    .padding(.top, 2)
            }
        }
    }

    private func exerciseRow(name: String, sets: [ExerciseSet]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(FortiFitColors.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)

            ForEach(sets) { exerciseSet in
                Text(setDetailText(exerciseSet))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FortiFitColors.secondaryText)
            }
        }
    }

    private func setDetailText(_ exerciseSet: ExerciseSet) -> String {
        if let weightKg = exerciseSet.weightKg {
            let weightStr = UnitConversion.displayWeight(weightKg, useLbs: userSettings.useLbs)
            return "\(exerciseSet.sets) × \(exerciseSet.reps) @ \(weightStr)"
        } else {
            return "\(exerciseSet.sets) × \(exerciseSet.reps) (BW)"
        }
    }
}
