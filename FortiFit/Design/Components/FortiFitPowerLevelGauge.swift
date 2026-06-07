import SwiftUI

/// Pure helper mapping `pct_change` onto the gauge track [0…1].
///
/// Spec: `position = (clamp(pct, −30, +30) + 30) / 60`. Returns `nil` when the
/// upstream `pct_change` is undefined (cold-start / no-baseline), which drives
/// the gauge's no-data presentation.
///
/// See SERVICES.md § Power Level Algorithm → Widget & Hero Gauge Position and
/// CONSTANTS.md § Power Level Gauge.
func powerLevelGaugePosition(pctChange: Double?) -> Double? {
    guard let pct = pctChange else { return nil }
    let clamped = min(max(pct, -30), 30)
    return (clamped + 30) / 60
}

/// Continuous gauge that surfaces `PowerLevelService` `pct_change` across a
/// fixed −30%…+30% visible range with status-colored zones and a thumb at the
/// current value. Reused by the Power Level widget (compact) and the
/// Breakdown Sheet hero (hero). One component, two scales — see CONSTANTS.md
/// § Power Level Gauge for visual tokens.
struct FortiFitPowerLevelGauge: View {
    enum Scale {
        case compact
        case hero
    }

    /// Direction of an off-scale `pct_change`. Drives the overflow chevron's
    /// pointing direction; the halo inherits the thumb's status color.
    /// `nil` when `|pctChange| ≤ 30` or in the no-data state.
    enum OverflowDirection {
        case positive
        case negative
    }

    let status: PowerLevelService.Status
    /// Raw `pct_change` from `windowComparison().deltaPct`. `nil` → no-data
    /// state (Steady-gray track, no thumb).
    let pctChange: Double?
    var scale: Scale = .compact
    /// Accessibility identifier for the gauge container. Hosts wire this per
    /// `AccessibilityIdentifiers.swift`.
    var gaugeIdentifier: String
    var thumbIdentifier: String
    /// Identifier on the off-scale halo+chevron composite. Present in the view
    /// hierarchy only when `|pctChange| > 30` (CONSTANTS.md § Power Level Gauge
    /// → Overflow Indicator).
    var overflowIndicatorIdentifier: String
    /// Identifier on the breathing halo behind the thumb. Present only when
    /// `shouldPulse(...)` is true (CONSTANTS.md § Power Level Gauge → Thumb
    /// Pulse).
    var pulseHaloIdentifier: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseExpanded: Bool = false

    private static let trackHeight: CGFloat = 8
    private static let thumbDiameter: CGFloat = 16
    private static let tickWidth: CGFloat = 1

    // Overflow indicator tokens — CONSTANTS § Power Level Gauge → Overflow Indicator.
    // Halo radii scale from `thumbDiameter` so the indicator stays in proportion
    // between the compact (widget) and hero (Breakdown Sheet) renderings.
    private static let overflowHaloOuterRatio: CGFloat = 0.875
    private static let overflowHaloInnerRatio: CGFloat = 0.6875
    private static let overflowHaloOuterOpacity: CGFloat = 0.18
    private static let overflowHaloInnerOpacity: CGFloat = 0.28
    private static let overflowChevronPointSize: CGFloat = 9
    private static let overflowThreshold: Double = 30

