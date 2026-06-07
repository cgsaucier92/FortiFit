import SwiftUI

struct FortiFitWeekStrip: View {
    @Binding var selectedDate: Date
    @Binding var dayOffset: Int
    var planItems: [PlanCardItem]

    @State private var dragTranslation: CGFloat = 0
    private let calendar = Calendar(identifier: .iso8601)
    private let bufferDays = 7

    private func allDates(for offset: Int) -> [Date] {
        let today = Date()
        guard let baseStart = calendar.date(byAdding: .day, value: offset - bufferDays, to: today.startOfWeek) else {
            return []
        }
        let totalDays = 7 + bufferDays * 2
        return (0..<totalDays).compactMap { calendar.date(byAdding: .day, value: $0, to: baseStart) }
    }

    private var visibleDates: [Date] {
        let today = Date()
        guard let baseStart = calendar.date(byAdding: .day, value: dayOffset, to: today.startOfWeek) else {
            return []
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: baseStart) }
    }

    private var monthIndicator: String {
        guard let first = visibleDates.first, let last = visibleDates.last else { return "" }
        let firstMonth = calendar.component(.month, from: first)
        let firstYear = calendar.component(.year, from: first)
        let lastMonth = calendar.component(.month, from: last)
        let lastYear = calendar.component(.year, from: last)

        let currentYear = calendar.component(.year, from: Date())
        let formatter = DateFormatter()
        formatter.locale = Locale.current

        let monthSymbols = formatter.monthSymbols ?? []
        let firstName = monthSymbols[firstMonth - 1]

        if firstMonth == lastMonth && firstYear == lastYear {
            return firstYear == currentYear ? firstName : "\(firstName) \(firstYear)"
        } else {
            let lastName = monthSymbols[lastMonth - 1]
            if firstYear == lastYear {
                return firstYear == currentYear
                    ? "\(firstName) \u{2013} \(lastName)"
                    : "\(firstName) \u{2013} \(lastName) \(firstYear)"
            } else {
                return "\(firstName) \(firstYear) \u{2013} \(lastName) \(lastYear)"
            }
        }
    }

    private func dayAbbreviation(for date: Date) -> String {
        let weekday = calendar.component(.weekday, from: date)
        let labels = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        return labels[weekday - 1]
    }

    var body: some View {
        VStack(spacing: FortiFitSpacing.elementSpacing) {
            Text(monthIndicator.uppercased())
                .font(.system(size: 13, weight: .bold))
                .kerning(2)
                .foregroundStyle(FortiFitColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .center)

            GeometryReader { geo in
                let cellWidth = geo.size.width / 7
                let dates = allDates(for: dayOffset)
                let restOffset = -CGFloat(bufferDays) * cellWidth + dragTranslation

                HStack(spacing: 0) {
                    ForEach(Array(dates.enumerated()), id: \.offset) { _, date in
                        dayCellView(date: date, dayLabel: dayAbbreviation(for: date))
                            .frame(width: cellWidth)
                            .frame(minHeight: 84)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDate = date
                            }
                    }
                }
                .offset(x: restOffset)
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { value in
                            dragTranslation = value.translation.width
                        }
                        .onEnded { value in
                            let daysDragged = -Int(round(value.translation.width / cellWidth))
                            dayOffset += daysDragged
                            dragTranslation = 0
                        }
                )
            }
            .frame(minHeight: 84)
            .clipped()
        }
    }

    private func dayCellView(date: Date, dayLabel: String) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let dayNumber = calendar.component(.day, from: date)
        let dots = dotsForDate(date)

        return VStack(spacing: 6) {
            Text(dayLabel)
                .font(.system(size: 12, weight: .bold))
                .kerning(2)
                .foregroundStyle(FortiFitColors.mutedText)

            Text("\(dayNumber)")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(dayNumberColor(isSelected: isSelected, isToday: isToday))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSelected ? FortiFitColors.primaryAccent : .clear)
                )
                .overlay(
                    Circle()
                        .stroke(
                            (isToday && !isSelected) ? FortiFitColors.primaryAccent : .clear,
                            lineWidth: 1.5
                        )
                )

            VStack(spacing: 2) {
                dotRowCentered(dots: dots)
                dotRowSlotted(dots: dots)
            }
            .frame(height: 14)
        }
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

    private func dayNumberColor(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected {
            return FortiFitColors.background
        } else if isToday {
            return FortiFitColors.primaryAccent
        } else {
            return FortiFitColors.primaryText
        }
    }

    private func dotsForDate(_ date: Date) -> [Color] {
        let day = calendar.startOfDay(for: date)
        let itemsOnDay = planItems.filter { calendar.isDate($0.date, inSameDayAs: day) }
        return itemsOnDay.map { item in
            switch item {
            case .scheduled(let sw):
                return sw.status == "completed" ? FortiFitColors.positive : FortiFitColors.primaryAccent
            case .loggedOnly:
                return FortiFitColors.positive
            }
        }
    }
}
