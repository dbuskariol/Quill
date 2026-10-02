import AppKit
import Testing
@testable import Quill

struct TemplateCompletionTests {
    private func context(_ text: String, caret: Int? = nil) throws -> TemplateCompletion.Context {
        try #require(TemplateCompletion.context(in: text, selection: NSRange(location: caret ?? text.utf16.count, length: 0)))
    }
    @Test func bracesPartialWordsAndNamespacesAreDiscoverable() throws {
        let group = SnippetGroup(name: "Work")
        let library = Library(groups: [group], snippets: [Snippet(groupID: group.id, title: "Signature", abbreviation: ";sig", body: "Daniel")], macros: [CustomMacro(name: "greeting", body: "Hi")])
        #expect(TemplateCompletion.suggestions(for: try context("{{"), library: library).contains("ticket."))
        #expect(TemplateCompletion.suggestions(for: try context("{{ma"), library: library).contains("macro:greeting}}"))
        #expect(TemplateCompletion.suggestions(for: try context("{{sni"), library: library).contains("snippet:;sig}}"))
        #expect(TemplateCompletion.suggestions(for: try context("{{snippet."), library: library) == ["snippet:;sig}}"])
        #expect(TemplateCompletion.suggestions(for: try context("{{MACRO.gr"), library: library) == ["macro:greeting}}"])
        #expect(TemplateCompletion.suggestions(for: try context("{{ticket.requester.fi"), library: library) == ["ticket.requester.first_name}}"])
    }
    @Test func contextUsesUTF16AndRespectsExpressionBoundaries() throws {
        let value = "🌏 café {{sni}} after"
        let caret = "🌏 café {{sni".utf16.count
        let result = try context(value, caret: caret)
        #expect(result.range == NSRange(location: "🌏 café {{".utf16.count, length: 3))
        #expect(result.closingBraces)
        for text in ["plain", "{{date}}", "{{ticket.id | upcase", "{{ma\nmore", "{{one}more", "{{" + String(repeating: "x", count: 257)] {
            #expect(TemplateCompletion.context(in: text, selection: NSRange(location: text.utf16.count, length: 0)) == nil)
        }
        #expect(TemplateCompletion.context(in: "{{ma", selection: NSRange(location: 2, length: 2)) == nil)
        #expect(TemplateCompletion.context(in: "{{ma", selection: NSRange(location: 99, length: 0)) == nil)
        #expect(try context("{{date}} {{ti").query == "ti")
        #expect(TemplateCompletion.context(in: "{{date}}", selection: NSRange(location: 4, length: 0)) == nil)
    }
    @Test func existingClosingBracesAreNotDuplicatedAndReferencesAreSafe() throws {
        let group = SnippetGroup(name: "Work")
        let first = Snippet(groupID: group.id, title: "First", abbreviation: ";same", body: "a")
        let second = Snippet(groupID: group.id, title: "Second", abbreviation: ";same", body: "b")
        let macro = CustomMacro(name: "self", body: "")
        let library = Library(groups: [group], snippets: [first, second], macros: [macro])
        #expect(TemplateCompletion.suggestions(for: try context("{{sni"), library: library) == ["snippet:"])
        #expect(TemplateCompletion.suggestions(for: try context("{{macro:"), library: library, excludingMacro: macro.id).isEmpty)
        #expect(TemplateCompletion.suggestions(for: try context("{{da}}", caret: 4), library: library) == ["date", "date:yyyy-MM-dd|7"])
        #expect(TemplateCompletion.suggestions(for: try context("{{no_such_token"), library: library).isEmpty)
    }
    @Test func completionIsBoundedAndSupportsUnicodeMacroNames() throws {
        let macros = (0..<100).map { CustomMacro(name: "greeting\($0)", body: "") } + [CustomMacro(name: "挨拶", body: "こんにちは")]
        let library = Library(groups: [], snippets: [], macros: macros)
        #expect(TemplateCompletion.suggestions(for: try context("{{macro:"), library: library).count == 60)
        #expect(TemplateCompletion.suggestions(for: try context("{{macro:挨"), library: library) == ["macro:挨拶}}"])
    }
    @Test @MainActor func nativeInsertionUsesCaretAndUndo() throws {
        let view = CompletingTextView()
        view.allowsUndo = true
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = view
        window.makeFirstResponder(view)
        view.string = "Hi 🌏 friend"
        view.setSelectedRange(NSRange(location: 3, length: 2))
        let controller = TemplateEditorController(); controller.textView = view
        controller.insert("{{ticket.id}}")
        #expect(view.string == "Hi {{ticket.id}} friend")
        #expect(view.selectedRange().location == "Hi {{ticket.id}}".utf16.count)
        view.undoManager?.undo()
        #expect(view.string == "Hi 🌏 friend")
    }
    @Test @MainActor func nativeCompletionReusesBracesAndCompletesAWholeConditional() throws {
        let view = CompletingTextView()
        view.string = "🌏 {{da}} after"
        view.setSelectedRange(NSRange(location: "🌏 {{da".utf16.count, length: 0))
        let range = view.rangeForUserCompletion
        view.insertCompletion("date", forPartialWordRange: range, movement: NSReturnTextMovement, isFinal: true)
        #expect(view.string == "🌏 {{date}} after")
        #expect(view.selectedRange().location == "🌏 {{date}}".utf16.count)
        let values = TemplateCompletion.suggestions(for: try context("{{if"), library: Library(groups: [], snippets: []))
        #expect(values == [String(TemplateCompletion.conditional.dropFirst(2))])
        #expect(try TemplateRenderer.parse("{{" + values[0]).contains { if case .conditional = $0 { true } else { false } })
    }
    @Test @MainActor func workspaceDestinationsAndNewMacrosPreserveOtherDrafts() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LibraryStore(repository: LibraryRepository(url: directory.appending(path: "library.json")))
        await store.load()
        var snippet = try #require(store.selected); snippet.body = "Unfinished"
        store.drafts[snippet.id] = snippet
        store.createMacro()
        let first = try #require(store.selectedMacroID)
        #expect(store.destination == .macros)
        #expect(store.macroDrafts[first]?.name == "New macro")
        store.isShowingSettings = true
        #expect(!store.showCustomMacros)
        store.showCustomMacros = true
        #expect(!store.isShowingSettings)
        #expect(store.selectedMacroID == first)
        store.macroSearch = "Missing"
        store.createMacro()
        #expect(store.macroSearch.isEmpty)
        #expect(store.macroDrafts[try #require(store.selectedMacroID)]?.name == "New macro 2")
        #expect(store.drafts[snippet.id]?.body == "Unfinished")
    }
}
