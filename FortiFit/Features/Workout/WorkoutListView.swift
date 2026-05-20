import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WorkoutViewModel()
    @State private var showRPEFilterSheet = false
    @State private var rpeFilterWorkoutType: String?
    @State private var rpeMin: Int = 1
    @State private var rpeMax: Int = 10
    @State private var activeSwipeWorkoutID: UUID?
    @State private var headerHeight: CGFloat = 0
    var selectedTab: Int = 1

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                if viewModel.workouts.isEmpty {
                    emptyState
                } else {
                    workoutTypeList
                }

                FortiFitFixedHeader(headerHeight: $headerHeight) {
                    HStack {
                        FortiFitEllipsisButton(menuItems: [
                            (label: "View Workout Templates", systemImage: "doc.on.doc", identifier: AccessibilityID.viewSavedTemplatesMenuItem, action: {
                                viewModel.showSavedTemplates = true
                            })
                        ])
                        .accessibilityIdentifier(AccessibilityID.workoutsEllipsisMenu)
                        Spacer()
                        Menu {
                            Button {
                                viewModel.resetForm()
                                viewModel.showLogWorkout = true
                            } label: {
                                Label("Log Workout", systemImage: "pencil.circle")
                            }
                            Button {
                                viewModel.showCreateTemplate = true
                            } label: {
                                Label("Create Workout Template", systemImage: "square.and.pencil")
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16))
                                .foregroundStyle(FortiFitColors.primaryAccent)
                                .frame(height: FortiFitSpacing.minTouchTarget)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius)
                                        .fill(.clear)
                                        .stroke(FortiFitColors.primaryAccent, lineWidth: 1)
                                )
                        }
                        .simultaneousGesture(LongPressGesture(minimumDuration: 0.01).onEnded { _ in
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                        })
                    }
                }
            }
            .background(FortiFitColors.background)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .onAppear { viewModel.loadWorkouts(context: modelContext) }
            .onDisappear { viewModel.exitReorderMode() }
            .onChange(of: selectedTab, initial: false) { oldValue, _ in
                guard oldValue == 1 else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        viewModel.showLogWorkout = false
                        viewModel.selectedWorkout = nil
                        viewModel.showCreateTemplate = false
                        viewModel.showSavedTemplates = false
                        viewModel.showDeleteConfirmation = false
                        viewModel.showDeleteTypeConfirmation = false
                        viewModel.showCustomDateRangePicker = false
                        viewModel.workoutToDelete = nil
                        viewModel.workoutTypeToDelete = nil
                        showRPEFilterSheet = false
                        activeSwipeWorkoutID = nil
                    }
                    if viewModel.isReorderMode {
                        viewModel.exitReorderMode()
                    }
                }
            }
            .navigationDestination(isPresented: $viewModel.showLogWorkout) {
                LogWorkoutView(viewModel: viewModel)
                    .onDisappear { viewModel.loadWorkouts(context: modelContext) }
            }
            .navigationDestination(item: $viewModel.selectedWorkout) { workout in
                WorkoutDetailView(workout: workout, viewModel: viewModel)
                    .onDisappear { viewModel.loadWorkouts(context: modelContext) }
            }
            .navigationDestination(isPresented: $viewModel.showCreateTemplate) {
                CreateTemplateView(editingTemplate: nil)
            }
            .navigationDestination(isPresented: $viewModel.showSavedTemplates) {
                SavedTemplatesListView()
            }
            .alert(
                "Delete \(viewModel.workoutToDelete?.name ?? "Workout")?",
                isPresented: $viewModel.showDeleteConfirmation
            ) {
                Button("Cancel", role: .cancel) {
                    viewModel.workoutToDelete = nil
                    activeSwipeWorkoutID = nil
                }
                Button("Delete", role: .destructive) {
                    if let workout = viewModel.workoutToDelete {
                        viewModel.deleteWorkout(workout, context: modelContext)
                        viewModel.workoutToDelete = nil
                        activeSwipeWorkoutID = nil
                    }
                }
            } message: {
                Text("This can't be undone.")
            }
            .alert(
                "Delete all \(viewModel.workoutTypeToDelete ?? "") workouts?",
                isPresented: $viewModel.showDeleteTypeConfirmation
            ) {
                Button("Cancel", role: .cancel) {
                    viewModel.workoutTypeToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let workoutType = viewModel.workoutTypeToDelete {
                        viewModel.deleteWorkoutType(workoutType, context: modelContext)
                        viewModel.workoutTypeToDelete = nil
                    }
                }
            } message: {
                if let workoutType = viewModel.workoutTypeToDelete {
                    let count = viewModel.workoutsByType[workoutType]?.count ?? 0
                    Text("This will permanently delete all \(count) \(workoutType) workouts. This can't be undone.")
                }
            }
            .sheet(isPresented: $viewModel.showCustomDateRangePicker) {
                customDateRangeSheet
            }
            .sheet(isPresented: $showRPEFilterSheet) {
                rpeRangeSheet
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()
            VStack(spacing: FortiFitSpacing.gapMedium) {
                Text("Log your first workout to see it here.")
                    .font(FortiFitTypography.body)
                    .foregroundStyle(FortiFitColors.mutedText)
                    .frame(maxWidth: .infinity)
                FortiFitButton("Log Workout", style: .outline) {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    viewModel.resetForm()
                    viewModel.showLogWorkout = true
                }
            }
            .padding(.horizontal, FortiFitSpacing.screenHorizontal)
            Spacer()
        }
    }

    // MARK: - Workout Type List

    @ViewBuilder
    private var workoutTypeList: some View {
        if viewModel.isReorderMode {
            reorderModeList
        } else {
            normalModeList
        }
    }

    /// Normal mode: ScrollView with expandable cards, context menus, etc.
    private var normalModeList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.typeOrders) { typeOrder in
                    workoutTypeSection(typeOrder: typeOrder)
                }
            }
            .padding(.horizontal, FortiFitSpacing.screenHorizontal)
            .padding(.top, headerHeight)
        }
        .scrollClipDisabled()
    }

    /// Reorder mode: ScrollView with onDrag/onDrop DropDelegate for drag-to-reorder.
    private var reorderModeList: some View {
        ScrollView {
            VStack(spacing: FortiFitSpacing.elementSpacing) {
                ForEach(viewModel.typeOrders) { typeOrder in
                    let wType = typeOrder.workoutType
                    let count = viewModel.workoutsByType[wType]?.count ?? 0

                    FortiFitWorkoutTypeCard(
                        typeName: wType,
                        workoutCount: count,
                        isExpanded: false,
                        isReorderMode: true,
                        onTap: { }
                    )
                    .reorderableCard(
                        payload: wType,
                        in: viewModel.typeOrders,
                        identifiedBy: \.workoutType
                    ) { fromIndex, toIndex in
                        var types = viewModel.typeOrders.map(\.workoutType)
                        types.move(fromOffsets: IndexSet(integer: fromIndex),
                                   toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
                        viewModel.reorderTypes(orderedTypes: types, context: modelContext)
                    }
                }

                // Bottom area extends the tappable region beyond the last card
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 300)
            }
            .padding(.horizontal, FortiFitSpacing.screenHorizontal)
            .padding(.top, headerHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.exitReorderMode()
                }
            }
        }
        .scrollClipDisabled()
    }

    // MARK: - Workout Type Section (Normal Mode)

    @ViewBuilder
    private func workoutTypeSection(typeOrder: WorkoutTypeOrder) -> some View {
        let wType = typeOrder.workoutType
        let allTypeWorkouts = viewModel.workoutsByType[wType] ?? []
        let sortOption = viewModel.sortOption(forType: wType)
        let filterState = viewModel.filterState(forType: wType)
        let displayedWorkouts = viewModel.displayedWorkouts(forType: wType)
        let totalFiltered = viewModel.totalFilteredCount(forType: wType)

        VStack(spacing: 0) {
            // Card header with context menu
            FortiFitWorkoutTypeCard(
                typeName: wType,
                workoutCount: allTypeWorkouts.count,
                isExpanded: typeOrder.isExpanded,
                isNonDefaultSort: sortOption != .newestFirst,
                activeFilterCount: filterState.activeFilterCount,
                isReorderMode: false,
                onTap: {
                    viewModel.toggleExpanded(for: wType, context: modelContext)
                }
            )
            .accessibilityIdentifier(AccessibilityID.workoutTypeCard(wType))
            .contextMenu {
                sortMenu(forType: wType, currentSort: sortOption)
                filterMenu(forType: wType, currentFilter: filterState)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.enterReorderMode()
                    }
                } label: {
                    Label("Reorder Workout Types", systemImage: "arrow.up.arrow.down")
                }

                Button(role: .destructive) {
                    viewModel.workoutTypeToDelete = wType
                    viewModel.showDeleteTypeConfirmation = true
                } label: {
                    Label("Delete Workout Type", systemImage: "trash")
                }

                if viewModel.hasNonDefaultSortOrFilters(forType: wType) {
                    Button(role: .destructive) {
                        viewModel.clearSortAndFilters(forType: wType, context: modelContext)
                    } label: {
                        Label("Reset View", systemImage: "arrow.counterclockwise")
                    }
                }
            }

            // Expanded content
            if typeOrder.isExpanded {
                expandedContent(
                    forType: wType,
                    displayedWorkouts: displayedWorkouts,
                    totalFiltered: totalFiltered,
                    filterState: filterState
                )
            }
        }
        .padding(.bottom, typeOrder.isExpanded ? FortiFitSpacing.elementSpacing : FortiFitSpacing.gapMedium)
    }

    // MARK: - Sort Context Menu

    @ViewBuilder
    private func sortMenu(forType workoutType: String, currentSort: WorkoutSortOption) -> some View {
        Menu {
            ForEach(WorkoutSortOption.allCases, id: \.self) { option in
                Button {
                    viewModel.setSortOption(option, forType: workoutType, context: modelContext)
                } label: {
                    HStack {
                        Text(option.label)
                        if option == currentSort {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Sort by...", systemImage: "list.number")
        }
    }

    // MARK: - Filter Context Menu

    @ViewBuilder
    private func filterMenu(forType workoutType: String, currentFilter: WorkoutFilterState) -> some View {
        Menu {
            // Date range sub-menu
            Menu("Date range") {
                ForEach(WorkoutFilterState.datePresets, id: \.self) { preset in
                    Button {
                        var state = currentFilter
                        state.dateRangePreset = preset
                        state.customDateStart = nil
                        state.customDateEnd = nil
                        viewModel.updateFilterState(state, forType: workoutType, context: modelContext)
                    } label: {
                        HStack {
                            Text(WorkoutFilterState.datePresetLabel(preset))
                            if currentFilter.dateRangePreset == preset && currentFilter.customDateStart == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Button {
                    viewModel.customDateRangeWorkoutType = workoutType
                    viewModel.customDateStart = currentFilter.customDateStart ?? Calendar.current.date(byAdding: .month, value: -1, to: Date())!
                    viewModel.customDateEnd = currentFilter.customDateEnd ?? Date()
                    viewModel.showCustomDateRangePicker = true
                } label: {
                    HStack {
                        Text("Custom range")
                        if currentFilter.customDateStart != nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            // RPE range
            Button {
                rpeFilterWorkoutType = workoutType
                rpeMin = currentFilter.rpeMin ?? 1
                rpeMax = currentFilter.rpeMax ?? 10
                showRPEFilterSheet = true
            } label: {
                HStack {
                    Text("Effort range")
                    if currentFilter.rpeMin != nil || currentFilter.rpeMax != nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            // Duration range (hidden for Yoga/Pilates)
            if viewModel.showDurationFilter(forType: workoutType) {
                Menu("Duration range") {
                    ForEach(WorkoutFilterState.allDurationBuckets, id: \.self) { bucket in
                        let isActive = currentFilter.durationBuckets?.contains(bucket) ?? false
                        Button {
                            var state = currentFilter
                            var buckets = state.durationBuckets ?? []
                            if isActive {
                                buckets.removeAll { $0 == bucket }
                            } else {
                                buckets.append(bucket)
                            }
                            state.durationBuckets = buckets.isEmpty ? nil : buckets
                            viewModel.updateFilterState(state, forType: workoutType, context: modelContext)
                        } label: {
                            HStack {
                                Text(WorkoutFilterState.durationBucketLabels[bucket] ?? bucket)
                                if isActive {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            Label("Filter by...", systemImage: "line.3.horizontal.decrease")
        }
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private func expandedContent(
        forType workoutType: String,
        displayedWorkouts: [Workout],
        totalFiltered: Int,
        filterState: WorkoutFilterState
    ) -> some View {
        // Search bar (only for types with >20 workouts)
        if viewModel.shouldShowSearchBar(forType: workoutType) {
            searchBar(forType: workoutType)
                .background(FortiFitColors.cardSurface)
                .overlay(alignment: .top) {
                    Rectangle().fill(FortiFitColors.border).frame(height: 1)
                }
                .overlay(
                    Rectangle().fill(FortiFitColors.border).frame(width: 1),
                    alignment: .leading
                )
                .overlay(
                    Rectangle().fill(FortiFitColors.border).frame(width: 1),
                    alignment: .trailing
                )
        }

        // Filter empty state
        if viewModel.isFilterResultEmpty(forType: workoutType) {
            filterEmptyState(forType: workoutType)
        }
        // Search empty state
        else if viewModel.isSearchEmpty(forType: workoutType) {
            searchEmptyRow
        }
        // Workout rows
        else {
            let hasShowMore = viewModel.showMoreVisible(forType: workoutType)

            ForEach(Array(displayedWorkouts.enumerated()), id: \.element.id) { index, workout in
                let isLast = index == displayedWorkouts.count - 1 && !hasShowMore

                FortiFitSwipeToDelete(
                    itemID: workout.id,
                    activeSwipeID: $activeSwipeWorkoutID,
                    onDelete: {
                        viewModel.workoutToDelete = workout
                        viewModel.showDeleteConfirmation = true
                    }
                ) {
                    workoutPreviewRow(workout)
                        .background(FortiFitColors.cardSurface)
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: isLast ? FortiFitSpacing.cornerRadius : 0,
                        bottomTrailingRadius: isLast ? FortiFitSpacing.cornerRadius : 0,
                        topTrailingRadius: 0
                    )
                )
                .overlay(alignment: .top) {
                    Rectangle().fill(FortiFitColors.border).frame(height: 1)
                }
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: isLast ? FortiFitSpacing.cornerRadius : 0,
                        bottomTrailingRadius: isLast ? FortiFitSpacing.cornerRadius : 0,
                        topTrailingRadius: 0
                    )
                    .stroke(FortiFitColors.border, lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    if activeSwipeWorkoutID != nil {
                        activeSwipeWorkoutID = nil
                    } else {
                        viewModel.selectedWorkout = workout
                    }
                }
            }

            // Show More button
            if hasShowMore {
                showMoreButton(forType: workoutType)
            }
        }
    }

    // MARK: - Search Bar

    private func searchBar(forType workoutType: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FortiFitColors.mutedText)

            let binding = Binding<String>(
                get: { viewModel.searchQuery(forType: workoutType) },
                set: { viewModel.setSearchQuery($0, forType: workoutType) }
            )

            TextField("Search workouts", text: binding)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FortiFitColors.primaryText)
                .autocorrectionDisabled()

            if !viewModel.searchQuery(forType: workoutType).isEmpty {
                Button {
                    viewModel.clearSearch(forType: workoutType)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(FortiFitColors.mutedText)
                }
            }
        }
        .padding(.horizontal, FortiFitSpacing.cardPadding)
        .padding(.vertical, 10)
        .background(FortiFitColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: FortiFitSpacing.cornerRadius))
        .padding(.horizontal, FortiFitSpacing.cardPadding)
        .padding(.vertical, 8)
    }

    // MARK: - Show More Button

    private func showMoreButton(forType workoutType: String) -> some View {
        Button {
            viewModel.loadMore(forType: workoutType)
        } label: {
            Text(viewModel.showMoreText(forType: workoutType))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FortiFitColors.mutedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FortiFitSpacing.gapSmall)
        }
        .background(FortiFitColors.cardSurface)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: FortiFitSpacing.cornerRadius,
                bottomTrailingRadius: FortiFitSpacing.cornerRadius,
                topTrailingRadius: 0
            )
        )
        .overlay(alignment: .top) {
            Rectangle().fill(FortiFitColors.border).frame(height: 1)
        }
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: FortiFitSpacing.cornerRadius,
                bottomTrailingRadius: FortiFitSpacing.cornerRadius,
                topTrailingRadius: 0
            )
            .stroke(FortiFitColors.border, lineWidth: 1)
        )
    }

    // MARK: - Filter Empty State

    private func filterEmptyState(forType workoutType: String) -> some View {
        VStack(spacing: 8) {
            Text("No workouts match your filters.")
                .font(FortiFitTypography.note)
                .foregroundStyle(FortiFitColors.mutedText)

            Button("Clear filters") {
                viewModel.clearSortAndFilters(forType: workoutType, context: modelContext)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(FortiFitColors.primaryAccent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FortiFitSpacing.gapMedium)
        .background(FortiFitColors.cardSurface)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: FortiFitSpacing.cornerRadius,
                bottomTrailingRadius: FortiFitSpacing.cornerRadius,
                topTrailingRadius: 0
            )
        )
        .overlay(alignment: .top) {
            Rectangle().fill(FortiFitColors.border).frame(height: 1)
        }
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: FortiFitSpacing.cornerRadius,
                bottomTrailingRadius: FortiFitSpacing.cornerRadius,
                topTrailingRadius: 0
            )
            .stroke(FortiFitColors.border, lineWidth: 1)
        )
    }

    // MARK: - Search Empty State

    private var searchEmptyRow: some View {
        Text("No workouts found.")
            .font(FortiFitTypography.note)
            .foregroundStyle(FortiFitColors.mutedText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, FortiFitSpacing.gapMedium)
            .background(FortiFitColors.cardSurface)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: FortiFitSpacing.cornerRadius,
                    bottomTrailingRadius: FortiFitSpacing.cornerRadius,
                    topTrailingRadius: 0
                )
            )
            .overlay(alignment: .top) {
                Rectangle().fill(FortiFitColors.border).frame(height: 1)
            }
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: FortiFitSpacing.cornerRadius,
                    bottomTrailingRadius: FortiFitSpacing.cornerRadius,
                    topTrailingRadius: 0
                )
                .stroke(FortiFitColors.border, lineWidth: 1)
            )
    }

    // MARK: - Workout Preview Row

    private func workoutPreviewRow(_ workout: Workout) -> some View {
        HStack(alignment: .top, spacing: FortiFitSpacing.gapSmall) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(FortiFitColors.primaryText)

                Text(workout.date.dayFormatted)
                    .font(FortiFitTypography.bodySmall)
                    .foregroundStyle(FortiFitColors.mutedText)

                durationDistanceSummary(for: workout)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FortiFitColors.mutedText)
                .padding(.top, 2)
        }
        .padding(.horizontal, FortiFitSpacing.cardPadding)
        .padding(.vertical, FortiFitSpacing.gapSmall)
    }

    // MARK: - Duration / Distance Summary

    @ViewBuilder
    private func durationDistanceSummary(for workout: Workout) -> some View {
        let text = durationDistanceText(for: workout)
        if !text.isEmpty || workout.isAppleWatchSourced {
            HStack(spacing: 4) {
                if !text.isEmpty {
                    Text(text)
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(FortiFitColors.mutedText)
                }
                if workout.isAppleWatchSourced {
                    if !text.isEmpty {
                        Text("·")
                            .font(FortiFitTypography.bodySmall)
                            .foregroundStyle(FortiFitColors.mutedText)
                    }
                    Text("Apple Workout")
                        .font(FortiFitTypography.bodySmall)
                        .foregroundStyle(FortiFitColors.mutedText)
                }
            }
        }
    }

    private func durationDistanceText(for workout: Workout) -> String {
        let settings = UserSettings.shared
        let parts: [String] = [
            workout.durationMinutes.map { "\($0) min" },
            workout.distanceKm.map { km in
                if settings.useMiles {
                    return String(format: "%.1f mi", UnitConversion.kmToMiles(km))
                } else {
                    return String(format: "%.1f km", km)
                }
            }
        ].compactMap { $0 }
        return parts.joined(separator: " · ")
    }

    // MARK: - Custom Date Range Sheet

    private var customDateRangeSheet: some View {
        NavigationStack {
            Form {
                DatePicker("Start Date", selection: $viewModel.customDateStart, in: ...Date(), displayedComponents: .date)
                DatePicker("End Date", selection: $viewModel.customDateEnd, in: ...Date(), displayedComponents: .date)
            }
            .navigationTitle("Custom Date Range")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showCustomDateRangePicker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        if let wType = viewModel.customDateRangeWorkoutType {
                            var state = viewModel.filterState(forType: wType)
                            state.dateRangePreset = nil
                            state.customDateStart = viewModel.customDateStart
                            state.customDateEnd = viewModel.customDateEnd
                            viewModel.updateFilterState(state, forType: wType, context: modelContext)
                        }
                        viewModel.showCustomDateRangePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - RPE Range Sheet

    private var rpeRangeSheet: some View {
        NavigationStack {
            Form {
                Stepper("Min Effort: \(rpeMin)", value: $rpeMin, in: 1...rpeMax)
                Stepper("Max Effort: \(rpeMax)", value: $rpeMax, in: rpeMin...10)
            }
            .navigationTitle("Effort Range")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showRPEFilterSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        if let wType = rpeFilterWorkoutType {
                            var state = viewModel.filterState(forType: wType)
                            state.rpeMin = rpeMin
                            state.rpeMax = rpeMax
                            viewModel.updateFilterState(state, forType: wType, context: modelContext)
                        }
                        showRPEFilterSheet = false
                    }
                }
                #if os(iOS)
                ToolbarItem(placement: .bottomBar) {
                    Button("Clear Effort Filter") {
                        if let wType = rpeFilterWorkoutType {
                            var state = viewModel.filterState(forType: wType)
                            state.rpeMin = nil
                            state.rpeMax = nil
                            viewModel.updateFilterState(state, forType: wType, context: modelContext)
                        }
                        showRPEFilterSheet = false
                    }
                    .foregroundStyle(FortiFitColors.alert)
                }
                #endif
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    WorkoutListView()
        .modelContainer(for: [Workout.self, ExerciseSet.self, Goal.self, WorkoutTypeOrder.self], inMemory: true)
}
