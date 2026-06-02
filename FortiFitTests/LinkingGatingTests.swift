import Testing
import Foundation
import SwiftData
@testable import FortiFit

// MARK: - Phase 11 Step 5 — HomeWidgetService.isLinkedActive 5 gate rules

@MainActor
struct IsLinkedActiveTests {

    private func resetSettings() {
        let settings = UserSettings.shared
        settings.recoveryLoadManuallyUnlinked = false
        settings.healthKitEnabled = true
    }

    private func widget(_ type: String, _ sortOrder: Int) -> HomeWidget {
        HomeWidget(widgetType: type, sortOrder: sortOrder)
    }

    private func stub(gating: RecoveryStatusGatingState) -> FoundationStubHealthKitClient {
        let stub = FoundationStubHealthKitClient()
        stub.hasRecentSleepDataToReturn = (gating == .live)
        return stub
    }

    /// Configure `RecoveryStatusService.current` to a service whose computed gating
    /// state matches `gating`. The static `current` weak reference is set by `init`.
    private func setRecoveryGating(_ gating: RecoveryStatusGatingState) -> RecoveryStatusService {
        let svc = RecoveryStatusService(client: stub(gating: gating))
        svc.currentGatingState = gating
        return svc
    }

    @Test func rule1_manualUnlinkOverrideReturnsFalse() {
        resetSettings()
        let settings = UserSettings.shared
        settings.recoveryLoadManuallyUnlinked = true
        defer { settings.recoveryLoadManuallyUnlinked = false }

        let recovery = setRecoveryGating(.live)
        let widgets = [widget("recoveryStatus", 0), widget("trainingLoad", 1)]
        withExtendedLifetime(recovery) {
            #expect(HomeWidgetService.isLinkedActive(widgets: widgets, settings: settings) == false)
        }
    }

    @Test func rule2_missingTrainingLoadReturnsFalse() {
        resetSettings()
        let recovery = setRecoveryGating(.live)
        let widgets = [widget("recoveryStatus", 0), widget("powerLevel", 1)]
        withExtendedLifetime(recovery) {
            #expect(HomeWidgetService.isLinkedActive(widgets: widgets, settings: UserSettings.shared) == false)
        }
    }

    @Test func rule2_missingRecoveryStatusReturnsFalse() {
        resetSettings()
        let recovery = setRecoveryGating(.live)
        let widgets = [widget("trainingLoad", 0), widget("powerLevel", 1)]
        withExtendedLifetime(recovery) {
            #expect(HomeWidgetService.isLinkedActive(widgets: widgets, settings: UserSettings.shared) == false)
        }
    }

    @Test func rule3_nonAdjacentReturnsFalse() {
        resetSettings()
        let recovery = setRecoveryGating(.live)
        let widgets = [
            widget("recoveryStatus", 0),
            widget("powerLevel", 1),
            widget("trainingLoad", 2)
        ]
        withExtendedLifetime(recovery) {
            #expect(HomeWidgetService.isLinkedActive(widgets: widgets, settings: UserSettings.shared) == false)
        }
    }

    @Test func rule4_gatingNonLiveReturnsFalse() {
        resetSettings()
        let recovery = setRecoveryGating(.noSleepTracker)
        let widgets = [widget("recoveryStatus", 0), widget("trainingLoad", 1)]
        withExtendedLifetime(recovery) {
            #expect(HomeWidgetService.isLinkedActive(widgets: widgets, settings: UserSettings.shared) == false)
        }
    }

    @Test func rule5_allGatesPassedReturnsTrue() {
        resetSettings()
        let recovery = setRecoveryGating(.live)
        let widgets = [widget("recoveryStatus", 0), widget("trainingLoad", 1)]
        withExtendedLifetime(recovery) {
            #expect(HomeWidgetService.isLinkedActive(widgets: widgets, settings: UserSettings.shared) == true)
        }
    }

    @Test func rule5_reverseOrderAdjacentAlsoLinks() {
        resetSettings()
        let recovery = setRecoveryGating(.live)
        // TL above RS, still adjacent — linking should succeed.
        let widgets = [widget("trainingLoad", 0), widget("recoveryStatus", 1)]
        withExtendedLifetime(recovery) {
            #expect(HomeWidgetService.isLinkedActive(widgets: widgets, settings: UserSettings.shared) == true)
        }
    }
}

// MARK: - Phase 11 Step 5 — Manual-unlink flag clearing

@MainActor
struct ManualUnlinkFlagClearingTests {

