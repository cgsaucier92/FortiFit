import SwiftUI

struct FortiFitMonthGrid: View {
    @Binding var selectedDate: Date
    @Binding var displayedMonth: Date
    var planItems: [PlanCardItem]

    private let calendar = Calendar(identifier: .iso8601)
    private let dayAbbreviations = ["M", "T", "W", "T", "F", "S", "S"]

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        // Monday = 2 in ISO calendar. Find weekday of first day.
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        // Convert to Monday-based index (Mon=0, Tue=1, ..., Sun=6)
        let offset = (firstWeekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        // Pad to complete the last week
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    var body: some View {
        VStack(spacing: FortiFitSpacing.elementSpacing) {
            // Month navigation
            HStack {
                Button {
                    shiftMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FortiFitColors.primaryAccent)
                        .frame(width: FortiFitSpacing.minTouchTarget, height: FortiFitSpacing.minTouchTarget)
                }

                Spacer()

                Text(monthTitle.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(FortiFitColors.primaryText)

                Spacer()

                Button {
                    shiftMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FortiFitColors.primaryAccent)
                        .frame(width: FortiFitSpacing.minTouchTarget, height: FortiFitSpacing.minTouchTarget)
                }
            }

            // Day-of-week headers
            HStack(spacing: 0) {
                ForEach(dayAbbreviations.indices, id: \.self) { index in
                    Text(dayAbbreviations[index])
                        .font(.system(size: 12, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(FortiFitColors.mutedText)
                        .frame(maxWidth: .infinity)
                        .textCase(.uppercase)
                }
            }

            // Day grid
            let rows = daysInMonth.chunked(into: 7)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                        if let date {
                            monthDayCell(date: date)
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedDate = date
                                }
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                        }
                    }
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width < 0 {
                        shiftMonth(1)
                    } else if value.translation.width > 0 {
                        shiftMonth(-1)
                    }
                }
        )
    }

    private func monthDayCell(date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let dayNumber = calendar.component(.day, from: date)
        let dots = dotsForDate(date)

        return VStack(spacing: 6) {
            Text("\(dayNumber)")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(monthDayColor(isSelected: isSelected, isToday: isToday))
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
        .frame(height: 60)
    }

    private func monthDayColor(isSelected: Bool, isToday: Bool) -> Color {
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

    private func shiftMonth(_ direction: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: direction, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}

// MARK: - Array Chunking Helper

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
