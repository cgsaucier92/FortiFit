import Foundation

extension Double {
    /// Rounds to the specified number of decimal places.
    func rounded(to places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }

    /// Display as a clean string — no trailing zeros for whole numbers.
    var cleanString: String {
        if self.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(self))"
        } else {
            return String(format: "%.1f", self)
        }
    }
}
