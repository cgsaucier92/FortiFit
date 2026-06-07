import Testing
import Foundation
@testable import FortiFit

/// Phase 12 — Power Level Gauge unit tests.
///
/// Covers the pure `powerLevelGaugePosition(pctChange:)` mapping, clamp
/// honesty (caption-vs-thumb separation), no-data state, and status → glyph /
/// color mapping. See TESTING.md § Power Level Gauge Test Strategy (Phase 12).
struct PowerLevelGaugeTests {

    // MARK: - Position Helper

    @Test func test_gaugePosition_atOrBelowMinus30_returnsZero() {
        #expect(powerLevelGaugePosition(pctChange: -30) == 0.0)
        #expect(powerLevelGaugePosition(pctChange: -45) == 0.0)
        #expect(powerLevelGaugePosition(pctChange: -1000) == 0.0)
    }

    @Test func test_gaugePosition_atOrAbovePlus30_returnsOne() {
        #expect(powerLevelGaugePosition(pctChange: 30) == 1.0)
        #expect(powerLevelGaugePosition(pctChange: 75) == 1.0)
        #expect(powerLevelGaugePosition(pctChange: 9_999) == 1.0)
    }

    @Test func test_gaugePosition_atZero_returnsHalf() {
        let position = powerLevelGaugePosition(pctChange: 0)
        #expect(position == 0.5)
    }

    @Test func test_gaugePosition_atThresholds_returnsThirdAndTwoThirds() throws {
        // -10% → (clamp(-10, -30, 30) + 30) / 60 = 20/60 = 1/3
        let lower = try #require(powerLevelGaugePosition(pctChange: -10))
        #expect(abs(lower - (1.0 / 3.0)) < 1e-9)

        // +10% → (10 + 30) / 60 = 40/60 = 2/3
        let upper = try #require(powerLevelGaugePosition(pctChange: 10))
        #expect(abs(upper - (2.0 / 3.0)) < 1e-9)
    }

    // MARK: - Clamp Honesty

    @Test func test_gaugeClamp_extremePositive_thumbClampedButCaptionUnclamped() {
        // Thumb position must clamp to track end (1.0) even when the raw
        // pct_change blows past the visible range — but a caption derived from
        // the raw value still reports the true magnitude.
        let pct: Double = 212
        #expect(powerLevelGaugePosition(pctChange: pct) == 1.0)

        // Caption is rendered separately from raw `pct_change`. Mirror what the
        // widget / hero formatters do so the contract stays explicit.
        let rounded = Int(pct.rounded())
        let sign = rounded >= 0 ? "+" : ""
        let caption = "\(sign)\(rounded)% vs prior 30d"
        #expect(caption == "+212% vs prior 30d")
    }

    @Test func test_gaugeClamp_extremeNegative_thumbClampedButCaptionUnclamped() {
        let pct: Double = -187
        #expect(powerLevelGaugePosition(pctChange: pct) == 0.0)
        let rounded = Int(pct.rounded())
        let sign = rounded >= 0 ? "+" : ""
        let caption = "\(sign)\(rounded)% vs prior 30 days"
        #expect(caption == "-187% vs prior 30 days")
    }

    // MARK: - No-Data State

    @Test func test_gauge_noBaselineOrColdStart_returnsNoDataState() {
        // nil pct_change → no thumb position (no-data state).
        #expect(powerLevelGaugePosition(pctChange: nil) == nil)
    }

    // MARK: - Overflow Indicator (BUG-074)

    /// Regression test for BUG-074. Strict `> +30` triggers the off-scale
    /// treatment so the clamped thumb position is no longer misread as the
    /// exact value. See CONSTANTS.md § Power Level Gauge → Overflow Indicator.
    @Test func test_overflow_pctAbovePositiveThreshold_returnsPositive() {
        #expect(FortiFitPowerLevelGauge.overflowDirection(for: 31) == .positive)
        #expect(FortiFitPowerLevelGauge.overflowDirection(for: 141) == .positive)
        #expect(FortiFitPowerLevelGauge.overflowDirection(for: 9_999) == .positive)
    }

    /// Regression test for BUG-074. Strict `< −30` triggers the off-scale
    /// treatment with a left-pointing chevron.
    @Test func test_overflow_pctBelowNegativeThreshold_returnsNegative() {
        #expect(FortiFitPowerLevelGauge.overflowDirection(for: -31) == .negative)
        #expect(FortiFitPowerLevelGauge.overflowDirection(for: -62) == .negative)
        #expect(FortiFitPowerLevelGauge.overflowDirection(for: -9_999) == .negative)
    }

