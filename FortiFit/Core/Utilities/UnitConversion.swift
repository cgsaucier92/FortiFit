import Foundation

enum UnitConversion {
    static let kgToLbsFactor: Double = 2.205
    static let kmToMilesFactor: Double = 0.621371

    /// Converts km to miles, rounded to 2 decimal places.
    static func kmToMiles(_ km: Double) -> Double {
        return (km * kmToMilesFactor * 100).rounded() / 100
    }

    /// Converts miles to km.
    static func milesToKm(_ miles: Double) -> Double {
        return miles / kmToMilesFactor
    }

    /// Formats a distance for display in the given unit system. Rounds to 2 decimal places.
    static func displayDistance(_ km: Double, useMiles: Bool) -> String {
        if useMiles {
            return String(format: "%.2f mi", km * kmToMilesFactor)
        } else {
            return String(format: "%.2f km", km)
        }
    }

    /// Formats an optional distance. Returns "--" when nil.
    static func displayDistance(_ km: Double?, useMiles: Bool) -> String {
        guard let km else { return "--" }
        return displayDistance(km, useMiles: useMiles)
    }

    /// Converts kg to lbs. Returns nil if input is nil (bodyweight).
    static func kgToLbs(_ kg: Double?) -> Double? {
        guard let kg else { return nil }
        return kg * kgToLbsFactor
    }

    /// Converts lbs to kg. Returns nil if input is nil (bodyweight).
    static func lbsToKg(_ lbs: Double?) -> Double? {
        guard let lbs else { return nil }
        return lbs / kgToLbsFactor
    }

    /// Formats a weight for display in the given unit system.
    /// Returns "BW" for nil (bodyweight). Rounds lbs to nearest integer.
    static func displayWeight(_ kg: Double?, useLbs: Bool) -> String {
        guard let kg else { return "BW" }
        if useLbs {
            let lbs = kg * kgToLbsFactor
            return "\(Int(lbs.rounded())) lbs"
        } else {
            // Show kg with no decimals if whole, otherwise 1 decimal
            if kg.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(kg)) kg"
            } else {
                return String(format: "%.1f kg", kg)
            }
        }
    }

    /// Returns just the numeric value string in the current unit (no unit suffix).
    static func displayValue(_ kg: Double?, useLbs: Bool) -> String {
        guard let kg else { return "BW" }
        if useLbs {
            return "\(Int((kg * kgToLbsFactor).rounded()))"
        } else {
            if kg.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(kg))"
            } else {
                return String(format: "%.1f", kg)
            }
        }
    }
}
