import Testing
import Foundation
@testable import FortiFit

struct UnitConversionTests {

    @Test func kgToLbs1KgReturnsApprox2205() {
        let result = UnitConversion.kgToLbs(1.0)!
        #expect(abs(result - 2.205) < 0.001)
    }

    @Test func kgToLbs100KgReturnsApprox2205() {
        let result = UnitConversion.kgToLbs(100.0)!
        #expect(abs(result - 220.5) < 0.1)
    }

    @Test func nilWeightDisplaysBW() {
        let display = UnitConversion.displayWeight(nil, useLbs: false)
        #expect(display == "BW")
    }

    @Test func nilWeightInLbsDisplaysBW() {
        let display = UnitConversion.displayWeight(nil, useLbs: true)
        #expect(display == "BW")
    }

    @Test func lbsValuesAreRounded() {
        // 80 kg * 2.205 = 176.4 → should round to 176
        let display = UnitConversion.displayWeight(80, useLbs: true)
        #expect(display == "176 lbs")
    }

    @Test func kgWholeNumberDisplaysCleanly() {
        let display = UnitConversion.displayWeight(100, useLbs: false)
        #expect(display == "100 kg")
    }

    @Test func kgDecimalDisplaysOneDecimal() {
        let display = UnitConversion.displayWeight(82.5, useLbs: false)
        #expect(display == "82.5 kg")
    }

    // MARK: - km↔miles

    @Test func kmToMiles1KmReturnsApprox062() {
        let result = UnitConversion.kmToMiles(1.0)
        #expect(abs(result - 0.62) < 0.01)
    }

    @Test func kmToMiles5KmReturnsApprox311() {
        let result = UnitConversion.kmToMiles(5.0)
        #expect(abs(result - 3.11) < 0.01)
    }

    @Test func milesToKm1MileReturnsApprox161() {
        let result = UnitConversion.milesToKm(1.0)
        #expect(abs(result - 1.609) < 0.01)
    }

    @Test func milesValuesRoundedTo2DecimalPlaces() {
        // 3.0 km * 0.621371 = 1.864113 → rounds to 1.86
        let result = UnitConversion.kmToMiles(3.0)
        let formatted = String(format: "%.2f", result)
        #expect(formatted == "1.86")
    }

    @Test func nilDistanceDoesNotCrash() {
        let result = UnitConversion.displayDistance(nil, useMiles: false)
        #expect(result == "--")
    }

    // MARK: - Cardio preview distance formatting (matches WorkoutListView.durationSummary)

    @Test func cardioPreviewDistanceShowsKmWhenMetric() {
        let km = 5.123
        let formatted = String(format: "%.1f km", km)
        #expect(formatted == "5.1 km")
    }

    @Test func cardioPreviewDistanceShowsMilesWhenImperial() {
        let km = 5.0
        let miles = UnitConversion.kmToMiles(km)
        let formatted = String(format: "%.1f mi", miles)
        #expect(formatted == "3.1 mi")
    }

    @Test func cardioPreviewDistanceConverts10KmToMiles() {
        let km = 10.0
        let miles = UnitConversion.kmToMiles(km)
        let formatted = String(format: "%.1f mi", miles)
        #expect(formatted == "6.2 mi")
    }

    @Test func cardioPreviewDistanceZeroKmShowsZero() {
        let km = 0.0
        let formattedKm = String(format: "%.1f km", km)
        let formattedMi = String(format: "%.1f mi", UnitConversion.kmToMiles(km))
        #expect(formattedKm == "0.0 km")
        #expect(formattedMi == "0.0 mi")
    }
}
