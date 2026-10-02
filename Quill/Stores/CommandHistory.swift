import Foundation
import Observation

@MainActor @Observable final class CommandHistory {
    private(set) var recent: [String]
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        recent = defaults.stringArray(forKey: "recentCommands") ?? []
    }
    func record(_ id: String) {
        recent.removeAll { $0 == id }
        recent.insert(id, at: 0)
        recent = Array(recent.prefix(8))
        defaults.set(recent, forKey: "recentCommands")
    }
    func clear() { recent = []; defaults.removeObject(forKey: "recentCommands") }
}
