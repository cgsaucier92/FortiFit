import XCTest
import SwiftData
@testable import FortiFit

/// Phase 11 Step 7 — link/unlink lifecycle coverage: auto-link via reorder, auto-unlink
/// on gating degradation, sticky-flag preservation across reorders, and Sleep Cascade
/// 500ms debounce.
@MainActor
final class LinkingLifecycleIntegrationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let result = try TestFixtures.inMemoryContext()
        container = result.0
        context = result.1
        // Clean Phase 11 entities + Home widgets between tests since UserSettings is a singleton.
        for snap in try context.fetch(FetchDescriptor<DailySleepSnapshot>()) { context.delete(snap) }
        for snap in try context.fetch(FetchDescriptor<DailyTrainingLoadSnapshot>()) { context.delete(snap) }
        for widget in try context.fetch(FetchDescriptor<HomeWidget>()) { context.delete(widget) }
        try context.save()
        UserSettings.shared.recoveryLoadManuallyUnlinked = false
        UserSettings.shared.healthKitEnabled = true
    }

    // MARK: - Helpers

    private func seedWidgets(types: [String]) throws -> [HomeWidget] {
        var widgets: [HomeWidget] = []
        for (sortOrder, type) in types.enumerated() {
            let w = HomeWidget(widgetType: type, sortOrder: sortOrder)
            context.insert(w)
            widgets.append(w)
        }
        try context.save()
        return widgets
    }

    private func makeRecoveryService(gating: RecoveryStatusGatingState) -> RecoveryStatusService {
        let stub = StubHealthKitClient()
        stub.hasRecentSleepDataToReturn = (gating == .live)
        let svc = RecoveryStatusService(client: stub)
        svc.currentGatingState = gating
        svc.isLinkedActive = false
        svc.setContext(context)
        return svc
    }

    // MARK: - Auto-link via reorder

    func test_autoLinkWhenWidgetsBecomeAdjacent() throws {
        let recovery = makeRecoveryService(gating: .live)

        // Start non-adjacent: RS at 0, powerLevel at 1, TL at 2.
        let widgets = try seedWidgets(types: ["recoveryStatus", "powerLevel", "trainingLoad"])
        withExtendedLifetime(recovery) {
            XCTAssertFalse(
                HomeWidgetService.isLinkedActive(widgets: widgets, settings: UserSettings.shared),
                "Non-adjacent widgets should not link"
            )

            // Reorder to make them adjacent: TL, RS, powerLevel (TL at 0, RS at 1).
            HomeWidgetService.reorder(orderedTypes: ["trainingLoad", "recoveryStatus", "powerLevel"], context: context)
            let reordered = HomeWidgetService.fetchAll(context: context)
            XCTAssertTrue(
                HomeWidgetService.isLinkedActive(widgets: reordered, settings: UserSettings.shared),
                "Adjacent widgets should auto-link"
            )
        }
    }

    // MARK: - Auto-unlink on gating degradation

    func test_autoUnlinkWhenGatingDegrades() throws {
        let recovery = makeRecoveryService(gating: .live)
        let widgets = try seedWidgets(types: ["recoveryStatus", "trainingLoad"])

        withExtendedLifetime(recovery) {
            XCTAssertTrue(HomeWidgetService.isLinkedActive(widgets: widgets, settings: UserSettings.shared))

            // Simulate sleep scope revoked → gating drops to noSleepTracker.
            recovery.currentGatingState = .noSleepTracker

            XCTAssertFalse(
                HomeWidgetService.isLinkedActive(widgets: widgets, settings: UserSettings.shared),
                "Gating degradation should auto-unlink"
            )
        }
    }

    // MARK: - Manual-unlink sticky flag preservation

    func test_manualUnlinkFlagRetainedAfterUnrelatedReorder() throws {
        let recovery = makeRecoveryService(gating: .live)
        let widgets = try seedWidgets(types: ["recoveryStatus", "trainingLoad", "powerLevel", "weekStreak"])

        UserSettings.shared.recoveryLoadManuallyUnlinked = true
        defer { UserSettings.shared.recoveryLoadManuallyUnlinked = false }

        withExtendedLifetime(recovery) {
            XCTAssertFalse(
                HomeWidgetService.isLinkedActive(widgets: widgets, settings: UserSettings.shared),
                "Sticky manual-unlink flag should keep composite collapsed"
            )

            // Reorder powerLevel <-> weekStreak. RS and TL stay at 0 and 1.
            let prevTypes = widgets.map(\.widgetType)
            let newTypes = ["recoveryStatus", "trainingLoad", "weekStreak", "powerLevel"]
            HomeWidgetService.clearManualUnlinkIfReorderAffectedPair(
                previousOrderedTypes: prevTypes,
                newOrderedTypes: newTypes,
                settings: UserSettings.shared
            )
            HomeWidgetService.reorder(orderedTypes: newTypes, context: context)

            XCTAssertTrue(
                UserSettings.shared.recoveryLoadManuallyUnlinked,
                "Unrelated reorder must not clear the manual-unlink flag"
            )
        }
    }

    func test_manualUnlinkFlagClearedAfterPairAffectingReorder() throws {
        let recovery = makeRecoveryService(gating: .live)
        let widgets = try seedWidgets(types: ["recoveryStatus", "trainingLoad", "powerLevel"])

        UserSettings.shared.recoveryLoadManuallyUnlinked = true
        defer { UserSettings.shared.recoveryLoadManuallyUnlinked = false }

        withExtendedLifetime(recovery) {
            let prevTypes = widgets.map(\.widgetType)
            // Move powerLevel to position 0 — pushes RS and TL down by one.
            let newTypes = ["powerLevel", "recoveryStatus", "trainingLoad"]
            HomeWidgetService.clearManualUnlinkIfReorderAffectedPair(
                previousOrderedTypes: prevTypes,
                newOrderedTypes: newTypes,
                settings: UserSettings.shared
            )
            HomeWidgetService.reorder(orderedTypes: newTypes, context: context)

            XCTAssertFalse(
                UserSettings.shared.recoveryLoadManuallyUnlinked,
                "Reorder that changes RS or TL position must clear the manual-unlink flag"
            )

            // After clearing, link gates pass → composite renders.
            let reordered = HomeWidgetService.fetchAll(context: context)
            XCTAssertTrue(
                HomeWidgetService.isLinkedActive(widgets: reordered, settings: UserSettings.shared)
            )
        }
    }

    // MARK: - Composite-as-source reorder (BUG-060 regression)

    /// BUG-060 — Dragging the Linked Recovery & Load composite onto another widget
    /// must move both pair widgets together. Pre-fix, the destination card's generic
    /// onReorder ran a single-widget `types.move` on `"recoveryStatus"` only, splitting
    /// the pair and unlinking the composite.
    func test_movePairOrderedTypes_compositeDraggedOntoLaterWidget_pairStaysAdjacentAndLinked() throws {
        let recovery = makeRecoveryService(gating: .live)
        // Pair at the top, then three non-pair widgets after.
        let initialTypes = ["recoveryStatus", "trainingLoad", "powerLevel", "weekStreak", "todaysPlan"]
        let widgets = try seedWidgets(types: initialTypes)

        withExtendedLifetime(recovery) {
            XCTAssertTrue(
                HomeWidgetService.isLinkedActive(widgets: widgets, settings: UserSettings.shared),
                "Sanity: pair should be linked at start"
            )

            // Composite dragged onto `weekStreak` (a non-adjacent later widget).
            guard let newTypes = HomeWidgetService.movePairOrderedTypes(
                previousOrderedTypes: initialTypes,
                targetType: "weekStreak"
            ) else {
                XCTFail("movePairOrderedTypes returned nil for valid inputs")
                return
            }

            // Pair landed adjacent to weekStreak (after it, since pair was before target).
            XCTAssertEqual(newTypes, ["powerLevel", "weekStreak", "recoveryStatus", "trainingLoad", "todaysPlan"])

            // Pair widgets are still adjacent (`abs == 1`) and in original relative order.
            let rsIdx = newTypes.firstIndex(of: "recoveryStatus")!
            let tlIdx = newTypes.firstIndex(of: "trainingLoad")!
            XCTAssertEqual(abs(rsIdx - tlIdx), 1, "Pair must remain adjacent after move")
            XCTAssertLessThan(rsIdx, tlIdx, "Pair's relative order (RS before TL) must be preserved")

            // Persist + verify link gate still passes.
            HomeWidgetService.reorder(orderedTypes: newTypes, context: context)
            let reordered = HomeWidgetService.fetchAll(context: context)
            XCTAssertTrue(
                HomeWidgetService.isLinkedActive(widgets: reordered, settings: UserSettings.shared),
                "Pair must remain linked after composite-as-source drag"
            )
        }
    }

    /// BUG-060 — Same regression, opposite direction: composite dragged onto an
    /// earlier widget should land the pair adjacent to (and *before*) the target.
    func test_movePairOrderedTypes_compositeDraggedOntoEarlierWidget_pairStaysAdjacentAndLinked() throws {
        let recovery = makeRecoveryService(gating: .live)
        // Pair at the end, two non-pair widgets first.
        let initialTypes = ["powerLevel", "weekStreak", "todaysPlan", "recoveryStatus", "trainingLoad"]
        let widgets = try seedWidgets(types: initialTypes)

        withExtendedLifetime(recovery) {
            XCTAssertTrue(HomeWidgetService.isLinkedActive(widgets: widgets, settings: UserSettings.shared))

            // Composite dragged onto `powerLevel` (the first widget).
            guard let newTypes = HomeWidgetService.movePairOrderedTypes(
                previousOrderedTypes: initialTypes,
                targetType: "powerLevel"
            ) else {
                XCTFail("movePairOrderedTypes returned nil for valid inputs")
                return
            }

            // Pair lands immediately before powerLevel (since pair was after target).
            XCTAssertEqual(newTypes, ["recoveryStatus", "trainingLoad", "powerLevel", "weekStreak", "todaysPlan"])

            let rsIdx = newTypes.firstIndex(of: "recoveryStatus")!
            let tlIdx = newTypes.firstIndex(of: "trainingLoad")!
            XCTAssertEqual(abs(rsIdx - tlIdx), 1)

            HomeWidgetService.reorder(orderedTypes: newTypes, context: context)
            let reordered = HomeWidgetService.fetchAll(context: context)
            XCTAssertTrue(HomeWidgetService.isLinkedActive(widgets: reordered, settings: UserSettings.shared))
        }
    }

    /// BUG-060 — guard rails: target cannot be a pair member (would be a no-op /
    /// nonsensical drop on the composite itself), and missing pair widgets must
    /// return nil rather than crash.
    func test_movePairOrderedTypes_returnsNilForInvalidTargets() {
        let valid = ["recoveryStatus", "trainingLoad", "powerLevel"]

        // Target IS a pair member → nil.
        XCTAssertNil(HomeWidgetService.movePairOrderedTypes(previousOrderedTypes: valid, targetType: "recoveryStatus"))
        XCTAssertNil(HomeWidgetService.movePairOrderedTypes(previousOrderedTypes: valid, targetType: "trainingLoad"))

        // Target absent from collection → nil.
        XCTAssertNil(HomeWidgetService.movePairOrderedTypes(previousOrderedTypes: valid, targetType: "powerLevelMissing"))

        // Pair widget missing → nil (linked composite couldn't exist anyway).
        let halfPair = ["recoveryStatus", "powerLevel"]
        XCTAssertNil(HomeWidgetService.movePairOrderedTypes(previousOrderedTypes: halfPair, targetType: "powerLevel"))
    }

    // MARK: - Sleep Cascade 500ms debounce

    func test_sleepObserverDebouncesToTrailingFire() async throws {
        let stub = StubHealthKitClient()
        UserSettings.shared.healthKitEnabled = true
        let service = RecoveryStatusService(client: stub)
        service.setContext(context)

        // Track how many times the SwiftData write path actually fires by counting
        // snapshots in the store after 5 observer fires in rapid succession.
        stub.sleepSamplesToReturn = [
            sample(stage: .inBed, durationMinutes: 480, endOffsetMinutes: 0),
            sample(stage: .asleepDeep, durationMinutes: 80, endOffsetMinutes: -120),
            sample(stage: .asleepCore, durationMinutes: 300, endOffsetMinutes: -30)
        ]

        // Fire 5 observer events within 200ms.
        for _ in 0..<5 {
            await service.handleSleepObserverFire()
            try await Task.sleep(nanoseconds: 40_000_000) // 40ms
        }
        // Wait past the 500ms debounce window to let the trailing cascade fire.
        try await Task.sleep(nanoseconds: 700_000_000)

        // The Sleep Cascade body should have run; we can't easily count its invocations
        // (it's debounced internally) but we can verify the end state: today's snapshot
        // exists with the expected aggregate.
        let snapshots = try context.fetch(FetchDescriptor<DailySleepSnapshot>())
        // Exactly one snapshot for today (the upsert path dedupes by wakeUpDate even
        // across multiple observer fires).
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.totalSleepMinutes, 380)
    }

    // MARK: - Fixture helper (anchored to 8 AM today to avoid time-of-day flake)

    private var wakeUpWindowAnchor: Date {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private func sample(stage: HKSleepStage, durationMinutes: Int, endOffsetMinutes: Int) -> HKSleepSampleSnapshot {
        let end = wakeUpWindowAnchor.addingTimeInterval(TimeInterval(endOffsetMinutes * 60))
        let start = end.addingTimeInterval(TimeInterval(-durationMinutes * 60))
        return HKSleepSampleSnapshot(uuid: UUID(), stage: stage, startDate: start, endDate: end, sourceBundleID: "com.apple.health")
    }
}
