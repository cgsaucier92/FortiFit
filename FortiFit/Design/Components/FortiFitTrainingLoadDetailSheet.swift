import SwiftUI
import SwiftData
import Charts

/// Training Load Detail Sheet — opened by tapping the Training Load home widget.
/// Hero gradient bar + 14-day chart + contributing workouts + week comparison + recovery callout.
///
/// See SCREENS.md § Training Load Detail Sheet and CONSTANTS.md § Training Load Detail Sheet.
struct FortiFitTrainingLoadDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var loadResult = ExerciseLoadService.LoadResult(score: 0, zone: "Resting", zoneColor: "737373", advisory: "")
    @State private var dailyScores: [ExerciseLoadService.TrainingLoadDailyScore] = []
    @State private var contributors: [ExerciseLoadService.TrainingLoadContributor] = []
    @State private var weekComparison: ExerciseLoadService.TrainingLoadWeekComparison?
    @State private var trainedToday: Bool = false
    @State private var selectedChartIndex: Int? = nil

    var onSeeInfo: (() -> Void)?
    var onConfigureSettings: (() -> Void)?
    var onNavigateToWorkout: ((UUID) -> Void)?

    private var chartHasEnoughData: Bool {
        // Per spec: ≥ 3 days with ≥ 1 workout in last 14 days
        dailyScores.filter { $0.score > 0 }.count >= 3
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FortiFitSpacing.cardPadding) {
                header
                heroBlock
                dailyChartBlock
                contributingWorkoutsBlock
                weekComparisonBlock
                recoveryCalloutBlock
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
                .accessibilityIdentifier(AccessibilityID.trainingLoadDetailSheet_closeButton)
            }

            Text("Training Load Insights")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(FortiFitColors.primaryAccent)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, FortiFitSpacing.gapMedium)
        }
    }

    // MARK: - Hero

    private var heroBlock: some View {
        FortiFitCard(borderColor: Color(hex: loadResult.zoneColor)) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                FortiFitProgressBar(
                    progress: loadResult.score / 100,
                    barColor: Color(hex: loadResult.zoneColor)
                )
                Text(loadResult.zone)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color(hex: loadResult.zoneColor))
                Text("\(Int(loadResult.score.rounded())) / 100")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(Color(hex: loadResult.zoneColor))
            }
        }
        .accessibilityIdentifier(AccessibilityID.trainingLoadDetailSheet_hero)
    }

    // MARK: - 14-Day Chart

    private var dailyChartBlock: some View {
        FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                Text("Last 14 Days · Training Load")
                    .font(FortiFitTypography.detailSheetItemTitle)
                    .foregroundStyle(FortiFitColors.primaryAccent)

                if chartHasEnoughData {
                    interactiveDailyChart
                    selectionAnnotation
                } else {
                    Text(AppConstants.WidgetDetail.EmptyState.trainingLoadChart)
                        .font(FortiFitTypography.note)
                        .foregroundStyle(FortiFitColors.mutedText)
                        .padding(.vertical, FortiFitSpacing.gapMedium)
                        .accessibilityIdentifier(AccessibilityID.trainingLoadDetailSheet_emptyState_coldStart)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.trainingLoadDetailSheet_dailyChart)
    }

    /// 14-day Swift Chart with tap-to-select + drag-to-scrub selection state, matching
    /// the behavior of `FortiFitChartDetailView` on the Trends screen.
    private var interactiveDailyChart: some View {
        Chart {
            ForEach(Array(dailyScores.enumerated()), id: \.element.date) { index, entry in
                let isSelected = selectedChartIndex == index
                let isLatest = entry.date == dailyScores.last?.date
                let isDimmed = selectedChartIndex != nil && !isSelected

                LineMark(
                    x: .value("Day", entry.date),
                    y: .value("Score", entry.score)
                )
                .foregroundStyle(FortiFitColors.primaryAccent.opacity(selectedChartIndex == nil ? 1.0 : 0.55))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Day", entry.date),
                    y: .value("Score", entry.score)
                )
                .foregroundStyle(Color(hex: entry.zoneColor).opacity(isDimmed ? 0.35 : 1.0))
                .symbolSize(isSelected ? 96 : (isLatest ? 64 : 16))
                .accessibilityIdentifier(AccessibilityID.trainingLoadDetailSheet_chartDataPoint(index))
            }

            if let idx = selectedChartIndex, idx < dailyScores.count {
                RuleMark(x: .value("Selected", dailyScores[idx].date))
                    .foregroundStyle(FortiFitColors.primaryAccent.opacity(0.6))
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

    /// Renders the selected data point's score, zone, and date below the chart.
    /// Cleared when the user taps outside the plot or selects no point.
    @ViewBuilder
    private var selectionAnnotation: some View {
        if let idx = selectedChartIndex, idx < dailyScores.count {
            let entry = dailyScores[idx]
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
            .accessibilityIdentifier(AccessibilityID.trainingLoadDetailSheet_chartSelectionAnnotation)
        }
    }

    /// Tap/drag handler: find the daily-score entry whose date is closest to the gesture's
    /// x-coordinate (resolved via `ChartProxy.value(atX:)`) and select it. Fires a light
    /// haptic on selection change, matching `FortiFitChartDetailView.scrubToNearest`.
    private func scrubChart(to location: CGPoint, proxy: ChartProxy) {
        guard !dailyScores.isEmpty else { return }
        guard let dateValue: Date = proxy.value(atX: location.x) else { return }
        var closestIndex = 0
        var closestDist = abs(dailyScores[0].date.timeIntervalSince(dateValue))
        for i in 1..<dailyScores.count {
            let dist = abs(dailyScores[i].date.timeIntervalSince(dateValue))
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

    // MARK: - Contributing Workouts

    private var contributingWorkoutsBlock: some View {
        FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                Text("Contributing This Week")
                    .font(FortiFitTypography.detailSheetItemTitle)
                    .foregroundStyle(FortiFitColors.primaryAccent)

                if contributors.isEmpty {
                    Text(AppConstants.WidgetDetail.EmptyState.trainingLoadContributingWorkouts)
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
        }
        .accessibilityIdentifier(AccessibilityID.trainingLoadDetailSheet_contributingWorkouts)
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
            // Percent label + inline horizontal bar (Phase 8.8 polish): visualizes each
            // workout's share of the last-7-day stress-load total. Absolute stress-load
            // value is intentionally suppressed to avoid the additivity false-expectation.
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

    // MARK: - Week Comparison

    @ViewBuilder
    private var weekComparisonBlock: some View {
        if let comparison = weekComparison {
            let insufficient = comparison.matchedDayCount < 2
            let hasAnyData = comparison.currentWeekTss > 0 || comparison.previousWeekTss > 0
            // Hide entirely when there's no data AND no early-week reason to surface the
            // "Not enough data" treatment — preserves the existing standalone behavior of
            // not showing an empty card to never-trained users.
            if insufficient || hasAnyData {
                FortiFitCard {
                    VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                        HStack {
                            Text("Training Load")
                                .font(FortiFitTypography.detailSheetItemTitle)
                                .foregroundStyle(FortiFitColors.primaryAccent)
                            Spacer()
                            if insufficient {
                                Text("Not enough data")
                                    .font(FortiFitTypography.bodySmall)
                                    .foregroundStyle(FortiFitColors.mutedText)
                            } else {
                                let deltaColor: Color = comparison.deltaPct >= 0 ? FortiFitColors.alert : FortiFitColors.positive
                                let arrow = comparison.deltaPct >= 0 ? "↑" : "↓"
                                Text("\(arrow) \(abs(comparison.deltaPct))%")
                                    .font(FortiFitTypography.bodySmall)
                                    .foregroundStyle(deltaColor)
                            }
                        }
                        Text(FortiFitLinkedRecoveryLoadDetailSheet.windowComparisonCaption(now: Date()))
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.mutedText)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier(AccessibilityID.trainingLoadDetailSheet_weekComparisonCaption)
                    }
                }
                .accessibilityIdentifier(AccessibilityID.trainingLoadDetailSheet_weekComparison)
            }
        }
    }

    // MARK: - Recovery Callout

    private var recoveryCalloutBlock: some View {
        FortiFitCard(borderColor: Color(hex: loadResult.zoneColor)) {
            Text(loadResult.advisory)
                .font(FortiFitTypography.body)
                .foregroundStyle(FortiFitColors.primaryText)
        }
        .accessibilityIdentifier(AccessibilityID.trainingLoadDetailSheet_recoveryCallout)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 0) {
            Spacer()
            footerButton(label: "See Info", identifier: AccessibilityID.trainingLoadDetailSheet_seeInfoButton) {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onSeeInfo?()
                }
            }
            Text("·")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FortiFitColors.mutedText)
                .padding(.horizontal, FortiFitSpacing.elementSpacing)
            footerButton(label: "Configure Settings", identifier: AccessibilityID.trainingLoadDetailSheet_configureSettingsButton) {
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

    // MARK: - Reload

    private func reload() {
        let settings = UserSettings.shared
        let now = Date()
        let workouts = WorkoutService.fetchLast10DaysWorkouts(context: modelContext, now: now)
        // BUG-067 — route through `computeCurrentScore` (with empty sleep map → every
        // day uses sleepFactor = 1.0) so the unlinked detail sheet's hero shares the
        // same discrete per-day decay shape as the Home widget bar and the chip's
        // baseline. Mathematically equivalent to `calculateLoad` at midnight boundaries;
        // diverges by a small bounded amount at fractional offsets — uniformly across
        // the unlinked surface.
        loadResult = ExerciseLoadService.computeCurrentScore(
            workouts: workouts,
            sleepSnapshotsByDay: [:],
            targetSleepHours: settings.targetSleepHours,
            experienceLevel: settings.experienceLevel,
            targetMinutesPerWorkout: settings.targetMinutesPerWorkout,
            now: now
        )
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        trainedToday = workouts.contains { calendar.startOfDay(for: $0.date) == todayStart }

        dailyScores = ExerciseLoadService.fourteenDayDailyScores(context: modelContext, now: now)
        contributors = ExerciseLoadService.contributingWorkouts(context: modelContext, now: now)
        weekComparison = ExerciseLoadService.weekOverWeekComparison(context: modelContext, now: now)
    }
}
