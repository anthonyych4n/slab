import Foundation

struct CustomLayout: LayoutTemplate, Codable, Identifiable {
    var id: String
    var name: String
    var icon: String
    var zones: [LayoutZone]

    init(id: String = UUID().uuidString, name: String, icon: String = "rectangle.dashed", zones: [LayoutZone]) {
        self.id = id; self.name = name; self.icon = icon; self.zones = zones
    }
}
