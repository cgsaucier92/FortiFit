import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitSyncService.self) private var syncService
    @State private var settings = UserSettings.shared
    @State private var headerHeight: CGFloat = 0
    @State private var viewModel: SettingsViewModel?
    @State private var showDisableAlert = false
    @State private var showAppleWatchDisableAlert = false
    @Environment(WatchScheduleService.self) private var watchScheduleService

    private var unitSelection: String {
        settings.useLbs ? "LBS" : "KG"
    }

    private var distanceSelection: String {
        settings.useMiles ? "MILES" : "KM"
    }

    var body: some View {
        ZStack(alignment: .top) {
        ScrollView {
            VStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
                FortiFitScreenHeading("General Settings", color: FortiFitColors.primaryAccent)

                FortiFitCard(borderColor: FortiFitColors.border) {
                    HStack {
                        Text("Weight Unit")
                            .font(FortiFitTypography.body)
                            .foregroundStyle(FortiFitColors.primaryText)
                        Spacer()
                        FortiFitSegmentedToggle(
                            options: ["KG", "LBS"],
                            selected: Binding(
                                get: { unitSelection },
                                set: { settings.useLbs = $0 == "LBS" }
                            ),
                            accessibilityIdentifier: AccessibilityID.settingsWeightUnitToggle
                        )
                        .frame(width: 120)
                    }
                }

                FortiFitCard(borderColor: FortiFitColors.border) {
                    HStack {
                        Text("Distance Unit")
                            .font(FortiFitTypography.body)
                            .foregroundStyle(FortiFitColors.primaryText)
                        Spacer()
                        FortiFitSegmentedToggle(
                            options: ["KM", "MILES"],
                            selected: Binding(
                                get: { distanceSelection },
                                set: { settings.useMiles = $0 == "MILES" }
                            )
                        )
                        .frame(width: 120)
                    }
                }

                FortiFitDivider()

                appleHealthSection

                appleWatchSection
            }
            .padding(.horizontal, FortiFitSpacing.screenHorizontal)
            .padding(.top, headerHeight)
            .padding(.bottom, FortiFitSpacing.gapXLarge)
        }
        .scrollClipDisabled()
        .onAppear {
            if viewModel == nil {
                viewModel = SettingsViewModel(syncService: syncService)
            }
        }
        .alert("Disconnect Apple Health?", isPresented: $showDisableAlert) {
            Button("Disconnect", role: .destructive) {
                Task { await viewModel?.toggleHealthKit(context: modelContext) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Sync will stop, but your existing linked workouts will be kept.")
        }

        // Fixed header
        FortiFitFixedHeader(headerHeight: $headerHeight) {
            HStack {
                FortiFitBackButton { dismiss() }
                    .accessibilityIdentifier(AccessibilityID.settingsBackButton)
                Spacer()
            }
        }
        }
        .background(FortiFitColors.background)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    // MARK: - Apple Watch Section

    @ViewBuilder
    private var appleWatchSection: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.gapMedium) {
            FortiFitCard(borderColor: FortiFitColors.border) {
                VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                    Toggle(isOn: Binding(
                        get: { settings.syncPlanToAppleWatchEnabled },
                        set: { newValue in
                            if newValue {
                                settings.syncPlanToAppleWatchEnabled = true
                                Task {
                                    await watchScheduleService.handleMasterToggleOn(context: modelContext)
                                }
                            } else {
                                showAppleWatchDisableAlert = true
                            }
                        }
                    )) {
                        Text(AppConstants.AppleWatch.settingsToggleLabel)
                            .font(FortiFitTypography.body)
                            .foregroundStyle(FortiFitColors.primaryText)
                    }
                    .tint(FortiFitColors.primaryAccent)
                    .accessibilityIdentifier(AccessibilityID.settingsAppleWatchToggle)

                    Text(AppConstants.AppleWatch.settingsDescription)
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(FortiFitColors.mutedText)
                }
            }
        }
        .alert(AppConstants.AppleWatch.settingsTurnOffConfirmTitle, isPresented: $showAppleWatchDisableAlert) {
            Button("Turn Off", role: .destructive) {
                settings.syncPlanToAppleWatchEnabled = false
                Task {
                    await watchScheduleService.handleMasterToggleOff(context: modelContext)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(AppConstants.AppleWatch.settingsTurnOffConfirmMessage)
        }
    }

    @ViewBuilder
    private var appleWatchStatusLine: some View {
        switch watchScheduleService.authState {
        case .granted:
            Text(AppConstants.AppleWatch.settingsStatusConnected)
                .font(FortiFitTypography.bodySmall)
                .foregroundStyle(FortiFitColors.positive)
        case .denied:
            VStack(alignment: .leading, spacing: FortiFitSpacing.elementSpacing) {
                Text(AppConstants.AppleWatch.settingsStatusDenied)
                    .font(FortiFitTypography.bodySmall)
                    .foregroundStyle(FortiFitColors.alert)
                Button(AppConstants.AppleWatch.settingsOpenSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .tint(FortiFitColors.primaryAccent)
                .accessibilityIdentifier(AccessibilityID.settingsAppleWatchOpenSettingsButton)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Apple Health Section

    @ViewBuilder
    private var appleHealthSection: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.gapMedium) {
            FortiFitScreenHeading("Apple Health & Devices", color: FortiFitColors.primaryAccent)

            FortiFitCard(borderColor: FortiFitColors.border) {
                VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                    Toggle(isOn: Binding(
                        get: { viewModel?.healthKitEnabled ?? false },
                        set: { newValue in
                            if newValue {
                                Task { await viewModel?.toggleHealthKit(context: modelContext) }
                            } else {
                                showDisableAlert = true
                            }
                        }
                    )) {
                        Text("Connect to Apple Health")
                            .font(FortiFitTypography.body)
                            .foregroundStyle(FortiFitColors.primaryText)
                    }
                    .tint(FortiFitColors.primaryAccent)
                    .accessibilityIdentifier(AccessibilityID.settingsAppleHealthToggle)

                    Text("Import workouts from Apple Watch and other Health-connected apps. Linked workouts appear automatically and can't be fully unlinked in bulk.")
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(FortiFitColors.mutedText)

                    if let statusText = viewModel?.lastSyncDescription {
                        Text(statusText)
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(viewModel?.authStatus == .granted ? FortiFitColors.positive : FortiFitColors.mutedText)
                    }

                    if viewModel?.healthKitEnabled == true {
                        if viewModel?.authStatus == .granted {
                            Button {
                                Task { await viewModel?.syncNow(context: modelContext) }
                            } label: {
                                HStack(spacing: 6) {
                                    if viewModel?.isSyncing == true {
                                        ProgressView()
                                            .tint(FortiFitColors.primaryAccent)
                                            .scaleEffect(0.8)
                                    }
                                    Text("Sync Now")
                                        .font(FortiFitTypography.body.weight(.semibold))
                                }
                            }
                            .disabled(viewModel?.isSyncing == true)
                            .tint(FortiFitColors.primaryAccent)
                            .accessibilityIdentifier(AccessibilityID.settingsAppleHealthSyncNowButton)
                        } else if viewModel?.authStatus == .denied {
                            Button("Open iOS Settings") {
                                viewModel?.openIOSSettings()
                            }
                            .tint(FortiFitColors.primaryAccent)
                            .accessibilityIdentifier(AccessibilityID.settingsAppleHealthOpenSettingsButton)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(HealthKitSyncService(client: DefaultHealthKitClient(), matcher: WorkoutMatcher()))
            .environment(WatchScheduleService(scheduler: NoOpWorkoutScheduler()))
    }
}
