import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let workout: Workout
    @Bindable var viewModel: WorkoutViewModel
    @State private var isEditingNote = false
    @State private var noteText = ""
    @State private var showDeleteAlert = false
    @State private var showEditWorkout = false
    @State private var showSaveAsTemplatePrompt = false
    @State private var saveAsTemplateName = ""
    @State private var showTemplateSavedToast = false
    @State private var showShowOnPlanToast = false
    @State private var showUnlinkAlert = false
    @State private var showHealthSourceInfoSheet = false
    @State private var headerHeight: CGFloat = 0
    @State private var activeMetric: WorkoutMetric?

    private var settings: UserSettings { UserSettings.shared }

    var body: some View {
        ZStack {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
                    // Title
                    FortiFitLabel("Workout")
                    FortiFitScreenHeading(workout.name)
                    Text("\(workout.date.shortFormatted)\(workout.time != nil ? " · \(workout.time!.timeFormatted)" : "") · \(workout.workoutType)")
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(FortiFitColors.mutedText)

                    if workout.isHealthKitLinked {
                        let resolvedSource = resolvedSourceName
                        Button {
                            showHealthSourceInfoSheet = true
                        } label: {
                            FortiFitHealthSourceIndicator(
                                sourceName: resolvedSource,
                                showGlyph: workout.isAppleWatchSourced
                            )
                        }
                        .accessibilityIdentifier(AccessibilityID.workoutDetailHealthSourceIndicator)
                    }

                    FortiFitDivider()

                    // Summary stat-card grid + Exercises
                    summarySection

                    FortiFitDivider()

                    // Notes
                    notesSection
                }
                .padding(.horizontal, FortiFitSpacing.screenHorizontal)
                .padding(.top, headerHeight)
                .padding(.bottom, FortiFitSpacing.gapXLarge)
            }
            .scrollClipDisabled()

            // Fixed header
            FortiFitFixedHeader(headerHeight: $headerHeight) {
                VStack(alignment: .leading, spacing: FortiFitSpacing.gapLarge) {
                    HStack {
                        FortiFitBackButton { dismiss() }
                        Spacer()
                        FortiFitActionButtonGroup(
                            onShare: {
                                #if os(iOS)
                                viewModel.exportWorkout(workout)
                                #endif
                            },
                            onEdit: {
                                viewModel.populateForm(from: workout)
                                showEditWorkout = true
                            },
                            onDelete: {
                                showDeleteAlert = true
                            }
                        )
                        if workout.workoutType == "Strength Training" || workout.workoutType == "HIIT" || workout.hiddenFromPlan || workout.isHealthKitLinked {
                            Menu {
                                if workout.workoutType == "Strength Training" || workout.workoutType == "HIIT" {
                                    Button {
                                        saveAsTemplateName = workout.name
                                        showSaveAsTemplatePrompt = true
                                    } label: {
                                        Label("Save as Template", systemImage: "square.and.arrow.down")
                                    }
                                    .accessibilityIdentifier(AccessibilityID.saveAsTemplateMenuItem)
                                }
                                if workout.isHealthKitLinked {
                                    Button(role: .destructive) {
                                        showUnlinkAlert = true
                                    } label: {
                                        Label("Unlink from Apple Health", systemImage: "heart.slash")
                                    }
                                    .accessibilityIdentifier(AccessibilityID.workoutDetailHealthUnlinkButton)
                                }
                                if workout.hiddenFromPlan {
                                    Button {
                                        PlanService.setHiddenFromPlan(workout: workout, hidden: false, context: modelContext)
                                        withAnimation {
                                            showShowOnPlanToast = true
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            withAnimation {
                                                showShowOnPlanToast = false
                                            }
                                        }
                                    } label: {
                                        Label("Show on Plan", systemImage: "calendar.badge.plus")
                                    }
                                    .accessibilityIdentifier(AccessibilityID.workoutDetailShowOnPlanMenuItem)
                                }
                            } label: {
                                FortiFitEllipsisButton()
                            }
                            .accessibilityIdentifier(AccessibilityID.workoutDetailEllipsis)
                        }
                    }
                }
            }
        }
        .background(FortiFitColors.background)

            // Share error toast
            if viewModel.showShareError {
                VStack {
                    Text("Couldn't generate image. Try again.")
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, FortiFitSpacing.cardPadding)
                        .padding(.vertical, FortiFitSpacing.elementSpacing)
                        .background(
                            Capsule()
                                .fill(FortiFitColors.primaryAccent)
                        )
                        .padding(.top, FortiFitSpacing.screenTop)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
            }

            // "Showing on Plan." toast
            VStack {
                Text("Showing on Plan")
                    .font(FortiFitTypography.bodySmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, FortiFitSpacing.cardPadding)
                    .padding(.vertical, FortiFitSpacing.elementSpacing)
                    .background(
                        Capsule()
                            .fill(FortiFitColors.primaryAccent)
                    )
                    .padding(.top, FortiFitSpacing.screenTop)
                Spacer()
            }
            .opacity(showShowOnPlanToast ? 1 : 0)
            .offset(y: showShowOnPlanToast ? 0 : -60)
            .allowsHitTesting(showShowOnPlanToast)
            .animation(.easeInOut(duration: 0.2), value: showShowOnPlanToast)

            // "Template saved!" toast
            if showTemplateSavedToast {
                VStack {
                    Text("Template saved!")
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, FortiFitSpacing.cardPadding)
                        .padding(.vertical, FortiFitSpacing.elementSpacing)
                        .background(
                            Capsule()
                                .fill(FortiFitColors.primaryAccent)
                        )
                        .padding(.top, FortiFitSpacing.screenTop)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .swipeToDismiss()
        .onAppear {
            noteText = workout.note ?? ""
        }
        .alert(
            "Delete \(workout.name)?",
            isPresented: $showDeleteAlert
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteWorkout(workout, context: modelContext)
                dismiss()
            }
        } message: {
            Text("This can't be undone.")
        }
        .alert(
            AppConstants.HealthKit.ellipsisUnlinkConfirmTitle,
            isPresented: $showUnlinkAlert
        ) {
            Button("Cancel", role: .cancel) {}
            Button(AppConstants.HealthKit.ellipsisUnlinkConfirmDestructive, role: .destructive) {
                WorkoutService.unlink(workout, context: modelContext)
            }
        } message: {
            Text(AppConstants.HealthKit.ellipsisUnlinkConfirmMessage)
        }
        .alert("Name Template", isPresented: $showSaveAsTemplatePrompt) {
            TextField("Template name", text: $saveAsTemplateName)
            Button("Cancel", role: .cancel) {
                saveAsTemplateName = ""
            }
            Button("Save") {
                viewModel.saveWorkoutAsTemplate(
                    name: saveAsTemplateName,
                    workout: workout,
                    context: modelContext
                )
                saveAsTemplateName = ""
                withAnimation {
                    showTemplateSavedToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showTemplateSavedToast = false
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.saveTemplateConfirmButton)
        } message: {
            Text("Enter a name for this template.")
        }
        .navigationDestination(isPresented: $showEditWorkout) {
            LogWorkoutView(viewModel: viewModel) {
                dismiss()
            }
            .onDisappear {
                viewModel.loadWorkouts(context: modelContext)
            }
        }
        #if os(iOS)
        .sheet(isPresented: Binding(
            get: { viewModel.shareImage != nil },
            set: { if !$0 { viewModel.shareImage = nil } }
        )) {
            if let image = viewModel.shareImage {
                ShareSheet(activityItems: [image])
            }
        }
        #endif
        .sheet(isPresented: $showHealthSourceInfoSheet) {
            FortiFitHealthSourceInfoSheet(
                workout: workout,
                sourceName: resolvedSourceName,
                lastSyncDate: workout.healthKitUUID != nil ? UserSettings.shared.healthKitLastSyncDate : nil,
                onUnlink: {
                    WorkoutService.unlink(workout, context: modelContext)
                }
            )
        }
        .sheet(item: $activeMetric) { metric in
            FortiFitMetricDetailSheet(workout: workout, metric: metric)
        }
        .onChange(of: viewModel.showShareError) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        viewModel.showShareError = false
                    }
                }
            }
        }
    }

    // MARK: - Unified Summary (stat-card grid + exercises)

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
            let cards = summaryCards
            if !cards.isEmpty {
                FortiFitWidgetHeader(title: "Summary")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(cards, id: \.identifier) { card in
                        FortiFitStatCard(
                            symbolName: card.symbol,
                            label: card.label,
                            value: card.value,
                            unit: card.unit,
                            iconColor: card.iconColor,
                            valueColor: card.valueColor,
                            accessibilityIdentifier: card.identifier,
                            onTap: { activeMetric = card.metric }
                        )
                    }
                }
            }

            if (workout.workoutType == "Strength Training" || workout.workoutType == "HIIT") && !workout.exerciseSets.isEmpty {
                if !cards.isEmpty {
                    FortiFitDivider()
                        .padding(.top, FortiFitSpacing.gapSmall)
                }

                FortiFitWidgetHeader(title: "Exercises")
                    .padding(.top, FortiFitSpacing.gapSmall)

                let grouped = Dictionary(grouping: workout.exerciseSets.sorted { $0.sortOrder < $1.sortOrder }, by: { $0.exerciseName })
                let sortedNames = grouped.keys.sorted { name1, name2 in
                    let order1 = grouped[name1]?.first?.sortOrder ?? 0
                    let order2 = grouped[name2]?.first?.sortOrder ?? 0
                    return order1 < order2
                }

                ForEach(sortedNames, id: \.self) { exerciseName in
                    if let sets = grouped[exerciseName] {
                        FortiFitCard(borderColor: FortiFitColors.border) {
                            VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
                                Text(exerciseName)
                                    .font(FortiFitTypography.dataValue)
                                    .foregroundStyle(FortiFitColors.primaryText)

                                ForEach(sets) { exerciseSet in
                                    HStack {
                                        Text("\(exerciseSet.sets) sets × \(exerciseSet.reps) reps")
                                            .font(FortiFitTypography.bodySmall)
                                            .foregroundStyle(FortiFitColors.secondaryText)
                                        Spacer()
                                        Text(UnitConversion.displayWeight(exerciseSet.weightKg, useLbs: settings.useLbs))
                                            .font(FortiFitTypography.dataValue)
                                            .foregroundStyle(FortiFitColors.primaryAccent)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Summary Card Data

    private struct StatCardData {
        let metric: WorkoutMetric
        let symbol: String
        let label: String
        let value: String
        let unit: String?
        let identifier: String
        let iconColor: Color
        let valueColor: Color
    }

    private var summaryCards: [StatCardData] {
        var cards: [StatCardData] = []

        if let rpe = workout.rpe {
            let bandColor = AppConstants.effortColor(for: rpe)
            cards.append(StatCardData(
                metric: .effort,
                symbol: WorkoutMetric.effort.sfSymbol,
                label: "Effort",
                value: AppConstants.effortLabel(for: rpe),
                unit: nil,
                identifier: AccessibilityID.workoutDetail_summaryCard_effort,
                iconColor: bandColor,
                valueColor: bandColor
            ))
        }

        if let duration = workout.durationMinutes {
            let color = AppConstants.statCardColor(for: .duration)
            cards.append(StatCardData(
                metric: .duration,
                symbol: WorkoutMetric.duration.sfSymbol,
                label: "Duration",
                value: "\(duration)",
                unit: "min",
                identifier: AccessibilityID.workoutDetail_summaryCard_duration,
                iconColor: color,
                valueColor: color,

            ))
        }

        if let avg = workout.avgHeartRate {
            let color = AppConstants.statCardColor(for: .avgHR)
            cards.append(StatCardData(
                metric: .avgHR,
                symbol: WorkoutMetric.avgHR.sfSymbol,
                label: "Avg HR",
                value: "\(avg)",
                unit: "bpm",
                identifier: AccessibilityID.workoutDetail_summaryCard_avgHR,
                iconColor: color,
                valueColor: color,

            ))
        }

        if let max = workout.maxHeartRate {
            let color = AppConstants.statCardColor(for: .maxHR)
            cards.append(StatCardData(
                metric: .maxHR,
                symbol: WorkoutMetric.maxHR.sfSymbol,
                label: "Max HR",
                value: "\(max)",
                unit: "bpm",
                identifier: AccessibilityID.workoutDetail_summaryCard_maxHR,
                iconColor: color,
                valueColor: color,

            ))
        }

        if let active = workout.activeEnergyKcal {
            let color = AppConstants.statCardColor(for: .activeKcal)
            cards.append(StatCardData(
                metric: .activeKcal,
                symbol: WorkoutMetric.activeKcal.sfSymbol,
                label: "Active kcal",
                value: "\(Int(active))",
                unit: "kcal",
                identifier: AccessibilityID.workoutDetail_summaryCard_activeKcal,
                iconColor: color,
                valueColor: color,

            ))
        }

        if let total = workout.totalEnergyBurnedKcal {
            let color = AppConstants.statCardColor(for: .totalKcal)
            cards.append(StatCardData(
                metric: .totalKcal,
                symbol: WorkoutMetric.totalKcal.sfSymbol,
                label: "Total kcal",
                value: "\(Int(total))",
                unit: "kcal",
                identifier: AccessibilityID.workoutDetail_summaryCard_totalKcal,
                iconColor: color,
                valueColor: color,

            ))
        }

        // Singles (no natural pair) — placed after pairs to avoid gaps
        if workout.workoutType == "Cardio", let distance = workout.distanceKm {
            let displayVal: String
            let displayUnit: String
            if settings.useMiles {
                displayVal = String(format: "%.1f", UnitConversion.kmToMiles(distance))
                displayUnit = "mi"
            } else {
                displayVal = String(format: "%.1f", distance)
                displayUnit = "km"
            }
            let color = AppConstants.statCardColor(for: .distance)
            cards.append(StatCardData(
                metric: .distance,
                symbol: WorkoutMetric.distance.sfSymbol,
                label: "Distance",
                value: displayVal,
                unit: displayUnit,
                identifier: AccessibilityID.workoutDetail_summaryCard_distance,
                iconColor: color,
                valueColor: color
            ))
        }

        if let elevation = workout.elevationAscendedMeters {
            let displayVal: String
            let displayUnit: String
            if settings.useMiles {
                displayVal = "\(Int(elevation * UnitConversion.metersToFeetFactor))"
                displayUnit = "ft"
            } else {
                displayVal = "\(Int(elevation))"
                displayUnit = "m"
            }
            let color = AppConstants.statCardColor(for: .elevation)
            cards.append(StatCardData(
                metric: .elevation,
                symbol: WorkoutMetric.elevation.sfSymbol,
                label: "Elevation",
                value: displayVal,
                unit: displayUnit,
                identifier: AccessibilityID.workoutDetail_summaryCard_elevation,
                iconColor: color,
                valueColor: color,

            ))
        }

        if let exerciseMin = workout.exerciseMinutes {
            let color = AppConstants.statCardColor(for: .exerciseMinutes)
            cards.append(StatCardData(
                metric: .exerciseMinutes,
                symbol: WorkoutMetric.exerciseMinutes.sfSymbol,
                label: "Exercise min",
                value: "\(exerciseMin)",
                unit: "min",
                identifier: AccessibilityID.workoutDetail_summaryCard_exerciseMinutes,
                iconColor: color,
                valueColor: color,

            ))
        }

        return cards
    }

    // MARK: - Source Name Resolution

    private var resolvedSourceName: String {
        guard let bundleID = workout.healthKitSourceBundleID else { return "another app" }
        if bundleID.hasPrefix("com.apple.health") { return "Apple Workout" }
        let knownSources: [String: String] = [
            "com.strava": "Strava",
            "com.fiit.fiit": "Fiit",
            "com.onepeloton.peloton": "Peloton"
        ]
        for (prefix, name) in knownSources {
            if bundleID.hasPrefix(prefix) { return name }
        }
        return "another app"
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: FortiFitSpacing.gapSmall) {
            HStack {
                FortiFitWidgetHeader(title: "Notes")
                Spacer()
                Button {
                    isEditingNote.toggle()
                } label: {
                    Image(systemName: isEditingNote ? "checkmark.circle.fill" : "pencil")
                        .font(.system(size: 16))
                        .foregroundStyle(FortiFitColors.primaryAccent)
                        .frame(width: FortiFitSpacing.minTouchTarget, height: FortiFitSpacing.minTouchTarget)
                }
            }

            if isEditingNote {
                TextEditor(text: $noteText)
                    .font(FortiFitTypography.body)
                    .foregroundStyle(FortiFitColors.primaryText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100)
                    .padding(FortiFitSpacing.cardPadding)
                    .background(FortiFitColors.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadiusSmall))
                    .tint(FortiFitColors.primaryAccent)

                FortiFitButton("Save Notes", style: .primary) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.updateNote(workout, note: noteText.isEmpty ? nil : noteText, context: modelContext)
                    isEditingNote = false
                }
            } else {
                FortiFitCard(borderColor: FortiFitColors.border) {
                    Text(noteText.isEmpty ? "No notes for this session." : noteText)
                        .font(noteText.isEmpty ? FortiFitTypography.note : FortiFitTypography.body)
                        .foregroundStyle(noteText.isEmpty ? FortiFitColors.mutedText : FortiFitColors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

#Preview {
    let workout = Workout(name: "Push Day I", workoutType: "Strength Training", rpe: 8)
    NavigationStack {
        WorkoutDetailView(workout: workout, viewModel: WorkoutViewModel())
    }
}
