import Foundation
import SwiftData

@Model
final class HomeWidget {
    var id: UUID
    var widgetType: String
    var sortOrder: Int

    init(widgetType: String, sortOrder: Int) {
        self.id = UUID()
        self.widgetType = widgetType
        self.sortOrder = sortOrder
    }
}
