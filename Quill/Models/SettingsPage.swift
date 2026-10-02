import Foundation

enum SettingsPage: String, CaseIterable, Identifiable {
    case general = "General", storage = "Library", expansion = "Expansion", privacy = "Privacy", statistics = "Statistics", updates = "Updates"
    var id: Self { self }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .storage: "folder"
        case .expansion: "text.cursor"
        case .privacy: "hand.raised"
        case .statistics: "chart.bar"
        case .updates: "arrow.triangle.2.circlepath"
        }
    }
}

