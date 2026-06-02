import SwiftUI
import SwiftData
import Charts

/// Combined detail sheet for the linked Recovery & Load composite (Phase 11).
/// Dual hero, stages bar, stacked 14-day combined chart, window comparison,
/// correlation callout, personal insights, last-3-nights, contributing workouts,
/// time-since-workout, recovery readiness callout, footer.
///
/// See SCREENS.md § Linked Recovery & Load Detail Sheet and CONSTANTS.md § Linked
/// Recovery & Load Detail Sheet.
struct FortiFitLinkedRecoveryLoadDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(RecoveryStatusService.self) private var recoveryService

    var onSeeInfo: (() -> Void)?
    var onConfigureSettings: (() -> Void)?
    /// Tap a Contributing This Week row → host dismisses the sheet and pushes that
    /// workout's detail. Mirrors `FortiFitTrainingLoadDetailSheet.onNavigateToWorkout`.
    var onNavigateToWorkout: ((UUID) -> Void)?

    @State private var settings = UserSettings.shared
    @State private var selectedLoadChartIndex: Int? = nil
    @State private var selectedSleepChartIndex: Int? = nil

    private var todaysSnapshot: DailySleepSnapshot? { recoveryService.todaysSnapshot }
    private var recent30: [DailySleepSnapshot] { recoveryService.recent30DaySleep }
    private var last14Sleep: [DailySleepSnapshot] { Array(recent30.suffix(14)) }
    private var dailyLoadScores: [ExerciseLoadService.TrainingLoadDailyScore] {
        // BUG-067 — pass the live sleep map and target so today's data point uses the
        // sleep-adjusted score (matches the hero), not the baseline `calculateLoad`.
        ExerciseLoadService.fourteenDayDailyScores(
            context: modelContext,
            sleepSnapshotsByDay: recoveryService.cachedSnapshotsByDay(),
            targetSleepHours: settings.targetSleepHours
        )
    }

    private var loadResult: ExerciseLoadService.LoadResult {
        let cutoff = Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        let workouts = WorkoutService.fetchWorkouts(from: cutoff, to: Date(), context: modelContext)
        return ExerciseLoadService.computeCurrentScore(
            workouts: workouts,
            sleepSnapshotsByDay: recoveryService.cachedSnapshotsByDay(),
            targetSleepHours: settings.targetSleepHours,
            experienceLevel: settings.experienceLevel,
            targetMinutesPerWorkout: settings.targetMinutesPerWorkout
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FortiFitSpacing.cardPadding) {
                header
                dualHeroBlock
                stagesBarBlock
                combinedChartBlock
                windowComparisonBlock
                personalInsightsBlock
                last3NightsBlock
                contributingWorkoutsBlock
                timeSinceWorkoutBlock
                recoveryReadinessCalloutBlock
                footer
            }
            .padding(.horizontal, FortiFitSpacing.screenHorizontal)
            .padding(.bottom, FortiFitSpacing.gapXLarge)
        }
        .background(FortiFitColors.cardSurface)
        .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_sheet)
    }

    // MARK: - Header

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
                .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_closeButton)
            }
            Text("Recovery & Load Insights")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(FortiFitColors.primaryAccent)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, FortiFitSpacing.gapMedium)
        }
    }

    // MARK: - Dual hero

    private var dualHeroBlock: some View {
        FortiFitCard {
            HStack(alignment: .top, spacing: FortiFitSpacing.gapMedium) {
                VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                    Text("SLEEP")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(FortiFitColors.primaryAccent)
                    Text(formatHero(totalMinutes: todaysSnapshot?.totalSleepMinutes))
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle((todaysSnapshot?.totalSleepMinutes ?? 0) > 0
                                         ? FortiFitColors.primaryText
                                         : FortiFitColors.mutedText)
                    Text(formatDeepCaption(snapshot: todaysSnapshot))
                        .font(.system(size: 11, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(FortiFitColors.mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_recoveryHero)

                VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                    Text("TRAINING LOAD")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(FortiFitColors.primaryAccent)
                    Text("\(Int(loadResult.score.rounded()))/100")
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle(Color(hex: loadResult.zoneColor))
                    Text("ADJUSTED FOR SLEEP")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(FortiFitColors.mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_loadHero)
            }
        }
        .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_dualHero)
    }

    private func formatHero(totalMinutes: Int?) -> String {
        guard let minutes = totalMinutes, minutes > 0 else { return "— h —m" }
        return "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m"
    }

    private func formatDeepCaption(snapshot: DailySleepSnapshot?) -> String {
        guard let snap = snapshot, snap.totalSleepMinutes > 0 else { return "NO DATA" }
        let percent = Int((Double(snap.deepSleepMinutes) / Double(snap.totalSleepMinutes) * 100).rounded())
        let deepHours = snap.deepSleepMinutes / 60
        let deepMins = snap.deepSleepMinutes % 60
        if deepHours > 0 {
            return "\(percent)% DEEP · \(deepHours)h \(String(format: "%02d", deepMins))m"
        }
        return "\(percent)% DEEP · \(deepMins)m"
    }

    // MARK: - Stages bar (reuses pattern from unlinked sheet)

    private var stagesBarBlock: some View {
        FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                GeometryReader { geo in
                    stagesBar(width: geo.size.width)
                }
                .frame(height: 12)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_stagesBar)

                stagesLegend

                sleepEfficiencyCaption
            }
        }
    }

    private func stagesBar(width: CGFloat) -> some View {
        let deep = Double(todaysSnapshot?.deepSleepMinutes ?? 0)
        let rem = Double(todaysSnapshot?.remSleepMinutes ?? 0)
        let core = Double(todaysSnapshot?.coreSleepMinutes ?? 0)
        let awake = Double(todaysSnapshot?.awakeMinutes ?? 0)
        let total = max(deep + rem + core + awake, 1)

        return HStack(spacing: 0) {
            Rectangle().fill(FortiFitColors.chartPurple).frame(width: width * deep / total)
            Rectangle().fill(FortiFitColors.primaryAccent).frame(width: width * rem / total)
            Rectangle().fill(Color(hex: "93c5fd")).frame(width: width * core / total)
            Rectangle().fill(FortiFitColors.sleepAwake).frame(width: width * awake / total)
        }
        .background(FortiFitColors.border)
    }

    private var stagesLegend: some View {
        HStack(spacing: FortiFitSpacing.gapMedium) {
            legendDot(color: FortiFitColors.chartPurple, label: "Deep")
            legendDot(color: FortiFitColors.primaryAccent, label: "REM")
            legendDot(color: Color(hex: "93c5fd"), label: "Core")
            legendDot(color: FortiFitColors.sleepAwake, label: "Awake")
        }
        .font(.system(size: 11, weight: .bold))
        .kerning(FortiFitTypography.labelKerning)
        .foregroundStyle(FortiFitColors.mutedText)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label.uppercased())
        }
    }

    @ViewBuilder
    private var sleepEfficiencyCaption: some View {
        if let efficiency = todaysSnapshot?.sleepEfficiencyPercent,
           let inBed = todaysSnapshot?.inBedMinutes,
           let asleep = todaysSnapshot?.totalSleepMinutes {
            let asleepHM = "\(asleep / 60)h \(String(format: "%02d", asleep % 60))m"
            let inBedHM = "\(inBed / 60)h \(String(format: "%02d", inBed % 60))m"
            Text("Sleep efficiency: \(efficiency)% (\(asleepHM) asleep of \(inBedHM) in bed)")
                .font(FortiFitTypography.bodySmall)
                .foregroundStyle(FortiFitColors.mutedText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_sleepEfficiencyCaption)
        }
    }

    // MARK: - 14-day combined chart

    private var combinedChartBlock: some View {
        FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                Text("Last 14 Days · Training Load (Sleep-Adjusted)")
                    .font(FortiFitTypography.detailSheetItemTitle)
                    .foregroundStyle(FortiFitColors.primaryText)

                loadSparkline
                    .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_loadSparkline)
                loadSelectionAnnotation

                Text("Last 14 Days · Sleep duration")
                    .font(FortiFitTypography.detailSheetItemTitle)
                    .foregroundStyle(FortiFitColors.primaryText)
                    .padding(.top, FortiFitSpacing.gapSmall)

                sleepSparkline
                    .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_sleepSparkline)
                sleepSelectionAnnotation
            }
        }
        .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_combinedChart)
    }

    /// 14-day sleep duration chart with tap-to-select + drag-to-scrub, mirroring
    /// `FortiFitTrainingLoadDetailSheet.interactiveDailyChart`.
    private var sleepSparkline: some View {
        Chart {
            ForEach(Array(last14Sleep.enumerated()), id: \.element.id) { index, snap in
                let isSelected = selectedSleepChartIndex == index
                let isLatest = snap.id == last14Sleep.last?.id
                let isDimmed = selectedSleepChartIndex != nil && !isSelected

                LineMark(
                    x: .value("Date", snap.wakeUpDate),
                    y: .value("Hours", Double(snap.totalSleepMinutes) / 60.0)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(FortiFitColors.chartPurple.opacity(selectedSleepChartIndex == nil ? 1.0 : 0.55))
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Date", snap.wakeUpDate),
                    y: .value("Hours", Double(snap.totalSleepMinutes) / 60.0)
                )
                .foregroundStyle((isLatest ? FortiFitColors.primaryAccent : FortiFitColors.chartPurple).opacity(isDimmed ? 0.35 : 1.0))
                .symbolSize(isSelected ? 96 : (isLatest ? 60 : 16))
                .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_sleepChartDataPoint(index))
            }

            if let idx = selectedSleepChartIndex, idx < last14Sleep.count {
                RuleMark(x: .value("Selected", last14Sleep[idx].wakeUpDate))
                    .foregroundStyle(FortiFitColors.chartPurple.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartYScale(domain: DailySleepSnapshot.sparklineDomain(for: last14Sleep))
        .chartYAxis {
            AxisMarks(position: .leading, values: DailySleepSnapshot.sparklineAxisValues(for: DailySleepSnapshot.sparklineDomain(for: last14Sleep))) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    .foregroundStyle(FortiFitColors.border)
                AxisValueLabel()
                    .foregroundStyle(FortiFitColors.mutedText)
            }
        }
        .chartXAxis(.hidden)
        .chartOverlay { proxy in
            GeometryReader { _ in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                scrubSleepChart(to: value.location, proxy: proxy)
                            }
                    )
                    .onTapGesture { location in
                        scrubSleepChart(to: location, proxy: proxy)
                    }
            }
        }
        .frame(height: 100)
    }

    /// 14-day sleep-adjusted Training Load chart with tap-to-select + drag-to-scrub.
    /// Uses the same `fourteenDayDailyScores` helper as `FortiFitTrainingLoadDetailSheet`
    /// so days without a persisted `DailyTrainingLoadSnapshot` fall back to a live
    /// recompute (BUG-054).
    private var loadSparkline: some View {
        Chart {
            ForEach(Array(dailyLoadScores.enumerated()), id: \.element.date) { index, entry in
                let isSelected = selectedLoadChartIndex == index
                let isLatest = entry.date == dailyLoadScores.last?.date
                let isDimmed = selectedLoadChartIndex != nil && !isSelected

                LineMark(
                    x: .value("Day", entry.date),
                    y: .value("Score", entry.score)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color(hex: loadResult.zoneColor).opacity(selectedLoadChartIndex == nil ? 1.0 : 0.55))
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Day", entry.date),
                    y: .value("Score", entry.score)
                )
                .foregroundStyle(Color(hex: entry.zoneColor).opacity(isDimmed ? 0.35 : 1.0))
                .symbolSize(isSelected ? 96 : (isLatest ? 60 : 16))
                .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_loadChartDataPoint(index))
            }

            if let idx = selectedLoadChartIndex, idx < dailyLoadScores.count {
                RuleMark(x: .value("Selected", dailyLoadScores[idx].date))
                    .foregroundStyle(Color(hex: loadResult.zoneColor).opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .leading, values: [30, 55, 80]) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    .foregroundStyle(FortiFitColors.border)
                AxisValueLabel()
                    .foregroundStyle(FortiFitColors.mutedText)
            }
        }
        .chartXAxis(.hidden)
        .chartOverlay { proxy in
            GeometryReader { _ in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                scrubLoadChart(to: value.location, proxy: proxy)
                            }
                    )
                    .onTapGesture { location in
                        scrubLoadChart(to: location, proxy: proxy)
                    }
            }
        }
        .frame(height: 100)
    }

    /// Selected sleep night → duration (purple), deep caption, date.
    @ViewBuilder
    private var sleepSelectionAnnotation: some View {
        if let idx = selectedSleepChartIndex, idx < last14Sleep.count {
            let snap = last14Sleep[idx]
            HStack(spacing: FortiFitSpacing.elementSpacing) {
                Text(formatHero(totalMinutes: snap.totalSleepMinutes))
                    .font(FortiFitTypography.labelSmall)
                    .foregroundStyle(FortiFitColors.chartPurple)
                Text(formatDeepCaption(snapshot: snap))
                    .font(FortiFitTypography.labelSmall)
                    .foregroundStyle(FortiFitColors.primaryText)
                Spacer()
                Text(snap.wakeUpDate.shortFormatted)
                    .font(FortiFitTypography.labelSmall)
                    .foregroundStyle(FortiFitColors.mutedText)
            }
            .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_sleepChartSelectionAnnotation)
        }
    }

    /// Selected load day → score (zone color), zone label, date.
    @ViewBuilder
    private var loadSelectionAnnotation: some View {
        if let idx = selectedLoadChartIndex, idx < dailyLoadScores.count {
            let entry = dailyLoadScores[idx]
            HStack(spacing: FortiFitSpacing.elementSpacing) {
                Text("\(entry.score) / 100")
                    .font(FortiFitTypography.labelSmall)
                    .foregroundStyle(Color(hex: entry.zoneColor))
                Text(entry.zone)
                    .font(FortiFitTypography.labelSmall)
                    .foregroundStyle(FortiFitColors.primaryText)
                Spacer()
                Text(entry.date.shortFormatted)
                    .font(FortiFitTypography.labelSmall)
                    .foregroundStyle(FortiFitColors.mutedText)
            }
            .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_loadChartSelectionAnnotation)
        }
    }

    private func scrubSleepChart(to location: CGPoint, proxy: ChartProxy) {
        guard !last14Sleep.isEmpty else { return }
        guard let dateValue: Date = proxy.value(atX: location.x) else { return }
        var closestIndex = 0
        var closestDist = abs(last14Sleep[0].wakeUpDate.timeIntervalSince(dateValue))
        for i in 1..<last14Sleep.count {
            let dist = abs(last14Sleep[i].wakeUpDate.timeIntervalSince(dateValue))
            if dist < closestDist {
                closestDist = dist
                closestIndex = i
            }
        }
        if selectedSleepChartIndex != closestIndex {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            selectedSleepChartIndex = closestIndex
        }
    }

    private func scrubLoadChart(to location: CGPoint, proxy: ChartProxy) {
        let scores = dailyLoadScores
        guard !scores.isEmpty else { return }
        guard let dateValue: Date = proxy.value(atX: location.x) else { return }
        var closestIndex = 0
        var closestDist = abs(scores[0].date.timeIntervalSince(dateValue))
        for i in 1..<scores.count {
            let dist = abs(scores[i].date.timeIntervalSince(dateValue))
            if dist < closestDist {
                closestDist = dist
                closestIndex = i
            }
        }
        if selectedLoadChartIndex != closestIndex {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            selectedLoadChartIndex = closestIndex
        }
    }

    // MARK: - Window comparison

    private var windowComparisonBlock: some View {
        let stressComparison = ExerciseLoadService.weekOverWeekComparison(context: modelContext)
        let sleepComparison = sleepWeekComparison
        let matchedDayCount = stressComparison.matchedDayCount
        return FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                comparisonRow(
                    label: "Stress Load",
                    value: stressComparisonValueText(comparison: stressComparison),
                    isHigherBetter: false,
                    sign: stressComparison.matchedDayCount < 2 ? 0 : stressComparison.deltaPct
                )
                comparisonRow(
                    label: "Sleep",
                    value: sleepComparisonValueText(comparison: sleepComparison, matchedDayCount: matchedDayCount),
                    isHigherBetter: true,
                    sign: matchedDayCount < 2 ? 0 : sleepComparison.deltaPct
                )

                if settings.recoverySheetStressLoadExpanded {
                    Text(Self.windowComparisonCaption(now: Date()))
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(FortiFitColors.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_windowComparisonCaption)
                }

                collapseChevron(
                    isExpanded: settings.recoverySheetStressLoadExpanded,
                    accessibilityID: AccessibilityID.linkedRecoveryLoadDetailSheet_windowComparison_chevron
                ) {
                    settings.recoverySheetStressLoadExpanded.toggle()
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_windowComparison)
    }

    private func stressComparisonValueText(comparison: ExerciseLoadService.TrainingLoadWeekComparison) -> String {
        if comparison.matchedDayCount < 2 { return "Not enough data" }
        let arrow = comparison.deltaPct >= 0 ? "↑" : "↓"
        return "\(arrow) \(abs(comparison.deltaPct))%"
    }

    private func sleepComparisonValueText(comparison: RecoveryStatusService.SleepWeekComparison, matchedDayCount: Int) -> String {
        if matchedDayCount < 2 { return "Not enough data" }
        let arrow = comparison.deltaPct >= 0 ? "↑" : "↓"
        return "\(arrow) \(abs(comparison.deltaPct))%"
    }

    /// Spells out the matched Mon-through-current-weekday window on both sides so users
    /// can see the comparison is apples-to-apples (Mon–Thu vs Mon–Thu on a Thursday, full
    /// week vs full week on a Sunday). Stress Load sums and Sleep means use the same two
    /// windows, so one caption covers both rows (BUG-065, BUG-066).
    static func windowComparisonCaption(now: Date) -> String {
        let isoCalendar = Calendar(identifier: .iso8601)
        let calendar = Calendar.current
        let currentStart = now.startOfWeek

        guard let prevStart = isoCalendar.date(byAdding: .weekOfYear, value: -1, to: currentStart) else {
            return "This week so far vs same period last week"
        }

        let dayOffset = max(0, min(6, calendar.dateComponents([.day], from: currentStart, to: now).day ?? 0))
        guard let prevMatchedEnd = isoCalendar.date(byAdding: .day, value: dayOffset, to: prevStart) else {
            return "This week so far vs same period last week"
        }

        let style = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day()
        return "This week so far (\(currentStart.formatted(style)) – today) vs same period last week (\(prevStart.formatted(style)) – \(prevMatchedEnd.formatted(style)))"
    }

    private var sleepWeekComparison: RecoveryStatusService.SleepWeekComparison {
        recoveryService.sleepWeekOverWeekComparison()
    }

    private func comparisonRow(label: String, value: String, isHigherBetter: Bool, sign: Int) -> some View {
        let color: Color = {
            if sign == 0 { return FortiFitColors.mutedText }
            if (sign > 0) == isHigherBetter { return FortiFitColors.positive }
            return FortiFitColors.alert
        }()
        return HStack {
            Text(label)
                .font(FortiFitTypography.detailSheetItemTitle)
                .foregroundStyle(FortiFitColors.primaryText)
            Spacer()
            Text(value)
                .font(FortiFitTypography.bodySmall)
                .foregroundStyle(color)
        }
    }

    private func formatCorrelation(delta: Double, variant: String) -> String {
        let n = Int(abs(delta).rounded())
        guard let template = AppConstants.RecoveryStatus.correlationCopy[variant] else { return "" }
        return template.replacingOccurrences(of: "{n}", with: "\(n)")
    }

    // MARK: - Personal insights (now includes the sleep-load correlation callout)

    @ViewBuilder
    private var personalInsightsBlock: some View {
        let insights = recoveryService.computePersonalInsights(context: modelContext)
        let correlation = recoveryService.computeSleepLoadCorrelation(context: modelContext)
        if !insights.isEmpty || correlation != nil {
            FortiFitCard {
                VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                    Text("Personal Insights")
                        .font(FortiFitTypography.detailSheetItemTitle)
                        .foregroundStyle(FortiFitColors.primaryText)
                    if settings.recoverySheetPersonalInsightsExpanded {
                        if let corr = correlation {
                            Text(formatCorrelation(delta: corr.delta, variant: corr.copyVariant))
                                .font(FortiFitTypography.bodySmall)
                                .foregroundStyle(FortiFitColors.mutedText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_correlationCallout)
                        }
                        ForEach(Array(insights.enumerated()), id: \.offset) { idx, insight in
                            Text(insight)
                                .font(FortiFitTypography.bodySmall)
                                .foregroundStyle(FortiFitColors.mutedText)
                                .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_personalInsightsRow(idx))
                        }
                    }
                    collapseChevron(
                        isExpanded: settings.recoverySheetPersonalInsightsExpanded,
                        accessibilityID: AccessibilityID.linkedRecoveryLoadDetailSheet_personalInsights_chevron
                    ) {
                        settings.recoverySheetPersonalInsightsExpanded.toggle()
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_personalInsights)
        }
    }

    // MARK: - Last 3 nights

    @ViewBuilder
    private var last3NightsBlock: some View {
        let last3 = Array(recent30.suffix(3).reversed())
        if !last3.isEmpty {
            FortiFitCard {
                VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                    Text("Last 3 Nights")
                        .font(FortiFitTypography.detailSheetItemTitle)
                        .foregroundStyle(FortiFitColors.primaryText)

                    if settings.recoverySheetLast3NightsExpanded {
                        HStack(spacing: FortiFitSpacing.gapMedium) {
                            ForEach(last3) { snap in
                                VStack(spacing: 4) {
                                    Text(snap.wakeUpDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                        .font(FortiFitTypography.bodySmall)
                                        .foregroundStyle(FortiFitColors.mutedText)
                                    Text("\(snap.totalSleepMinutes / 60)h \(String(format: "%02d", snap.totalSleepMinutes % 60))m")
                                        .font(FortiFitTypography.bodySmall)
                                        .foregroundStyle(FortiFitColors.primaryText)
                                    Text("\(snap.totalSleepMinutes > 0 ? Int((Double(snap.deepSleepMinutes) / Double(snap.totalSleepMinutes) * 100).rounded()) : 0)% deep")
                                        .font(FortiFitTypography.bodySmall)
                                        .foregroundStyle(FortiFitColors.mutedText)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }

                    collapseChevron(
                        isExpanded: settings.recoverySheetLast3NightsExpanded,
                        accessibilityID: AccessibilityID.linkedRecoveryLoadDetailSheet_last3Nights_chevron
                    ) {
                        settings.recoverySheetLast3NightsExpanded.toggle()
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_last3Nights)
        }
    }

    // MARK: - Contributing this week

    private var contributingWorkoutsBlock: some View {
        // Sleep-adjusted contributions so each row's share matches the linked sheet's
        // hero, daily chart, and chip. Pass-through the same sleep map + target as the
        // hero (lines 27–46), keeping every surface on the same view of the week.
        let contributors = ExerciseLoadService.sleepAdjustedContributingWorkouts(
            context: modelContext,
            sleepSnapshotsByDay: recoveryService.cachedSnapshotsByDay(),
            targetSleepHours: settings.targetSleepHours
        )
        return FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                Text("Contributing This Week")
                    .font(FortiFitTypography.detailSheetItemTitle)
                    .foregroundStyle(FortiFitColors.primaryText)

                if settings.recoverySheetContributingExpanded {
                    if contributors.isEmpty {
                        Text(AppConstants.WidgetDetail.EmptyState.linkedContributingWorkouts)
                            .font(FortiFitTypography.note)
                            .foregroundStyle(FortiFitColors.mutedText)
                            .padding(.vertical, FortiFitSpacing.gapMedium)
                    } else {
                        ForEach(contributors) { contributor in
                            contributorRow(contributor)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        onNavigateToWorkout?(contributor.workoutId)
                                    }
                                }
                            if contributor.id != contributors.last?.id {
                                Divider().background(FortiFitColors.border)
                            }
                        }
                    }
                }

                collapseChevron(
                    isExpanded: settings.recoverySheetContributingExpanded,
                    accessibilityID: AccessibilityID.linkedRecoveryLoadDetailSheet_contributingWorkouts_chevron
                ) {
                    settings.recoverySheetContributingExpanded.toggle()
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_contributingWorkouts)
    }

    private func contributorRow(_ c: ExerciseLoadService.TrainingLoadContributor) -> some View {
        HStack(alignment: .center, spacing: FortiFitSpacing.elementSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(c.workoutName)
                    .font(FortiFitTypography.bodySmall)
                    .foregroundStyle(FortiFitColors.mutedText)
                    .lineLimit(1)
                Text(c.date.shortFormatted)
                    .font(FortiFitTypography.bodySmall)
                    .foregroundStyle(FortiFitColors.mutedText)
            }
            Spacer()
            Text("\(c.percentOfWeeklyLoad)%")
                .font(FortiFitTypography.labelSmall)
                .foregroundStyle(FortiFitColors.mutedText)
                .monospacedDigit()
            contributorShareBar(percent: c.percentOfWeeklyLoad)
        }
        .padding(.vertical, FortiFitSpacing.elementSpacing / 2)
    }

    private func contributorShareBar(percent: Int) -> some View {
        let fraction = max(0, min(1, Double(percent) / 100.0))
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(FortiFitColors.elevatedSurface)
                Capsule()
                    .fill(FortiFitColors.primaryAccent)
                    .frame(width: max(2, proxy.size.width * fraction))
            }
        }
        .frame(width: 56, height: 4)
        .accessibilityHidden(true)
    }

    // MARK: - Time since workout

    private var timeSinceWorkoutBlock: some View {
        FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                Text("Time Since Last Workout")
                    .font(FortiFitTypography.detailSheetItemTitle)
                    .foregroundStyle(FortiFitColors.primaryText)

                if settings.recoverySheetTimeSinceWorkoutExpanded {
                    Text(recoveryService.lastWorkoutHero(context: modelContext))
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(FortiFitColors.primaryText)
                        .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_timeSinceWorkout_headline)

                    perTypeRows
                }

                collapseChevron(
                    isExpanded: settings.recoverySheetTimeSinceWorkoutExpanded,
                    accessibilityID: AccessibilityID.linkedRecoveryLoadDetailSheet_timeSinceWorkout_chevron
                ) {
                    settings.recoverySheetTimeSinceWorkoutExpanded.toggle()
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_timeSinceWorkout)
    }

    private var perTypeRows: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
            ForEach(perTypeData, id: \.type) { entry in
                HStack(spacing: FortiFitSpacing.elementSpacing) {
                    if let symbol = AppConstants.workoutTypeSymbols[entry.type] {
                        Image(systemName: symbol)
                            .font(.system(size: 13))
                            .foregroundStyle(FortiFitColors.mutedText)
                            .frame(width: 18)
                    }
                    Text("\(entry.type) · \(entry.timeSince)")
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(FortiFitColors.mutedText)
                    Spacer()
                }
                .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_timeSinceWorkout_typeRow(entry.type))
            }
        }
    }

    private var perTypeData: [(type: String, timeSince: String, mostRecent: Date)] {
        var rows: [(type: String, timeSince: String, mostRecent: Date)] = []
        for type in AppConstants.workoutTypes {
            let predicate = #Predicate<Workout> { $0.workoutType == type }
            var descriptor = FetchDescriptor<Workout>(predicate: predicate, sortBy: [SortDescriptor(\.date, order: .reverse)])
            descriptor.fetchLimit = 1
            guard let workout = (try? modelContext.fetch(descriptor))?.first else { continue }
            let formatted = recoveryService.formatLastWorkoutHero(latestDate: workout.date, now: Date())
            rows.append((type: type, timeSince: formatted, mostRecent: workout.date))
        }
        return rows.sorted { $0.mostRecent > $1.mostRecent }
    }

    // MARK: - Recovery readiness callout

    private var recoveryReadinessCalloutBlock: some View {
        let combined = recoveryService.computeLinkedAdvisory(
            baseAdvisory: loadResult.advisory,
            zone: loadResult.zone,
            trainedToday: loadResult.trainedToday,
            sleepHours: todaysSnapshot.map { Double($0.totalSleepMinutes) / 60.0 },
            targetSleepHours: settings.targetSleepHours
        )
        return FortiFitCard(borderColor: Color(hex: loadResult.zoneColor)) {
            Text(combined)
                .font(FortiFitTypography.body)
                .foregroundStyle(FortiFitColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier(AccessibilityID.linkedRecoveryLoadDetailSheet_recoveryCallout)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 0) {
            Spacer()
            footerButton(label: "See Info", identifier: AccessibilityID.linkedRecoveryLoadDetailSheet_seeInfoButton) {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onSeeInfo?()
                }
            }
            Text("·")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FortiFitColors.mutedText)
                .padding(.horizontal, FortiFitSpacing.elementSpacing)
            footerButton(label: "Configure Settings", identifier: AccessibilityID.linkedRecoveryLoadDetailSheet_configureSettingsButton) {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onConfigureSettings?()
                }
            }
            Spacer()
        }
        .padding(.top, FortiFitSpacing.gapLarge)
    }

    private func footerButton(label: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FortiFitColors.primaryAccent)
                .frame(minHeight: FortiFitSpacing.minTouchTarget)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Collapse chevron

    private func collapseChevron(
        isExpanded: Bool,
        accessibilityID: String,
        toggle: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.1)) {
                toggle()
            }
        } label: {
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FortiFitColors.mutedText)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
    }
}
