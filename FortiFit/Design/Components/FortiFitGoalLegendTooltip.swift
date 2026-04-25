import SwiftUI

/// Overlay tooltip showing progress percentage (all goal rings) and the Distance/Duration
/// color legend (dual-arc Speed and Distance rings). Positioned below the ring with an
/// upward-pointing arrow. Supports 0.15s opacity fade-in/out; dismissed by re-tap or
/// tap-outside.
struct FortiFitGoalLegendTooltip: View {
    @Binding var isVisible: Bool
    let percentage: Int
    let isDualArc: Bool

    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                // Upward-pointing arrow
                Triangle()
                    .fill(FortiFitColors.elevatedSurface)
                    .frame(width: 12, height: 6)

                // Tooltip body
                VStack(alignment: isDualArc ? .leading : .center, spacing: isDualArc ? 8 : 0) {
                    // Percentage headline (all goal types)
                    Text("\(percentage)%")
                        .font(.system(size: AppConstants.goalTooltipPercentageFontSize, weight: .heavy))
                        .foregroundStyle(FortiFitColors.primaryText)

                    // Legend rows (dual-arc only)
                    if isDualArc {
                        legendRow(color: FortiFitColors.goalDistanceRing, label: "Distance")
                        legendRow(color: FortiFitColors.goalDurationRing, label: "Duration")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(FortiFitColors.elevatedSurface)
                        .stroke(FortiFitColors.border, lineWidth: 1)
                )
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.15), value: isVisible)
        }
    }

    private func legendRow(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(FortiFitColors.secondaryText)
                .textCase(.uppercase)
        }
    }
}

/// Simple upward-pointing triangle shape for the tooltip arrow.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
