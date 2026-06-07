import SwiftUI

/// Power Level home widget — Phase 12 layout.
///
/// Header row: "Power Level" + right-aligned delta caption. Below the
/// header row: continuous gauge. The directional indicator glyph is **not**
/// rendered on the widget card (the gauge thumb + color zones carry the
/// state); it still renders on the Breakdown Sheet hero. Status word and
/// contextual message are likewise omitted from the card; the status word
/// is preserved in the gauge's VoiceOver label for color-independent state.
///
/// See SCREENS.md § Home Screen → Power Level widget and CONSTANTS.md
/// § Power Level Gauge.
struct FortiFitPowerLevelWidget: View {
    let result: PowerLevelService.PowerLevelResult
    /// Raw `pct_change` (the existing `windowComparison().deltaPct`). `nil`
    /// when the upstream is undefined (cold-start / no-baseline) — drives the
    /// gauge's no-data presentation.
    let pctChange: Double?
    var isReorderMode: Bool = false

    private var isNoData: Bool {
        result.status == .noData || pctChange == nil
    }

    private var deltaCaption: String {
        guard let pct = pctChange else {
            return "No data"
        }
        let rounded = Int(pct.rounded())
        let sign = rounded >= 0 ? "+" : ""
        return "\(sign)\(rounded)% vs prior 30d"
    }

    var body: some View {
        FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                HStack(alignment: .center, spacing: FortiFitSpacing.elementSpacing) {
                    FortiFitWidgetHeader(title: "Power Level")

                    Spacer()

                    Text(deltaCaption)
                        .font(FortiFitTypography.labelSmall)
                        .foregroundStyle(FortiFitColors.mutedText)
                        .accessibilityIdentifier(AccessibilityID.homeWidget_powerLevel_deltaCaption)
                }

                FortiFitPowerLevelGauge(
                    status: result.status,
                    pctChange: pctChange,
                    scale: .compact,
                    gaugeIdentifier: AccessibilityID.homeWidget_powerLevel_gauge,
                    thumbIdentifier: AccessibilityID.homeWidget_powerLevel_gaugeThumb,
                    overflowIndicatorIdentifier: AccessibilityID.homeWidget_powerLevel_gaugeOverflowIndicator,
                    pulseHaloIdentifier: AccessibilityID.homeWidget_powerLevel_gaugeThumbPulse
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, isReorderMode ? 24 : 0)
        }
        .accessibilityIdentifier(AccessibilityID.homeWidget_powerLevel_card)
        // Mark the no-data state for diagnostic / smoke-test branching without
        // changing the visible string-based identifiers above.
        .accessibilityValue(isNoData ? "noData" : "live")
    }
}
