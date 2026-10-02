import Foundation

enum ExpansionDuration: String, CaseIterable, Identifiable, Sendable {
    case untilQuit, always, fifteenMinutes, oneHour
    var id: Self { self }
    var title: String {
        switch self {
        case .untilQuit: "Until Quill Quits"
        case .always: "Every Time Quill Opens"
        case .fifteenMinutes: "15 Minutes"
        case .oneHour: "1 Hour"
        }
    }
    var interval: TimeInterval? {
        switch self {
        case .fifteenMinutes: 15 * 60
        case .oneHour: 60 * 60
        case .untilQuit, .always: nil
        }
    }
    var explanation: String {
        switch self {
        case .untilQuit: "Closing the library keeps expansion running. Quitting Quill stops it."
        case .always: "After you enable expansion, Quill resumes it whenever it launches. Pause stops it until you enable it again."
        case .fifteenMinutes, .oneHour: "Expansion pauses automatically when the timer ends or Quill quits."
        }
    }
}
