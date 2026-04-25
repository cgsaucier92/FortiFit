import Foundation

extension Date {
    /// Returns the start of the ISO week (Monday at 00:00:00) containing this date.
    var startOfWeek: Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2 // Monday
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }

    /// Returns the end of the ISO week (Sunday at 23:59:59) containing this date.
    var endOfWeek: Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        guard let end = calendar.date(byAdding: .day, value: 6, to: startOfWeek) else { return self }
        return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
    }

    /// Returns the Monday–Sunday range for the week containing this date.
    var weekRange: ClosedRange<Date> {
        startOfWeek...endOfWeek
    }

    /// Returns true if this date falls in the same ISO week as the other date.
    func isSameWeek(as other: Date) -> Bool {
        startOfWeek == other.startOfWeek
    }

    /// Formatted display string, e.g. "Mar 17, 2026"
    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: self)
    }

    /// Formatted display string with day of week, e.g. "Mon, Mar 17"
    var dayFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: self)
    }

    /// Formatted time string following the user's locale (e.g. "2:35 PM" or "14:35")
    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: self)
    }
}
