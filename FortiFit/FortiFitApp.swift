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
}
