//
//  FortiFitApp.swift
//  FortiFit
//
//  Created by cameron saucier on 3/19/26.
//

import SwiftUI
import SwiftData

@main
struct FortiFitApp: App {
    @State private var importPayload: TemplatePayload?
    @State private var showImportPrompt = false
    @State private var showImportError = false
    @State private var healthKitMatcher: WorkoutMatcher
    @State private var healthKitSyncService: HealthKitSyncService
    @State private var appleActivityService: AppleActivityService
    @State private var watchScheduleService: WatchScheduleService
    @State private var recoveryStatusService: RecoveryStatusService
    @State private var currentPendingMatch: PendingMatch?
    @State private var showLaunchSplash = true
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Workout.self,
            ExerciseSet.self,
            Goal.self,
            WorkoutTypeOrder.self,
            WorkoutTemplate.self,
            TemplateExerciseSet.self,
            HomeWidget.self,
            TrendsChart.self,
            ScheduledWorkout.self,
            GoalSnapshot.self,
            WorkoutMatchRejection.self,
            DailySleepSnapshot.self,
            DailyTrainingLoadSnapshot.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // Wipe SwiftData store for a clean test run
        if CommandLine.arguments.contains("--reset-state") {
            let storeURL = modelConfiguration.url
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
        }

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Schema changed during development — delete the stale store and recreate.
            let storeURL = modelConfiguration.url
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            UserSettings.shared.healthKitAnchor = nil
            UserSettings.shared.healthKitLastSyncDate = nil
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    init() {
        let isUITesting = CommandLine.arguments.contains("--uitesting")
        if isUITesting {
            UIView.setAnimationsEnabled(false)
        }
        if CommandLine.arguments.contains("--reset-state") {
            if let bundleId = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
            }
        }
        let client: HealthKitClient = isUITesting ? NoOpHealthKitClient() : DefaultHealthKitClient()
        let matcher = WorkoutMatcher()
        _healthKitMatcher = State(initialValue: matcher)
        let syncService = HealthKitSyncService(client: client, matcher: matcher)
        let recovery = RecoveryStatusService(client: client)
        syncService.recoveryStatusService = recovery
        _healthKitSyncService = State(initialValue: syncService)
        _appleActivityService = State(initialValue: AppleActivityService(client: client))
        _recoveryStatusService = State(initialValue: recovery)
        let workoutScheduler: WorkoutSchedulerProtocol = isUITesting ? NoOpWorkoutScheduler() : DefaultWorkoutScheduler()
        _watchScheduleService = State(initialValue: WatchScheduleService(scheduler: workoutScheduler))
    }

    private var isUITesting: Bool {
        CommandLine.arguments.contains("--uitesting")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
            if isUITesting {
                ContentView()
                    .environment(healthKitSyncService)
                    .environment(appleActivityService)
                    .environment(watchScheduleService)
                    .environment(recoveryStatusService)
                    .task {
                        let context = sharedModelContainer.mainContext
                        if CommandLine.arguments.contains("--seed-hk-workout") {
                            seedHealthKitLinkedWorkout(context: context)
                        }
                        if CommandLine.arguments.contains("--seed-hk-strava-workout") {
                            seedStravaLinkedWorkout(context: context)
                        }
                        if CommandLine.arguments.contains("--seed-hk-unknown-workout") {
                            seedUnknownSourceWorkout(context: context)
                        }
                        if CommandLine.arguments.contains("--seed-hk-pending-match") {
                            seedPendingMatch(context: context)
                            presentNextPendingMatch()
                        }
                    }
                    .sheet(item: $currentPendingMatch, onDismiss: {
                        presentNextPendingMatch()
                    }) { match in
                        let context = sharedModelContainer.mainContext
                        let workout = fetchWorkout(id: match.workoutId, context: context)
                        MatchPromptSheetView(
                            pendingMatch: match,
                            workout: workout,
                            onLink: {
                                healthKitMatcher.resolvePending(
                                    workoutId: match.workoutId,
                                    snapshot: match.snapshot,
                                    decision: .link,
                                    context: context
                                )
                            },
                            onKeepSeparate: {
                                healthKitMatcher.resolvePending(
                                    workoutId: match.workoutId,
                                    snapshot: match.snapshot,
                                    decision: .keepSeparate,
                                    context: context
                                )
                            },
                            onDecideLater: {
                                healthKitMatcher.resolvePending(
                                    workoutId: match.workoutId,
                                    snapshot: match.snapshot,
                                    decision: .decideLater,
                                    context: context
                                )
                            }
                        )
                    }
            } else {
                ContentView()
                    .environment(healthKitSyncService)
                    .environment(appleActivityService)
                    .environment(watchScheduleService)
                    .environment(recoveryStatusService)
                    .task {
                        let context = sharedModelContainer.mainContext
                        WorkoutService.migrateSprintsToCardioIfNeeded(context: context)
                        HomeWidgetService.migrateWorkoutInfoRemovalIfNeeded(context: context)
                        healthKitSyncService.setContext(context)
                        recoveryStatusService.setContext(context)
                        if CommandLine.arguments.contains("--seed-hk-workout") {
                            seedHealthKitLinkedWorkout(context: context)
                        }
                        if CommandLine.arguments.contains("--seed-hk-strava-workout") {
                            seedStravaLinkedWorkout(context: context)
                        }
                        if CommandLine.arguments.contains("--seed-hk-unknown-workout") {
                            seedUnknownSourceWorkout(context: context)
                        }
                        if CommandLine.arguments.contains("--seed-hk-pending-match") {
                            seedPendingMatch(context: context)
                            presentNextPendingMatch()
                        }
                        if UserSettings.shared.healthKitEnabled {
                            if !UserSettings.shared.hasResetAnchorForPhase87 {
                                UserSettings.shared.healthKitAnchor = nil
                                UserSettings.shared.healthKitLastSyncDate = nil
                                UserSettings.shared.hasResetAnchorForPhase87 = true
                            }
                            try? await DefaultHealthKitClient().requestAuthorization()
                            await healthKitSyncService.importPendingWorkouts(context: context)
                            healthKitSyncService.startObserving()
                            healthKitSyncService.registerBackgroundTask()
                            appleActivityService.startObserving()
                            appleActivityService.refresh()
                            appleActivityService.refreshWorkoutContributions(context: context)
                            // Phase 11 — Recovery Status launch refresh.
                            await recoveryStatusService.refresh(forceCatchUp: false)
                            await healthKitSyncService.runSleepCatchUpIfNeeded()
                        }
                        if UserSettings.shared.syncPlanToAppleWatchEnabled {
                            await watchScheduleService.refreshAuthState()
                            await watchScheduleService.reconcile(context: context)
                        }
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .active {
                            presentNextPendingMatch()
                            if UserSettings.shared.syncPlanToAppleWatchEnabled {
                                let context = sharedModelContainer.mainContext
                                Task {
                                    await watchScheduleService.refreshAuthState()
                                    await watchScheduleService.reconcile(context: context)
                                }
                            }
                            // Phase 11 — 6pm-cutoff sleep catch-up, guarded internally.
                            Task {
                                await healthKitSyncService.runSleepCatchUpIfNeeded()
                            }
                        }
                    }
                    .sheet(item: $currentPendingMatch, onDismiss: {
                        presentNextPendingMatch()
                    }) { match in
                        let context = sharedModelContainer.mainContext
                        let workout = fetchWorkout(id: match.workoutId, context: context)
                        MatchPromptSheetView(
                            pendingMatch: match,
                            workout: workout,
                            onLink: {
                                healthKitMatcher.resolvePending(
                                    workoutId: match.workoutId,
                                    snapshot: match.snapshot,
                                    decision: .link,
                                    context: context
                                )
                            },
                            onKeepSeparate: {
                                healthKitMatcher.resolvePending(
                                    workoutId: match.workoutId,
                                    snapshot: match.snapshot,
                                    decision: .keepSeparate,
                                    context: context
                                )
                            },
                            onDecideLater: {
                                healthKitMatcher.resolvePending(
                                    workoutId: match.workoutId,
                                    snapshot: match.snapshot,
                                    decision: .decideLater,
                                    context: context
                                )
                            }
                        )
                    }
                    .onOpenURL { url in
                        guard url.scheme == "fitnavi", url.host == "template" else { return }
                        if let payload = TemplateShareService.decodeTemplateURL(url: url) {
                            importPayload = payload
                            showImportError = false
                        } else {
                            importPayload = nil
                            showImportError = true
                        }
                        showImportPrompt = true
                    }
                    .overlay {
                        if showImportPrompt {
                            TemplateImportView(
                                payload: showImportError ? nil : importPayload
                            ) {
                                showImportPrompt = false
                                importPayload = nil
                                showImportError = false
                            }
                        }
                    }
            }

            if showLaunchSplash {
                LaunchSplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
            }
            .task {
                if isUITesting {
                    showLaunchSplash = false
                    return
                }
                try? await Task.sleep(for: .seconds(LaunchSplashView.displayDuration))
                withAnimation(.easeOut(duration: LaunchSplashView.fadeDuration)) {
                    showLaunchSplash = false
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func presentNextPendingMatch() {
        currentPendingMatch = healthKitMatcher.pendingMatches().first
    }

    private func fetchWorkout(id: UUID, context: ModelContext) -> Workout? {
        let predicate = #Predicate<Workout> { w in w.id == id }
        let descriptor = FetchDescriptor<Workout>(predicate: predicate)
        return (try? context.fetch(descriptor))?.first
    }

    private func seedHealthKitLinkedWorkout(context: ModelContext) {
        let workout = Workout(
            name: "HK Smoke Test Run",
            date: Date(),
            workoutType: "Cardio",
            rpe: 7,
            durationMinutes: 35,
            distanceKm: 5.2,
            healthKitUUID: UUID(),
            healthKitSourceBundleID: "com.apple.health.workout-builder",
            healthKitActivityType: "Running",
            avgHeartRate: 155,
            maxHeartRate: 178,
            activeEnergyKcal: 420
        )
        context.insert(workout)
        WorkoutTypeOrderService.ensureOrderExists(for: "Cardio", context: context)
        try? context.save()
    }

    private func seedStravaLinkedWorkout(context: ModelContext) {
        let workout = Workout(
            name: "HK Strava Ride",
            date: Date(),
            workoutType: "Cardio",
            durationMinutes: 60,
            distanceKm: 25.0,
            healthKitUUID: UUID(),
            healthKitSourceBundleID: "com.strava.run",
            healthKitActivityType: "Cycling",
            avgHeartRate: 145,
            maxHeartRate: 172,
            activeEnergyKcal: 580
        )
        context.insert(workout)
        WorkoutTypeOrderService.ensureOrderExists(for: "Cardio", context: context)
        try? context.save()
    }

    private func seedUnknownSourceWorkout(context: ModelContext) {
        let workout = Workout(
            name: "HK Unknown Source Workout",
            date: Date(),
            workoutType: "Cardio",
            durationMinutes: 40,
            distanceKm: 6.0,
            healthKitUUID: UUID(),
            healthKitSourceBundleID: "com.unknowndev.randomfitness",
            healthKitActivityType: "Running",
            avgHeartRate: 138,
            maxHeartRate: 162,
            activeEnergyKcal: 350
        )
        context.insert(workout)
        WorkoutTypeOrderService.ensureOrderExists(for: "Cardio", context: context)
        try? context.save()
    }

    private func seedPendingMatch(context: ModelContext) {
        let manualWorkout = Workout(
            name: "Morning Strength",
            date: Date(),
            workoutType: "Strength Training",
            durationMinutes: 45
        )
        context.insert(manualWorkout)
        try? context.save()

        let snapshot = HealthKitWorkoutSnapshot(
            uuid: UUID(),
            activityTypeRawValue: 50,
            sourceBundleID: "com.apple.health.workout-builder",
            startDate: Date().addingTimeInterval(-1800),
            endDate: Date().addingTimeInterval(900),
            durationMinutes: 45,
            distanceKm: nil,
            avgHeartRate: 142,
            maxHeartRate: 168,
            activeEnergyKcal: 350,
            totalEnergyBurnedKcal: nil,
            elevationAscendedMeters: nil,
            exerciseMinutes: nil,
            indoor: false
        )
        healthKitMatcher.queuePendingMatch(workoutId: manualWorkout.id, snapshot: snapshot)
    }
}
