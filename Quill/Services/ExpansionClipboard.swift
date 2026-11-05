import AppKit

/// A single explicitly authorized paste. Never keeps history or overwrites a newer copy.
@MainActor final class ExpansionClipboard {
    private let board: NSPasteboard
    private let saved: [NSPasteboardItem]
    private var ownedChange: Int?
    private let capturedChange: Int


    init(board: NSPasteboard = .general) throws {
        self.board = board
        let change = board.changeCount
        capturedChange = change
        var bytes = 0
        saved = try (board.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                // Do not materialize promised/private clipboard formats or lose their contents.
                guard !type.rawValue.lowercased().contains("promise"), type.rawValue != "org.nspasteboard.ConcealedType", let data = item.data(forType: type) else {
                    throw LibraryError.invalid("This clipboard contains a format Quill cannot safely restore. Copy plain text first, or choose Direct Accessibility in Expansion settings.")
                }
                bytes += data.count
                guard bytes <= 16 * 1024 * 1024 else { throw LibraryError.invalid("The clipboard is too large to preserve safely. Copy plain text first, or use Direct Accessibility.") }
                copy.setData(data, forType: type)
            }
            return copy
        }
        guard board.changeCount == change else { throw LibraryError.invalid("The clipboard changed. Your abbreviation was kept; try again.") }
    }
    func write(_ text: String) throws {
        guard board.changeCount == capturedChange else { throw LibraryError.invalid("The clipboard changed. Your abbreviation was kept; try again.") }
        board.clearContents()
        ownedChange = board.changeCount
        guard board.setString(text, forType: .string) else {
            restore()
            throw LibraryError.invalid("The clipboard did not accept the expansion. Your abbreviation was kept.")
        }
        ownedChange = board.changeCount
    }
    func restore() {
        guard let ownedChange, board.changeCount == ownedChange else { return }
        self.ownedChange = nil
        board.clearContents()
        if !saved.isEmpty { _ = board.writeObjects(saved) }
    }
}
