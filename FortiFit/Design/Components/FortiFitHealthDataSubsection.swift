import SwiftUI

struct SummaryItem: Identifiable {
    let id = UUID()
    let symbol: String
    let symbolColor: Color
    let label: String
    let value: String
}

struct FortiFitSummaryGrid: View {
    let items: [SummaryItem]

    private let columns = [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
            ForEach(items) { item in
                HStack(spacing: 4) {
                    Image(systemName: item.symbol)
                        .font(FortiFitTypography.body)
                        .foregroundStyle(item.symbolColor)
                    if !item.label.isEmpty {
                        Text(item.label)
                            .font(FortiFitTypography.body)
                            .foregroundStyle(FortiFitColors.primaryText)
                    }
                    Text(item.value)
                        .font(FortiFitTypography.dataValue)
                        .foregroundStyle(FortiFitColors.primaryAccent)
                }
            }
        }
    }
}

enum SummaryItemBuilder {
    static func items(for workout: Workout, useLbs: Bool = UserSettings.shared.useLbs, useMiles: Bool = UserSettings.shared.useMiles) -> [SummaryItem] {
        var result: [SummaryItem] = []

        // Pair: RPE | Duration
        if let rpe = workout.rpe {
            result.append(SummaryItem(
                symbol: AppConstants.summaryFieldSymbols["RPE"] ?? "gauge",
                symbolColor: FortiFitColors.primaryText,
                label: "Effort",
                value: "\(rpe)"
            ))
        }
        if let duration = workout.durationMinutes {
            result.append(SummaryItem(
                symbol: AppConstants.summaryFieldSymbols["Duration"] ?? "clock",
                symbolColor: FortiFitColors.primaryText,
                label: "Duration",
                value: "\(duration) min"
            ))
        }
        // Pair: Distance | Elevation
        if let distance = workout.distanceKm {
            result.append(SummaryItem(
                symbol: AppConstants.summaryFieldSymbols["Distance"] ?? "ruler",
                symbolColor: FortiFitColors.primaryText,
                label: "Distance",
                value: UnitConversion.displayDistance(distance, useMiles: useMiles)
            ))
        }
        if let elevation = workout.elevationAscendedMeters {
            let displayValue = useMiles ? "\(Int(elevation * 3.28084)) ft" : "\(Int(elevation)) m"
            result.append(SummaryItem(
                symbol: "arrow.up.right",
                symbolColor: FortiFitColors.primaryText,
                label: "Elevation",
                value: displayValue
            ))
        }
        // Pair: Avg HR | Max HR
        if let avg = workout.avgHeartRate {
            result.append(SummaryItem(
                symbol: "heart.fill",
                symbolColor: FortiFitColors.primaryText,
                label: "Avg HR",
                value: "\(avg) bpm"
            ))
        }
        if let max = workout.maxHeartRate {
            result.append(SummaryItem(
                symbol: "heart.fill",
                symbolColor: FortiFitColors.primaryText,
                label: "Max HR",
                value: "\(max) bpm"
            ))
        }
        // Pair: Active | Total
        if let active = workout.activeEnergyKcal {
            result.append(SummaryItem(
                symbol: "flame.fill",
                symbolColor: FortiFitColors.primaryText,
                label: "Active",
                value: "\(Int(active)) kcal"
            ))
        }
        if let total = workout.totalEnergyBurnedKcal {
            result.append(SummaryItem(
                symbol: "flame",
                symbolColor: FortiFitColors.primaryText,
                label: "Total",
                value: "\(Int(total)) kcal"
            ))
        }
        if let exerciseMin = workout.exerciseMinutes {
            result.append(SummaryItem(
                symbol: "figure.walk",
                symbolColor: FortiFitColors.primaryText,
                label: "Exercise",
                value: "\(exerciseMin) min"
            ))
        }

        return result
    }
}
