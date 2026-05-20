import SwiftUI
import SwiftData
import Charts

/// Power Level Breakdown Sheet — opened by tapping the Power Level home widget.
/// Hero + 30-day volume chart + top exercises + window comparison + calculated nudge.
///
/// See SCREENS.md § Power Level Breakdown Sheet and CONSTANTS.md § Power Level Detail Sheet.
struct FortiFitPowerLevelDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var powerLevel = PowerLevelService.PowerLevelResult(
        status: .noData, statusLabel: "", indicator: "",
        indicatorColor: "737373", message: ""
    )
    @State private var topExercises: [PowerLevelService.PowerLevelTopExercise] = []
    @State private var windowComparison = PowerLevelService.PowerLevelWindowComparison(current30dAvg: 0, previous30dAvg: 0, deltaPct: 0)
    @State private var nudge = PowerLevelService.PowerLevelNudge(archetype: .coldStart, inputs: .init(), messageKey: "coldStart")
    @State private var dailyVolume: [(date: Date, volume: Double)] = []
    @State private var selectedChartIndex: Int? = nil

    var onSeeInfo: (() -> Void)?
    var onNavigateToStrengthTracker: ((String) -> Void)?

    private var qualifyingWorkoutCount: Int {
        // Count of qualifying workouts in current 30d window — informs empty-state branches
        nudge.inputs.currentSessionCount30d ?? topExercises.reduce(0) { $0 + $1.sessionCountInWindow }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FortiFitSpacing.cardPadding) {
                header
                heroBlock
                volumeChartBlock
                topExercisesBlock
                windowComparisonBlock
                nudgeBlock
                footer
            }
            .padding(.horizontal, FortiFitSpacing.screenHorizontal)
            .padding(.bottom, FortiFitSpacing.gapXLarge)
        }
        .background(FortiFitColors.cardSurface)
        .task { reload() }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FortiFitColors.mutedText)
                        .frame(width: FortiFitSpacing.minTouchTarget, height: FortiFitSpacing.minTouchTarget)
                }
                .accessibilityIdentifier(AccessibilityID.powerLevelDetailSheet_closeButton)
            }

            Text("Power Level Insights")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(FortiFitColors.primaryAccent)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, FortiFitSpacing.gapMedium)
        }
    }

    // MARK: - Hero

    private var heroBlock: some View {
        FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                if isColdStart {
                    Text("Steady")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(FortiFitColors.primaryAccent)
                    Text("—")
                        .font(.system(size: 48, weight: .black))
                        .foregroundStyle(FortiFitColors.primaryAccent)
                    Text(AppConstants.WidgetDetail.EmptyState.powerLevelHero)
                        .font(FortiFitTypography.note)
                        .foregroundStyle(FortiFitColors.mutedText)
                } else {
                    Text(powerLevel.statusLabel)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Color(hex: powerLevel.indicatorColor))
                    Text(powerLevel.indicator)
                        .font(.system(size: 48, weight: .black))
                        .foregroundStyle(Color(hex: powerLevel.indicatorColor))
                    Text(formattedAvgVolumeLine)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(FortiFitColors.primaryText)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.powerLevelDetailSheet_hero)
    }

    private var isColdStart: Bool {
        nudge.archetype == .coldStart
    }

    private var formattedAvgVolumeLine: String {
        "\(formattedVolume(windowComparison.current30dAvg)) avg volume"
    }

    // MARK: - Volume Chart

    private var volumeChartBlock: some View {
        FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                Text("Last 30 days")
                    .font(FortiFitTypography.labelSmall)
                    .kerning(FortiFitTypography.labelKerning)
                    .foregroundStyle(FortiFitColors.mutedText)

                if chartEntries.count < 2 {
                    Text(AppConstants.WidgetDetail.EmptyState.powerLevelVolumeChart)
                        .font(FortiFitTypography.note)
                        .foregroundStyle(FortiFitColors.mutedText)
                        .padding(.vertical, FortiFitSpacing.gapMedium)
                } else {
                    interactiveVolumeChart
                    selectionAnnotation
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.powerLevelDetailSheet_volumeChart)
    }

    private var chartEntries: [(date: Date, volume: Double)] {
        dailyVolume.filter { $0.volume > 0 }
    }

    /// 30-day Swift Chart with tap-to-select + drag-to-scrub selection state, matching
    /// the behavior of `FortiFitTrainingLoadDetailSheet.interactiveDailyChart`.
    private var interactiveVolumeChart: some View {
        let entries = chartEntries
        return Chart {
            ForEach(Array(entries.enumerated()), id: \.element.date) { index, entry in
                let isSelected = selectedChartIndex == index
                let isLatest = entry.date == entries.last?.date
                let isDimmed = selectedChartIndex != nil && !isSelected

                LineMark(
                    x: .value("Day", entry.date),
                    y: .value("Volume", entry.volume)
                )
                .foregroundStyle(FortiFitColors.chartPurple.opacity(selectedChartIndex == nil ? 1.0 : 0.55))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Day", entry.date),
                    y: .value("Volume", entry.volume)
                )
                .foregroundStyle(
                    (isLatest ? FortiFitColors.primaryAccent : FortiFitColors.chartPurple)
                        .opacity(isDimmed ? 0.35 : 1.0)
                )
                .symbolSize(isSelected ? 96 : (isLatest ? 64 : 20))
                .accessibilityIdentifier(AccessibilityID.powerLevelDetailSheet_chartDataPoint(index))
            }

            if let idx = selectedChartIndex, idx < entries.count {
                RuleMark(x: .value("Selected", entries[idx].date))
                    .foregroundStyle(FortiFitColors.primaryAccent.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartXAxis(.hidden)
        .chartOverlay { proxy in
            GeometryReader { _ in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                scrubChart(to: value.location, proxy: proxy)
                            }
                    )
                    .onTapGesture { location in
                        scrubChart(to: location, proxy: proxy)
                    }
            }
        }
        .frame(height: 140)
    }

    /// Renders the selected data point's volume and date below the chart.
    @ViewBuilder
    private var selectionAnnotation: some View {
        let entries = chartEntries
        if let idx = selectedChartIndex, idx < entries.count {
            let entry = entries[idx]
            HStack(spacing: FortiFitSpacing.elementSpacing) {
                Text(formattedVolume(entry.volume))
                    .font(FortiFitTypography.labelSmall)
                    .foregroundStyle(FortiFitColors.primaryAccent)
                Spacer()
                Text(entry.date.shortFormatted)
                    .font(FortiFitTypography.labelSmall)
                    .foregroundStyle(FortiFitColors.mutedText)
            }
            .accessibilityIdentifier(AccessibilityID.powerLevelDetailSheet_chartSelectionAnnotation)
        }
    }

    /// Tap/drag handler: find the chart entry whose date is closest to the gesture's
    /// x-coordinate (resolved via `ChartProxy.value(atX:)`) and select it. Fires a light
    /// haptic on selection change, matching `FortiFitTrainingLoadDetailSheet.scrubChart`.
    private func scrubChart(to location: CGPoint, proxy: ChartProxy) {
        let entries = chartEntries
        guard !entries.isEmpty else { return }
        guard let dateValue: Date = proxy.value(atX: location.x) else { return }
        var closestIndex = 0
        var closestDist = abs(entries[0].date.timeIntervalSince(dateValue))
        for i in 1..<entries.count {
            let dist = abs(entries[i].date.timeIntervalSince(dateValue))
            if dist < closestDist {
                closestDist = dist
                closestIndex = i
            }
        }
        if selectedChartIndex != closestIndex {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            selectedChartIndex = closestIndex
        }
    }

    private func formattedVolume(_ volume: Double) -> String {
        let settings = UserSettings.shared
        let display: Int
        if settings.useLbs {
            display = Int(((UnitConversion.kgToLbs(volume)) ?? 0).rounded())
        } else {
            display = Int(volume.rounded())
        }
        let unit = settings.useLbs ? "lbs" : "kg"
        return "\(display.formatted(.number)) \(unit)"
    }

    // MARK: - Top Exercises

    private var topExercisesBlock: some View {
        FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                Text("Driving your trend")
                    .font(FortiFitTypography.labelSmall)
                    .kerning(FortiFitTypography.labelKerning)
                    .foregroundStyle(FortiFitColors.mutedText)

                if topExercises.isEmpty {
                    Text(AppConstants.WidgetDetail.EmptyState.powerLevelTopExercises)
                        .font(FortiFitTypography.note)
                        .foregroundStyle(FortiFitColors.mutedText)
                        .padding(.vertical, FortiFitSpacing.gapMedium)
                } else {
                    ForEach(Array(topExercises.enumerated()), id: \.offset) { index, exercise in
                        topExerciseRow(exercise: exercise, index: index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    onNavigateToStrengthTracker?(exercise.exerciseName)
                                }
                            }
                        if index < topExercises.count - 1 {
                            Divider().background(FortiFitColors.border)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.powerLevelDetailSheet_topExercises)
    }

    private func topExerciseRow(exercise: PowerLevelService.PowerLevelTopExercise, index: Int) -> some View {
        // No prior-window data → render an em-dash instead of a misleading "+0%".
        let hasBaseline = exercise.previousWindowVolume > 0
        let sign = exercise.deltaPct >= 0 ? "+" : ""
        let deltaColor: Color
        if !hasBaseline {
            deltaColor = FortiFitColors.mutedText
        } else if exercise.deltaPct > 10 {
            deltaColor = FortiFitColors.positive
        } else if exercise.deltaPct < -10 {
            deltaColor = FortiFitColors.alert
        } else {
            deltaColor = FortiFitColors.primaryAccent
        }
        let deltaLabel = hasBaseline ? "\(sign)\(Int(exercise.deltaPct.rounded()))%" : "\u{2014}"
        return HStack(alignment: .center, spacing: FortiFitSpacing.elementSpacing) {
            Text(exercise.exerciseName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(FortiFitColors.primaryText)
                .lineLimit(1)
            Spacer()
            Text(deltaLabel)
                .font(FortiFitTypography.labelSmall)
                .foregroundStyle(deltaColor)
            sparkline(values: exercise.sparkline30d)
                .frame(width: 80, height: 24)
        }
        .padding(.vertical, FortiFitSpacing.elementSpacing / 2)
        .accessibilityIdentifier(AccessibilityID.powerLevelDetailSheet_topExerciseRow(index))
    }

    private func sparkline(values: [Double]) -> some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("idx", index),
                    y: .value("v", value)
                )
                .foregroundStyle(FortiFitColors.primaryAccent)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { $0.background(Color.clear) }
    }

    // MARK: - Window Comparison

    @ViewBuilder
    private var windowComparisonBlock: some View {
        if windowComparison.current30dAvg > 0 && windowComparison.previous30dAvg > 0 {
            windowComparisonCard
        }
    }

    private var windowComparisonCard: some View {
        let sign = windowComparison.deltaPct >= 0 ? "+" : ""
        let deltaColor: Color = {
            if windowComparison.deltaPct > 10 { return FortiFitColors.positive }
            if windowComparison.deltaPct < -10 { return FortiFitColors.alert }
            return FortiFitColors.primaryAccent
        }()
        let settings = UserSettings.shared
        let currentDisplay = settings.useLbs
            ? Int((UnitConversion.kgToLbs(windowComparison.current30dAvg) ?? 0).rounded())
            : Int(windowComparison.current30dAvg.rounded())
        let prevDisplay = settings.useLbs
            ? Int((UnitConversion.kgToLbs(windowComparison.previous30dAvg) ?? 0).rounded())
            : Int(windowComparison.previous30dAvg.rounded())
        return FortiFitCard {
            HStack {
                Text("Current 30d: \(currentDisplay.formatted(.number)) · Previous 30d: \(prevDisplay.formatted(.number))")
                    .font(FortiFitTypography.body)
                    .foregroundStyle(FortiFitColors.primaryText)
                Spacer()
                Text("(\(sign)\(Int(windowComparison.deltaPct.rounded()))%)")
                    .font(FortiFitTypography.labelSmall)
                    .foregroundStyle(deltaColor)
            }
        }
        .accessibilityIdentifier(AccessibilityID.powerLevelDetailSheet_windowComparison)
    }

    // MARK: - Nudge

    private var nudgeBlock: some View {
        FortiFitCard {
            Text(renderedNudgeCopy)
                .font(FortiFitTypography.note)
                .foregroundStyle(FortiFitColors.mutedText)
        }
        .accessibilityIdentifier(AccessibilityID.powerLevelDetailSheet_nudge)
    }

    private var renderedNudgeCopy: String {
        guard let template = AppConstants.PowerLevel.nudgeCopy[nudge.messageKey] else {
            return AppConstants.PowerLevel.nudgeCopy["coldStart"] ?? ""
        }
        var copy = template
        if let v = nudge.inputs.currentSessionCount30d {
            copy = copy.replacingOccurrences(of: "{currentSessionCount30d}", with: "\(v)")
        }
        if let v = nudge.inputs.previousSessionCount30d {
            copy = copy.replacingOccurrences(of: "{previousSessionCount30d}", with: "\(v)")
        }
        if let v = nudge.inputs.topExerciseName {
            copy = copy.replacingOccurrences(of: "{topExerciseName}", with: v)
        }
        if let v = nudge.inputs.avgSessionsPerWeek30d {
            // 3.0 → "3", 3.5 → "3.5"
            let formatted = (v.truncatingRemainder(dividingBy: 1) == 0) ? "\(Int(v))" : String(format: "%.1f", v)
            copy = copy.replacingOccurrences(of: "{avgSessionsPerWeek30d}", with: formatted)
        }
        if let v = nudge.inputs.deltaPct {
            copy = copy.replacingOccurrences(of: "{deltaPct}", with: "\(v)")
        }
        return copy
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onSeeInfo?()
                }
            } label: {
                Text("See Info")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FortiFitColors.primaryAccent)
                    .frame(minHeight: FortiFitSpacing.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.powerLevelDetailSheet_seeInfoButton)
            Spacer()
        }
        .padding(.top, FortiFitSpacing.gapLarge)
    }

    // MARK: - Reload

    private func reload() {
        let now = Date()
        powerLevel = PowerLevelService.calculatePowerLevel(context: modelContext, now: now)
        topExercises = PowerLevelService.topContributingExercises(context: modelContext, now: now)
        windowComparison = PowerLevelService.windowComparison(context: modelContext, now: now)
        nudge = PowerLevelService.computeNudge(context: modelContext, now: now)
        dailyVolume = computeDailyVolume(now: now)
    }

    private func computeDailyVolume(now: Date) -> [(date: Date, volume: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -30, to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today) else {
            return []
        }
        let predicate = #Predicate<Workout> { workout in
            workout.date >= start && workout.date < end &&
            (workout.workoutType == "Strength Training" || workout.workoutType == "HIIT")
        }
        let descriptor = FetchDescriptor<Workout>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let workouts = (try? modelContext.fetch(descriptor)) ?? []

        var byDay: [Date: Double] = [:]
        for workout in workouts {
            let day = calendar.startOfDay(for: workout.date)
            byDay[day, default: 0] += PowerLevelService.workoutVolume(for: workout)
        }
        return (0..<30).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (date: day, volume: byDay[day] ?? 0)
        }
    }
}