    // Pulse tokens — CONSTANTS § Power Level Gauge → Thumb Pulse.
    private static let pulseScaleMin: CGFloat = 1.0
    private static let pulseScaleMax: CGFloat = 2.1
    private static let pulseOpacityMax: Double = 0.35
    private static let pulseDuration: Double = 1.6
    /// Horizontal padding applied around the track and axis labels so the
    /// thumb at clamped positions (and its off-scale halo when overflowing)
    /// have breathing room from the parent card's inner edge. Chosen to clear
    /// the worst-case lateral extent — the off-scale halo's outer radius
    /// (`thumbDiameter * overflowHaloOuterRatio ≈ 14pt`) — with a 2pt buffer.
    private static let gaugeHorizontalInset: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.gapMedium) {
            track
            axisLabels
        }
        .padding(.horizontal, Self.gaugeHorizontalInset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voiceOverLabel)
    }

    // MARK: - Track

    private var track: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                trackZones(width: proxy.size.width)
                thresholdTicks(width: proxy.size.width)
                if let position {
                    ZStack {
                        if shouldPulse {
                            pulseHalo
                        }
                        if overflowDirection != nil {
                            overflowHalos
                        }
                        thumb
                        if let overflowDirection {
                            overflowChevron(direction: overflowDirection)
                        }
                    }
                    .offset(x: thumbX(in: proxy.size.width, position: position))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: position)
                }
            }
        }
        .frame(height: Self.thumbDiameter)
        .accessibilityIdentifier(gaugeIdentifier)
    }

    @ViewBuilder
    private func trackZones(width: CGFloat) -> some View {
        if isNoData {
            // Steady-gray track only — no zones.
            RoundedRectangle(cornerRadius: Self.trackHeight / 2)
                .fill(FortiFitColors.border)
                .frame(width: width, height: Self.trackHeight)
        } else {
            // Red (-30…-10) | Gray (-10…+10) | Green (+10…+30).
            // Boundaries at 1/3 and 2/3 of track width.
            HStack(spacing: 0) {
                Rectangle()
                    .fill(FortiFitColors.alert)
                    .frame(width: width / 3, height: Self.trackHeight)
                Rectangle()
                    .fill(FortiFitColors.border)
                    .frame(width: width / 3, height: Self.trackHeight)
                Rectangle()
                    .fill(FortiFitColors.positive)
                    .frame(width: width - 2 * (width / 3), height: Self.trackHeight)
            }
            .clipShape(RoundedRectangle(cornerRadius: Self.trackHeight / 2))
            .frame(width: width, height: Self.trackHeight)
        }
    }

    private func thresholdTicks(width: CGFloat) -> some View {
        // Two 1pt dividers at -10% (1/3) and +10% (2/3), filled with card-bg
        // for contrast. Hidden in the no-data state per CONSTANTS § Empty.
        ZStack(alignment: .leading) {
            if !isNoData {
                Rectangle()
                    .fill(FortiFitColors.cardSurface)
                    .frame(width: Self.tickWidth, height: Self.trackHeight)
                    .offset(x: width / 3 - Self.tickWidth / 2)
                Rectangle()
                    .fill(FortiFitColors.cardSurface)
                    .frame(width: Self.tickWidth, height: Self.trackHeight)
                    .offset(x: 2 * width / 3 - Self.tickWidth / 2)
            }
        }
    }

    private var thumb: some View {
        Circle()
            .fill(thumbColor)
            .frame(width: Self.thumbDiameter, height: Self.thumbDiameter)
            .overlay(
                Circle().stroke(FortiFitColors.cardSurface, lineWidth: 2)
            )
            .accessibilityIdentifier(thumbIdentifier)
    }

    /// Breathing halo behind the thumb. Renders only when `shouldPulse` is true
    /// — suppressed on `.steady` / `.noData`, when off-scale, and when
    /// `accessibilityReduceMotion` is on. Color tracks `thumbColor` so status
    /// changes propagate automatically.
    private var pulseHalo: some View {
        Circle()
            .fill(thumbColor)
            .frame(width: Self.thumbDiameter, height: Self.thumbDiameter)
            .scaleEffect(pulseExpanded ? Self.pulseScaleMax : Self.pulseScaleMin)
            .opacity(pulseExpanded ? 0 : Self.pulseOpacityMax)
            .accessibilityIdentifier(pulseHaloIdentifier)
            .onAppear {
                withAnimation(.easeOut(duration: Self.pulseDuration).repeatForever(autoreverses: false)) {
                    pulseExpanded = true
                }
            }
    }

    /// Off-scale halos: two concentric circles in the thumb's status color,
    /// rendered **behind** the thumb so they bleed outward around the clamped
    /// position. See CONSTANTS.md § Power Level Gauge → Overflow Indicator.
    private var overflowHalos: some View {
        let outerDiameter = Self.thumbDiameter * Self.overflowHaloOuterRatio * 2
        let innerDiameter = Self.thumbDiameter * Self.overflowHaloInnerRatio * 2
        return ZStack {
            Circle()
                .fill(thumbColor.opacity(Self.overflowHaloOuterOpacity))
                .frame(width: outerDiameter, height: outerDiameter)
            Circle()
                .fill(thumbColor.opacity(Self.overflowHaloInnerOpacity))
                .frame(width: innerDiameter, height: innerDiameter)
        }
    }

    /// Off-scale chevron: SF Symbol drawn **on top of** the thumb so the
    /// directional cue is visible against the colored thumb fill. The overflow
    /// indicator's accessibility identifier lives here — the chevron is the
    /// distinctive directional mark of the indicator.
    private func overflowChevron(direction: OverflowDirection) -> some View {
        let chevron = direction == .positive ? "chevron.right.2" : "chevron.left.2"
        return Image(systemName: chevron)
            .font(.system(size: Self.overflowChevronPointSize, weight: .bold))
            .foregroundStyle(FortiFitColors.cardSurface)
            .accessibilityIdentifier(overflowIndicatorIdentifier)
    }

    private func thumbX(in width: CGFloat, position: Double) -> CGFloat {
        // Thumb is centered at `position`; subtract half its diameter so the
        // circle sits on the value rather than starting at it.
        let center = CGFloat(position) * width
        return center - Self.thumbDiameter / 2
    }

    // MARK: - Axis Labels

    private var axisLabels: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                axisLabel("−30%")
                    .position(x: 0 + axisInsetLeading, y: axisYCenter)
                axisLabel("−10%")
                    .position(x: proxy.size.width / 3, y: axisYCenter)
                axisLabel("+10%")
                    .position(x: 2 * proxy.size.width / 3, y: axisYCenter)
                axisLabel("+30%")
                    .position(x: proxy.size.width - axisInsetTrailing, y: axisYCenter)
            }
        }
        .frame(height: axisLabelHeight)
    }

    private func axisLabel(_ text: String) -> some View {
        Text(text)
            .font(FortiFitTypography.labelSmall)
            .kerning(1)
            .foregroundStyle(FortiFitColors.mutedText)
            .fixedSize()
    }

    private var axisLabelHeight: CGFloat { 14 }
    private var axisYCenter: CGFloat { axisLabelHeight / 2 }
    private var axisInsetLeading: CGFloat { 14 }   // ~half of "−30%" width so it aligns with track start
    private var axisInsetTrailing: CGFloat { 14 }

    // MARK: - State Derivation

    private var isNoData: Bool {
        status == .noData || pctChange == nil
    }

    private var position: Double? {
        guard !isNoData else { return nil }
        return powerLevelGaugePosition(pctChange: pctChange)
    }

    /// `.positive` when `pctChange > +30`, `.negative` when `pctChange < −30`,
    /// `nil` otherwise (or in the no-data state). Strict greater-than at the
    /// boundary so a value of exactly ±30% sits cleanly on the axis label
    /// without triggering the off-scale treatment.
    private var overflowDirection: OverflowDirection? {
        guard !isNoData else { return nil }
        return Self.overflowDirection(for: pctChange)
    }

    /// Pure helper exposed for tests. Single source of truth for the off-scale
    /// rule: strict `|pct| > 30` triggers; `nil` and `±30` exactly do not.
    /// See CONSTANTS.md § Power Level Gauge → Overflow Indicator.
    static func overflowDirection(for pctChange: Double?) -> OverflowDirection? {
        guard let pct = pctChange else { return nil }
        if pct > overflowThreshold { return .positive }
        if pct < -overflowThreshold { return .negative }
        return nil
    }

    private var shouldPulse: Bool {
        Self.shouldPulse(
            status: status,
            isNoData: isNoData,
            reduceMotion: reduceMotion
        )
    }

    /// Pure helper exposed for tests. Pulse rule: only `.rising` or `.deloading`,
    /// not no-data, not under Reduce Motion. Steady is intentionally excluded so
    /// the widget stays calm when nothing is changing. Off-scale states still
    /// pulse — the animated halo sits behind the static off-scale halo + chevron
    /// so the "live" cue stacks with the "saturated" cue.
    /// See CONSTANTS.md § Power Level Gauge → Thumb Pulse.
    static func shouldPulse(
        status: PowerLevelService.Status,
        isNoData: Bool,
        reduceMotion: Bool
    ) -> Bool {
        if reduceMotion || isNoData { return false }
        switch status {
        case .rising, .deloading: return true
        case .steady, .noData:    return false
        }
    }

    private var thumbColor: Color {
        Self.color(for: status)
    }

    static func color(for status: PowerLevelService.Status) -> Color {
        switch status {
        case .deloading: return FortiFitColors.alert
        case .steady:    return FortiFitColors.mutedText
        case .rising:    return FortiFitColors.positive
        case .noData:    return FortiFitColors.mutedText
        }
    }

    static func glyph(for status: PowerLevelService.Status) -> String {
        switch status {
        case .deloading: return "↓"
        case .steady:    return "—"
        case .rising:    return "↑"
        case .noData:    return "—"
        }
    }

    // MARK: - Accessibility

    /// `"Power level: {status}. {pct}% versus the prior 30 days."` — the status
    /// word is spoken even though it is not drawn (WCAG AA color-independent state).
    private var voiceOverLabel: String {
        let statusWord: String
        switch status {
        case .deloading: statusWord = "Deloading"
        case .steady:    statusWord = "Steady"
        case .rising:    statusWord = "Rising"
        case .noData:    statusWord = "No data"
        }
        guard let pct = pctChange else {
            return "Power level: \(statusWord). No data versus the prior 30 days."
        }
        let rounded = Int(pct.rounded())
        let signed = rounded >= 0 ? "+\(rounded)" : "\(rounded)"
        let base = "Power level: \(statusWord). \(signed)% versus the prior 30 days."
        switch overflowDirection {
        case .positive: return base + " Off-scale — past +30%."
        case .negative: return base + " Off-scale — past −30%."
        case .none:     return base
        }
    }
}

