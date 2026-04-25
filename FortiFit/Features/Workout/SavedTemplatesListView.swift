import SwiftUI
import SwiftData

struct SavedTemplatesListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.dateCreated, order: .reverse) private var templates: [WorkoutTemplate]

    @State private var viewModel = WorkoutTemplateViewModel()
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var templateToDelete: WorkoutTemplate?
    @State private var showDeleteConfirmation = false
    @State private var templateToShare: WorkoutTemplate?
    @State private var templateToSchedule: WorkoutTemplate?
    @State private var showScheduleSheet = false
    @State private var showCreateTemplate = false
    @State private var headerHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            if templates.isEmpty {
                VStack {
                    Spacer()
                    Text("No saved templates. Create your first template to get started.")
                        .font(FortiFitTypography.body)
                        .foregroundStyle(FortiFitColors.mutedText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, FortiFitSpacing.screenHorizontal)
                    Spacer()
                }
                .padding(.top, headerHeight)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                        FortiFitScreenHeading("Saved Templates")

                        ForEach(templates) { template in
                            templateRow(template)
                        }
                    }
                    .padding(.horizontal, FortiFitSpacing.screenHorizontal)
                    .padding(.top, headerHeight)
                    .padding(.bottom, FortiFitSpacing.gapXLarge)
                }
                .scrollClipDisabled()
            }

            // Fixed header
            VStack(spacing: 0) {
                HStack {
                    FortiFitBackButton { dismiss() }
                    Spacer()
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        showCreateTemplate = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(FortiFitColors.primaryAccent)
                            .frame(width: FortiFitSpacing.minTouchTarget, height: FortiFitSpacing.minTouchTarget)
                            .background(
                                RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                                    .fill(.clear)
                                    .stroke(FortiFitColors.primaryAccent, lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, FortiFitSpacing.screenHorizontal)
                .padding(.top, FortiFitSpacing.screenTop)
                .padding(.bottom, FortiFitSpacing.elementSpacing)
                .background(FortiFitColors.background.opacity(0.90))

                LinearGradient(
                    colors: [FortiFitColors.background.opacity(0.90), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 30)
                .allowsHitTesting(false)
            }
            .overlay {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { headerHeight = geo.size.height }
                        .onChange(of: geo.size.height) { _, newValue in headerHeight = newValue }
                }
            }
        }
        .background(FortiFitColors.background)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationDestination(item: $selectedTemplate) { template in
            CreateTemplateView(editingTemplate: template)
        }
        .navigationDestination(isPresented: $showCreateTemplate) {
            CreateTemplateView(editingTemplate: nil)
        }
        .alert(
            "Delete \(templateToDelete?.name ?? "Template")?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) {
                templateToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let template = templateToDelete {
                    viewModel.deleteTemplate(template, context: modelContext)
                    templateToDelete = nil
                }
            }
        } message: {
            Text("This can't be undone.")
        }
        #if os(iOS)
        .overlay {
            if let template = templateToShare {
                TemplateQRModalView(template: template) {
                    templateToShare = nil
                }
            }
        }
        #endif
        .sheet(isPresented: $showScheduleSheet) {
            ScheduleWorkoutView(
                preSelectedDate: Date(),
                preSelectedTemplate: templateToSchedule,
                onSchedule: { template, date, time, recurrence in
                    PlanService.scheduleWorkout(
                        template: template,
                        date: date,
                        time: time,
                        recurrenceRule: recurrence,
                        context: modelContext
                    )
                    showScheduleSheet = false
                    templateToSchedule = nil
                }
            )
        }
    }

    // MARK: - Template Row

    private func templateRow(_ template: WorkoutTemplate) -> some View {
        Button {
            selectedTemplate = template
        } label: {
            FortiFitCard(borderColor: FortiFitColors.border) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(FortiFitColors.primaryText)

                        Text(template.workoutType)
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.mutedText)

                        Text("Created \(template.dateCreated.dayFormatted)")
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.mutedText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FortiFitColors.mutedText)
                        .padding(.top, 2)
                }
            }
        }
        .buttonStyle(PressableCardButtonStyle())
        .contextMenu {
            #if os(iOS)
            Button {
                templateToShare = template
            } label: {
                Label("Share Template", systemImage: "qrcode")
            }
            #endif

            Button {
                templateToSchedule = template
                showScheduleSheet = true
            } label: {
                Label("Schedule This Template", systemImage: "calendar.badge.plus")
            }

            Button(role: .destructive) {
                templateToDelete = template
                showDeleteConfirmation = true
            } label: {
                Label("Delete Template", systemImage: "trash")
            }
        }
    }
}

#Preview {
    SavedTemplatesListView()
        .modelContainer(for: [WorkoutTemplate.self, TemplateExerciseSet.self], inMemory: true)
}
