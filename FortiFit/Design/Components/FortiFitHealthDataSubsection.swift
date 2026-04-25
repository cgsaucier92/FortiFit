import SwiftUI

struct FortiFitHealthDataSubsection: View {
    let workout: Workout

    private var settings: UserSettings { UserSettings.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
            if workout.avgHeartRate != nil || workout.maxHeartRate != nil {
                HStack {
                    if let avg = workout.avgHeartRate {
                        healthRow(symbol: "heart.fill", label: "Avg HR", value: "\(avg) bpm")
                    }
                    if let max = workout.maxHeartRate {
                        healthRow(symbol: "heart.fill", label: "Max HR", value: "\(max) bpm")
                    }
                }
            }

            if workout.activeEnergyKcal != nil || workout.totalEnergyBurnedKcal != nil {
                HStack {
                    if let active = workout.activeEnergyKcal {
                        healthRow(symbol: "flame.fill", label: "Active", value: "\(Int(active)) kcal")
                    }
                    if let total = workout.totalEnergyBurnedKcal {
                        healthRow(symbol: "flame", label: "Total", value: "\(Int(total)) kcal")
                    }
                }
            }

            if let elevation = workout.elevationAscendedMeters {
                let displayValue: String = {
                    if settings.useMiles {
                        let feet = elevation * 3.28084
                        return "\(Int(feet)) ft"
                    }
                    return "\(Int(elevation)) m"
                }()
                healthRow(symbol: "arrow.up.right", label: "Elevation", value: displayValue)
            }

            if let exerciseMin = workout.exerciseMinutes {
                healthRow(symbol: "figure.walk", label: "Exercise", value: "\(exerciseMin) min")
            }

            if let indoor = workout.indoor {
                healthRow(symbol: indoor ? "building.2" : "sun.max", label: "", value: indoor ? "Indoor" : "Outdoor")
            }
        }
    }

    private func healthRow(symbol: String, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundStyle(.pink)
            if !label.isEmpty {
                Text(label)
                    .font(FortiFitTypography.bodySmall)
                    .foregroundStyle(FortiFitColors.secondaryText)
            }
            Text(value)
                .font(FortiFitTypography.dataValue)
                .foregroundStyle(FortiFitColors.primaryAccent)
            Spacer()
        }
    }
}
