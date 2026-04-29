import SwiftUI

struct WorkoutShareCardView: View {
    let workout: Workout
    let userSettings: UserSettings

    private var isStrengthOrHIIT: Bool {
        workout.workoutType == "Strength Training" || workout.workoutType == "HIIT"
    }

    private var sortedExerciseSets: [ExerciseSet] {
        workout.exerciseSets.sorted { $0.sortOrder < $1.sortOrder }
    }

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

            FortiFitDivider()

            // Date/time line
            Text(dateTimeLine)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FortiFitColors.primaryAccent)

            // Workout type
            Text(workout.workoutType)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FortiFitColors.secondaryText)

            // Stat-card grid
            let cards = shareCardStats
            if !cards.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(cards, id: \.label) { card in
                        shareStatCard(card)
                    }
                }
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

    // MARK: - Share Stat Card Data

    private struct ShareStatData {
        let symbol: String
        let label: String
        let value: String
        let unit: String?
    }

    private var shareCardStats: [ShareStatData] {
        var cards: [ShareStatData] = []

        if let rpe = workout.rpe {
            cards.append(ShareStatData(
                symbol: WorkoutMetric.effort.sfSymbol,
                label: "Effort",
                value: AppConstants.effortLabel(for: rpe),
                unit: nil
            ))
        }
        if let duration = workout.durationMinutes {
            cards.append(ShareStatData(
                symbol: WorkoutMetric.duration.sfSymbol,
                label: "Duration",
                value: "\(duration)",
                unit: "min"
            ))
        }
        if workout.workoutType == "Cardio", let distance = workout.distanceKm {
            if userSettings.useMiles {
                cards.append(ShareStatData(
                    symbol: WorkoutMetric.distance.sfSymbol,
                    label: "Distance",
                    value: String(format: "%.1f", UnitConversion.kmToMiles(distance)),
                    unit: "mi"
                ))
            } else {
                cards.append(ShareStatData(
                    symbol: WorkoutMetric.distance.sfSymbol,
                    label: "Distance",
                    value: String(format: "%.1f", distance),
                    unit: "km"
                ))
            }
        }
        if let avg = workout.avgHeartRate {
            cards.append(ShareStatData(
                symbol: WorkoutMetric.avgHR.sfSymbol,
                label: "Avg HR",
                value: "\(avg)",
                unit: "bpm"
            ))
        }
        if let max = workout.maxHeartRate {
            cards.append(ShareStatData(
                symbol: WorkoutMetric.maxHR.sfSymbol,
                label: "Max HR",
                value: "\(max)",
                unit: "bpm"
            ))
        }
        if let active = workout.activeEnergyKcal {
            cards.append(ShareStatData(
                symbol: WorkoutMetric.activeKcal.sfSymbol,
                label: "Active kcal",
                value: "\(Int(active))",
                unit: "kcal"
            ))
        }
        if let total = workout.totalEnergyBurnedKcal {
            cards.append(ShareStatData(
                symbol: WorkoutMetric.totalKcal.sfSymbol,
                label: "Total kcal",
                value: "\(Int(total))",
                unit: "kcal"
            ))
        }
        if let elevation = workout.elevationAscendedMeters {
            if userSettings.useMiles {
                cards.append(ShareStatData(
                    symbol: WorkoutMetric.elevation.sfSymbol,
                    label: "Elevation",
                    value: "\(Int(elevation * 3.28084))",
                    unit: "ft"
                ))
            } else {
                cards.append(ShareStatData(
                    symbol: WorkoutMetric.elevation.sfSymbol,
                    label: "Elevation",
                    value: "\(Int(elevation))",
                    unit: "m"
                ))
            }
        }
        if let exerciseMin = workout.exerciseMinutes {
            cards.append(ShareStatData(
                symbol: WorkoutMetric.exerciseMinutes.sfSymbol,
                label: "Exercise min",
                value: "\(exerciseMin)",
                unit: "min"
            ))
        }

        return cards
    }

    private func shareStatCard(_ data: ShareStatData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: data.symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FortiFitColors.mutedText)
                Text(data.label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FortiFitColors.mutedText)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(data.value)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(FortiFitColors.primaryText)
                if let unit = data.unit {
                    Text(unit)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FortiFitColors.secondaryText)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FortiFitColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FortiFitColors.border, lineWidth: 1)
        )
    }

    // MARK: - Exercises

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
