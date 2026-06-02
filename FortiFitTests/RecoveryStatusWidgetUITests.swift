import Testing
import Foundation
import SwiftData
@testable import FortiFit

// MARK: - Phase 11 Step 4 — HomeViewModel tap routing for Recovery Status

@MainActor
struct RecoveryStatusTapRoutingTests {

    private func widget(_ type: String) -> HomeWidget {
        HomeWidget(widgetType: type, sortOrder: 0)
    }

    private func viewModel() -> HomeViewModel { HomeViewModel() }

    @Test func tapRoute_recoveryStatus_liveOpensDetailSheet() {
        let vm = viewModel()
        let route = vm.tapRoute(
            for: widget("recoveryStatus"),
            isEditMode: false,
            recoveryStatusGating: .live
        )
        #expect(route == .recoveryStatusLive)
    }

    @Test func tapRoute_recoveryStatus_connectAppleHealthRoutesToSettings() {
        let vm = viewModel()
        let route = vm.tapRoute(
            for: widget("recoveryStatus"),
            isEditMode: false,
            recoveryStatusGating: .connectAppleHealth
        )
        #expect(route == .recoveryStatusConnectHK)
    }

    @Test func tapRoute_recoveryStatus_sleepAccessDeniedRoutesToiOSSettings() {
        let vm = viewModel()
        let route = vm.tapRoute(
            for: widget("recoveryStatus"),
            isEditMode: false,
            recoveryStatusGating: .sleepAccessDenied
        )
        #expect(route == .recoveryStatusSleepDenied)
    }

    @Test func tapRoute_recoveryStatus_noSleepTrackerRoutesToNoop() {
        let vm = viewModel()
        let route = vm.tapRoute(
            for: widget("recoveryStatus"),
            isEditMode: false,
            recoveryStatusGating: .noSleepTracker
        )
        #expect(route == .recoveryStatusNoTracker)
    }

    @Test func tapRoute_recoveryStatus_editModeSuppresses() {
        let vm = viewModel()
        let route = vm.tapRoute(
            for: widget("recoveryStatus"),
            isEditMode: true,
            recoveryStatusGating: .live
        )
        #expect(route == .suppressed)
    }

    @Test func tapRoute_recoveryStatus_missingGatingDefaultsToConnect() {
        // No `recoveryStatusGating` passed → defaults to `connectAppleHealth`.
        let vm = viewModel()
        let route = vm.tapRoute(for: widget("recoveryStatus"), isEditMode: false)
        #expect(route == .recoveryStatusConnectHK)
    }
}

// MARK: - Phase 11 Step 4 — See Info copy presence

struct RecoveryStatusSeeInfoCopyTests {

    @Test func recoveryStatusEntryExistsInWidgetInfoModalCopy() {
        let copy = AppConstants.widgetInfoModalCopy["recoveryStatus"]
        #expect(copy != nil)
    }

    @Test func recoveryStatusCopyHasSixSections() {
        let copy = AppConstants.widgetInfoModalCopy["recoveryStatus"]
        #expect(copy?.sections.count == 6)
    }

    @Test func recoveryStatusCopyTitleAndIntroPresent() {
        let copy = AppConstants.widgetInfoModalCopy["recoveryStatus"]
        #expect(copy?.title == "About Recovery Status")
        #expect((copy?.intro.isEmpty ?? true) == false)
    }
}

// MARK: - Phase 11 Step 4 — Widget gating state computed mappings

@MainActor
struct RecoveryStatusWidgetGatingComputationTests {

    @Test func gatingDerivedFromHKDisabled() async {
        let settings = UserSettings.shared
        let original = settings.healthKitEnabled
        defer { settings.healthKitEnabled = original }
        settings.healthKitEnabled = false

        let client = FoundationStubHealthKitClient()
        let svc = RecoveryStatusService(client: client)
        let state = await svc.computeGatingState()
        #expect(state == .connectAppleHealth)
    }

    @Test func gatingDerivedFromHKEnabledNoRecentData() async {
        let settings = UserSettings.shared
        let original = settings.healthKitEnabled
        defer { settings.healthKitEnabled = original }
        settings.healthKitEnabled = true

        let client = FoundationStubHealthKitClient()
        client.hasRecentSleepDataToReturn = false
        let svc = RecoveryStatusService(client: client)
        let state = await svc.computeGatingState()
        #expect(state == .noSleepTracker)
    }

    @Test func gatingDerivedFromHKEnabledWithRecentData() async {
        let settings = UserSettings.shared
        let original = settings.healthKitEnabled
        defer { settings.healthKitEnabled = original }
        settings.healthKitEnabled = true

        let client = FoundationStubHealthKitClient()
        client.hasRecentSleepDataToReturn = true
        let svc = RecoveryStatusService(client: client)
        let state = await svc.computeGatingState()
        #expect(state == .live)
    }
}
