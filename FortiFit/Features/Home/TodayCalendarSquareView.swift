import SwiftUI

struct TodayCalendarSquareView: View {
    let plannedCount: Int
    let completedCount: Int

    private var dayAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: Date()).uppercased()
    }

    private var monthAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: Date()).uppercased()
    }

    private var dateNumber: Int {
        Calendar.current.component(.day, from: Date())
    }

    private let cornerRadius: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            // Top bar — day abbreviation
            Text(dayAbbreviation)
                .font(.system(size: 11, weight: .black))
                .kerning(2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: cornerRadius,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: cornerRadius
                    )
                    .fill(FortiFitColors.primaryAccent)
                )

            // Body — month, date number + dots
            VStack(spacing: 4) {
                Text(monthAbbreviation)
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(FortiFitColors.mutedText)

                Text("\(dateNumber)")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(FortiFitColors.primaryText)

                dotIndicators
            }
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: cornerRadius,
                    bottomTrailingRadius: cornerRadius,
                    topTrailingRadius: 0
                )
                .fill(FortiFitColors.elevatedSurface)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    // MARK: - Dot Indicators

    @ViewBuilder
    private var dotIndicators: some View {
        let totalDots = plannedCount + completedCount
        if totalDots > 0 {
            HStack(spacing: 4) {
                let maxVisible = 3
                let visibleCompleted = min(completedCount, maxVisible)
                let remainingSlots = maxVisible - visibleCompleted
                let visiblePlanned = min(plannedCount, remainingSlots)
                let overflow = totalDots - (visibleCompleted + visiblePlanned)

                ForEach(0..<visibleCompleted, id: \.self) { _ in
                    Circle()
                        .fill(FortiFitColors.positive)
                        .frame(width: 6, height: 6)
                }
                ForEach(0..<visiblePlanned, id: \.self) { _ in
                    Circle()
                        .fill(FortiFitColors.primaryAccent)
                        .frame(width: 6, height: 6)
                }
                if overflow > 0 {
                    Text("+\(overflow)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(FortiFitColors.mutedText)
                }
            }
        }
    }
}
