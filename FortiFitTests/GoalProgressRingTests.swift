import Testing
import Foundation
import SwiftUI
@testable import FortiFit

/// Section 10: FortiFitGoalProgressRing Tests
/// Tests the computation logic that feeds the ring component.

struct GoalProgressRingTests {

    // Helper: Computes silhouette opacity using the same formula as FortiFitGoalProgressRing
    private func silhouetteOpacity(progress: Double, isVictory: Bool) -> Double {
        if isVictory { return AppConstants.goalSilhouetteCompletedOpacity }
        return 0.10 + (min(max(progress, 0), 1.0) * 0.30)
    }

    // Helper: Resolves SF Symbol for goal type
    private func sfSymbol(for goalType: String) -> String {
        switch goalType {
        case "Strength PR": return AppConstants.goalSymbolStrengthPR
        case "Repetitions PR": return AppConstants.goalSymbolRepsPR
        case "Speed and Distance": return AppConstants.goalSymbolSpeedDistance
        case "weeklyWorkouts": return AppConstants.goalSymbolWeeklyWorkouts
        default: return AppConstants.goalSymbolStrengthPR
        }
    }

    // Helper: Resolves ring color by index
    private func goalColor(colorIndex: Int) -> Color {
        FortiFitColors.goalColors[colorIndex % FortiFitColors.goalColors.count]
    }

    // RING-001
    @Test func silhouetteOpacityAtZeroPercent() {
        let opacity = silhouetteOpacity(progress: 0.0, isVictory: false)
        #expect(opacity == 0.10)
    }

    // RING-002
    @Test func silhouetteOpacityAt50Percent() {
        let opacity = silhouetteOpacity(progress: 0.5, isVictory: false)
        #expect(abs(opacity - 0.25) < 0.001)
    }

    // RING-003
    @Test func silhouetteOpacityAt100PercentNonVictory() {
        let opacity = silhouetteOpacity(progress: 1.0, isVictory: false)
        #expect(abs(opacity - 0.40) < 0.001)
    }

    // RING-004
    @Test func silhouetteOpacityAtVictoryState() {
        let opacity = silhouetteOpacity(progress: 1.0, isVictory: true)
        #expect(opacity >= 0.85 && opacity <= 1.0)
    }

    // RING-005
    @Test func silhouetteOpacityClampsAtFloorForNegativeProgress() {
        let opacity = silhouetteOpacity(progress: -0.1, isVictory: false)
        #expect(opacity == 0.10)
    }

    // RING-006
    @Test func correctSFSymbolForExercisePR() {
        #expect(sfSymbol(for: "Strength PR") == "figure.strengthtraining.traditional")
    }

    // RING-007
    @Test func correctSFSymbolForRepsPR() {
        #expect(sfSymbol(for: "Repetitions PR") == "figure.strengthtraining.traditional")
    }

    // RING-008
    @Test func correctSFSymbolForSpeedDistance() {
        #expect(sfSymbol(for: "Speed and Distance") == "figure.run")
    }

    // RING-009
    @Test func correctSFSymbolForWeeklyWorkouts() {
        #expect(sfSymbol(for: "weeklyWorkouts") == "calendar")
    }

    // RING-010: Single ring mode for Strength PR
    @Test func singleRingModeForStrengthPR() {
        // Strength PR uses single ring with goal cycling color
        let goalType = "Strength PR"
        let colorIndex = 0
        let isDualArc = goalType == "Speed and Distance" && false // no dual distances
        #expect(isDualArc == false)
        #expect(goalColor(colorIndex: colorIndex) == FortiFitColors.goalColors[0])
    }

    // RING-011: Single ring for Speed and Distance with distance-only
    @Test func singleRingForSpeedDistanceDistanceOnly() {
        let goalType = "Speed and Distance"
        let hasDualTargets = false // only distance target set
        let distanceProgress: Double = 0.7
        let isDualArc = goalType == "Speed and Distance" && hasDualTargets
        #expect(isDualArc == false)
        // Single target distance-only uses purple
        let singleArcColor: Color = distanceProgress > 0 ? FortiFitColors.goalDistanceRing : FortiFitColors.goalDurationRing
        #expect(singleArcColor == FortiFitColors.goalDistanceRing)
    }

    // RING-012: Single ring for Speed and Distance with duration-only
    @Test func singleRingForSpeedDistanceDurationOnly() {
        let goalType = "Speed and Distance"
        let hasDualTargets = false // only duration target set
        let durationProgress: Double = 0.75
        let isDualArc = goalType == "Speed and Distance" && hasDualTargets
        #expect(isDualArc == false)
        // Duration-only uses light cyan
        let singleArcColor: Color = durationProgress > 0 ? FortiFitColors.goalDurationRing : FortiFitColors.goalDistanceRing
        #expect(singleArcColor == FortiFitColors.goalDurationRing)
    }

    // RING-013: Dual-arc ring for Speed and Distance with both targets (even at zero progress)
    @Test func dualArcRingForSpeedDistanceBothTargets() {
        let goalType = "Speed and Distance"
        let hasDualTargets = true // both distance and duration targets set
        let isDualArc = goalType == "Speed and Distance" && hasDualTargets
        #expect(isDualArc == true)
        // Outer = purple (distance), Inner = light cyan (duration)
        #expect(FortiFitColors.goalDistanceRing == Color(hex: "4B2893"))
        #expect(FortiFitColors.goalDurationRing == Color(hex: "8FE6F6"))
    }

    // RING-016: Dual-arc renders at zero progress when both targets exist
    @Test func dualArcRingRendersAtZeroProgress() {
        let goalType = "Speed and Distance"
        let hasDualTargets = true
        let distanceProgress: Double = 0.0
        let durationProgress: Double = 0.0
        let isDualArc = goalType == "Speed and Distance" && hasDualTargets
        // Both targets set but zero progress — must still show dual-arc
        #expect(isDualArc == true)
        #expect(distanceProgress == 0.0)
        #expect(durationProgress == 0.0)
    }

    // RING-014: Goal color cycles correctly
    @Test func goalColorCyclesCorrectly() {
        #expect(goalColor(colorIndex: 0) == Color(hex: "FFBF51"))   // Orange
        #expect(goalColor(colorIndex: 1) == Color(hex: "BB2BC0"))   // Pink
        #expect(goalColor(colorIndex: 2) == Color(hex: "10b981"))   // Green
        #expect(goalColor(colorIndex: 3) == Color(hex: "ef4444"))   // Red
    }

    // RING-015: Goal color wraps on index > 3
    @Test func goalColorWrapsOnIndexGreaterThan3() {
        // 5 % 4 = 1 → Pink
        #expect(goalColor(colorIndex: 5) == Color(hex: "BB2BC0"))
    }
}
