import SwiftUI
import SwiftData

struct ScheduleWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.dateCreated, order: .reverse) private var templates: [WorkoutTemplate]

    var preSelectedDate: Date
    var preSelectedTemplate: WorkoutTemplate?
    var onSchedule: (WorkoutTemplate, Date, Date?, String?) -> Void

    @State private var selectedTemplate: WorkoutTemplate?
    @State private var scheduledDate: Date
    @State private var showTimePicker = false
    @State private var scheduledTime: Date = Date()
    @State private var recurrence = "None"
    @State private var headerHeight: CGFloat = 0

    private let recurrenceOptions = ["None", "Weekly", "Biweekly"]

    init(
        preSelectedDate: Date,
        preSelectedTemplate: WorkoutTemplate?,
        onSchedule: @escaping (WorkoutTemplate, Date, Date?, String?) -> Void
    ) {
        self.preSelectedDate = preSelectedDate
        self.preSelectedTemplate = preSelectedTemplate
        self.onSchedule = onSchedule

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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
            if templates.isEmpty {
                VStack {
                    Spacer()
                    Text("You'll need to create a template before scheduling a workout. You can create a template from the Workouts or Saved Templates screens.")
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
                        // Template selection
                        FortiFitLabel("Template", color: FortiFitColors.primaryText)
                        templateSelectionSection

                        // Date picker
                        FortiFitLabel("Date", color: FortiFitColors.primaryText)
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
                        Toggle(isOn: $showTimePicker) {
                            FortiFitLabel("Set Specific Time", color: FortiFitColors.primaryText)
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

                        // Recurrence
                        FortiFitLabel("Recurrence", color: FortiFitColors.primaryText)
                        FortiFitSegmentedToggle(
                            options: recurrenceOptions,
                            selected: $recurrence
                        )

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
                        FortiFitButton("Schedule Workout", style: .primary, isEnabled: canSchedule) {
                            guard let template = selectedTemplate else { return }
                            onSchedule(
                                template,
                                scheduledDate,
                                showTimePicker ? scheduledTime : nil,
                                recurrenceRule
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
                        Text("Schedule Workout")
                            .font(FortiFitTypography.screenHeading)
                            .kerning(FortiFitTypography.screenHeadingKerning)
                            .foregroundStyle(FortiFitColors.primaryAccent)
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(FortiFitColors.mutedText)
                                .frame(width: FortiFitSpacing.minTouchTarget, height: FortiFitSpacing.minTouchTarget)
                        }
                    }

                    FortiFitDivider()
                }
            }
            }
            .background(FortiFitColors.background)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
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
                                Text("\(template.exerciseSets.count) exercises")
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
