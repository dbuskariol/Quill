import AppKit
import Observation

@MainActor @Observable final class QuickActionStore {
    private(set) var lastCopiedText: String?
    var message: String?
    private let statistics: LocalStatistics
    init(statistics: LocalStatistics) { self.statistics = statistics }
    func copy(_ text: String) -> Bool {
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(text, forType: .string) else {
            message = "The clipboard did not accept the text."; return false
        }
        statistics.recordCopy()
        lastCopiedText = text; message = "Copied resolved text."
        return true
    }
    func repeatLastCopy() { if let lastCopiedText { _ = copy(lastCopiedText) } }
    func clear() { lastCopiedText = nil; message = "Last copy cleared from Quill’s memory." }
}
