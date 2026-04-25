import SwiftUI

struct FortiFitWeekStrip: View {
    @Binding var selectedDate: Date
    @Binding var dayOffset: Int
    var planItems: [PlanCardItem]

    @State private var dragDayDelta: Int = 0
    private let calendar = Calendar(identifier: .iso8601)
    private let dayAbbreviations = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    /// Points of drag per day shift
    private let pointsPerDay: CGFloat = 50

    /// The effective day offset including any in-progress drag.
    private var effectiveOffset: Int {
        dayOffset + dragDayDelta
    }

    /// The 7 dates currently visible in the strip.
    private var weekDates: [Date] {
        let today = Date()
        guard let baseStart = calendar.date(byAdding: .day, value: effectiveOffset, to: today.startOfWeek) else {
            return []
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: baseStart) }
    }

    /// Month indicator label that shows above the week strip.
    private var monthIndicator: String {
        guard let first = weekDates.first, let last = weekDates.last else { return "" }
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

    var body: some View {
        VStack(spacing: FortiFitSpacing.elementSpacing) {
            // Month indicator
            Text(monthIndicator.uppercased())
                .font(.system(size: 13, weight: .bold))
                .kerning(2)
                .foregroundStyle(FortiFitColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .center)

            // Day cells
            HStack(spacing: 0) {
                ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                    dayCellView(date: date, dayLabel: dayAbbreviations[index])
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 72)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedDate = date
                        }
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onChanged { value in
                    let delta = -Int(round(value.translation.width / pointsPerDay))
                    if delta != dragDayDelta {
                        dragDayDelta = delta
                    }
                }
                .onEnded { _ in
                    dayOffset += dragDayDelta
                    dragDayDelta = 0
                }
        )
        .animation(.easeInOut(duration: 0.08), value: effectiveOffset)
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

            HStack(spacing: 4) {
                ForEach(Array(dots.prefix(3).enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 6)
        }
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
