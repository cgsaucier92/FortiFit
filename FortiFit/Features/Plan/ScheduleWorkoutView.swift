import SwiftUI
import SwiftData

struct ScheduleWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(WatchScheduleService.self) private var watchScheduleService
    @Query(sort: \WorkoutTemplate.dateCreated, order: .reverse) private var templates: [WorkoutTemplate]

    var preSelectedDate: Date
    var preSelectedTemplate: WorkoutTemplate?
    var onSchedule: (WorkoutTemplate, Date, Date?, String?, Bool) -> Void
    var onOpenSettings: (() -> Void)?

    @State private var selectedTemplate: WorkoutTemplate?
    @State private var scheduledDate: Date
    @State private var showTimePicker = false
    @State private var scheduledTime: Date = Date()
    @State private var recurrence = "None"
    @State private var headerHeight: CGFloat = 0
    @State private var pushToAppleWatch = false
    @State private var showPushInfoPopover = false
    @State private var showMasterOffPopover = false

    private let recurrenceOptions = ["None", "Weekly", "Biweekly"]

    init(
        preSelectedDate: Date,
        preSelectedTemplate: WorkoutTemplate?,
        onSchedule: @escaping (WorkoutTemplate, Date, Date?, String?, Bool) -> Void,
        onOpenSettings: (() -> Void)? = nil
    ) {
        self.preSelectedDate = preSelectedDate
        self.preSelectedTemplate = preSelectedTemplate
        self.onSchedule = onSchedule
        self.onOpenSettings = onOpenSettings

        let today = Calendar.current.startOfDay(for: Date())
        let date = Calendar.current.startOfDay(for: preSelectedDate)
        _scheduledDate = State(initialValue: date >= today ? preSelectedDate : Date())
        _selectedTemplate = State(initialValue: preSelectedTemplate)
    }

    private var canSchedule: Bool {
        selectedTemplate != nil
    }

    private var recurrenceRule: String? {
        switch recurrence {
        case "Weekly": return "weekly"
        case "Biweekly": return "biweekly"
        default: return nil
        }
    }

    private var masterOn: Bool {
        UserSettings.shared.syncPlanToAppleWatchEnabled
    }

    private var authGranted: Bool {
        watchScheduleService.authState == .granted
    }

    private var pushEnabled: Bool {
        masterOn && authGranted
    }

    var body: some View {
        ZStack(alignment: .top) {
            if templates.isEmpty {
                VStack {
                    Spacer()
                    Text("You'll need to create a template before planning a workout. You can create a template from the Workouts or Workout Templates screens.")
                        .font(FortiFitTypography.body)
                        .foregroundStyle(FortiFitColors.mutedText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, FortiFitSpacing.screenHorizontal)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
                        FortiFitScreenHeading("Plan Workout")

                        // Template selection
                        FortiFitLabel("Workout Template", color: FortiFitColors.primaryText)
                        templateSelectionSection

                        // Date picker
                        FortiFitLabel("Scheduled Date", color: FortiFitColors.primaryText)
                        DatePicker(
                            "",
                            selection: $scheduledDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(FortiFitColors.primaryAccent)
                        .colorScheme(.dark)

                        // Optional time
                        setSpecificTimeSection

                        // Recurrence
                        FortiFitLabel("Recurrence", color: FortiFitColors.primaryText)
                        FortiFitSegmentedToggle(
                            options: recurrenceOptions,
                            selected: $recurrence
                        )

                        // Push to Apple Watch
                        pushToAppleWatchSection

                        // Summary card
                        if let template = selectedTemplate {
                            FortiFitLabel("Summary", color: FortiFitColors.primaryText)
                            FortiFitCard(borderColor: FortiFitColors.border) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(template.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(FortiFitColors.primaryText)
                                    Text(scheduledDate.shortFormatted)
                                        .font(FortiFitTypography.bodySmall)
                                        .foregroundStyle(FortiFitColors.mutedText)
                                    if showTimePicker {
                                        Text(scheduledTime.timeFormatted)
                                            .font(FortiFitTypography.bodySmall)
                                            .foregroundStyle(FortiFitColors.mutedText)
                                    }
                                    if recurrence != "None" {
                                        Text(recurrence)
                                            .font(FortiFitTypography.bodySmall)
                                            .foregroundStyle(FortiFitColors.primaryAccent)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        // Schedule button
                        FortiFitButton("Plan Workout", style: .primary, isEnabled: canSchedule) {
                            guard let template = selectedTemplate else { return }
                            onSchedule(
                                template,
                                scheduledDate,
                                showTimePicker ? scheduledTime : nil,
                                recurrenceRule,
                                pushToAppleWatch
                            )
                            dismiss()
                        }
                        .accessibilityIdentifier(AccessibilityID.scheduleWorkoutConfirmButton)
                    }
                    .padding(.horizontal, FortiFitSpacing.screenHorizontal)
                    .padding(.top, headerHeight)
                    .padding(.bottom, FortiFitSpacing.gapXLarge)
                }
                .scrollClipDisabled()
            }

            // Fixed header
            FortiFitFixedHeader(headerHeight: $headerHeight) {
                VStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
                    HStack {
                        FortiFitBackButton { dismiss() }
                        Spacer()
                    }
                }
            }
        }
        .background(FortiFitColors.background)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .swipeToDismiss()
        .onAppear {
            if pushEnabled {
                pushToAppleWatch = true
            }
        }
    }

    // MARK: - Scheduled Time Section

    @ViewBuilder
    private var setSpecificTimeSection: some View {
        Toggle(isOn: $showTimePicker) {
            FortiFitLabel("Scheduled Time", color: FortiFitColors.primaryText)
        }
        .tint(FortiFitColors.primaryAccent)

        if showTimePicker {
            DatePicker(
                "",
                selection: $scheduledTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .tint(FortiFitColors.primaryAccent)
            .colorScheme(.dark)
        }
    }

    // MARK: - Push to Apple Watch Section

    @ViewBuilder
    private var pushToAppleWatchSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if pushEnabled {
                Toggle(isOn: $pushToAppleWatch) {
                    HStack(spacing: 6) {
                        Text(AppConstants.AppleWatch.scheduleWorkoutToggleLabel)
                            .foregroundStyle(FortiFitColors.primaryText)
                        Button { showPushInfoPopover.toggle() } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(FortiFitColors.mutedText)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showPushInfoPopover) {
                            Text(AppConstants.AppleWatch.watchSyncInfoPopover)
                                .font(FortiFitTypography.bodySmall)
                                .foregroundStyle(FortiFitColors.primaryText)
                                .padding()
                                .frame(width: 280)
                                .fixedSize(horizontal: false, vertical: true)
                                .presentationCompactAdaptation(.popover)
                        }
                        .accessibilityIdentifier(AccessibilityID.scheduleWorkout_pushToAppleWatchInfoPopover)
                    }
                }
                .tint(FortiFitColors.primaryAccent)
                .accessibilityIdentifier(AccessibilityID.scheduleWorkout_pushToAppleWatchToggle)
            } else {
                // Disabled state — master off or auth denied
                ZStack {
                    Toggle(isOn: .constant(false)) {
                        Text(AppConstants.AppleWatch.scheduleWorkoutToggleLabel)
                            .foregroundStyle(FortiFitColors.primaryText)
                    }
                    .tint(FortiFitColors.primaryAccent)
                    .disabled(true)
                    .opacity(0.4)
                    .accessibilityIdentifier(AccessibilityID.scheduleWorkout_pushToAppleWatchToggle)

                    // Tap overlay for showing popover
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showMasterOffPopover = true
                        }
                }
                .popover(isPresented: $showMasterOffPopover) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppConstants.AppleWatch.masterOffTitle)
                            .font(FortiFitTypography.label)
                            .foregroundStyle(FortiFitColors.primaryText)

                        Text(disabledCaption)
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.primaryText)

                        Button(disabledButtonLabel) {
                            showMasterOffPopover = false
                            if !masterOn {
                                dismiss()
                                onOpenSettings?()
                            } else {
                                #if os(iOS)
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                                #endif
                            }
                        }
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(FortiFitColors.primaryAccent)
                        .accessibilityIdentifier(AccessibilityID.masterSyncOff_openSettingsButton)
                    }
                    .padding()
                    .frame(width: 280)
                    .fixedSize(horizontal: false, vertical: true)
                    .presentationCompactAdaptation(.popover)
                    .accessibilityIdentifier(AccessibilityID.masterSyncOff_popover)
                }

                Text(disabledCaption)
                    .font(FortiFitTypography.bodySmall)
                    .foregroundStyle(FortiFitColors.mutedText)
            }
        }
    }

    private var disabledCaption: String {
        if !masterOn {
            return AppConstants.AppleWatch.scheduleWorkoutMasterOffCaption
        }
        return AppConstants.AppleWatch.scheduleWorkoutAuthDeniedCaption
    }

    private var disabledButtonLabel: String {
        if !masterOn {
            return AppConstants.AppleWatch.masterOffOpenSettings
        }
        return AppConstants.AppleWatch.authDeniedOpenSettings
    }

    // MARK: - Template Selection

    @ViewBuilder
    private var templateSelectionSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                Button {
                    selectedTemplate = template
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(FortiFitColors.primaryText)
                            HStack(spacing: FortiFitSpacing.elementSpacing) {
                                Text(template.workoutType)
                                    .font(FortiFitTypography.bodySmall)
                                    .foregroundStyle(FortiFitColors.mutedText)
                                Text("\(Set(template.exerciseSets.map(\.exerciseName)).count) exercises")
                                    .font(FortiFitTypography.bodySmall)
                                    .foregroundStyle(FortiFitColors.mutedText)
                            }
                        }
                        Spacer()
                        if selectedTemplate?.id == template.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(FortiFitColors.primaryAccent)
                        }
                    }
                    .padding(.horizontal, FortiFitSpacing.cardPadding)
                    .padding(.vertical, FortiFitSpacing.gapSmall)
                }
                .background(
                    selectedTemplate?.id == template.id
                        ? FortiFitColors.primaryAccent.opacity(0.1)
                        : .clear
                )
                .accessibilityIdentifier(AccessibilityID.templateSelectionRow(index))

                if template.id != templates.last?.id {
                    Rectangle()
                        .fill(FortiFitColors.border)
                        .frame(height: 1)
                }
            }
        }
        .background(FortiFitColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                .stroke(FortiFitColors.border, lineWidth: 1)
        )
    }
}
