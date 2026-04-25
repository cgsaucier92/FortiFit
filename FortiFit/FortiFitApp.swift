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
    @State private var healthKitMatcher = WorkoutMatcher()
    @State private var healthKitSyncService: HealthKitSyncService?
    @State private var showMatchPrompt = false
    @State private var currentPendingMatch: PendingMatch?
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
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    init() {
        if CommandLine.arguments.contains("--uitesting") {
            UIView.setAnimationsEnabled(false)
        }
        if CommandLine.arguments.contains("--reset-state") {
            if let bundleId = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(healthKitSyncService ?? HealthKitSyncService(client: DefaultHealthKitClient(), matcher: healthKitMatcher))
                .task {
                    let syncService = HealthKitSyncService(client: DefaultHealthKitClient(), matcher: healthKitMatcher)
                    healthKitSyncService = syncService
                    let context = sharedModelContainer.mainContext
                    WorkoutService.migrateSprintsToCardioIfNeeded(context: context)
                    syncService.setContext(context)
                    if CommandLine.arguments.contains("--seed-hk-workout") {
                        seedHealthKitLinkedWorkout(context: context)
                    }
                    if CommandLine.arguments.contains("--seed-hk-pending-match") {
                        seedPendingMatch(context: context)
                        presentNextPendingMatch()
                    }
                    if UserSettings.shared.healthKitEnabled {
                        await syncService.importPendingWorkouts(context: context)
                        syncService.startObserving()
                        syncService.registerBackgroundTask()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        presentNextPendingMatch()
                    }
                }
                .sheet(isPresented: $showMatchPrompt) {
                    presentNextPendingMatch()
                } content: {
                    if let match = currentPendingMatch {
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
        .modelContainer(sharedModelContainer)
    }

    private func presentNextPendingMatch() {
        guard let match = healthKitMatcher.pendingMatches().first else {
            currentPendingMatch = nil
            return
        }
        currentPendingMatch = match
        showMatchPrompt = true
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
