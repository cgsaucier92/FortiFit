import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

struct FortiFitProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ProgressViewModel()
    @State private var draggingChartType: String?
    @State private var deleteTarget: TrendsChart?
    @State private var showDeleteConfirm = false
    @State private var infoChartType: String?
    @State private var headerHeight: CGFloat = 0
    private var settings: UserSettings { UserSettings.shared }
    var selectedTab: Int = 3

    var body: some View {
        NavigationStack {
        ZStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: FortiFitSpacing.gapMedium) {
                        if viewModel.charts.isEmpty {
                            Text("Tap the menu to add charts to your Trends screen.")
                                .font(FortiFitTypography.note)
                                .foregroundStyle(FortiFitColors.mutedText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, FortiFitSpacing.gapXLarge)
                        } else {
                            ForEach(viewModel.charts) { chart in
                                chartCard(for: chart)
                            }
                            .animation(.easeInOut(duration: 0.2), value: viewModel.charts.map(\.chartType))
                        }
                    }
                    .padding(.horizontal, FortiFitSpacing.screenHorizontal)
                    .padding(.top, headerHeight)
                    .padding(.bottom, FortiFitSpacing.gapXLarge)
                }
                .scrollClipDisabled()
                .onTapGesture {
                    if viewModel.isReorderMode {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.isReorderMode = false
                        }
                    }
                }

                FortiFitFixedHeader(headerHeight: $headerHeight) {
                    HStack {
                        Menu {
                            Button {
                                viewModel.showAddChartMenu = true
                            } label: {
                                Label("Add Charts", systemImage: "chart.xyaxis.line")
                            }
                            .accessibilityIdentifier(AccessibilityID.trendsAddChartsMenuItem)
                        } label: {
                            FortiFitEllipsisButton()
                        }
                        .accessibilityIdentifier(AccessibilityID.trendsEllipsisMenu)
                        Spacer()
                    }
                }
            }
            .background(FortiFitColors.background)

            // Add Chart Menu Overlay (Task 8)
            if viewModel.showAddChartMenu {
                FortiFitAddChartMenu(
                    isPresented: $viewModel.showAddChartMenu,
                    addedChartTypes: viewModel.addedChartTypes,
                    onAdd: { chartType in
                        viewModel.addChart(chartType: chartType, context: modelContext)
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showAddChartMenu)
        .onAppear { viewModel.loadData(context: modelContext) }
        .onDisappear { viewModel.isReorderMode = false }
        .onChange(of: selectedTab) { oldValue, _ in
            guard oldValue == 3 else { return }
            viewModel.showAddChartMenu = false
            viewModel.isReorderMode = false
            showDeleteConfirm = false
            deleteTarget = nil
            infoChartType = nil
        }
        .alert("Delete \(deleteTarget.flatMap { AppConstants.trendsChartDisplayNames[$0.chartType] } ?? "Chart")?",
               isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { deleteTarget = nil }
            Button("Delete", role: .destructive) {
                if let chart = deleteTarget {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.deleteChart(chart, context: modelContext)
                    }
                }
                deleteTarget = nil
            }
        } message: {
            Text("You can always add it again from the Add Charts menu")
        }
        .sheet(item: Binding(
            get: { infoChartType.map { InfoChartID(chartType: $0) } },
            set: { infoChartType = $0?.chartType }
        )) { item in
            FortiFitChartInfoModal(chartType: item.chartType)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        } // NavigationStack
    }

    // MARK: - Chart Card with Context Menu & Reorder (Tasks 9, 16)

    @ViewBuilder
    private func chartCard(for chart: TrendsChart) -> some View {
        Group {
            if viewModel.isReorderMode {
                chartContent(for: chart)
            } else {
                Button(action: {}) {
                    chartContent(for: chart)
                }
                .buttonStyle(PressableCardButtonStyle())
            }
        }
        .overlay(alignment: .trailing) {
            if viewModel.isReorderMode {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(FortiFitColors.mutedText)
                    .rotationEffect(.degrees(90))
                    .padding(.trailing, FortiFitSpacing.cardPadding)
            }
        }
        .opacity(draggingChartType == chart.chartType ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isReorderMode)
        .contentShape(Rectangle())
        .onDrag {
            guard viewModel.isReorderMode else {
                return NSItemProvider()
            }
            draggingChartType = chart.chartType
            return NSItemProvider(object: chart.chartType as NSString)
        }
        .onDrop(of: [.text], delegate: ChartDropDelegate(
            chart: chart,
            viewModel: viewModel,
            draggingChartType: $draggingChartType,
            modelContext: modelContext
        ))
        .contextMenu {
            if !viewModel.isReorderMode {
                Button {
                    infoChartType = chart.chartType
                } label: {
                    Label("See Info", systemImage: AppConstants.seeInfoIcon)
                }
                .accessibilityIdentifier(AccessibilityID.trendsChart_seeInfoMenuItem)

                Button {
                    viewModel.isReorderMode = true
                } label: {
                    Label("Reorder Charts", systemImage: "arrow.up.arrow.down")
                }

                Button(role: .destructive) {
                    deleteTarget = chart
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Chart", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Chart Content Factory (Task 16)

    @ViewBuilder
    private func chartContent(for chart: TrendsChart) -> some View {
        switch chart.chartType {
        case "strengthTracker":
            strengthTrackerCard
        case "trainingFrequency":
            trainingFrequencyCard
        case "personalRecords":
            personalRecordsCard
        case "trainingLoadTrend":
            trainingLoadTrendCard
        case "workoutVolume":
            workoutVolumeCard
        case "rpeTrend":
            rpeTrendCard
        case "workoutTypeBreakdown":
            workoutTypeBreakdownCard
        case "sessionDuration":
            sessionDurationCard
        default:
            EmptyView()
        }
    }

    // MARK: - 1. Strength Tracker

    private var strengthTrackerCard: some View {
        FortiFitCard(borderColor: FortiFitColors.border) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                FortiFitWidgetHeader(title: "Strength Tracker")

                if viewModel.availableExercises.isEmpty {
                    emptyChartMessage("Log more workouts to display strength trends.")
                } else {
                    FortiFitSelect(
                        options: viewModel.availableExercises,
                        selected: Binding(
                            get: { viewModel.selectedExercise },
                            set: { viewModel.selectExercise($0) }
                        ),
                        placeholder: "Select Exercise"
                    )

                    timeRangeToggle(
                        selected: Binding(
                            get: { viewModel.selectedTimeRange },
                            set: { viewModel.selectTimeRange($0) }
                        )
                    )

                    if viewModel.hasStrengthData {
                        Chart {
                            ForEach(viewModel.strengthDataPoints) { point in
                                let displayWeight = settings.useLbs
                                    ? (point.weight * UnitConversion.kgToLbsFactor)
                                    : point.weight

                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Weight", displayWeight)
                                )
                                .foregroundStyle(Color(hex: "BB2BC0"))

                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("Weight", displayWeight)
                                )
                                .foregroundStyle(Color(hex: "BB2BC0"))
                            }
                        }
                        .chartYAxisLabel(settings.useLbs ? "lbs" : "kg")
                        .chartYAxis {
                            AxisMarks(position: .leading) { _ in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(FortiFitColors.border)
                                AxisValueLabel()
                                    .foregroundStyle(FortiFitColors.mutedText)
                            }
                        }
                        .chartXAxis {
                            AxisMarks { _ in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(FortiFitColors.border)
                                AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                                    .foregroundStyle(FortiFitColors.mutedText)
                            }
                        }
                        .chartXScale(range: .plotDimension(padding: 16))
                        .frame(height: 200)

                        if let latest = viewModel.strengthDataPoints.last {
                            Text("Latest: \(UnitConversion.displayWeight(latest.weight, useLbs: settings.useLbs))")
                                .font(FortiFitTypography.bodySmall)
                                .foregroundStyle(FortiFitColors.secondaryText)
                        }
                    } else {
                        emptyChartMessage("Log more workouts to display strength trends.")
                    }
                }
            }
            .padding(.trailing, viewModel.isReorderMode ? 36 : 0)
        }
    }

    // MARK: - 2. Training Frequency

    private var trainingFrequencyCard: some View {
        FortiFitCard(borderColor: FortiFitColors.border) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                FortiFitWidgetHeader(title: "Training Frequency")

                if !viewModel.hasFrequencyData {
                    emptyChartMessage("Complete your first full week to see frequency trends.")
                } else {
                    Chart {
                        ForEach(viewModel.weeklyFrequency) { entry in
                            BarMark(
                                x: .value("Week", weekLabel(entry.weekStart)),
                                y: .value("Sessions", entry.count)
                            )
                            .foregroundStyle(Color(hex: "10b981"))
                        }

                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(FortiFitColors.border)
                            AxisValueLabel()
                                .foregroundStyle(FortiFitColors.mutedText)
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .foregroundStyle(FortiFitColors.mutedText)
                        }
                    }
                    .chartXAxisLabel("week of")
                    .frame(height: 200)

                    legendSquare(color: Color(hex: "10b981"), label: "Sessions")
                }
            }
            .padding(.trailing, viewModel.isReorderMode ? 36 : 0)
        }
    }

    // MARK: - 3. Personal Records (Task 11 — Redesigned)

    private var personalRecordsCard: some View {
        FortiFitCard(borderColor: FortiFitColors.border) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                FortiFitWidgetHeader(title: "Personal Records")

                if !viewModel.hasPRData {
                    emptyChartMessage("Log more workouts to display personal records.")
                } else {
                    let prExercises = viewModel.exercisesWithPRs()

                    // Exercise dropdown
                    FortiFitSelect(
                        options: prExercises,
                        selected: Binding(
                            get: { viewModel.selectedPRExercise },
                            set: { viewModel.selectPRExercise($0) }
                        ),
                        placeholder: "Select Exercise"
                    )

                    if let comparison = viewModel.prComparison(for: viewModel.selectedPRExercise) {
                        // PR Summary Row
                        HStack(spacing: FortiFitSpacing.gapMedium) {
                            // Previous Record
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Previous Record")
                                    .font(FortiFitTypography.label)
                                    .kerning(FortiFitTypography.labelKerning)
                                    .foregroundStyle(FortiFitColors.primaryText)
                                Text(UnitConversion.displayWeight(comparison.previousRecord, useLbs: settings.useLbs))
                                    .font(FortiFitTypography.dataValue)
                                    .foregroundStyle(FortiFitColors.primaryAccent)
                                Text(comparison.previousDate.shortFormatted)
                                    .font(FortiFitTypography.bodySmall)
                                    .foregroundStyle(FortiFitColors.mutedText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // Current Record
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Record")
                                    .font(FortiFitTypography.label)
                                    .kerning(FortiFitTypography.labelKerning)
                                    .foregroundStyle(FortiFitColors.primaryText)
                                Text(UnitConversion.displayWeight(comparison.currentRecord, useLbs: settings.useLbs))
                                    .font(FortiFitTypography.dataValue)
                                    .foregroundStyle(FortiFitColors.primaryAccent)
                                Text(comparison.currentDate.shortFormatted)
                                    .font(FortiFitTypography.bodySmall)
                                    .foregroundStyle(FortiFitColors.mutedText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Bar Chart
                        let prevDisplay = settings.useLbs
                            ? comparison.previousRecord * UnitConversion.kgToLbsFactor
                            : comparison.previousRecord
                        let currDisplay = settings.useLbs
                            ? comparison.currentRecord * UnitConversion.kgToLbsFactor
                            : comparison.currentRecord

                        Chart {
                            BarMark(
                                x: .value("Record", "Previous"),
                                y: .value("Weight", prevDisplay)
                            )
                            .foregroundStyle(Color(hex: "8FE6F6"))

                            BarMark(
                                x: .value("Record", "Current"),
                                y: .value("Weight", currDisplay)
                            )
                            .foregroundStyle(Color(hex: "0845AD"))
                        }
                        .chartYScale(domain: 0...(max(prevDisplay, currDisplay) * 1.2))
                        .chartYAxis {
                            AxisMarks(position: .leading) { _ in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(FortiFitColors.border)
                                AxisValueLabel()
                                    .foregroundStyle(FortiFitColors.mutedText)
                            }
                        }
                        .chartXAxis {
                            AxisMarks { _ in
                                AxisValueLabel()
                                    .foregroundStyle(FortiFitColors.mutedText)
                            }
                        }
                        .frame(height: 200)
                    }
                }
            }
            .padding(.trailing, viewModel.isReorderMode ? 36 : 0)
        }
    }

    // MARK: - 4. Training Load Trend

    private var trainingLoadTrendCard: some View {
        FortiFitCard(borderColor: FortiFitColors.border) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                FortiFitWidgetHeader(title: "Training Load Trend")

                if !viewModel.hasLoadTrendData {
                    emptyChartMessage("Log more workouts to display load trends.")
                } else {
                    Chart {
                        RectangleMark(
                            xStart: nil, xEnd: nil,
                            yStart: .value("", 81), yEnd: .value("", 100)
                        )
                        .foregroundStyle(FortiFitColors.alert.opacity(0.1))

                        RectangleMark(
                            xStart: nil, xEnd: nil,
                            yStart: .value("", 56), yEnd: .value("", 80)
                        )
                        .foregroundStyle(FortiFitColors.warning.opacity(0.1))

                        RectangleMark(
                            xStart: nil, xEnd: nil,
                            yStart: .value("", 31), yEnd: .value("", 55)
                        )
                        .foregroundStyle(FortiFitColors.caution.opacity(0.1))

                        RectangleMark(
                            xStart: nil, xEnd: nil,
                            yStart: .value("", 1), yEnd: .value("", 30)
                        )
                        .foregroundStyle(FortiFitColors.positive.opacity(0.1))

                        ForEach(viewModel.dailyLoadScores) { entry in
                            let zoneResult = ExerciseLoadService.classifyZone(score: entry.score)
                            let dotColor = Color(hex: zoneResult.zoneColor)

                            PointMark(
                                x: .value("Day", weekLabel(entry.date)),
                                y: .value("Score", entry.score)
                            )
                            .foregroundStyle(dotColor)
                            .symbolSize(60)

                            LineMark(
                                x: .value("Day", weekLabel(entry.date)),
                                y: .value("Score", entry.score),
                                series: .value("Series", "Load")
                            )
                            .foregroundStyle(FortiFitColors.primaryText.opacity(0.3))
                        }

                        ForEach(viewModel.rollingAverage) { entry in
                            LineMark(
                                x: .value("Day", weekLabel(entry.date)),
                                y: .value("Score", entry.avg),
                                series: .value("Series", "Average")
                            )
                            .foregroundStyle(FortiFitColors.primaryAccent)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(FortiFitColors.border)
                            AxisValueLabel()
                                .foregroundStyle(FortiFitColors.mutedText)
                        }
                    }
                    .chartXAxis {
                        let everyOtherLabel = Set(
                            viewModel.dailyLoadScores.enumerated()
                                .filter { $0.offset % 2 == 0 }
                                .map { weekLabel($0.element.date) }
                        )
                        AxisMarks { value in
                            if let label = value.as(String.self), everyOtherLabel.contains(label) {
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(FortiFitColors.border)
                                AxisValueLabel()
                                    .foregroundStyle(FortiFitColors.mutedText)
                            }
                        }
                    }
                    .frame(height: 200)

                    HStack(spacing: FortiFitSpacing.gapSmall) {
                        legendDot(color: FortiFitColors.positive, label: "Low")
                        legendDot(color: FortiFitColors.caution, label: "Mod")
                        legendDot(color: FortiFitColors.warning, label: "High")
                        legendDot(color: FortiFitColors.alert, label: "Peak")
                    }
                }
            }
            .padding(.trailing, viewModel.isReorderMode ? 36 : 0)
        }
    }

    // MARK: - 5. Workout Volume (Task 12)

    private var workoutVolumeCard: some View {
        FortiFitCard(borderColor: FortiFitColors.border) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                FortiFitWidgetHeader(title: "Workout Volume")

                timeRangeToggle(
                    selected: Binding(
                        get: { viewModel.selectedVolumeTimeRange },
                        set: { viewModel.selectVolumeTimeRange($0) }
                    )
                )

                if !viewModel.hasVolumeData {
                    emptyChartMessage("Log more Strength or HIIT workouts to display volume trends")
                } else {
                    Chart {
                        ForEach(viewModel.volumeDataPoints) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Volume", point.volume)
                            )
                            .foregroundStyle(Color(hex: "4B2893"))

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Volume", point.volume)
                            )
                            .foregroundStyle(Color(hex: "4B2893"))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(FortiFitColors.border)
                            AxisValueLabel()
                                .foregroundStyle(FortiFitColors.mutedText)
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(FortiFitColors.border)
                            AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                                .foregroundStyle(FortiFitColors.mutedText)
                        }
                    }
                    .chartXScale(range: .plotDimension(padding: 16))
                    .frame(height: 200)
                }
            }
            .padding(.trailing, viewModel.isReorderMode ? 36 : 0)
        }
    }

    // MARK: - 6. RPE Trend (Task 13)

    private var rpeTrendCard: some View {
        FortiFitCard(borderColor: FortiFitColors.border) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                FortiFitWidgetHeader(title: "Effort Trend")

                if !viewModel.hasRPEData {
                    emptyChartMessage("Log workouts with effort ratings to display effort trends")
                } else {
                    Chart {
                        ForEach(viewModel.rpeWeeklyData) { entry in
                            BarMark(
                                x: .value("Week", weekLabel(entry.weekStart)),
                                y: .value("Effort", entry.averageRPE)
                            )
                            .foregroundStyle(Color(hex: "FFBF51"))
                        }
                    }
                    .chartYScale(domain: 0...10)
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(FortiFitColors.border)
                            AxisValueLabel()
                                .foregroundStyle(FortiFitColors.mutedText)
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .foregroundStyle(FortiFitColors.mutedText)
                        }
                    }
                    .frame(height: 200)
                }
            }
            .padding(.trailing, viewModel.isReorderMode ? 36 : 0)
        }
    }

    // MARK: - 7. Workout Type Breakdown (Task 14)

    private var workoutTypeBreakdownCard: some View {
        FortiFitCard(borderColor: FortiFitColors.border) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                FortiFitWidgetHeader(title: "Workout Type Breakdown")

                breakdownTimeRangeToggle

                if !viewModel.hasTypeBreakdownData {
                    emptyChartMessage("Log more workouts to display your training breakdown.")
                } else {
                    Chart(viewModel.typeBreakdownData) { entry in
                        SectorMark(
                            angle: .value("Count", entry.count),
                            innerRadius: .ratio(0.5),
                            angularInset: 1.5
                        )
                        .foregroundStyle(AppConstants.workoutTypeChartColors[entry.workoutType] ?? FortiFitColors.primaryAccent)
                        .annotation(position: .overlay) {
                            Text("\(entry.count)")
                                .font(FortiFitTypography.bodySmall)
                                .foregroundStyle(FortiFitColors.primaryText)
                        }
                    }
                    .frame(height: 200)

                    // Legend
                    FlowLayout(spacing: FortiFitSpacing.gapSmall) {
                        ForEach(viewModel.typeBreakdownData) { entry in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(AppConstants.workoutTypeChartColors[entry.workoutType] ?? FortiFitColors.primaryAccent)
                                    .frame(width: 8, height: 8)
                                Text("\(entry.workoutType) (\(entry.count))")
                                    .font(FortiFitTypography.bodySmall)
                                    .foregroundStyle(FortiFitColors.mutedText)
                            }
                        }
                    }
                }
            }
            .padding(.trailing, viewModel.isReorderMode ? 36 : 0)
        }
    }

    // MARK: - 8. Session Duration (Task 15)

    private var sessionDurationCard: some View {
        FortiFitCard(borderColor: FortiFitColors.border) {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                FortiFitWidgetHeader(title: "Session Duration")

                if !viewModel.hasDurationData {
                    emptyChartMessage("Log workouts with duration to display session length trends")
                } else {
                    Chart {
                        ForEach(viewModel.durationWeeklyData) { entry in
                            BarMark(
                                x: .value("Week", weekLabel(entry.weekStart)),
                                y: .value("Duration", entry.averageDuration)
                            )
                            .foregroundStyle(Color(hex: "289193"))
                        }

                    }
                    .chartYAxisLabel("min")
                    .chartXAxisLabel("week of")
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(FortiFitColors.border)
                            AxisValueLabel()
                                .foregroundStyle(FortiFitColors.mutedText)
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .foregroundStyle(FortiFitColors.mutedText)
                        }
                    }
                    .frame(height: 200)
                }
            }
            .padding(.trailing, viewModel.isReorderMode ? 36 : 0)
        }
    }

    // MARK: - Shared Controls

    private func timeRangeToggle(selected: Binding<ProgressViewModel.TimeRange>) -> some View {
        HStack(spacing: FortiFitSpacing.elementSpacing) {
            ForEach(ProgressViewModel.TimeRange.allCases, id: \.self) { range in
                Button {
                    selected.wrappedValue = range
                } label: {
                    Text(range.rawValue)
                        .font(FortiFitTypography.label)
                        .kerning(FortiFitTypography.labelKerning)
                        .foregroundStyle(
                            selected.wrappedValue == range
                                ? FortiFitColors.primaryAccent
                                : FortiFitColors.mutedText
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selected.wrappedValue == range
                                ? FortiFitColors.primaryAccent.opacity(0.15)
                                : FortiFitColors.elevatedSurface
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusPill))
                }
            }
        }
    }

    private var breakdownTimeRangeToggle: some View {
        HStack(spacing: FortiFitSpacing.elementSpacing) {
            ForEach(ProgressViewModel.BreakdownTimeRange.allCases, id: \.self) { range in
                Button {
                    viewModel.selectBreakdownTimeRange(range)
                } label: {
                    Text(range.rawValue)
                        .font(FortiFitTypography.label)
                        .kerning(FortiFitTypography.labelKerning)
                        .foregroundStyle(
                            viewModel.selectedBreakdownTimeRange == range
                                ? FortiFitColors.primaryAccent
                                : FortiFitColors.mutedText
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            viewModel.selectedBreakdownTimeRange == range
                                ? FortiFitColors.primaryAccent.opacity(0.15)
                                : FortiFitColors.elevatedSurface
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusPill))
                }
            }
        }
    }

    // MARK: - Helpers

    private func emptyChartMessage(_ message: String) -> some View {
        Text(message)
            .font(FortiFitTypography.note)
            .foregroundStyle(FortiFitColors.mutedText)
    }

    private func weekLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(FortiFitTypography.bodySmall)
                .foregroundStyle(FortiFitColors.mutedText)
        }
    }

    private func legendSquare(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(FortiFitTypography.bodySmall)
                .foregroundStyle(FortiFitColors.mutedText)
        }
    }

    private func legendDash(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            DashedLine()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .foregroundStyle(color)
                .frame(width: 20, height: 1)
            Text(label)
                .font(FortiFitTypography.bodySmall)
                .foregroundStyle(FortiFitColors.mutedText)
        }
    }
}

