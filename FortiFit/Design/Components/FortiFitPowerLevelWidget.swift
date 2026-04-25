import SwiftUI

struct FortiFitPowerLevelWidget: View {
    let result: PowerLevelService.PowerLevelResult
    @Binding var showTooltip: Bool
    var isReorderMode: Bool = false

    var body: some View {
        FortiFitCard {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                HStack {
                    FortiFitWidgetHeader(title: "Power Level")
                    FortiFitHintTooltip(
                        message: "Measures your average exercise volume trend for Strength Training and HIIT workouts",
                        isVisible: $showTooltip
                    )
                    Spacer()
                }

                if result.status == .noData {
                    Text(result.message)
                        .font(FortiFitTypography.note)
                        .foregroundStyle(FortiFitColors.primaryText)
                } else {
                    HStack(spacing: FortiFitSpacing.elementSpacing) {
                        Text(result.statusLabel)
                            .font(FortiFitTypography.dataValue)
                            .foregroundStyle(Color(hex: result.indicatorColor))

                        Text(result.indicator)
                            .font(FortiFitTypography.dataValue)
                            .foregroundStyle(Color(hex: result.indicatorColor))
                    }

                    Text(result.message)
                        .font(FortiFitTypography.note)
                        .foregroundStyle(FortiFitColors.primaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, isReorderMode ? 24 : 0)
        }
    }
}
