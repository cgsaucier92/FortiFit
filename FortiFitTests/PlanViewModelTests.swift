import Testing
import Foundation
import SwiftData
@testable import FortiFit

// MARK: - PlanViewModel Tests

@Suite("PlanViewModel")
struct PlanViewModelTests {

    // =========================================================================
    // MARK: - Initial State
    // =========================================================================

    @Test("Default calendar mode is week")
    func initialState_defaultsToWeekMode() {
        let viewModel = PlanViewModel()
        #expect(viewModel.calendarMode == .week)
    }

    @Test("Selected date is today")
    func initialState_selectedDateIsToday() {
        let viewModel = PlanViewModel()
        let todayStart = Calendar.current.startOfDay(for: Date())
        let selectedStart = Calendar.current.startOfDay(for: viewModel.selectedDate)
        #expect(selectedStart == todayStart)
    }

    @Test("Week offset is zero")
    func initialState_dayOffsetIsZero() {
        let viewModel = PlanViewModel()
        #expect(viewModel.dayOffset == 0)
    }

    @Test("No sheets presented on init")
    func initialState_noSheetPresented() {
        let viewModel = PlanViewModel()
        #expect(viewModel.showScheduleSheet == false)
        #expect(viewModel.showCompletionSheet == false)
        #expect(viewModel.showDateResolutionPrompt == false)
    }

    // =========================================================================
    // MARK: - Day Selection
    // =========================================================================

    @Test("selectDay updates selectedDate")
    func selectDay_updatesSelectedDate() {
        let viewModel = PlanViewModel()
        let tomorrow = PlanTestFactory.tomorrow
        viewModel.selectDay(tomorrow)
        #expect(Calendar.current.startOfDay(for: viewModel.selectedDate) == tomorrow)
    }

    @Test("selectDay filters workouts for selected day")
    @MainActor
    func selectDay_filtersWorkoutsForSelectedDay() throws {
        let context = try makePlanTestContext()
        let viewModel = PlanViewModel()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.tomorrow, time: nil, recurrenceRule: nil, context: context)

        viewModel.loadWorkoutsForCurrentView(context: context)
        viewModel.selectDay(PlanTestFactory.today)
        viewModel.updateSelectedDayItems(context: context)

