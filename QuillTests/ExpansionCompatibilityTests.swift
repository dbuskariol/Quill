import AppKit
import Testing
@testable import Quill

struct ExpansionTypingBufferTests {
    private var library: Library {
        let group = SnippetGroup(name: "Test")
        return Library(groups: [group], snippets: [Snippet(groupID: group.id, title: "Reply", abbreviation: ";café", body: "Hello")])
    }
    @Test func bufferMatchesOnlyCompleteTypedSuffixAndPreservesDelimiter() throws {
        var buffer = ExpansionTypingBuffer(); buffer.reset(atBeginning: true)
        buffer.append(";caf")
        #expect(buffer.match(library: library, policy: .init()) == nil)
        buffer.append("é")
        #expect(try #require(buffer.match(library: library, policy: .init())).range == NSRange(location: 0, length: 5))
        var policy = ExpansionPolicy(); policy.trigger = .delimiter
        #expect(buffer.match(library: library, policy: policy) == nil)
        buffer.append(" ")
        #expect(try #require(buffer.match(library: library, policy: policy)).delimiter == " ")
    }
    @Test func unknownBoundaryWaitsForObservedBoundaryAndResetDiscardsContext() {
        var buffer = ExpansionTypingBuffer()
        buffer.append(";café")
        #expect(buffer.match(library: library, policy: .init()) == nil)
        buffer.append(" ;café")
        #expect(buffer.match(library: library, policy: .init()) != nil)
        buffer.reset(); buffer.append("é")
        #expect(buffer.match(library: library, policy: .init()) == nil)
    }
    @Test func bufferIsBoundedAndBackspaceRemovesAWholeGrapheme() {
        var buffer = ExpansionTypingBuffer(); buffer.reset(atBeginning: true)
        buffer.append(String(repeating: "🙂", count: 1000))
        #expect(buffer.text.count == 256)
        buffer.append("👨‍👩‍👧‍👦"); buffer.backspace()
        #expect(buffer.text.count == 255)
        #expect(!buffer.text.contains("👨"))
        buffer.reset(); #expect(buffer.text.isEmpty)
    }
}

@MainActor struct ExpansionClipboardTests {
    @Test func restoresAllFormatsAndMultipleItems() throws {
        let board = NSPasteboard.withUniqueName(); defer { board.releaseGlobally() }
        let first = NSPasteboardItem(); first.setString("Original", forType: .string)
        let privateType = NSPasteboard.PasteboardType("com.example.source")
        first.setData(Data([1, 2, 3]), forType: privateType)
        let second = NSPasteboardItem(); second.setString("<b>Second</b>", forType: .html)
        #expect(board.writeObjects([first, second]))
        let transaction = try ExpansionClipboard(board: board)
        try transaction.write("Expanded")
        #expect(board.string(forType: .string) == "Expanded")
        transaction.restore()
        #expect(board.pasteboardItems?.count == 2)
        #expect(board.pasteboardItems?.first?.string(forType: .string) == "Original")
        #expect(board.pasteboardItems?.first?.data(forType: privateType) == Data([1, 2, 3]))
        #expect(board.pasteboardItems?.last?.string(forType: .html) == "<b>Second</b>")
    }
    @Test func neverOverwritesNewCopyOrChangedSnapshot() throws {
        let board = NSPasteboard.withUniqueName(); defer { board.releaseGlobally() }
        board.setString("Original", forType: .string)
        let transaction = try ExpansionClipboard(board: board)
        try transaction.write("Expanded")
        board.clearContents(); board.setString("New copy", forType: .string)
        transaction.restore()
        #expect(board.string(forType: .string) == "New copy")
        let stale = try ExpansionClipboard(board: board)
        board.clearContents(); board.setString("Changed again", forType: .string)
        #expect(throws: (any Error).self) { try stale.write("Do not write") }
        #expect(board.string(forType: .string) == "Changed again")
    }
    @Test func emptyClipboardRestoresEmptyAndProtectedClipboardIsUntouched() throws {
        let board = NSPasteboard.withUniqueName(); defer { board.releaseGlobally() }
        let transaction = try ExpansionClipboard(board: board)
        try transaction.write("Reply"); transaction.restore()
        #expect(board.pasteboardItems?.isEmpty ?? true)
        board.setString("Protected", forType: .string)
        board.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
        #expect(throws: (any Error).self) { try ExpansionClipboard(board: board) }
        #expect(board.string(forType: .string) == "Protected")
    }
    @Test func oversizedOrPromisedClipboardIsRefusedBeforeWriting() {
        let board = NSPasteboard.withUniqueName(); defer { board.releaseGlobally() }
        board.setData(Data(count: 16 * 1024 * 1024 + 1), forType: .png)
        #expect(throws: (any Error).self) { try ExpansionClipboard(board: board) }
        board.clearContents(); board.setData(Data(), forType: .init("com.apple.pasteboard.promised-file-url"))
        #expect(throws: (any Error).self) { try ExpansionClipboard(board: board) }
    }
    @Test func partialDocumentValuesDoNotPretendToBeCompleteText() {
        let element = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        let partial = PasteExpansionTarget(pid: 1, element: element, window: element, text: "visible fragment", selection: CFRange(location: 500, length: 0))
        #expect(partial.matchingText == nil)
        let complete = PasteExpansionTarget(pid: 1, element: element, window: element, text: "abc", selection: CFRange(location: 3, length: 0))
        #expect(complete.matchingText == "abc")
    }
    @Test func cursorMovementCountsNativeCharactersInsteadOfUTF16Units() {
        #expect(PasteExpansionTarget.cursorSteps(text: "Hello🙂👨‍👩‍👧‍👦", offset: 5, delimiter: " ") == 3)
        #expect(PasteExpansionTarget.cursorSteps(text: "Hello🙂", offset: 6, delimiter: "") == nil)
        #expect(PasteExpansionTarget.cursorSteps(text: "Hello", offset: 5, delimiter: "") == 0)
        #expect(PasteExpansionTarget.cursorSteps(text: "Hello", offset: 99, delimiter: "") == nil)
    }
    @Test func pasteAcceptsEditableTextWithoutRequiringTextSetters() {
        #expect(PasteExpansionTarget.isEditableRole(kAXTextAreaRole, editable: nil))
        #expect(PasteExpansionTarget.isEditableRole("AXWebArea", editable: true))
        #expect(!PasteExpansionTarget.isEditableRole("AXWebArea", editable: nil))
        #expect(!PasteExpansionTarget.isEditableRole(kAXTextFieldRole, editable: false))
        #expect(!PasteExpansionTarget.isEditableRole(kAXButtonRole, editable: nil))
    }
}

@MainActor struct ExpansionKeyboardTextTests {
    @Test func unicodePayloadAndDelimiterKeysDoNotDependOnKeyboardLayout() throws {
        let event = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))
        let units = Array("é🙂".utf16)
        event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        #expect(ExpansionKeyboardText.characters(for: event) == "é🙂")
        let tab = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 48, keyDown: true))
        #expect(ExpansionKeyboardText.characters(for: tab) == "\t")
        let enter = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true))
        #expect(ExpansionKeyboardText.characters(for: enter) == "\n")
    }
}
