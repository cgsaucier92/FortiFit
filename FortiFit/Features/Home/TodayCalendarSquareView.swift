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
                .padding(.trailing, -2)
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
                Spacer().frame(height: 2)
                Text(monthAbbreviation)
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1)
                    .padding(.trailing, -1)
                    .foregroundStyle(FortiFitColors.mutedText)

                Text("\(dateNumber)")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(FortiFitColors.primaryText)

                dotIndicators
            }
            .padding(.bottom, 8)
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
            let dots = dotColors()
            VStack(spacing: 2) {
                dotRowCentered(dots: dots)
                dotRowSlotted(dots: dots)
            }
            .frame(height: 14)
        }
    }

    private func dotColors() -> [Color] {
        let maxTotal = 6
        let visibleCompleted = min(completedCount, maxTotal)
        let visiblePlanned = min(plannedCount, maxTotal - visibleCompleted)
        return Array(repeating: FortiFitColors.positive, count: visibleCompleted)
            + Array(repeating: FortiFitColors.primaryAccent, count: visiblePlanned)
    }

    /// Row 1 — naturally centered under the day number. With 1 dot the dot sits
    /// directly under the number; with 2 it straddles center; with 3 the row fills.
    private func dotRowCentered(dots: [Color]) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<min(dots.count, 3), id: \.self) { index in
                Circle()
                    .fill(dots[index])
                    .frame(width: 6, height: 6)
            }
        }
        .frame(height: 6)
    }

    /// Row 2 — fixed 3-slot layout so dot 4 sits under dot 1, 5 under 2, 6 under 3.
    /// Row 1 is always full (3 dots) whenever row 2 has any content, so slot
    /// alignment between the rows is exact.
    private func dotRowSlotted(dots: [Color]) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { column in
                let index = 3 + column
                if index < dots.count {
                    Circle()
                        .fill(dots[index])
                        .frame(width: 6, height: 6)
                } else {
                    Color.clear
                        .frame(width: 6, height: 6)
                }
            }
        }
        .frame(height: 6)
    }
}
