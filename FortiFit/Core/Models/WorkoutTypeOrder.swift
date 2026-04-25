import Foundation
import SwiftData

@Model
final class WorkoutTypeOrder {
    var id: UUID
    var workoutType: String
    var sortOrder: Int
    var isExpanded: Bool
    var activeSortOption: String
    var activeFiltersJSON: String?

    init(
        id: UUID = UUID(),
        workoutType: String,
        sortOrder: Int,
        isExpanded: Bool = false,
        activeSortOption: String = "newestFirst",
        activeFiltersJSON: String? = nil
    ) {
        self.id = id
        self.workoutType = workoutType
        self.sortOrder = sortOrder
        self.isExpanded = isExpanded
        self.activeSortOption = activeSortOption
        self.activeFiltersJSON = activeFiltersJSON
    }
}
