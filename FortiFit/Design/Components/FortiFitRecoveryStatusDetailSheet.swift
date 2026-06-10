import SwiftUI
import SwiftData
import Charts

/// Recovery Status Detail Sheet — opened by tapping the Recovery Status widget in Live state.
/// Hero + sleep stages bar + efficiency caption + 14-day sparkline + last-7-nights stat row +
/// time-since-workout block + See Info / Configure Settings footer.
///
/// See SCREENS.md § Recovery Status Detail Sheet and CONSTANTS.md § Recovery Status Detail Sheet.
struct FortiFitRecoveryStatusDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(RecoveryStatusService.self) private var recoveryService

    var onSeeInfo: (() -> Void)?
    var onConfigureSettings: (() -> Void)?
    var onLogWorkout: (() -> Void)?

    @State private var settings = UserSettings.shared
    @State private var selectedChartIndex: Int? = nil

    private var todaysSnapshot: DailySleepSnapshot? { recoveryService.todaysSnapshot }
    private var recent30: [DailySleepSnapshot] { recoveryService.recent30DaySleep }
    private var hasEnoughForSparkline: Bool { recent30.count >= 7 }
    private var last14: [DailySleepSnapshot] { Array(recent30.suffix(14)) }

    private var noWorkoutsEver: Bool {
        var descriptor = FetchDescriptor<Workout>()
        descriptor.fetchLimit = 1
        let any = (try? modelContext.fetch(descriptor)) ?? []
        return any.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FortiFitSpacing.cardPadding) {
                header
                heroBlock
                stagesBarBlock
                sparklineBlock
                last7NightsStatRow
                timeSinceWorkoutBlock
                footer
            }
            .padding(.horizontal, FortiFitSpacing.screenHorizontal)
            .padding(.bottom, FortiFitSpacing.gapXLarge)
        }
        .background(FortiFitColors.cardSurface)
        .accessibilityIdentifier(AccessibilityID.recoveryStatusDetailSheet_sheet)
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
                .accessibilityIdentifier(AccessibilityID.recoveryStatusDetailSheet_closeButton)
            }
            Text("Recovery Status Insights")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(FortiFitColors.primaryAccent)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, FortiFitSpacing.gapMedium)
        }
    }

    // MARK: - Hero block

    private var heroBlock: some View {
        FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                Text("SLEEP")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(FortiFitColors.primaryAccent)

                Text(formatHero(totalMinutes: todaysSnapshot?.totalSleepMinutes))
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle((todaysSnapshot?.totalSleepMinutes ?? 0) > 0
                                     ? FortiFitColors.primaryText
                                     : FortiFitColors.mutedText)

                Text(formatDeepCaption(snapshot: todaysSnapshot))
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(FortiFitColors.mutedText)
            }
        }
        .accessibilityIdentifier(AccessibilityID.recoveryStatusDetailSheet_hero)
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

    // MARK: - Sleep stages bar

    private var stagesBarBlock: some View {
        FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                GeometryReader { geo in
                    stagesBar(width: geo.size.width)
                }
                .frame(height: 12)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .accessibilityIdentifier(AccessibilityID.recoveryStatusDetailSheet_stagesBar)

                stagesLegend
                    .accessibilityIdentifier(AccessibilityID.recoveryStatusDetailSheet_stagesLegend)

                if let efficiency = todaysSnapshot?.sleepEfficiencyPercent,
                   let inBed = todaysSnapshot?.inBedMinutes,
                   let asleep = todaysSnapshot?.totalSleepMinutes {
                    sleepEfficiencyCaption(percent: efficiency, asleepMinutes: asleep, inBedMinutes: inBed)
                }
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

    // MARK: - Sleep efficiency caption

    private func sleepEfficiencyCaption(percent: Int, asleepMinutes: Int, inBedMinutes: Int) -> some View {
        let asleepHM = "\(asleepMinutes / 60)h \(String(format: "%02d", asleepMinutes % 60))m"
        let inBedHM = "\(inBedMinutes / 60)h \(String(format: "%02d", inBedMinutes % 60))m"
        return Text("Sleep efficiency: \(percent)% (\(asleepHM) asleep of \(inBedHM) in bed)")
            .font(FortiFitTypography.labelSmall)
            .foregroundStyle(FortiFitColors.mutedText)
            .accessibilityIdentifier(AccessibilityID.recoveryStatusDetailSheet_sleepEfficiencyCaption)
    }

    // MARK: - Sparkline

    private var sparklineBlock: some View {
        FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                Text("Last 14 Days · Sleep Duration")
                    .font(FortiFitTypography.detailSheetItemTitle)
                    .foregroundStyle(FortiFitColors.primaryAccent)

                if hasEnoughForSparkline {
                    interactiveSparklineChart
                        .accessibilityIdentifier(AccessibilityID.recoveryStatusDetailSheet_sleepSparkline)
                    selectionAnnotation
                } else {
                    Text("Not enough sleep data yet to chart trends.")
                        .font(.system(size: 13))
                        .foregroundStyle(FortiFitColors.mutedText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 120)
                }
            }
        }
    }

    /// 14-day Swift Chart with tap-to-select + drag-to-scrub selection state, matching
    /// the behavior of `FortiFitTrainingLoadDetailSheet.interactiveDailyChart`.
    private var interactiveSparklineChart: some View {
        Chart {
            ForEach(Array(last14.enumerated()), id: \.element.id) { index, snap in
                let isSelected = selectedChartIndex == index
                let isLatest = snap.id == last14.last?.id
                let isDimmed = selectedChartIndex != nil && !isSelected

                LineMark(
                    x: .value("Date", snap.wakeUpDate),
                    y: .value("Hours", Double(snap.totalSleepMinutes) / 60.0)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(FortiFitColors.chartPurple.opacity(selectedChartIndex == nil ? 1.0 : 0.55))
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Date", snap.wakeUpDate),
                    y: .value("Hours", Double(snap.totalSleepMinutes) / 60.0)
                )
                .foregroundStyle((isLatest ? FortiFitColors.primaryAccent : FortiFitColors.chartPurple).opacity(isDimmed ? 0.35 : 1.0))
                .symbolSize(isSelected ? 96 : (isLatest ? 60 : 16))
                .accessibilityIdentifier(AccessibilityID.recoveryStatusDetailSheet_chartDataPoint(index))
            }

            if let idx = selectedChartIndex, idx < last14.count {
                RuleMark(x: .value("Selected", last14[idx].wakeUpDate))
                    .foregroundStyle(FortiFitColors.chartPurple.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartYScale(domain: DailySleepSnapshot.sparklineDomain(for: last14))
        .chartYAxis {
            AxisMarks(position: .leading, values: DailySleepSnapshot.sparklineAxisValues(for: DailySleepSnapshot.sparklineDomain(for: last14))) { _ in
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

    /// Renders the selected data point's sleep duration, deep-sleep caption, and date below
    /// the chart. Cleared when no point is selected.
    @ViewBuilder
    private var selectionAnnotation: some View {
        if let idx = selectedChartIndex, idx < last14.count {
            let snap = last14[idx]
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
            .accessibilityIdentifier(AccessibilityID.recoveryStatusDetailSheet_chartSelectionAnnotation)
        }
    }

    /// Tap/drag handler: find the snapshot whose `wakeUpDate` is closest to the gesture's
    /// x-coordinate (resolved via `ChartProxy.value(atX:)`) and select it. Fires a light
    /// haptic on selection change, matching the Training Load detail sheet.
    private func scrubChart(to location: CGPoint, proxy: ChartProxy) {
        guard !last14.isEmpty else { return }
        guard let dateValue: Date = proxy.value(atX: location.x) else { return }
        var closestIndex = 0
        var closestDist = abs(last14[0].wakeUpDate.timeIntervalSince(dateValue))
        for i in 1..<last14.count {
            let dist = abs(last14[i].wakeUpDate.timeIntervalSince(dateValue))
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

    // MARK: - Last-7-nights stat row

    private var last7NightsStatRow: some View {
        let last7 = Array(recent30.suffix(7))
        let avgSleepMin = last7.isEmpty ? 0 : last7.reduce(0) { $0 + $1.totalSleepMinutes } / last7.count
        let avgDeepMin = last7.isEmpty ? 0 : last7.reduce(0) { $0 + $1.deepSleepMinutes } / last7.count
        let targetMinutes = Int(settings.targetSleepHours * 60.0 * 0.85)
        let onTargetCount = last7.filter { $0.totalSleepMinutes >= targetMinutes }.count

        return FortiFitCard {
            HStack(spacing: 0) {
                statCell(label: "AVG SLEEP", value: last7.isEmpty ? "—" : formatHM(avgSleepMin))
                Divider().background(FortiFitColors.border)
                statCell(label: "AVG DEEP", value: last7.isEmpty ? "—" : formatHM(avgDeepMin))
                Divider().background(FortiFitColors.border)
                statCell(label: "NIGHTS ON TARGET", value: last7.isEmpty ? "—" : "\(onTargetCount)/7")
            }
        }
        .accessibilityIdentifier(AccessibilityID.recoveryStatusDetailSheet_last7NightsStatRow)
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .kerning(2)
                .foregroundStyle(FortiFitColors.primaryAccent)
                .multilineTextAlignment(.center)
            Text(value)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(FortiFitColors.mutedText)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatHM(_ minutes: Int) -> String {
        "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m"
    }

    // MARK: - Time since last workout

    private var timeSinceWorkoutBlock: some View {
        FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                Text("Time Since Last Workout")
                    .font(FortiFitTypography.detailSheetItemTitle)
                    .foregroundStyle(FortiFitColors.primaryAccent)

                if noWorkoutsEver {
                    coldStartEmpty
                } else {
                    Text(recoveryService.lastWorkoutHero(context: modelContext))
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(FortiFitColors.primaryText)
                        .accessibilityIdentifier(AccessibilityID.recoveryStatusDetailSheet_timeSinceWorkout_headline)

                    perTypeRows
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.recoveryStatusDetailSheet_timeSinceWorkout)
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
                .accessibilityIdentifier(AccessibilityID.recoveryStatusDetailSheet_timeSinceWorkout_typeRow(entry.type))
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

    // MARK: - Cold-start empty

    private var coldStartEmpty: some View {
        VStack(spacing: FortiFitSpacing.gapSmall) {
            Text("No workouts logged yet.")
                .font(.system(size: 15))
                .foregroundStyle(FortiFitColors.mutedText)
                .frame(maxWidth: .infinity, alignment: .center)

            FortiFitButton("Log a Workout", style: .primary) {
                dismiss()
                onLogWorkout?()
            }
        }
        .accessibilityIdentifier(AccessibilityID.recoveryStatusDetailSheet_emptyState_coldStart)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 0) {
            Spacer()
            footerButton(label: "See Info", identifier: AccessibilityID.recoveryStatusDetailSheet_seeInfoButton) {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onSeeInfo?()
                }
            }
            Text("·")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FortiFitColors.mutedText)
                .padding(.horizontal, FortiFitSpacing.elementSpacing)
            footerButton(label: "Configure Settings", identifier: AccessibilityID.recoveryStatusDetailSheet_configureSettingsButton) {
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
}
