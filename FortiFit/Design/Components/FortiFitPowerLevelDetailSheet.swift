import SwiftUI
import SwiftData

/// Power Level Breakdown Sheet — opened by tapping the Power Level home widget.
/// Hero + window comparison + top exercises + calculated nudge.
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
                windowComparisonBlock
                topExercisesBlock
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

    // MARK: - Hero (Phase 12 — icon-only gauge)

    /// `pct_change` for the hero gauge thumb. `nil` in cold-start, no-data, and
    /// no-baseline cases — drives the gauge's no-data presentation per
    /// CONSTANTS.md § Power Level Gauge → Empty / No-Data State.
    private var heroPctChange: Double? {
        if isColdStart || powerLevel.status == .noData { return nil }
        if windowComparison.previous30dAvg == 0 { return nil }
        return windowComparison.deltaPct
    }

    private var heroStatusForGauge: PowerLevelService.Status {
        // In cold-start, gauge renders Steady-gray no-data per spec — but the
        // gauge itself short-circuits to no-data when pctChange is nil, so the
        // status only steers the (suppressed) thumb color. Keep the real status
        // for the directional indicator above.
        powerLevel.status
    }

    private var heroBlock: some View {
        FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapMedium) {
                heroSummaryRow
                FortiFitPowerLevelGauge(
                    status: heroStatusForGauge,
                    pctChange: heroPctChange,
                    scale: .hero,
                    gaugeIdentifier: AccessibilityID.powerLevelDetailSheet_heroGauge,
                    thumbIdentifier: AccessibilityID.powerLevelDetailSheet_heroGaugeThumb,
                    overflowIndicatorIdentifier: AccessibilityID.powerLevelDetailSheet_heroGaugeOverflowIndicator,
                    pulseHaloIdentifier: AccessibilityID.powerLevelDetailSheet_heroGaugeThumbPulse
                )
            }
        }
        .accessibilityIdentifier(AccessibilityID.powerLevelDetailSheet_hero)
    }

    @ViewBuilder
    private var heroSummaryRow: some View {
        HStack(alignment: .center, spacing: FortiFitSpacing.gapMedium) {
            Text(heroIndicatorGlyph)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(heroIndicatorColor)

            VStack(alignment: .leading, spacing: 2) {
                if isColdStart {
                    Text(AppConstants.WidgetDetail.EmptyState.powerLevelHero)
                        .font(FortiFitTypography.note)
                        .foregroundStyle(FortiFitColors.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: FortiFitSpacing.elementSpacing) {
                        Text(formattedVolume(windowComparison.current30dAvg))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(FortiFitColors.primaryText)
                        Text("avg volume")
                            .font(FortiFitTypography.labelSmall)
                            .foregroundStyle(FortiFitColors.mutedText)
                    }
                    Text(heroDeltaCaption)
                        .font(FortiFitTypography.labelSmall)
                        .foregroundStyle(FortiFitColors.mutedText)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var heroIndicatorGlyph: String {
        FortiFitPowerLevelGauge.glyph(for: powerLevel.status)
    }

    private var heroIndicatorColor: Color {
        // Cold-start collapses to muted regardless of underlying status — the
        // gauge is in no-data state and the indicator must agree.
        if isColdStart || powerLevel.status == .noData {
            return FortiFitColors.mutedText
        }
        return FortiFitPowerLevelGauge.color(for: powerLevel.status)
    }

    private var heroDeltaCaption: String {
        guard let pct = heroPctChange else { return "No data" }
        let rounded = Int(pct.rounded())
        let sign = rounded >= 0 ? "+" : ""
        return "\(sign)\(rounded)% vs prior 30 days"
    }

    private var isColdStart: Bool {
        nudge.archetype == .coldStart
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
                Text("Driving Your Trend")
                    .font(FortiFitTypography.detailSheetItemTitle)
                    .foregroundStyle(FortiFitColors.primaryAccent)

                Text("% change in volume vs previous 30 days")
                    .font(FortiFitTypography.labelSmall)
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
        // Color matches the *displayed* (rounded) value's sign so near-zero
        // values like +0.3% — which render as "0%" — share the muted treatment.
        let roundedDelta = Int(exercise.deltaPct.rounded())
        let deltaColor: Color
        if !hasBaseline {
            deltaColor = FortiFitColors.mutedText
        } else if roundedDelta > 0 {
            deltaColor = FortiFitColors.positive
        } else if roundedDelta < 0 {
            deltaColor = FortiFitColors.alert
        } else {
            deltaColor = FortiFitColors.mutedText
        }
        let deltaLabel = hasBaseline ? "\(sign)\(roundedDelta)%" : "\u{2014}"
        return HStack(alignment: .center, spacing: FortiFitSpacing.elementSpacing) {
            Text(exercise.exerciseName)
                .font(FortiFitTypography.bodySmall)
                .foregroundStyle(FortiFitColors.mutedText)
                .lineLimit(1)
            Spacer()
            Text(deltaLabel)
                .font(FortiFitTypography.labelSmall)
                .foregroundStyle(deltaColor)
        }
        .padding(.vertical, FortiFitSpacing.elementSpacing / 2)
        .accessibilityIdentifier(AccessibilityID.powerLevelDetailSheet_topExerciseRow(index))
    }

    // MARK: - Window Comparison (Phase 12 — two-bar card)

    @ViewBuilder
    private var windowComparisonBlock: some View {
        // Hide entire block when either window is zero — unchanged from the
        // pre-Phase-12 single-line band.
        if windowComparison.current30dAvg > 0 && windowComparison.previous30dAvg > 0 {
            windowComparisonCard
        }
    }

    private var windowComparisonCard: some View {
        let statusColor = FortiFitPowerLevelGauge.color(for: powerLevel.status)
        let largerAvg = max(windowComparison.current30dAvg, windowComparison.previous30dAvg)
        let currentRatio = largerAvg > 0 ? windowComparison.current30dAvg / largerAvg : 0
        let previousRatio = largerAvg > 0 ? windowComparison.previous30dAvg / largerAvg : 0

        return FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapMedium) {
                windowComparisonHeader(statusColor: statusColor)
                windowComparisonBar(
                    label: "PREVIOUS 30D",
                    labelColor: FortiFitColors.mutedText,
                    valueText: formattedVolume(windowComparison.previous30dAvg),
                    valueColor: FortiFitColors.mutedText,
                    fillColor: FortiFitColors.mutedText,
                    ratio: previousRatio,
                    identifier: AccessibilityID.powerLevelDetailSheet_windowComparison_previousBar
                )
                windowComparisonBar(
                    label: "CURRENT 30D",
                    labelColor: statusColor,
                    valueText: formattedVolume(windowComparison.current30dAvg),
                    valueColor: FortiFitColors.primaryText,
                    fillColor: statusColor,
                    ratio: currentRatio,
                    identifier: AccessibilityID.powerLevelDetailSheet_windowComparison_currentBar
                )
            }
        }
        .accessibilityIdentifier(AccessibilityID.powerLevelDetailSheet_windowComparison)
    }

    private func windowComparisonHeader(statusColor: Color) -> some View {
        let rounded = Int(windowComparison.deltaPct.rounded())
        let sign = rounded >= 0 ? "+" : ""
        let chipText = "\(sign)\(rounded)%"
        return HStack {
            Text("Window Comparison")
                .font(FortiFitTypography.detailSheetItemTitle)
                .foregroundStyle(FortiFitColors.primaryAccent)
            Spacer()
            Text(chipText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(statusColor)
                .padding(.horizontal, FortiFitSpacing.elementSpacing)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusPill)
                        .fill(statusColor.opacity(0.12))
                )
                .accessibilityIdentifier(AccessibilityID.powerLevelDetailSheet_windowComparison_deltaChip)
        }
    }

    private func windowComparisonBar(
        label: String,
        labelColor: Color,
        valueText: String,
        valueColor: Color,
        fillColor: Color,
        ratio: Double,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing / 2) {
            HStack {
                Text(label)
                    .font(FortiFitTypography.labelSmall)
                    .kerning(1)
                    .foregroundStyle(labelColor)
                Spacer()
                Text(valueText)
                    .font(FortiFitTypography.labelSmall)
                    .foregroundStyle(valueColor)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(FortiFitColors.elevatedSurface)
                        .frame(width: proxy.size.width, height: 10)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(fillColor)
                        .frame(width: proxy.size.width * CGFloat(max(0, min(ratio, 1))), height: 10)
                }
            }
            .frame(height: 10)
        }
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Nudge

    private var nudgeBlock: some View {
        FortiFitCard {
            Text(renderedNudgeCopy)
                .font(FortiFitTypography.body)
                .foregroundStyle(FortiFitColors.primaryText)
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
    }
}