    @Test func clearsFlagWhenRSPositionChanges() {
        let settings = UserSettings.shared
        settings.recoveryLoadManuallyUnlinked = true
        defer { settings.recoveryLoadManuallyUnlinked = false }

        HomeWidgetService.clearManualUnlinkIfReorderAffectedPair(
            previousOrderedTypes: ["recoveryStatus", "trainingLoad", "powerLevel"],
            newOrderedTypes: ["powerLevel", "recoveryStatus", "trainingLoad"],
            settings: settings
        )
        #expect(settings.recoveryLoadManuallyUnlinked == false)
    }

    @Test func clearsFlagWhenTLPositionChanges() {
        let settings = UserSettings.shared
        settings.recoveryLoadManuallyUnlinked = true
        defer { settings.recoveryLoadManuallyUnlinked = false }

        HomeWidgetService.clearManualUnlinkIfReorderAffectedPair(
            previousOrderedTypes: ["recoveryStatus", "trainingLoad", "powerLevel"],
            newOrderedTypes: ["recoveryStatus", "powerLevel", "trainingLoad"],
            settings: settings
        )
        #expect(settings.recoveryLoadManuallyUnlinked == false)
    }

    @Test func retainsFlagWhenOnlyOtherWidgetsMove() {
        let settings = UserSettings.shared
        settings.recoveryLoadManuallyUnlinked = true
        defer { settings.recoveryLoadManuallyUnlinked = false }

        // Only powerLevel and weekStreak swap; RS and TL stay at indices 0 and 1.
        HomeWidgetService.clearManualUnlinkIfReorderAffectedPair(
            previousOrderedTypes: ["recoveryStatus", "trainingLoad", "powerLevel", "weekStreak"],
            newOrderedTypes: ["recoveryStatus", "trainingLoad", "weekStreak", "powerLevel"],
            settings: settings
        )
        #expect(settings.recoveryLoadManuallyUnlinked == true)
    }

    @Test func noopWhenFlagAlreadyFalse() {
        let settings = UserSettings.shared
        settings.recoveryLoadManuallyUnlinked = false

        HomeWidgetService.clearManualUnlinkIfReorderAffectedPair(
            previousOrderedTypes: ["recoveryStatus", "trainingLoad"],
            newOrderedTypes: ["trainingLoad", "recoveryStatus"],
            settings: settings
        )
        #expect(settings.recoveryLoadManuallyUnlinked == false)
    }
}

// MARK: - Phase 11 Step 5 — Tap routing with isLinkedActive

@MainActor
struct LinkedTapRoutingTests {

    private func widget(_ type: String, _ sortOrder: Int = 0) -> HomeWidget {
        HomeWidget(widgetType: type, sortOrder: sortOrder)
    }

    @Test func recoveryStatusTapRoutesToLinkedDetailWhenLinked() {
        let route = HomeViewModel().tapRoute(
            for: widget("recoveryStatus"),
            isEditMode: false,
            recoveryStatusGating: .live,
            isLinkedActive: true
        )
        #expect(route == .linkedRecoveryLoad)
    }

    @Test func trainingLoadTapRoutesToLinkedDetailWhenLinked() {
        let route = HomeViewModel().tapRoute(
            for: widget("trainingLoad"),
            isEditMode: false,
            recoveryStatusGating: .live,
            isLinkedActive: true
        )
        #expect(route == .linkedRecoveryLoad)
    }

    @Test func trainingLoadTapRoutesToTrainingLoadDetailWhenUnlinked() {
        let route = HomeViewModel().tapRoute(
            for: widget("trainingLoad"),
            isEditMode: false,
            recoveryStatusGating: .live,
            isLinkedActive: false
        )
        #expect(route == .trainingLoad)
    }

    @Test func recoveryStatusTapRoutesToRecoveryDetailWhenUnlinkedLive() {
        let route = HomeViewModel().tapRoute(
            for: widget("recoveryStatus"),
            isEditMode: false,
            recoveryStatusGating: .live,
            isLinkedActive: false
        )
        #expect(route == .recoveryStatusLive)
    }
}

// MARK: - Phase 11 Step 5 — linkedRecoveryLoad See Info copy

struct LinkedRecoveryLoadSeeInfoCopyTests {

    @Test func linkedRecoveryLoadEntryExists() {
        let copy = AppConstants.widgetInfoModalCopy["linkedRecoveryLoad"]
        #expect(copy != nil)
    }

    @Test func linkedRecoveryLoadCopyHasSixSections() {
        let copy = AppConstants.widgetInfoModalCopy["linkedRecoveryLoad"]
        #expect(copy?.sections.count == 6)
    }

    @Test func linkedRecoveryLoadCopyTitleIsAboutRecoveryAndLoad() {
        let copy = AppConstants.widgetInfoModalCopy["linkedRecoveryLoad"]
        #expect(copy?.title == "About Recovery & Load")
    }
}
