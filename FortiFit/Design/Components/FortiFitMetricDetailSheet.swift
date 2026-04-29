import SwiftUI
import SwiftData
import Charts

struct FortiFitMetricDetailSheet: View {
    let workout: Workout
    let metric: WorkoutMetric
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var settings: UserSettings { UserSettings.shared }
    private var metricColor: Color { AppConstants.statCardColor(for: metric) }

    private var heroIconColor: Color {
        if metric == .effort, let rpe = workout.rpe {
            return AppConstants.effortColor(for: rpe)
        }
        return metricColor
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundStyle(FortiFitColors.mutedText)
                }
                .accessibilityIdentifier(AccessibilityID.metricDetailSheet_closeButton)
                .accessibilityLabel("Close")
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroBlock
                    comparativeBlock
                    sparklineBlock
                    prChipBlock
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(FortiFitColors.cardSurface)
    }

    // MARK: - Hero Block

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: metric.sfSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(heroIconColor)
                Text(metric.displayLabel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FortiFitColors.primaryText)
            }

            if metric == .effort, let rpe = workout.rpe {
                Text(AppConstants.effortLabel(for: rpe))
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(AppConstants.effortColor(for: rpe))
                Text("(\(rpe))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FortiFitColors.secondaryText)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(heroValueString)
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(metricColor)
                    if let unit = heroUnitString {
                        Text(unit)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FortiFitColors.secondaryText)
                    }
                }
            }
        }
    }

    // MARK: - Comparative Block

    @ViewBuilder
    private var comparativeBlock: some View {
        let avg = WorkoutMetricService.comparativeAverage(for: metric, workout: workout, context: modelContext)
        if let avg {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your typical \(workout.workoutType) session — \(formattedComparativeValue(avg))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FortiFitColors.secondaryText)
                Text(deltaDescription(average: avg))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FortiFitColors.mutedText)
            }
        } else {
            Text("Not enough data yet — log a few more sessions.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FortiFitColors.mutedText)
        }
    }

    // MARK: - Sparkline Block

    @ViewBuilder
    private var sparklineBlock: some View {
        let data = WorkoutMetricService.sparklineData(for: metric, workout: workout, context: modelContext)
        if data.count >= 3 {
            VStack(alignment: .leading, spacing: 8) {
                Chart {
                    if metric == .effort {
                        effortSparklineMarks(data: data)
                    } else {
                        ForEach(Array(data.enumerated()), id: \.offset) { _, point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(metricColor)
                        }
                    }

                    ForEach(Array(data.enumerated()), id: \.offset) { _, point in
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(isCurrentWorkoutDate(point.date) ? FortiFitColors.primaryAccent : FortiFitColors.secondaryText)
                        .symbolSize(isCurrentWorkoutDate(point.date) ? 36 : 9)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 120)
                .padding(16)
                .background(FortiFitColors.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(FortiFitColors.border, lineWidth: 1)
                )

                Text("Last 30 days · \(workout.workoutType)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FortiFitColors.mutedText)
            }
        } else {
            Text("Not enough data yet — log a few more sessions.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FortiFitColors.mutedText)
        }
    }

    @ChartContentBuilder
    private func effortSparklineMarks(data: [(date: Date, value: Double)]) -> some ChartContent {
        ForEach(0..<(data.count - 1), id: \.self) { i in
            let p1 = data[i]
            let p2 = data[i + 1]
            let segmentColor = AppConstants.effortColor(for: Int(p2.value.rounded()))

            LineMark(
                x: .value("Date", p1.date),
                y: .value("Value", p1.value),
                series: .value("Seg", i)
            )
            .foregroundStyle(segmentColor)

            LineMark(
                x: .value("Date", p2.date),
                y: .value("Value", p2.value),
                series: .value("Seg", i)
            )
            .foregroundStyle(segmentColor)
        }
    }

    // MARK: - PR Chip Block

    @ViewBuilder
    private var prChipBlock: some View {
        if WorkoutMetricService.isPersonalBest(for: metric, workout: workout, context: modelContext) {
            Text("Personal best for \(workout.workoutType)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(FortiFitColors.primaryAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(FortiFitColors.primaryAccent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helpers

    private var heroValueString: String {
        guard let val = metric.value(from: workout) else { return "—" }
        switch metric {
        case .duration, .exerciseMinutes:
            return "\(Int(val))"
        case .distance:
            if settings.useMiles {
                return String(format: "%.1f", UnitConversion.kmToMiles(val))
            }
            return String(format: "%.1f", val)
        case .avgHR, .maxHR:
            return "\(Int(val))"
        case .activeKcal, .totalKcal:
            return "\(Int(val))"
        case .elevation:
            if settings.useMiles {
                return "\(Int(val * 3.28084))"
            }
            return "\(Int(val))"
        case .effort:
            return "\(Int(val))"
        }
    }

    private var heroUnitString: String? {
        switch metric {
        case .duration, .exerciseMinutes: return "min"
        case .distance: return settings.useMiles ? "mi" : "km"
        case .avgHR, .maxHR: return "bpm"
        case .activeKcal, .totalKcal: return "kcal"
        case .elevation: return settings.useMiles ? "ft" : "m"
        case .effort: return nil
        }
    }

    private func formattedComparativeValue(_ avg: Double) -> String {
        if metric == .effort {
            let label = AppConstants.effortLabel(for: Int(avg.rounded()))
            return "\(label) (\(String(format: "%.1f", avg)))"
        }
        switch metric {
        case .duration, .exerciseMinutes:
            return "\(Int(avg.rounded())) min"
        case .distance:
            if settings.useMiles {
                return String(format: "%.1f mi", UnitConversion.kmToMiles(avg))
            }
            return String(format: "%.1f km", avg)
        case .avgHR, .maxHR:
            return "\(Int(avg.rounded())) bpm"
        case .activeKcal, .totalKcal:
            return "\(Int(avg.rounded())) kcal"
        case .elevation:
            if settings.useMiles {
                return "\(Int((avg * 3.28084).rounded())) ft"
            }
            return "\(Int(avg.rounded())) m"
        default:
            return String(format: "%.1f", avg)
        }
    }

    private func deltaDescription(average: Double) -> String {
        guard let current = metric.value(from: workout) else { return "" }
        let diff = current - average

        switch metric {
        case .effort:
            if diff > 0.5 { return "Harder than typical" }
            if diff < -0.5 { return "Easier than typical" }
            return "About typical"
        case .duration, .exerciseMinutes:
            let m = Int(diff.rounded())
            if m > 0 { return "+\(m) min vs typical" }
            if m < 0 { return "\(m) min vs typical" }
            return "About typical"
        case .distance:
            let unit = settings.useMiles ? "mi" : "km"
            let displayDiff = settings.useMiles ? diff * UnitConversion.kmToMilesFactor : diff
            if abs(displayDiff) < 0.05 { return "About typical" }
            let sign = displayDiff > 0 ? "+" : ""
            return "\(sign)\(String(format: "%.1f", displayDiff)) \(unit) vs typical"
        case .avgHR, .maxHR:
            let b = Int(diff.rounded())
            if b > 0 { return "+\(b) bpm vs typical" }
            if b < 0 { return "\(b) bpm vs typical" }
            return "About typical"
        case .activeKcal, .totalKcal:
            let k = Int(diff.rounded())
            if k > 0 { return "+\(k) kcal vs typical" }
            if k < 0 { return "\(k) fewer kcal than typical" }
            return "About typical"
        case .elevation:
            let unit = settings.useMiles ? "ft" : "m"
            let displayDiff = settings.useMiles ? diff * 3.28084 : diff
            let d = Int(displayDiff.rounded())
            if d > 0 { return "+\(d) \(unit) vs typical" }
            if d < 0 { return "\(d) \(unit) vs typical" }
            return "About typical"
        }
    }

    private func isCurrentWorkoutDate(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: workout.date)
    }
}
