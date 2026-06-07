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

            // Date/time line
            Text(dateTimeLine)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FortiFitColors.primaryAccent)

            // Workout type
            Text(workout.workoutType)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FortiFitColors.secondaryText)

            FortiFitDivider()

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
        let iconColor: Color
        let valueColor: Color
        var effortRPE: Int? = nil
    }

    private var shareCardStats: [ShareStatData] {
        var cards: [ShareStatData] = []

        if let rpe = workout.rpe {
            let bandColor = AppConstants.effortColor(for: rpe)
            cards.append(ShareStatData(
                symbol: WorkoutMetric.effort.sfSymbol,
                label: "Effort",
                value: AppConstants.effortLabel(for: rpe),
                unit: nil,
                iconColor: bandColor,
                valueColor: bandColor,
                effortRPE: rpe
            ))
        }
        if let duration = workout.durationMinutes {
            let color = AppConstants.statCardColor(for: .duration)
            cards.append(ShareStatData(
                symbol: WorkoutMetric.duration.sfSymbol,
                label: "Duration",
                value: "\(duration)",
                unit: "min",
                iconColor: color,
                valueColor: color,

            ))
        }
        if let avg = workout.avgHeartRate {
            let color = AppConstants.statCardColor(for: .avgHR)
            cards.append(ShareStatData(
                symbol: WorkoutMetric.avgHR.sfSymbol,
                label: "Avg HR",
                value: "\(avg)",
                unit: "bpm",
                iconColor: color,
                valueColor: color,

            ))
        }
        if let max = workout.maxHeartRate {
            let color = AppConstants.statCardColor(for: .maxHR)
            cards.append(ShareStatData(
                symbol: WorkoutMetric.maxHR.sfSymbol,
                label: "Max HR",
                value: "\(max)",
                unit: "bpm",
                iconColor: color,
                valueColor: color,

            ))
        }
        if let active = workout.activeEnergyKcal {
            let color = AppConstants.statCardColor(for: .activeKcal)
            cards.append(ShareStatData(
                symbol: WorkoutMetric.activeKcal.sfSymbol,
                label: "Active kcal",
                value: "\(Int(active))",
                unit: "kcal",
                iconColor: color,
                valueColor: color,

            ))
        }
        if let total = workout.totalEnergyBurnedKcal {
            let color = AppConstants.statCardColor(for: .totalKcal)
            cards.append(ShareStatData(
                symbol: WorkoutMetric.totalKcal.sfSymbol,
                label: "Total kcal",
                value: "\(Int(total))",
                unit: "kcal",
                iconColor: color,
                valueColor: color,

            ))
        }
        if let elevation = workout.elevationAscendedMeters {
            let color = AppConstants.statCardColor(for: .elevation)
            if userSettings.useMiles {
                cards.append(ShareStatData(
                    symbol: WorkoutMetric.elevation.sfSymbol,
                    label: "Elevation",
                    value: "\(Int(elevation * UnitConversion.metersToFeetFactor))",
                    unit: "ft",
                    iconColor: color,
                    valueColor: color,
    
                ))
            } else {
                cards.append(ShareStatData(
                    symbol: WorkoutMetric.elevation.sfSymbol,
                    label: "Elevation",
                    value: "\(Int(elevation))",
                    unit: "m",
                    iconColor: color,
                    valueColor: color,
    
                ))
            }
        }
        if let exerciseMin = workout.exerciseMinutes {
            let color = AppConstants.statCardColor(for: .exerciseMinutes)
            cards.append(ShareStatData(
                symbol: WorkoutMetric.exerciseMinutes.sfSymbol,
                label: "Exercise min",
                value: "\(exerciseMin)",
                unit: "min",
                iconColor: color,
                valueColor: color,

            ))
        }
        if workout.workoutType == "Cardio", let distance = workout.distanceKm {
            let color = AppConstants.statCardColor(for: .distance)
            if userSettings.useMiles {
                cards.append(ShareStatData(
                    symbol: WorkoutMetric.distance.sfSymbol,
                    label: "Distance",
                    value: String(format: "%.1f", UnitConversion.kmToMiles(distance)),
                    unit: "mi",
                    iconColor: color,
                    valueColor: color,

                ))
            } else {
                cards.append(ShareStatData(
                    symbol: WorkoutMetric.distance.sfSymbol,
                    label: "Distance",
                    value: String(format: "%.1f", distance),
                    unit: "km",
                    iconColor: color,
                    valueColor: color,

                ))
            }
        }

        return cards
    }

    private func shareStatCard(_ data: ShareStatData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                if let rpe = data.effortRPE {
                    FortiFitEffortBars(rpe: rpe, size: 12)
                } else {
                    Image(systemName: data.symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(data.iconColor)
                }
                Text(data.label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FortiFitColors.primaryText)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(data.value)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(data.valueColor)
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
            FortiFitDivider()

            Text("Exercises")
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
