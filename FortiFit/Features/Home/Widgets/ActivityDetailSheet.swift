import SwiftUI
import Charts

struct ActivityDetailSheet: View {
    let activityService: AppleActivityService
    /// Phase 8.8 retrofit — called when the user taps the See Info footer button.
    /// Host should open the Activity Rings See Info Modal after the sheet dismisses.
    var onSeeInfo: (() -> Void)?
    /// Phase 8.8 retrofit — called when the user taps the Configure Settings footer button.
    /// Host should open the Activity Rings Settings Modal after the sheet dismisses.
    var onConfigureSettings: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRange: Int = 7
    @State private var summaries: [ActivitySummarySnapshot] = []
    @State private var selectedMoveIndex: Int? = nil
    @State private var selectedExerciseIndex: Int? = nil
    @State private var selectedStandIndex: Int? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FortiFitColors.mutedText)
                            .frame(
                                width: FortiFitSpacing.minTouchTarget,
                                height: FortiFitSpacing.minTouchTarget
                            )
                    }
                    .accessibilityIdentifier(AccessibilityID.activityDetailSheet_closeButton)
                }

                // Title
                Text(AppConstants.ActivityRings.detailSheetHeading)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(FortiFitColors.primaryAccent)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, FortiFitSpacing.gapMedium)

                // Range toggle
                HStack(spacing: 0) {
                    rangeButton(
                        label: AppConstants.ActivityRings.detailSheetRangeToggle7d,
                        value: 7,
                        identifier: AccessibilityID.activityDetailSheet_range7d
                    )
                    rangeButton(
                        label: AppConstants.ActivityRings.detailSheetRangeToggle30d,
                        value: 30,
                        identifier: AccessibilityID.activityDetailSheet_range30d
                    )
                }
                .background(FortiFitColors.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusSmall))
                .padding(.bottom, FortiFitSpacing.gapLarge)

                // Sparklines
                sparklineCard(
                    label: AppConstants.ActivityRings.detailSheetMoveSparklineLabel,
                    color: FortiFitColors.activityMoveRing,
                    goalValue: Double(activityService.moveGoal),
                    dataExtractor: { $0.moveCalories },
                    identifier: AccessibilityID.activityDetailSheet_moveSparkline,
                    unit: AppConstants.ActivityRings.moveUnit,
                    silhouetteIcon: AppConstants.ActivityRings.moveChevron,
                    selectedIndex: $selectedMoveIndex,
                    dataPointIdentifier: { AccessibilityID.activityDetailSheet_moveChartDataPoint($0) },
                    selectionAnnotationIdentifier: AccessibilityID.activityDetailSheet_moveChartSelectionAnnotation
                )
                .padding(.bottom, FortiFitSpacing.gapMedium)

                sparklineCard(
                    label: AppConstants.ActivityRings.detailSheetExerciseSparklineLabel,
                    color: FortiFitColors.activityExerciseRing,
                    goalValue: Double(activityService.exerciseGoal),
                    dataExtractor: { $0.exerciseMinutes },
                    identifier: AccessibilityID.activityDetailSheet_exerciseSparkline,
                    unit: AppConstants.ActivityRings.exerciseUnit,
                    silhouetteIcon: AppConstants.ActivityRings.exerciseChevron,
                    selectedIndex: $selectedExerciseIndex,
                    dataPointIdentifier: { AccessibilityID.activityDetailSheet_exerciseChartDataPoint($0) },
                    selectionAnnotationIdentifier: AccessibilityID.activityDetailSheet_exerciseChartSelectionAnnotation
                )
                .padding(.bottom, FortiFitSpacing.gapMedium)

                sparklineCard(
                    label: AppConstants.ActivityRings.detailSheetStandSparklineLabel,
                    color: FortiFitColors.activityStandRing,
                    goalValue: Double(activityService.standGoal),
                    dataExtractor: { Double($0.standHours) },
                    identifier: AccessibilityID.activityDetailSheet_standSparkline,
                    unit: AppConstants.ActivityRings.standUnit,
                    silhouetteIcon: AppConstants.ActivityRings.standChevron,
                    selectedIndex: $selectedStandIndex,
                    dataPointIdentifier: { AccessibilityID.activityDetailSheet_standChartDataPoint($0) },
                    selectionAnnotationIdentifier: AccessibilityID.activityDetailSheet_standChartSelectionAnnotation
                )
                .padding(.bottom, FortiFitSpacing.gapMedium)

                // Closure heatmap
                closureHeatmap
                    .padding(.bottom, FortiFitSpacing.gapMedium)

                // Phase 8.8 — Footer (See Info / Configure Settings)
                footer
                    .padding(.top, FortiFitSpacing.gapLarge)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, FortiFitSpacing.gapXLarge)
        }
        .background(FortiFitColors.cardSurface)
        .task { await loadSummaries() }
        .onChange(of: selectedRange) { _, _ in
            // Range switch (7d ↔ 30d) replaces the underlying day arrays, so any prior
            // selection index would point at a different date. Clear all three so the
            // user starts fresh.
            selectedMoveIndex = nil
            selectedExerciseIndex = nil
            selectedStandIndex = nil
            Task { await loadSummaries() }
        }
    }

    // MARK: - Range Button

    private func rangeButton(label: String, value: Int, identifier: String) -> some View {
        Button {
            selectedRange = value
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selectedRange == value ? FortiFitColors.primaryText : FortiFitColors.mutedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    selectedRange == value
                        ? FortiFitColors.primaryAccent.opacity(0.2)
                        : Color.clear
                )
        }
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Sparkline Card

    private func sparklineCard(
        label: String,
        color: Color,
        goalValue: Double,
        dataExtractor: @escaping (ActivitySummarySnapshot) -> Double,
        identifier: String,
        unit: String,
        silhouetteIcon: String,
        selectedIndex: Binding<Int?>,
        dataPointIdentifier: @escaping (Int) -> String,
        selectionAnnotationIdentifier: String
    ) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = buildDayRange()
        let summaryByDay = Dictionary(grouping: summaries, by: { calendar.startOfDay(for: $0.date) })

        return FortiFitCard(borderColor: FortiFitColors.border) {
            ZStack {
                Image(systemName: silhouetteIcon)
                    .font(.system(size: 100, weight: .bold))
                    .foregroundStyle(color.opacity(0.05))

                VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                    if summaries.isEmpty {
                        Text(AppConstants.ActivityRings.detailSheetEmptyMessage)
                            .font(FortiFitTypography.note)
                            .foregroundStyle(FortiFitColors.mutedText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, FortiFitSpacing.gapLarge)
                    } else {
                        interactiveSparklineChart(
                            label: label,
                            color: color,
                            goalValue: goalValue,
                            days: days,
                            summaryByDay: summaryByDay,
                            today: today,
                            calendar: calendar,
                            dataExtractor: dataExtractor,
                            selectedIndex: selectedIndex,
                            dataPointIdentifier: dataPointIdentifier
                        )
                        selectionAnnotation(
                            color: color,
                            unit: unit,
                            days: days,
                            summaryByDay: summaryByDay,
                            dataExtractor: dataExtractor,
                            selectedIndex: selectedIndex,
                            identifier: selectionAnnotationIdentifier
                        )
                    }

                    Text("Last \(selectedRange) days · \(label)")
                        .font(FortiFitTypography.note)
                        .foregroundStyle(FortiFitColors.mutedText)
                }
            }
        }
        .accessibilityIdentifier(identifier)
    }

    /// Sparkline chart with tap-to-select + drag-to-scrub selection state, mirroring
    /// `FortiFitTrainingLoadDetailSheet.interactiveDailyChart`. The selected day's line
    /// stays full opacity; non-selected dots dim to 0.35; the selected dot grows; a
    /// vertical RuleMark anchors the selection. The goal RuleMark (horizontal dashed)
    /// is preserved.
    private func interactiveSparklineChart(
        label: String,
        color: Color,
        goalValue: Double,
        days: [Date],
        summaryByDay: [Date: [ActivitySummarySnapshot]],
        today: Date,
        calendar: Calendar,
        dataExtractor: @escaping (ActivitySummarySnapshot) -> Double,
        selectedIndex: Binding<Int?>,
        dataPointIdentifier: @escaping (Int) -> String
    ) -> some View {
        Chart {
            ForEach(Array(days.enumerated()), id: \.element) { index, day in
                let value = summaryByDay[day]?.first.map(dataExtractor) ?? 0
                let isToday = calendar.isDate(day, inSameDayAs: today)
                let isSelected = selectedIndex.wrappedValue == index
                let isDimmed = selectedIndex.wrappedValue != nil && !isSelected

                LineMark(
                    x: .value("Day", day),
                    y: .value(label, value)
                )
                .foregroundStyle(color.opacity(selectedIndex.wrappedValue == nil ? 1.0 : 0.55))
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Day", day),
                    y: .value(label, value)
                )
                .foregroundStyle((isToday ? FortiFitColors.primaryAccent : color).opacity(isDimmed ? 0.35 : 1.0))
                .symbolSize(isSelected ? 96 : (isToday ? 36 : 9))
                .accessibilityIdentifier(dataPointIdentifier(index))
            }

            RuleMark(y: .value("Goal", goalValue))
                .foregroundStyle(FortiFitColors.mutedText)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            if let idx = selectedIndex.wrappedValue, idx < days.count {
                RuleMark(x: .value("Selected", days[idx]))
                    .foregroundStyle(color.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .foregroundStyle(FortiFitColors.mutedText)
            }
        }
        .frame(height: 120)
        .chartOverlay { proxy in
            GeometryReader { _ in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                scrubChart(to: value.location, proxy: proxy, days: days, selectedIndex: selectedIndex)
                            }
                    )
                    .onTapGesture { location in
                        scrubChart(to: location, proxy: proxy, days: days, selectedIndex: selectedIndex)
                    }
            }
        }
    }

    /// Selection annotation row below the chart — value (chart color) + unit + date (muted).
    /// Renders only when a point is selected.
    @ViewBuilder
    private func selectionAnnotation(
        color: Color,
        unit: String,
        days: [Date],
        summaryByDay: [Date: [ActivitySummarySnapshot]],
        dataExtractor: (ActivitySummarySnapshot) -> Double,
        selectedIndex: Binding<Int?>,
        identifier: String
    ) -> some View {
        if let idx = selectedIndex.wrappedValue, idx < days.count {
            let day = days[idx]
            let value = summaryByDay[day]?.first.map(dataExtractor) ?? 0
            HStack(spacing: FortiFitSpacing.elementSpacing) {
                Text("\(Int(value.rounded())) \(unit)")
                    .font(FortiFitTypography.labelSmall)
                    .foregroundStyle(color)
                Spacer()
                Text(day.shortFormatted)
                    .font(FortiFitTypography.labelSmall)
                    .foregroundStyle(FortiFitColors.mutedText)
            }
            .accessibilityIdentifier(identifier)
        }
    }

    /// Tap/drag handler: resolve the gesture's x-coordinate to a Date via `ChartProxy.value(atX:)`,
    /// find the closest day in `days`, and update `selectedIndex`. Fires a light haptic on
    /// selection change, matching `FortiFitTrainingLoadDetailSheet.scrubChart`.
    private func scrubChart(
        to location: CGPoint,
        proxy: ChartProxy,
        days: [Date],
        selectedIndex: Binding<Int?>
    ) {
        guard !days.isEmpty else { return }
        guard let dateValue: Date = proxy.value(atX: location.x) else { return }
        var closestIndex = 0
        var closestDist = abs(days[0].timeIntervalSince(dateValue))
        for i in 1..<days.count {
            let dist = abs(days[i].timeIntervalSince(dateValue))
            if dist < closestDist {
                closestDist = dist
                closestIndex = i
            }
        }
        if selectedIndex.wrappedValue != closestIndex {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            selectedIndex.wrappedValue = closestIndex
        }
    }

    // MARK: - Closure Heatmap

    private var closureHeatmap: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = buildDayRange()
        let summaryByDay = Dictionary(grouping: summaries, by: { calendar.startOfDay(for: $0.date) })
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return FortiFitCard(borderColor: FortiFitColors.border) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(days, id: \.self) { day in
                        let summary = summaryByDay[day]?.first
                        let isToday = calendar.isDate(day, inSameDayAs: today)
                        let closedCount = ringsClosed(for: summary)
                        let dayNumber = calendar.component(.day, from: day)

                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(cellColor(closedCount: closedCount))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(
                                            isToday ? FortiFitColors.primaryAccent : (closedCount == 0 ? FortiFitColors.border : Color.clear),
                                            lineWidth: 1
                                        )
                                )

                            Text("\(dayNumber)")
                                .font(.system(size: 10))
                                .foregroundStyle(FortiFitColors.primaryText)
                        }
                        .aspectRatio(1, contentMode: .fit)
                    }
                }

                Text("\(AppConstants.ActivityRings.detailSheetClosureHeatmapHeading) · last \(selectedRange) days")
                    .font(FortiFitTypography.note)
                    .foregroundStyle(FortiFitColors.mutedText)
            }
        }
        .accessibilityIdentifier(AccessibilityID.activityDetailSheet_closureHeatmap)
    }

    // MARK: - Helpers

    private func buildDayRange() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<selectedRange).compactMap { offset in
            calendar.date(byAdding: .day, value: -(selectedRange - 1 - offset), to: today)
        }
    }

    private func ringsClosed(for summary: ActivitySummarySnapshot?) -> Int {
        guard let s = summary else { return 0 }
        var count = 0
        if s.moveCalories >= Double(activityService.moveGoal) { count += 1 }
        if s.exerciseMinutes >= Double(activityService.exerciseGoal) { count += 1 }
        if s.standHours >= activityService.standGoal { count += 1 }
        return count
    }

    private func cellColor(closedCount: Int) -> Color {
        switch closedCount {
        case 3: return FortiFitColors.primaryAccent
        case 1, 2: return FortiFitColors.primaryAccent.opacity(0.4)
        default: return FortiFitColors.cardSurface
        }
    }

    private func loadSummaries() async {
        summaries = await activityService.fetchSummaries(days: selectedRange)
    }

    // MARK: - Footer (Phase 8.8 retrofit)

    private var footer: some View {
        HStack(spacing: 0) {
            Spacer()
            Button {
                dismiss()
                onSeeInfo?()
            } label: {
                Text("See Info")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FortiFitColors.primaryAccent)
                    .frame(minHeight: FortiFitSpacing.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.activityDetailSheet_seeInfoButton)

            Text("·")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FortiFitColors.mutedText)
                .padding(.horizontal, FortiFitSpacing.elementSpacing)

            Button {
                dismiss()
                onConfigureSettings?()
            } label: {
                Text("Configure Settings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FortiFitColors.primaryAccent)
                    .frame(minHeight: FortiFitSpacing.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.activityDetailSheet_configureSettingsButton)
            Spacer()
        }
    }
}
