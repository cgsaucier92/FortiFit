import Foundation
import SwiftData

@Model
final class TrendsChart {
    var id: UUID
    @Attribute(.unique) var chartType: String
    var sortOrder: Int

    init(chartType: String, sortOrder: Int) {
        self.id = UUID()
        self.chartType = chartType
        self.sortOrder = sortOrder
    }
}