        #expect(viewModel.selectedDayItems.count == 1)
    }

    // =========================================================================
    // MARK: - Calendar Mode
    // =========================================================================

    @Test("Toggle calendar mode switches between week and month")
    func toggleCalendarMode_switchesBetweenWeekAndMonth() {
        let viewModel = PlanViewModel()
        #expect(viewModel.calendarMode == .week)

        viewModel.calendarMode = .month
        #expect(viewModel.calendarMode == .month)

        viewModel.calendarMode = .week
        #expect(viewModel.calendarMode == .week)
    }

    // =========================================================================
    // MARK: - Completion Initiation
    // =========================================================================

    @Test("Initiate completion for today shows completion sheet directly")
    @MainActor
    func initiateCompletion_todaySchedule_showsCompletionSheetDirectly() throws {
        let context = try makePlanTestContext()
        let viewModel = PlanViewModel()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        let sw = PlanService.fetchForDate(date: PlanTestFactory.today, context: context).first!

        viewModel.initiateCompletion(scheduledWorkout: sw)

        #expect(viewModel.showCompletionSheet == true)
        #expect(viewModel.showDateResolutionPrompt == false)
        #expect(viewModel.activeScheduledWorkout != nil)
    }

    @Test("Initiate completion for past schedule shows date resolution prompt")
    @MainActor
    func initiateCompletion_pastSchedule_showsDateResolutionPrompt() throws {
        let context = try makePlanTestContext()
        let viewModel = PlanViewModel()

        // Manually create a past-dated ScheduledWorkout
        let sw = ScheduledWorkout(
            scheduledDate: PlanTestFactory.yesterday,
            workoutType: "Strength Training",
            workoutName: "Push Day"
        )
        sw.scheduledWorkoutSnapshot = "[]".data(using: .utf8)
        context.insert(sw)
        try context.save()

        viewModel.initiateCompletion(scheduledWorkout: sw)

        #expect(viewModel.showDateResolutionPrompt == true)
        #expect(viewModel.showCompletionSheet == false)
    }

    @Test("Initiate completion for future schedule shows date resolution prompt")
    @MainActor
    func initiateCompletion_futureSchedule_showsDateResolutionPrompt() throws {
        let context = try makePlanTestContext()
        let viewModel = PlanViewModel()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.tomorrow, time: nil, recurrenceRule: nil, context: context)
        let sw = PlanService.fetchForDate(date: PlanTestFactory.tomorrow, context: context).first!

        viewModel.initiateCompletion(scheduledWorkout: sw)

        #expect(viewModel.showDateResolutionPrompt == true)
        #expect(viewModel.showCompletionSheet == false)
    }

    // =========================================================================
    // MARK: - Completion Execution
    // =========================================================================

    @Test("completeWorkout creates workout and updates state")
    @MainActor
    func completeWorkout_createsWorkoutAndUpdatesState() throws {
        let context = try makePlanTestContext()
        let viewModel = PlanViewModel()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)

        viewModel.loadWorkoutsForCurrentView(context: context)
        viewModel.selectDay(PlanTestFactory.today)
        viewModel.updateSelectedDayItems(context: context)

        guard case .scheduled(let sw) = viewModel.selectedDayItems.first! else {
            Issue.record("Expected .scheduled card")
            return
        }
        viewModel.initiateCompletion(scheduledWorkout: sw)

        viewModel.completionRPE = 7
        viewModel.completionDuration = "55"
        viewModel.completeWorkout(context: context)

        // Sheet should dismiss
        #expect(viewModel.showCompletionSheet == false)
        #expect(viewModel.activeScheduledWorkout == nil)

        // Workout should exist
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == 1)
    }

    // =========================================================================
    // MARK: - Skip / Restore
    // =========================================================================

    @Test("Skip workout updates status")
    @MainActor
    func skipWorkout_updatesStatus() throws {
        let context = try makePlanTestContext()
        let viewModel = PlanViewModel()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)

        viewModel.loadWorkoutsForCurrentView(context: context)
        viewModel.selectDay(PlanTestFactory.today)
        viewModel.updateSelectedDayItems(context: context)

        guard case .scheduled(let sw) = viewModel.selectedDayItems.first! else {
            Issue.record("Expected .scheduled card")
            return
        }
        viewModel.skipWorkout(sw, context: context)

        #expect(sw.status == "skipped")
    }

    @Test("Restore workout reverts status")
    @MainActor
    func restoreWorkout_revertsStatus() throws {
        let context = try makePlanTestContext()
        let viewModel = PlanViewModel()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        let sw = PlanService.fetchForDate(date: PlanTestFactory.today, context: context).first!
        PlanService.skipWorkout(scheduledWorkout: sw, context: context)

        viewModel.loadWorkoutsForCurrentView(context: context)
        viewModel.selectDay(PlanTestFactory.today)
        viewModel.updateSelectedDayItems(context: context)
        viewModel.restoreWorkout(sw, context: context)

        #expect(sw.status == "planned")
    }

    // =========================================================================
    // MARK: - Data Loading
    // =========================================================================

    @Test("loadWorkouts populates selectedDayItems")
    @MainActor
    func loadWorkouts_populatesSelectedDayWorkouts() throws {
        let context = try makePlanTestContext()
        let viewModel = PlanViewModel()
        let template = PlanTestFactory.makeTemplate(context: context)

        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)
        PlanService.scheduleWorkout(template: template, date: PlanTestFactory.today, time: nil, recurrenceRule: nil, context: context)

        viewModel.selectDay(PlanTestFactory.today)
        viewModel.loadWorkoutsForCurrentView(context: context)
        viewModel.updateSelectedDayItems(context: context)

        #expect(viewModel.selectedDayItems.count == 2)
    }

    @Test("loadWorkouts empty when nothing scheduled")
    func loadWorkouts_emptyWhenNothingScheduled() throws {
        let context = try makePlanTestContext()
        let viewModel = PlanViewModel()
        viewModel.loadWorkoutsForCurrentView(context: context)
        #expect(viewModel.selectedDayItems.isEmpty)
    }
}
