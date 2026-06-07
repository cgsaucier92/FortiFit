import Testing
import Foundation
@testable import FortiFit

/// Unit tests for `FortiFitEffortBars`.
///
/// Covers the tier mapping (rpe 1–10 → 1..5 lit bars) and confirms the lit-bar
/// color resolves through `AppConstants.effortColor(for:)` so the bars stay in
/// lockstep with the value text and the documented Effort Color Mapping.
/// See TESTING.md § Effort Bars Test Strategy.
struct FortiFitEffortBarsTests {

    // MARK: - Tier Mapping

    @Test func test_litBarCount_easyRange_returnsOneBar() {
        #expect(FortiFitEffortBars.litBarCount(forRPE: 1) == 1)
        #expect(FortiFitEffortBars.litBarCount(forRPE: 2) == 1)
    }

    @Test func test_litBarCount_lightRange_returnsTwoBars() {
        #expect(FortiFitEffortBars.litBarCount(forRPE: 3) == 2)
        #expect(FortiFitEffortBars.litBarCount(forRPE: 4) == 2)
    }

    @Test func test_litBarCount_moderateRange_returnsThreeBars() {
        #expect(FortiFitEffortBars.litBarCount(forRPE: 5) == 3)
        #expect(FortiFitEffortBars.litBarCount(forRPE: 6) == 3)
    }

    @Test func test_litBarCount_hardRange_returnsFourBars() {
        #expect(FortiFitEffortBars.litBarCount(forRPE: 7) == 4)
        #expect(FortiFitEffortBars.litBarCount(forRPE: 8) == 4)
    }

    @Test func test_litBarCount_allOutRange_returnsFiveBars() {
        #expect(FortiFitEffortBars.litBarCount(forRPE: 9) == 5)
        #expect(FortiFitEffortBars.litBarCount(forRPE: 10) == 5)
    }

    @Test func test_litBarCount_outOfRange_returnsZero() {
        #expect(FortiFitEffortBars.litBarCount(forRPE: 0) == 0)
        #expect(FortiFitEffortBars.litBarCount(forRPE: -3) == 0)
        #expect(FortiFitEffortBars.litBarCount(forRPE: 11) == 0)
        #expect(FortiFitEffortBars.litBarCount(forRPE: 99) == 0)
    }

    // MARK: - Tier-to-Label Alignment

    /// The bar tier must agree with the 5-band Effort Label Mapping so the
    /// glyph and the value label tell the same story.
    @Test func test_litBarCount_alignsWithEffortLabelBuckets() {
        let pairs: [(rpe: Int, expectedLabel: String, expectedBars: Int)] = [
            (1, "Easy", 1), (2, "Easy", 1),
            (3, "Light", 2), (4, "Light", 2),
            (5, "Moderate", 3), (6, "Moderate", 3),
            (7, "Hard", 4), (8, "Hard", 4),
            (9, "All Out", 5), (10, "All Out", 5)
        ]
        for pair in pairs {
            #expect(AppConstants.effortLabel(for: pair.rpe) == pair.expectedLabel)
            #expect(FortiFitEffortBars.litBarCount(forRPE: pair.rpe) == pair.expectedBars)
        }
    }
}