#if DEBUG
#Preview("Compact — Rising") {
    FortiFitPowerLevelGauge(
        status: .rising,
        pctChange: 14,
        scale: .compact,
        gaugeIdentifier: "preview_gauge",
        thumbIdentifier: "preview_thumb",
        overflowIndicatorIdentifier: "preview_overflow",
        pulseHaloIdentifier: "preview_pulse"
    )
    .padding()
    .background(FortiFitColors.cardSurface)
}

#Preview("Compact — Deloading") {
    FortiFitPowerLevelGauge(
        status: .deloading,
        pctChange: -22,
        scale: .compact,
        gaugeIdentifier: "preview_gauge",
        thumbIdentifier: "preview_thumb",
        overflowIndicatorIdentifier: "preview_overflow",
        pulseHaloIdentifier: "preview_pulse"
    )
    .padding()
    .background(FortiFitColors.cardSurface)
}

#Preview("No Data") {
    FortiFitPowerLevelGauge(
        status: .noData,
        pctChange: nil,
        scale: .compact,
        gaugeIdentifier: "preview_gauge",
        thumbIdentifier: "preview_thumb",
        overflowIndicatorIdentifier: "preview_overflow",
        pulseHaloIdentifier: "preview_pulse"
    )
    .padding()
    .background(FortiFitColors.cardSurface)
}

#Preview("Compact — Off-scale +141%") {
    FortiFitPowerLevelGauge(
        status: .rising,
        pctChange: 141,
        scale: .compact,
        gaugeIdentifier: "preview_gauge",
        thumbIdentifier: "preview_thumb",
        overflowIndicatorIdentifier: "preview_overflow",
        pulseHaloIdentifier: "preview_pulse"
    )
    .padding()
    .background(FortiFitColors.cardSurface)
}

#Preview("Compact — Off-scale −62%") {
    FortiFitPowerLevelGauge(
        status: .deloading,
        pctChange: -62,
        scale: .compact,
        gaugeIdentifier: "preview_gauge",
        thumbIdentifier: "preview_thumb",
        overflowIndicatorIdentifier: "preview_overflow",
        pulseHaloIdentifier: "preview_pulse"
    )
    .padding()
    .background(FortiFitColors.cardSurface)
}
#endif
