import AppKit
import Observation

@MainActor @Observable final class QuickActionStore {
    enum CopyStyle { case formatted, plainText, markdown }
    private struct Payload { let text: String; let html: Data?; let rtf: Data? }
    private var lastPayload: Payload?
    var lastCopiedText: String? { lastPayload?.text }
    var message: String?
    private let pasteboard: NSPasteboard
    private let statistics: LocalStatistics
    init(statistics: LocalStatistics, pasteboard: NSPasteboard = .general) { self.statistics = statistics; self.pasteboard = pasteboard }
    func copy(_ text: String) -> Bool { write(Payload(text: text, html: nil, rtf: nil)) }
    func copy(_ result: RenderResult, style: CopyStyle = .formatted) -> Bool {
        do {
            guard result.format == .markdown, style != .markdown else { return copy(result.text) }
            let document = try MarkdownDocument(result.text)
            if style == .plainText { return copy(document.plainText) }
            let attributed = FormattedContent.attributed(document)
            let rtf = try attributed.data(from: NSRange(location: 0, length: attributed.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            return write(Payload(text: document.plainText, html: Data(document.html.utf8), rtf: rtf))
        } catch { message = "Could not prepare formatted content: \(error.localizedDescription)"; return false }
    }
    private func write(_ payload: Payload) -> Bool {
        let item = NSPasteboardItem()
        guard item.setString(payload.text, forType: .string), payload.html.map({ item.setData($0, forType: .html) }) ?? true, payload.rtf.map({ item.setData($0, forType: .rtf) }) ?? true else {
            message = "Could not prepare the clipboard formats."; return false
        }
        pasteboard.clearContents()
        guard pasteboard.writeObjects([item]) else { message = "The clipboard did not accept the content."; return false }
        statistics.recordCopy(); lastPayload = payload; message = "Copied resolved content."; return true
    }
    func repeatLastCopy() { if let lastPayload { _ = write(lastPayload) } }
    func clear() { lastPayload = nil; message = "Last copy cleared from Quill’s memory." }
}
