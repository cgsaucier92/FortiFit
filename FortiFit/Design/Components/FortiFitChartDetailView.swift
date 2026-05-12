import SwiftUI
import SwiftData
import Charts

struct FortiFitChartDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let charts: [TrendsChart]
    let initialChartIndex: Int

    @State private var currentPage: Int
    @State private var selectedRanges: [String: DetailTimeRange] = [:]
    @State private var selectedIndex: Int? = nil
    @State private var infoChartType: String? = nil
    @State private var selectedPRExercise: String = UserDefaults.standard.string(forKey: "trendsSelectedPRExercise") ?? ""
    @State private var selectedStrengthExercise: String = UserDefaults.standard.string(forKey: "trendsSelectedExercise") ?? ""

    private var settings: UserSettings { UserSettings.shared }

    init(charts: [TrendsChart], initialChartIndex: Int) {
        self.charts = charts
        self.initialChartIndex = initialChartIndex
        self._currentPage = State(initialValue: initialChartIndex)
    }

    private var currentChart: TrendsChart? {
        guard currentPage >= 0, currentPage < charts.count else { return nil }
        return charts[currentPage]
    }

    private var chartType: String {
        currentChart?.chartType ?? ""
    }

    private var activeRange: DetailTimeRange {
        selectedRanges[chartType] ?? DetailTimeRange.defaultRange(for: chartType)
    }

    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(Array(charts.enumerated()), id: \.element.id) { index, chart in
                chartDetailPage(for: chart)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(FortiFitColors.background)
        .onChange(of: currentPage) { _, _ in
            selectedIndex = nil
        }
        .sheet(item: Binding(
            get: { infoChartType.map { InfoChartWrapper(chartType: $0) } },
            set: { infoChartType = $0?.chartType }
        )) { item in
            if let content = AppConstants.chartInfoModalCopy[item.chartType] {
                FortiFitSeeInfoModal(content: content)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    // MARK: - Page Content

    @ViewBuilder
    private func chartDetailPage(for chart: TrendsChart) -> some View {
        let chartId = chart.chartType
        let range = selectedRanges[chartId] ?? DetailTimeRange.defaultRange(for: chartId)
        let eligibleRanges = DetailTimeRange.eligibleRanges(for: chartId)
        let title = AppConstants.trendsChartDisplayNames[chartId] ?? ""

        ScrollView {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapMedium) {
                topBar(chartId: chartId, title: title)

                detailHeaderSummary(chartId: chartId, range: range)

                if eligibleRanges.count > 1 {
                    rangeToggles(chartId: chartId, eligible: eligibleRanges, current: range)
                }

                detailChartContent(chartId: chartId, range: range)

                detailFooter(chartId: chartId, range: range)
            }
            .padding(.horizontal, FortiFitSpacing.screenHorizontal)
            .padding(.bottom, FortiFitSpacing.gapXLarge)
        }
        .onTapGesture {
            if selectedIndex != nil {
                selectedIndex = nil
            }
        }
        .accessibilityIdentifier(AccessibilityID.trendsChartDetailCard(chartId))
    }

    // MARK: - Top Bar

    @ViewBuilder
    private func topBar(chartId: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
            HStack {
                FortiFitBackButton(action: { dismiss() })
                    .accessibilityIdentifier(AccessibilityID.trendsChartDetailBackButton(chartId))
                Spacer()
            }

            HStack {
                Text(title)
                    .font(FortiFitTypography.screenHeading)
                    .foregroundStyle(FortiFitColors.primaryAccent)
                Spacer()
                Button {
                    infoChartType = chartId
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(FortiFitColors.mutedText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier(AccessibilityID.trendsChartDetailSeeInfoButton(chartId))
            }
        }
        .padding(.top, FortiFitSpacing.screenTop)
    }

    // MARK: - Header Summary with Delta

    @ViewBuilder
    private func detailHeaderSummary(chartId: String, range: DetailTimeRange) -> some View {
        if chartId == "workoutTypeBreakdown" {
            EmptyView()
        } else {
            let exerciseName = exerciseNameForChart(chartId)
            if let delta = TrendsChartService.comparisonDelta(for: chartId, exerciseName: exerciseName, range: range, context: modelContext) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(delta.hero)
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(heroColor(for: chartId))

                    Text(delta.caption)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(FortiFitColors.mutedText)
                        .kerning(2)
                        .padding(.top, 6)

                    if let deltaStr = delta.delta {
                        HStack(spacing: 4) {
                            Image(systemName: deltaIcon(delta.direction))
                                .font(.system(size: 11, weight: .bold))
                            Text(deltaStr)
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(deltaColor(delta.direction))
                        .padding(.top, 4)
                    }
                }
                .padding(.bottom, 16)
                .accessibilityIdentifier(AccessibilityID.trendsChartDetailHeaderSummary(chartId))
            }
        }
    }

    // MARK: - Range Toggles

    @ViewBuilder
    private func rangeToggles(chartId: String, eligible: [DetailTimeRange], current: DetailTimeRange) -> some View {
        HStack(spacing: FortiFitSpacing.elementSpacing) {
            ForEach(eligible, id: \.self) { range in
                Button {
                    selectedRanges[chartId] = range
                    selectedIndex = nil
                } label: {
                    Text(range.displayLabel)
                        .font(FortiFitTypography.label)
                        .kerning(FortiFitTypography.labelKerning)
                        .foregroundStyle(
                            current == range
                                ? FortiFitColors.primaryAccent
                                : FortiFitColors.mutedText
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            current == range
                                ? FortiFitColors.primaryAccent.opacity(0.15)
                                : FortiFitColors.elevatedSurface
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusPill))
                }
                .accessibilityIdentifier(AccessibilityID.trendsChartDetailRangeToggle(chartId, range: range.rawValue))
            }
        }
    }

    // MARK: - Chart Content Router

    @ViewBuilder
    private func detailChartContent(chartId: String, range: DetailTimeRange) -> some View {
        let exerciseName = exerciseNameForChart(chartId)
        let gradientAnchor = AppConstants.chartGradientAnchor(for: chartId)

        switch chartId {
        case "strengthTracker":
            let strengthExercises = TrendsChartService.exercisesWithStrengthData(context: modelContext)
            if !strengthExercises.isEmpty {
                FortiFitSelect(
                    options: strengthExercises,
                    selected: Binding(
                        get: { selectedStrengthExercise },
                        set: {
                            selectedStrengthExercise = $0
                            selectedIndex = nil
                            UserDefaults.standard.set($0, forKey: "trendsSelectedExercise")
                        }
                    ),
                    placeholder: "Select Exercise"
                )
            }
            lineChartDetail(chartId: chartId, range: range, exerciseName: exerciseName, color: FortiFitColors.chartPink, gradientAnchor: gradientAnchor, yLabel: settings.useLbs ? "lbs" : "kg")
        case "trainingFrequency":
            barChartDetail(chartId: chartId, range: range, color: FortiFitColors.positive, gradientAnchor: gradientAnchor, yLabel: "sessions")
        case "personalRecords":
            prTimelineDetail(chartId: chartId, exerciseName: exerciseName, gradientAnchor: gradientAnchor)
        case "trainingLoadTrend":
            trainingLoadDetail(chartId: chartId, range: range, gradientAnchor: gradientAnchor)
        case "workoutVolume":
            lineChartDetail(chartId: chartId, range: range, exerciseName: nil, color: FortiFitColors.chartPurple, gradientAnchor: gradientAnchor, yLabel: settings.useLbs ? "lbs" : "kg")
        case "rpeTrend":
            barChartDetail(chartId: chartId, range: range, color: FortiFitColors.chartOrange, gradientAnchor: gradientAnchor, yLabel: "RPE", yDomain: 0...10)
        case "workoutTypeBreakdown":
            breakdownDetail(chartId: chartId, range: range, gradientAnchor: gradientAnchor)
        case "sessionDuration":
            barChartDetail(chartId: chartId, range: range, color: FortiFitColors.chartTeal, gradientAnchor: gradientAnchor, yLabel: "min")
        default:
            EmptyView()
        }
    }

    // MARK: - Line Chart Detail (Strength Tracker, Workout Volume)

    @ViewBuilder
    private func lineChartDetail(chartId: String, range: DetailTimeRange, exerciseName: String?, color: Color, gradientAnchor: ChartGradientAnchor, yLabel: String) -> some View {
        let points = TrendsChartService.dataPoints(for: chartId, exerciseName: exerciseName, range: range, context: modelContext)

        if points.isEmpty {
            emptyChartState(chartId: chartId)
        } else {
            detailPlotArea(gradientAnchor: gradientAnchor) {
                Chart {
                    ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                        LineMark(
                            x: .value("Date", point.x),
                            y: .value("Value", point.y)
                        )
                        .foregroundStyle(selectedIndex == nil || selectedIndex == index ? color : color.opacity(0.35))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.x),
                            y: .value("Value", point.y)
                        )
                        .foregroundStyle(selectedIndex == nil || selectedIndex == index ? color : color.opacity(0.35))
                        .symbolSize(index == points.count - 1 ? 36 : 9)
                        .symbol {
                            if index == points.count - 1 && selectedIndex == nil {
                                Circle()
                                    .fill(color)
                                    .frame(width: 6, height: 6)
                                    .shadow(color: color.opacity(0.6), radius: 4)
                            } else {
                                Circle()
                                    .fill(selectedIndex == nil || selectedIndex == index ? color : color.opacity(0.35))
                                    .frame(width: 3, height: 3)
                            }
                        }
                        .accessibilityIdentifier(AccessibilityID.trendsChartDetailDataPoint(chartId, index: index))
                    }

                    if let idx = selectedIndex, idx < points.count {
                        RuleMark(x: .value("Selected", points[idx].x))
                            .foregroundStyle(color.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(FortiFitColors.border)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(fullNumericLabel(v, suffix: ""))
                                    .foregroundStyle(FortiFitColors.mutedText)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(FortiFitColors.border)
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                            .foregroundStyle(FortiFitColors.mutedText)
                    }
                }
                .chartXScale(range: .plotDimension(padding: 16))
                .chartOverlay { proxy in
                    GeometryReader { _ in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        scrubToNearest(proxy: proxy, location: value.location, points: points, chartId: chartId)
                                    }
                            )
                            .onTapGesture { location in
                                scrubToNearest(proxy: proxy, location: location, points: points, chartId: chartId)
                            }
                    }
                }
                .frame(height: 300)
            }

            selectionAnnotation(points: points, chartId: chartId)
        }
    }

    // MARK: - Bar Chart Detail (Frequency, RPE, Duration)

    @ViewBuilder
    private func barChartDetail(chartId: String, range: DetailTimeRange, color: Color, gradientAnchor: ChartGradientAnchor, yLabel: String, yDomain: ClosedRange<Double>? = nil) -> some View {
        let points = TrendsChartService.dataPoints(for: chartId, exerciseName: nil, range: range, context: modelContext)

        if points.isEmpty {
            emptyChartState(chartId: chartId)
        } else {
            let formatter = DateFormatter()
            let _ = (formatter.dateFormat = "M/d")
            let labelStride = max(1, Int(ceil(Double(points.count) / 6.0)))

            detailPlotArea(gradientAnchor: gradientAnchor) {
                Chart {
                    ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                        let label = formatter.string(from: point.x)
                        BarMark(
                            x: .value("Period", label),
                            y: .value("Value", point.y)
                        )
                        .foregroundStyle(selectedIndex == nil || selectedIndex == index ? color : color.opacity(0.35))
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5))
                        .accessibilityIdentifier(AccessibilityID.trendsChartDetailDataPoint(chartId, index: index))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(FortiFitColors.border)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(fullNumericLabel(v, suffix: ""))
                                    .foregroundStyle(FortiFitColors.mutedText)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        if value.index > 0 && value.index % labelStride == 0 {
                            AxisValueLabel()
                                .foregroundStyle(FortiFitColors.mutedText)
                        }
                    }
                }
                .modify { chart in
                    if let domain = yDomain {
                        chart.chartYScale(domain: domain)
                    } else {
                        chart
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { _ in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        tapBarNearest(proxy: proxy, location: value.location, points: points, chartId: chartId)
                                    }
                            )
                    }
                }
                .frame(height: 300)
            }

            selectionAnnotation(points: points, chartId: chartId)
        }
    }

    // MARK: - Training Load Detail

    @ViewBuilder
    private func trainingLoadDetail(chartId: String, range: DetailTimeRange, gradientAnchor: ChartGradientAnchor) -> some View {
        let points = TrendsChartService.dataPoints(for: chartId, exerciseName: nil, range: range, context: modelContext)

        if points.isEmpty {
            emptyChartState(chartId: chartId)
        } else {
            let formatter = DateFormatter()
            let _ = (formatter.dateFormat = "M/d")
            let labelStride = max(1, Int(ceil(Double(points.count) / 6.0)))

            detailPlotArea(gradientAnchor: gradientAnchor) {
                Chart {
                    RectangleMark(xStart: nil, xEnd: nil, yStart: .value("", 81), yEnd: .value("", 100))
                        .foregroundStyle(FortiFitColors.alert.opacity(0.15))
                    RectangleMark(xStart: nil, xEnd: nil, yStart: .value("", 56), yEnd: .value("", 80))
                        .foregroundStyle(FortiFitColors.warning.opacity(0.15))
                    RectangleMark(xStart: nil, xEnd: nil, yStart: .value("", 31), yEnd: .value("", 55))
                        .foregroundStyle(FortiFitColors.caution.opacity(0.15))
                    RectangleMark(xStart: nil, xEnd: nil, yStart: .value("", 1), yEnd: .value("", 30))
                        .foregroundStyle(FortiFitColors.positive.opacity(0.15))

                    ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                        let label = formatter.string(from: point.x)
                        let zoneResult = ExerciseLoadService.classifyZone(score: point.y)
                        let dotColor = Color(hex: zoneResult.zoneColor)

                        PointMark(
                            x: .value("Day", label),
                            y: .value("Score", point.y)
                        )
                        .foregroundStyle(selectedIndex == nil || selectedIndex == index ? dotColor : dotColor.opacity(0.35))
                        .symbolSize(60)
                        .accessibilityIdentifier(AccessibilityID.trendsChartDetailDataPoint(chartId, index: index))

                        LineMark(
                            x: .value("Day", label),
                            y: .value("Score", point.y),
                            series: .value("Series", "Load")
                        )
                        .foregroundStyle(FortiFitColors.primaryText.opacity(0.3))
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(FortiFitColors.border)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))")
                                    .foregroundStyle(FortiFitColors.mutedText)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        if value.index > 0 && value.index % labelStride == 0 {
                            AxisValueLabel()
                                .foregroundStyle(FortiFitColors.mutedText)
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { _ in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        tapBarNearest(proxy: proxy, location: value.location, points: points, chartId: chartId)
                                    }
                            )
                    }
                }
                .frame(height: 300)
            }

            selectionAnnotation(points: points, chartId: chartId)

            HStack(spacing: FortiFitSpacing.gapSmall) {
                legendDot(color: FortiFitColors.positive, label: "Low")
                legendDot(color: FortiFitColors.caution, label: "Mod")
                legendDot(color: FortiFitColors.warning, label: "High")
                legendDot(color: FortiFitColors.alert, label: "Peak")
            }
        }
    }

    // MARK: - PR Timeline Detail

    @ViewBuilder
    private func prTimelineDetail(chartId: String, exerciseName: String?, gradientAnchor: ChartGradientAnchor) -> some View {
        let prExercises = TrendsChartService.exercisesWithPRs(context: modelContext)
        let name = exerciseName ?? ""
        let events = TrendsChartService.fullPRTimeline(for: name, context: modelContext)

        if prExercises.isEmpty {
            emptyChartState(chartId: chartId)
        } else {
            FortiFitSelect(
                options: prExercises,
                selected: Binding(
                    get: { selectedPRExercise },
                    set: {
                        selectedPRExercise = $0
                        selectedIndex = nil
                        UserDefaults.standard.set($0, forKey: "trendsSelectedPRExercise")
                    }
                ),
                placeholder: "Select Exercise"
            )

            if events.isEmpty {
                emptyChartState(chartId: chartId)
            } else {
                let useLbs = settings.useLbs

                detailPlotArea(gradientAnchor: gradientAnchor) {
                    Chart {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            let displayWeight = useLbs ? event.weightKg * UnitConversion.kgToLbsFactor : event.weightKg

                            LineMark(
                                x: .value("Date", event.date),
                                y: .value("Weight", displayWeight)
                            )
                            .foregroundStyle(selectedIndex == nil || selectedIndex == index ? FortiFitColors.chartDeepBlue : FortiFitColors.chartDeepBlue.opacity(0.35))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Date", event.date),
                                y: .value("Weight", displayWeight)
                            )
                            .foregroundStyle(selectedIndex == nil || selectedIndex == index ? FortiFitColors.chartDeepBlue : FortiFitColors.chartDeepBlue.opacity(0.35))
                            .symbolSize(36)
                            .symbol {
                                Circle()
                                    .fill(selectedIndex == nil || selectedIndex == index ? FortiFitColors.chartDeepBlue : FortiFitColors.chartDeepBlue.opacity(0.35))
                                    .frame(width: 6, height: 6)
                                    .shadow(color: FortiFitColors.chartDeepBlue.opacity(0.6), radius: 4)
                            }
                            .accessibilityIdentifier(AccessibilityID.trendsChartDetailPRTimelinePoint(index: index))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(FortiFitColors.border)
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(fullNumericLabel(v, suffix: ""))
                                        .foregroundStyle(FortiFitColors.mutedText)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(FortiFitColors.border)
                            AxisValueLabel()
                                .foregroundStyle(FortiFitColors.mutedText)
                        }
                    }
                    .chartXScale(range: .plotDimension(padding: 16))
                    .chartOverlay { proxy in
                        GeometryReader { _ in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            tapPRTimeline(proxy: proxy, location: value.location, events: events, chartId: chartId)
                                        }
                                )
                        }
                    }
                    .frame(height: 300)
                }

                if let idx = selectedIndex, idx < events.count {
                    let event = events[idx]
                    let displayWeight = useLbs ? event.weightKg * UnitConversion.kgToLbsFactor : event.weightKg
                    let displayDelta = useLbs ? event.deltaKg * UnitConversion.kgToLbsFactor : event.deltaKg
                    let unit = useLbs ? "lbs" : "kg"

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(displayWeight.rounded())) \(unit)")
                            .font(FortiFitTypography.bodySmall.bold())
                            .foregroundStyle(FortiFitColors.primaryText)
                        Text(event.date.formatted(date: .abbreviated, time: .omitted))
                            .font(FortiFitTypography.bodySmall.bold())
                            .foregroundStyle(FortiFitColors.mutedText)
                        Text("+\(Int(displayDelta.rounded())) \(unit) from prior PR")
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.positive)
                    }
                    .accessibilityIdentifier(AccessibilityID.trendsChartDetailSelectionAnnotation(chartId))
                }
            }
        }
    }

    // MARK: - Workout Type Breakdown Detail

    @State private var breakdownSortMode: BreakdownSortMode = .countDesc

    enum BreakdownSortMode {
        case countDesc, countAsc, alphabetical

        var next: BreakdownSortMode {
            switch self {
            case .countDesc: return .countAsc
            case .countAsc: return .alphabetical
            case .alphabetical: return .countDesc
            }
        }
    }

    @ViewBuilder
    private func breakdownDetail(chartId: String, range: DetailTimeRange, gradientAnchor: ChartGradientAnchor) -> some View {
        let rows = TrendsChartService.breakdownPercentages(range: range, context: modelContext)

        if rows.isEmpty {
            emptyChartState(chartId: chartId)
        } else {
            let total = rows.reduce(0) { $0 + $1.count }

            detailPlotArea(gradientAnchor: gradientAnchor) {
                Chart(rows) { row in
                    SectorMark(
                        angle: .value("Count", row.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(AppConstants.workoutTypeChartColors[row.type] ?? FortiFitColors.primaryAccent)
                    .annotation(position: .overlay) {
                        if total > 0, Double(row.count) / Double(total) >= 0.08 {
                            Text("\(row.count)")
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
                        }
                    }
                }
                .frame(height: 250)
            }

            breakdownLegendTable(rows: rows)
        }
    }

    @ViewBuilder
    private func breakdownLegendTable(rows: [WorkoutTypeBreakdownRow]) -> some View {
        let sorted = sortedBreakdownRows(rows)

        VStack(spacing: 0) {
            HStack {
                Button { breakdownSortMode = breakdownSortMode.next } label: {
                    Text("Type")
                        .font(FortiFitTypography.label)
                        .kerning(FortiFitTypography.labelKerning)
                        .foregroundStyle(FortiFitColors.mutedText)
                }
                .accessibilityIdentifier(AccessibilityID.trendsChartDetailBreakdownSortHeader(column: "type"))
                Spacer()
                Button { breakdownSortMode = breakdownSortMode.next } label: {
                    Text("Count")
                        .font(FortiFitTypography.label)
                        .kerning(FortiFitTypography.labelKerning)
                        .foregroundStyle(FortiFitColors.mutedText)
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(width: 55)
                .accessibilityIdentifier(AccessibilityID.trendsChartDetailBreakdownSortHeader(column: "count"))
                Button { breakdownSortMode = breakdownSortMode.next } label: {
                    Text("%")
                        .font(FortiFitTypography.label)
                        .kerning(FortiFitTypography.labelKerning)
                        .foregroundStyle(FortiFitColors.mutedText)
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(width: 40)
                .accessibilityIdentifier(AccessibilityID.trendsChartDetailBreakdownSortHeader(column: "percent"))
                Button { breakdownSortMode = breakdownSortMode.next } label: {
                    Text("Avg Dur")
                        .font(FortiFitTypography.label)
                        .kerning(FortiFitTypography.labelKerning)
                        .foregroundStyle(FortiFitColors.mutedText)
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(width: 60)
                .accessibilityIdentifier(AccessibilityID.trendsChartDetailBreakdownSortHeader(column: "avgDuration"))
            }
            .padding(.vertical, 8)

            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, row in
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppConstants.workoutTypeChartColors[row.type] ?? FortiFitColors.primaryAccent)
                            .frame(width: 8, height: 8)
                        Text(row.type)
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.primaryText)
                    }
                    Spacer()
                    Text("\(row.count)")
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(FortiFitColors.primaryText)
                        .frame(width: 55, alignment: .trailing)
                    Text(String(format: "%.0f%%", row.percent))
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(FortiFitColors.primaryText)
                        .frame(width: 40, alignment: .trailing)
                    Text(row.avgDurationMinutes.map { "\($0) min" } ?? "—")
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(FortiFitColors.primaryText)
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.vertical, 6)
                .accessibilityIdentifier(AccessibilityID.trendsChartDetailBreakdownLegendRow(index: index))

                if index < sorted.count - 1 {
                    Divider()
                        .background(FortiFitColors.border)
                }
            }
        }
        .padding(FortiFitSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                .fill(FortiFitColors.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                .stroke(FortiFitColors.border, lineWidth: 1)
        )
    }

    // MARK: - Footer

    @ViewBuilder
    private func detailFooter(chartId: String, range: DetailTimeRange) -> some View {
        switch chartId {
        case "trainingFrequency":
            legendSquare(color: FortiFitColors.positive, label: "Sessions")
        default:
            EmptyView()
        }
    }

    // MARK: - Shared Detail Helpers

    @ViewBuilder
    private func detailPlotArea<Content: View>(gradientAnchor: ChartGradientAnchor, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 8, trailing: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(FortiFitColors.border, lineWidth: 1)
            )
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(FortiFitColors.cardSurface)
                    gradientView(gradientAnchor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            )
    }

    @ViewBuilder
    private func gradientView(_ anchor: ChartGradientAnchor) -> some View {
        switch anchor {
        case .single(let color):
            LinearGradient(colors: [color.opacity(0.2), color.opacity(0)], startPoint: .top, endPoint: .bottom)
        case .horizontalSplit(let leading, let trailing):
            ZStack {
                LinearGradient(colors: [leading, trailing], startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [Color.white.opacity(0.2), Color.clear], startPoint: .top, endPoint: .bottom)
                    .blendMode(.multiply)
            }
            .opacity(0.2)
        }
    }

    @ViewBuilder
    private func emptyChartState(chartId: String) -> some View {
        Text(AppConstants.chartEmptyMessages[chartId] ?? "Not enough data yet.")
            .font(FortiFitTypography.note)
            .foregroundStyle(FortiFitColors.mutedText)
            .frame(maxWidth: .infinity)
            .frame(height: 200)
    }

    @ViewBuilder
    private func selectionAnnotation(points: [ChartDataPoint], chartId: String) -> some View {
        if let idx = selectedIndex, idx < points.count {
            let point = points[idx]
            VStack(alignment: .leading, spacing: 2) {
                Text(point.label)
                    .font(FortiFitTypography.bodySmall.bold())
                    .foregroundStyle(FortiFitColors.primaryText)
                Text(point.x.formatted(date: .abbreviated, time: .omitted))
                    .font(FortiFitTypography.bodySmall.bold())
                    .foregroundStyle(FortiFitColors.mutedText)
            }
            .accessibilityIdentifier(AccessibilityID.trendsChartDetailSelectionAnnotation(chartId))
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(FortiFitTypography.bodySmall)
                .foregroundStyle(FortiFitColors.mutedText)
        }
    }

    private func legendSquare(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(FortiFitTypography.bodySmall)
                .foregroundStyle(FortiFitColors.mutedText)
        }
    }

    // MARK: - Selection Logic

    private func scrubToNearest(proxy: ChartProxy, location: CGPoint, points: [ChartDataPoint], chartId: String) {
        guard !points.isEmpty else { return }

        if let dateValue: Date = proxy.value(atX: location.x) {
            var closestIndex = 0
            var closestDist = abs(points[0].x.timeIntervalSince(dateValue))
            for i in 1..<points.count {
                let dist = abs(points[i].x.timeIntervalSince(dateValue))
                if dist < closestDist {
                    closestDist = dist
                    closestIndex = i
                }
            }
            if selectedIndex != closestIndex {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                selectedIndex = closestIndex
            }
        }
    }

    private func tapBarNearest(proxy: ChartProxy, location: CGPoint, points: [ChartDataPoint], chartId: String) {
        guard !points.isEmpty else { return }
        let plotWidth = proxy.plotSize.width
        let barWidth = plotWidth / CGFloat(points.count)
        let index = min(max(0, Int(location.x / barWidth)), points.count - 1)
        if selectedIndex != index {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            selectedIndex = index
        }
    }

    private func tapPRTimeline(proxy: ChartProxy, location: CGPoint, events: [PRTimelineEvent], chartId: String) {
        guard !events.isEmpty else { return }
        if let dateValue: Date = proxy.value(atX: location.x) {
            var closestIndex = 0
            var closestDist = abs(events[0].date.timeIntervalSince(dateValue))
            for i in 1..<events.count {
                let dist = abs(events[i].date.timeIntervalSince(dateValue))
                if dist < closestDist {
                    closestDist = dist
                    closestIndex = i
                }
            }
            if selectedIndex != closestIndex {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                selectedIndex = closestIndex
            }
        }
    }

    // MARK: - Helpers

    private func exerciseNameForChart(_ chartId: String) -> String? {
        switch chartId {
        case "strengthTracker":
            return selectedStrengthExercise.isEmpty ? nil : selectedStrengthExercise
        case "personalRecords":
            return selectedPRExercise.isEmpty ? nil : selectedPRExercise
        default:
            return nil
        }
    }

    private func heroColor(for chartId: String) -> Color {
        let anchor = AppConstants.chartGradientAnchor(for: chartId)
        switch anchor {
        case .single(let color): return color
        case .horizontalSplit: return FortiFitColors.primaryText
        }
    }

    private func deltaIcon(_ direction: DeltaDirection) -> String {
        switch direction {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .flat: return "minus"
        }
    }

    private func deltaColor(_ direction: DeltaDirection) -> Color {
        switch direction {
        case .up: return FortiFitColors.positive
        case .down: return FortiFitColors.alert
        case .flat: return FortiFitColors.mutedText
        }
    }

    private func fullNumericLabel(_ value: Double, suffix: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        return suffix.isEmpty ? formatted : "\(formatted) \(suffix)"
    }

    private func sortedBreakdownRows(_ rows: [WorkoutTypeBreakdownRow]) -> [WorkoutTypeBreakdownRow] {
        switch breakdownSortMode {
        case .countDesc: return rows.sorted { $0.count > $1.count }
        case .countAsc: return rows.sorted { $0.count < $1.count }
        case .alphabetical: return rows.sorted { $0.type < $1.type }
        }
    }
}

// MARK: - Chart Modifier Helper

private extension View {
    @ViewBuilder
    func modify<Content: View>(@ViewBuilder _ transform: (Self) -> Content) -> some View {
        transform(self)
    }
}

// MARK: - Info Chart Wrapper

private struct InfoChartWrapper: Identifiable {
    let chartType: String
    var id: String { chartType }
}