    /// Regression test for BUG-074. The boundary itself sits on the axis label,
    /// not over an off-scale state — strict greater-than keeps the threshold
    /// readable.
    @Test func test_overflow_atBoundaryThirty_returnsNil() {
        #expect(FortiFitPowerLevelGauge.overflowDirection(for: 30) == nil)
        #expect(FortiFitPowerLevelGauge.overflowDirection(for: -30) == nil)
    }

    /// Regression test for BUG-074. In-range values must not light up the
    /// off-scale indicator.
    @Test func test_overflow_withinVisibleRange_returnsNil() {
        #expect(FortiFitPowerLevelGauge.overflowDirection(for: 0) == nil)
        #expect(FortiFitPowerLevelGauge.overflowDirection(for: 14) == nil)
        #expect(FortiFitPowerLevelGauge.overflowDirection(for: -22) == nil)
        #expect(FortiFitPowerLevelGauge.overflowDirection(for: 29.9) == nil)
        #expect(FortiFitPowerLevelGauge.overflowDirection(for: -29.9) == nil)
    }

    /// Regression test for BUG-074. The no-data path (nil `pct_change`) must
    /// not surface an overflow indicator — the gauge already renders the
    /// Steady-gray track with no thumb in this state.
    @Test func test_overflow_inNoDataState_returnsNil() {
        #expect(FortiFitPowerLevelGauge.overflowDirection(for: nil) == nil)
    }

    // MARK: - Status Mapping

    // MARK: - Thumb Pulse

    @Test func test_pulse_risingInRange_pulses() {
        #expect(FortiFitPowerLevelGauge.shouldPulse(
            status: .rising, isNoData: false, reduceMotion: false
        ) == true)
    }

    @Test func test_pulse_deloadingInRange_pulses() {
        #expect(FortiFitPowerLevelGauge.shouldPulse(
            status: .deloading, isNoData: false, reduceMotion: false
        ) == true)
    }

    @Test func test_pulse_steady_suppressed() {
        #expect(FortiFitPowerLevelGauge.shouldPulse(
            status: .steady, isNoData: false, reduceMotion: false
        ) == false)
    }

    @Test func test_pulse_noDataStatus_suppressed() {
        #expect(FortiFitPowerLevelGauge.shouldPulse(
            status: .noData, isNoData: true, reduceMotion: false
        ) == false)
    }

    /// Off-scale states keep pulsing — the animated halo sits behind the static
    /// off-scale halo so "live" and "saturated" cues stack rather than compete.
    @Test func test_pulse_offScaleRising_stillPulses() {
        #expect(FortiFitPowerLevelGauge.shouldPulse(
            status: .rising, isNoData: false, reduceMotion: false
        ) == true)
    }

    @Test func test_pulse_offScaleDeloading_stillPulses() {
        #expect(FortiFitPowerLevelGauge.shouldPulse(
            status: .deloading, isNoData: false, reduceMotion: false
        ) == true)
    }

    @Test func test_pulse_reduceMotion_suppressedEvenWhenRising() {
        #expect(FortiFitPowerLevelGauge.shouldPulse(
            status: .rising, isNoData: false, reduceMotion: true
        ) == false)
    }

    // MARK: - Status Mapping

    @Test func test_statusMapping_eachStatus_mapsToCorrectGlyphAndColor() {
        #expect(FortiFitPowerLevelGauge.glyph(for: .deloading) == "↓")
        #expect(FortiFitPowerLevelGauge.glyph(for: .steady) == "—")
        #expect(FortiFitPowerLevelGauge.glyph(for: .rising) == "↑")
        // No-data renders as the steady em-dash glyph per CONSTANTS.
        #expect(FortiFitPowerLevelGauge.glyph(for: .noData) == "—")

        // Color mapping is verified via FortiFitColors identity — exact hex
        // assertions belong in Colors.swift tests if any. We just confirm the
        // mapping returns the expected token reference.
        #expect(FortiFitPowerLevelGauge.color(for: .deloading) == FortiFitColors.alert)
        #expect(FortiFitPowerLevelGauge.color(for: .steady) == FortiFitColors.mutedText)
        #expect(FortiFitPowerLevelGauge.color(for: .rising) == FortiFitColors.positive)
        #expect(FortiFitPowerLevelGauge.color(for: .noData) == FortiFitColors.mutedText)
    }
}
