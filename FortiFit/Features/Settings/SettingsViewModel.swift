import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class SettingsViewModel {
    private let client: HealthKitClient
    private let syncService: HealthKitSyncService
    private let settings = UserSettings.shared

    var healthKitEnabled: Bool { settings.healthKitEnabled }
    var isSyncing: Bool { syncService.isSyncing }

    var authStatus: HealthKitAuthorizationStatus {
        client.authorizationStatus()
    }

    var lastSyncDescription: String? {
        guard healthKitEnabled else { return nil }
        switch authStatus {
        case .denied:
            return "Permission denied in iOS Settings"
        case .granted:
            if let lastSync = settings.healthKitLastSyncDate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                return "Connected · last sync \(formatter.localizedString(for: lastSync, relativeTo: .now))"
            }
            return "Connected · never synced yet"
        case .notDetermined:
            return nil
        }
    }

    init(client: HealthKitClient = DefaultHealthKitClient(), syncService: HealthKitSyncService) {
        self.client = client
        self.syncService = syncService
    }

    func toggleHealthKit(context: ModelContext) async {
        if healthKitEnabled {
            syncService.disable()
        } else {
            await syncService.enable(context: context)
        }
    }

    func syncNow(context: ModelContext) async {
        await syncService.importPendingWorkouts(context: context)
    }

    func openIOSSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