// MARK: - Flow Layout for Legend

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, containerWidth: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let positions = layout(sizes: sizes, containerWidth: bounds.width).positions

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(
                x: bounds.minX + positions[index].x,
                y: bounds.minY + positions[index].y
            ), proposal: .unspecified)
        }
    }

    private func layout(sizes: [CGSize], containerWidth: CGFloat) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for size in sizes {
            if x + size.width > containerWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxWidth = max(maxWidth, x)
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

// MARK: - Info Chart Identifier

private struct InfoChartID: Identifiable {
    let chartType: String
    var id: String { chartType }
}

// MARK: - Chart Drop Delegate

private struct ChartDropDelegate: DropDelegate {
    let chart: TrendsChart
    let viewModel: ProgressViewModel
    @Binding var draggingChartType: String?
    let modelContext: ModelContext

    func performDrop(info: DropInfo) -> Bool {
        draggingChartType = nil
        viewModel.isReorderMode = false
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingChartType,
              dragging != chart.chartType,
              let fromIndex = viewModel.charts.firstIndex(where: { $0.chartType == dragging }),
              let toIndex = viewModel.charts.firstIndex(where: { $0.chartType == chart.chartType })
        else { return }

        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        withAnimation(.easeInOut(duration: 0.2)) {
            var types = viewModel.charts.map(\.chartType)
            types.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            viewModel.reorderCharts(orderedTypes: types, context: modelContext)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

#Preview {
    FortiFitProgressView()
        .modelContainer(for: [Workout.self, ExerciseSet.self, Goal.self, TrendsChart.self], inMemory: true)
}
