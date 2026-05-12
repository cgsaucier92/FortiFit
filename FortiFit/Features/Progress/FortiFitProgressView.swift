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
    @State private var detailChartIndex: Int?
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
                // Catch-all: drops landing outside any chart clear the stale drag state
                .onDrop(of: [.text], isTargeted: nil) { _, _ in
                    draggingChartType = nil
                    return false
                }

                FortiFitFixedHeader(headerHeight: $headerHeight) {
                    HStack {
                        FortiFitEllipsisButton(menuItems: [
                            (label: "Add Charts", systemImage: "chart.xyaxis.line", identifier: AccessibilityID.trendsAddChartsMenuItem, action: {
                                viewModel.showAddChartMenu = true
                            })
                        ])
                        .accessibilityIdentifier(AccessibilityID.trendsEllipsisMenu)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(FortiFitColors.background)

            // Add Chart Menu Overlay
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
        .onChange(of: viewModel.isReorderMode) { _, isOn in
            if !isOn { draggingChartType = nil }
        }
        .onChange(of: selectedTab) { oldValue, _ in
            guard oldValue == 3 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    detailChartIndex = nil
                    viewModel.showAddChartMenu = false
                    viewModel.isReorderMode = false
                    showDeleteConfirm = false
                    deleteTarget = nil
                    infoChartType = nil
                }
            }
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
            if let content = AppConstants.chartInfoModalCopy[item.chartType] {
                FortiFitSeeInfoModal(content: content)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .navigationDestination(item: $detailChartIndex) { index in
            FortiFitChartDetailView(
                charts: viewModel.charts,
                initialChartIndex: index
            )
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        } // NavigationStack
    }

    // MARK: - Chart Card with Context Menu & Reorder

    @ViewBuilder
    private func chartCard(for chart: TrendsChart) -> some View {
        Group {
            if viewModel.isReorderMode {
                chartContent(for: chart)
            } else {
                Button {
                    if let index = viewModel.charts.firstIndex(where: { $0.chartType == chart.chartType }) {
                        detailChartIndex = index
                    }
                } label: {
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

    // MARK: - Chart Content Factory

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
        let chartId = "strengthTracker"
        let isEmpty = viewModel.availableExercises.isEmpty || !viewModel.hasStrengthData
        return FortiFitChartCard(
            chartId: chartId,
            title: "Strength Tracker",
            summary: viewModel.chartSummary(for: chartId, context: modelContext),
            gradientAnchor: AppConstants.chartGradientAnchor(for: chartId),
            isEmpty: isEmpty,
            emptyMessage: AppConstants.chartEmptyMessages[chartId] ?? "",
            isReorderMode: viewModel.isReorderMode,
            onExpand: expandAction(for: chartId),
            controls: {
                if !viewModel.availableExercises.isEmpty {
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
                }
            },
            chart: {
                let lastDate = viewModel.strengthDataPoints.last?.date
                Chart {
                    ForEach(Array(viewModel.strengthDataPoints.enumerated()), id: \.element.id) { index, point in
                        let displayWeight = settings.useLbs
                            ? (point.weight * UnitConversion.kgToLbsFactor)
                            : point.weight

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", displayWeight)
                        )
                        .foregroundStyle(FortiFitColors.chartPink)
                        .interpolationMethod(.catmullRom)

                        if point.date == lastDate {
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Weight", displayWeight)
                            )
                            .foregroundStyle(FortiFitColors.chartPink)
                            .symbolSize(36)
                            .symbol {
                                Circle()
                                    .fill(FortiFitColors.chartPink)
                                    .frame(width: 6, height: 6)
                                    .shadow(color: FortiFitColors.chartPink.opacity(0.6), radius: 4)
                            }
                            .accessibilityIdentifier(AccessibilityID.trendsChartDataPoint(chartId, index: index))
                        } else {
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Weight", displayWeight)
                            )
                            .foregroundStyle(FortiFitColors.chartPink)
                            .symbolSize(9)
                            .accessibilityIdentifier(AccessibilityID.trendsChartDataPoint(chartId, index: index))
                        }
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
            },
            footer: { EmptyView() }
        )
    }

    // MARK: - 2. Training Frequency

    private var trainingFrequencyCard: some View {
        let chartId = "trainingFrequency"
        return FortiFitChartCard(
            chartId: chartId,
            title: "Training Frequency",
            summary: viewModel.chartSummary(for: chartId, context: modelContext),
            gradientAnchor: AppConstants.chartGradientAnchor(for: chartId),
            isEmpty: !viewModel.hasFrequencyData,
            emptyMessage: AppConstants.chartEmptyMessages[chartId] ?? "",
            isReorderMode: viewModel.isReorderMode,
            onExpand: expandAction(for: chartId),
            controls: { EmptyView() },
            chart: {
                Chart {
                    ForEach(Array(viewModel.weeklyFrequency.enumerated()), id: \.element.id) { index, entry in
                        let label = weekLabel(entry.weekStart)

                        BarMark(
                            x: .value("Week", label),
                            y: .value("Sessions", entry.count)
                        )
                        .foregroundStyle(FortiFitColors.positive)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5))
                        .accessibilityIdentifier(AccessibilityID.trendsChartDataPoint(chartId, index: index))
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
            },
            footer: {
                legendSquare(color: FortiFitColors.positive, label: "Sessions")
            }
        )
    }

    // MARK: - 3. Personal Records

    private var personalRecordsCard: some View {
        let chartId = "personalRecords"
        return FortiFitChartCard(
            chartId: chartId,
            title: "Personal Records",
            summary: viewModel.chartSummary(for: chartId, context: modelContext),
            gradientAnchor: AppConstants.chartGradientAnchor(for: chartId),
            isEmpty: !viewModel.hasPRData,
            emptyMessage: AppConstants.chartEmptyMessages[chartId] ?? "",
            isReorderMode: viewModel.isReorderMode,
            onExpand: expandAction(for: chartId),
            controls: {
                if viewModel.hasPRData {
                    let prExercises = viewModel.exercisesWithPRs()
                    FortiFitSelect(
                        options: prExercises,
                        selected: Binding(
                            get: { viewModel.selectedPRExercise },
                            set: { viewModel.selectPRExercise($0) }
                        ),
                        placeholder: "Select Exercise"
                    )
                }
            },
            chart: {
                if let comparison = viewModel.prComparison(for: viewModel.selectedPRExercise) {
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
                        .foregroundStyle(FortiFitColors.chartLightCyan)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5))

                        BarMark(
                            x: .value("Record", "Current"),
                            y: .value("Weight", currDisplay)
                        )
                        .foregroundStyle(FortiFitColors.chartDeepBlue)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5))
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
            },
            footer: {
                if let comparison = viewModel.prComparison(for: viewModel.selectedPRExercise) {
                    HStack(spacing: FortiFitSpacing.gapMedium) {
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
                }
            }
        )
    }

    // MARK: - 4. Training Load Trend

    private var trainingLoadTrendCard: some View {
        let chartId = "trainingLoadTrend"
        return FortiFitChartCard(
            chartId: chartId,
            title: "Training Load Trend",
            summary: viewModel.chartSummary(for: chartId, context: modelContext),
            gradientAnchor: AppConstants.chartGradientAnchor(for: chartId),
            isEmpty: !viewModel.hasLoadTrendData,
            emptyMessage: AppConstants.chartEmptyMessages[chartId] ?? "",
            isReorderMode: viewModel.isReorderMode,
            onExpand: expandAction(for: chartId),
            controls: { EmptyView() },
            chart: {
                let lastAvgDate = viewModel.rollingAverage.last.map { weekLabel($0.date) }
                Chart {
                    RectangleMark(
                        xStart: nil, xEnd: nil,
                        yStart: .value("", 81), yEnd: .value("", 100)
                    )
                    .foregroundStyle(FortiFitColors.alert.opacity(0.15))

                    RectangleMark(
                        xStart: nil, xEnd: nil,
                        yStart: .value("", 56), yEnd: .value("", 80)
                    )
                    .foregroundStyle(FortiFitColors.warning.opacity(0.15))

                    RectangleMark(
                        xStart: nil, xEnd: nil,
                        yStart: .value("", 31), yEnd: .value("", 55)
                    )
                    .foregroundStyle(FortiFitColors.caution.opacity(0.15))

                    RectangleMark(
                        xStart: nil, xEnd: nil,
                        yStart: .value("", 1), yEnd: .value("", 30)
                    )
                    .foregroundStyle(FortiFitColors.positive.opacity(0.15))

                    ForEach(Array(viewModel.dailyLoadScores.enumerated()), id: \.element.id) { index, entry in
                        let zoneResult = ExerciseLoadService.classifyZone(score: entry.score)
                        let dotColor = Color(hex: zoneResult.zoneColor)
                        let label = weekLabel(entry.date)

                        PointMark(
                            x: .value("Day", label),
                            y: .value("Score", entry.score)
                        )
                        .foregroundStyle(dotColor)
                        .symbolSize(60)
                        .accessibilityIdentifier(AccessibilityID.trendsChartDataPoint(chartId, index: index))

                        LineMark(
                            x: .value("Day", label),
                            y: .value("Score", entry.score),
                            series: .value("Series", "Load")
                        )
                        .foregroundStyle(FortiFitColors.primaryText.opacity(0.3))
                    }

                    ForEach(viewModel.rollingAverage) { entry in
                        let label = weekLabel(entry.date)
                        LineMark(
                            x: .value("Day", label),
                            y: .value("Score", entry.avg),
                            series: .value("Series", "Average")
                        )
                        .foregroundStyle(FortiFitColors.primaryAccent)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .interpolationMethod(.catmullRom)

                        if label == lastAvgDate {
                            PointMark(
                                x: .value("Day", label),
                                y: .value("Score", entry.avg)
                            )
                            .foregroundStyle(FortiFitColors.primaryAccent)
                            .symbol {
                                Circle()
                                    .fill(FortiFitColors.primaryAccent)
                                    .frame(width: 6, height: 6)
                                    .shadow(color: FortiFitColors.primaryAccent.opacity(0.6), radius: 4)
                            }
                        }
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
                .chartXScale(range: .plotDimension(padding: 16))
                .frame(height: 200)
            },
            footer: {
                HStack(spacing: FortiFitSpacing.gapSmall) {
                    legendDot(color: FortiFitColors.positive, label: "Low")
                    legendDot(color: FortiFitColors.caution, label: "Mod")
                    legendDot(color: FortiFitColors.warning, label: "High")
                    legendDot(color: FortiFitColors.alert, label: "Peak")
                }
            }
        )
    }

    // MARK: - 5. Workout Volume

    private var workoutVolumeCard: some View {
        let chartId = "workoutVolume"
        return FortiFitChartCard(
            chartId: chartId,
            title: "Workout Volume",
            summary: viewModel.chartSummary(for: chartId, context: modelContext),
            gradientAnchor: AppConstants.chartGradientAnchor(for: chartId),
            isEmpty: !viewModel.hasVolumeData,
            emptyMessage: AppConstants.chartEmptyMessages[chartId] ?? "",
            isReorderMode: viewModel.isReorderMode,
            onExpand: expandAction(for: chartId),
            controls: {
                timeRangeToggle(
                    selected: Binding(
                        get: { viewModel.selectedVolumeTimeRange },
                        set: { viewModel.selectVolumeTimeRange($0) }
                    )
                )
            },
            chart: {
                let lastDate = viewModel.volumeDataPoints.last?.date
                Chart {
                    ForEach(Array(viewModel.volumeDataPoints.enumerated()), id: \.element.id) { index, point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Volume", point.volume)
                        )
                        .foregroundStyle(FortiFitColors.chartPurple)
                        .interpolationMethod(.catmullRom)

                        if point.date == lastDate {
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Volume", point.volume)
                            )
                            .foregroundStyle(FortiFitColors.chartPurple)
                            .symbol {
                                Circle()
                                    .fill(FortiFitColors.chartPurple)
                                    .frame(width: 6, height: 6)
                                    .shadow(color: FortiFitColors.chartPurple.opacity(0.6), radius: 4)
                            }
                            .accessibilityIdentifier(AccessibilityID.trendsChartDataPoint(chartId, index: index))
                        } else {
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Volume", point.volume)
                            )
                            .foregroundStyle(FortiFitColors.chartPurple)
                            .symbolSize(9)
                            .accessibilityIdentifier(AccessibilityID.trendsChartDataPoint(chartId, index: index))
                        }
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
            },
            footer: { EmptyView() }
        )
    }

    // MARK: - 6. RPE Trend

    private var rpeTrendCard: some View {
        let chartId = "rpeTrend"
        return FortiFitChartCard(
            chartId: chartId,
            title: "Effort Trend",
            summary: viewModel.chartSummary(for: chartId, context: modelContext),
            gradientAnchor: AppConstants.chartGradientAnchor(for: chartId),
            isEmpty: !viewModel.hasRPEData,
            emptyMessage: AppConstants.chartEmptyMessages[chartId] ?? "",
            isReorderMode: viewModel.isReorderMode,
            onExpand: expandAction(for: chartId),
            controls: { EmptyView() },
            chart: {
                Chart {
                    ForEach(Array(viewModel.rpeWeeklyData.enumerated()), id: \.element.id) { index, entry in
                        let label = weekLabel(entry.weekStart)

                        BarMark(
                            x: .value("Week", label),
                            y: .value("Effort", entry.averageRPE)
                        )
                        .foregroundStyle(FortiFitColors.chartOrange)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5))
                        .accessibilityIdentifier(AccessibilityID.trendsChartDataPoint(chartId, index: index))
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
            },
            footer: { EmptyView() }
        )
    }

    // MARK: - 7. Workout Type Breakdown

    private var workoutTypeBreakdownCard: some View {
        let chartId = "workoutTypeBreakdown"
        let total = viewModel.typeBreakdownData.reduce(0) { $0 + $1.count }
        return FortiFitChartCard(
            chartId: chartId,
            title: "Workout Type Breakdown",
            summary: viewModel.chartSummary(for: chartId, context: modelContext),
            gradientAnchor: AppConstants.chartGradientAnchor(for: chartId),
            isEmpty: !viewModel.hasTypeBreakdownData,
            emptyMessage: AppConstants.chartEmptyMessages[chartId] ?? "",
            isReorderMode: viewModel.isReorderMode,
            onExpand: expandAction(for: chartId),
            controls: {
                breakdownTimeRangeToggle
            },
            chart: {
                Chart(viewModel.typeBreakdownData) { entry in
                    SectorMark(
                        angle: .value("Count", entry.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(AppConstants.workoutTypeChartColors[entry.workoutType] ?? FortiFitColors.primaryAccent)
                    .annotation(position: .overlay) {
                        if total > 0, Double(entry.count) / Double(total) >= 0.08 {
                            Text("\(entry.count)")
                                .font(FortiFitTypography.bodySmall)
                                .foregroundStyle(FortiFitColors.primaryText)
                        }
                    }
                }
                .chartBackground { proxy in
                    GeometryReader { geo in
                        if let plotFrame = proxy.plotFrame {
                            let frame = geo[plotFrame]
                            VStack(spacing: 2) {
                                Text("\(total)")
                                    .font(.system(size: 24, weight: .black))
                                    .foregroundStyle(FortiFitColors.primaryText)
                                Text(AppConstants.Trends.captionWorkouts)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(FortiFitColors.mutedText)
                                    .kerning(2)
                            }
                            .position(x: frame.midX, y: frame.midY)
                            .accessibilityIdentifier(AccessibilityID.trendsChart_workoutTypeBreakdown_centerLabel)
                        }
                    }
                }
                .frame(height: 200)
            },
            footer: {
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
        )
    }

    // MARK: - 8. Session Duration

    private var sessionDurationCard: some View {
        let chartId = "sessionDuration"
        return FortiFitChartCard(
            chartId: chartId,
            title: "Session Duration",
            summary: viewModel.chartSummary(for: chartId, context: modelContext),
            gradientAnchor: AppConstants.chartGradientAnchor(for: chartId),
            isEmpty: !viewModel.hasDurationData,
            emptyMessage: AppConstants.chartEmptyMessages[chartId] ?? "",
            isReorderMode: viewModel.isReorderMode,
            onExpand: expandAction(for: chartId),
            controls: { EmptyView() },
            chart: {
                Chart {
                    ForEach(Array(viewModel.durationWeeklyData.enumerated()), id: \.element.id) { index, entry in
                        let label = weekLabel(entry.weekStart)

                        BarMark(
                            x: .value("Week", label),
                            y: .value("Duration", entry.averageDuration)
                        )
                        .foregroundStyle(FortiFitColors.chartTeal)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5))
                        .accessibilityIdentifier(AccessibilityID.trendsChartDataPoint(chartId, index: index))
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
            },
            footer: { EmptyView() }
        )
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

    // MARK: - Expand Action

    private func expandAction(for chartType: String) -> (() -> Void)? {
        guard !viewModel.isReorderMode else { return nil }
        return {
            if let index = viewModel.charts.firstIndex(where: { $0.chartType == chartType }) {
                detailChartIndex = index
            }
        }
    }

    // MARK: - Helpers

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
