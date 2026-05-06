import SwiftUI

struct FortiFitChartCard<ControlsView: View, ChartView: View, FooterView: View>: View {
    let chartId: String
    let title: String
    let summary: ChartSummary?
    let gradientAnchor: ChartGradientAnchor
    let isEmpty: Bool
    let emptyMessage: String
    var isReorderMode: Bool = false
    @ViewBuilder let controls: () -> ControlsView
    @ViewBuilder let chart: () -> ChartView
    @ViewBuilder let footer: () -> FooterView

    var body: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
            FortiFitWidgetHeader(title: title)
                .accessibilityIdentifier(AccessibilityID.trendsChartCard(chartId))

            if isEmpty {
                controls()
                Text(emptyMessage)
                    .font(FortiFitTypography.note)
                    .foregroundStyle(FortiFitColors.mutedText)
            } else {
                if let summary, chartId != "workoutTypeBreakdown" {
                    headerSummaryView(summary)
                        .accessibilityIdentifier(AccessibilityID.trendsChartHeaderSummary(chartId))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(summary.hero), \(summary.caption)")
                }

                controls()

                plotArea {
                    chart()
                }

                footer()
            }
        }
        .padding(.trailing, isReorderMode ? 36 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FortiFitSpacing.cardPadding)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                    .fill(FortiFitColors.cardSurface)
                gradientBackground
                    .clipShape(RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                .stroke(FortiFitColors.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func headerSummaryView(_ summary: ChartSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.hero)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(heroColor)
            Text(summary.caption)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(FortiFitColors.mutedText)
                .kerning(2)
        }
        .padding(.bottom, 2)
    }

    private var heroColor: Color {
        switch gradientAnchor {
        case .single(let color):
            return color
        case .horizontalSplit:
            return FortiFitColors.primaryText
        }
    }

    @ViewBuilder
    private func plotArea<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 8, trailing: 8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(FortiFitColors.border, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var gradientBackground: some View {
        switch gradientAnchor {
        case .single(let color):
            LinearGradient(
                colors: [color.opacity(0.2), color.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .horizontalSplit(let leading, let trailing):
            ZStack {
                LinearGradient(
                    colors: [leading, trailing],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                LinearGradient(
                    colors: [Color.white.opacity(0.2), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.multiply)
            }
            .opacity(0.2)
        }
    }
}
