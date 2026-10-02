import Foundation
import Testing
@testable import Quill

struct TextExpanderImportTests {
    private func csv(_ text: String) throws -> TextExpanderImportPlan {
        try TextExpanderImporter.parse(Data(text.utf8), fileName: "Support.csv")
    }
    @Test func quotedCSVPreservesUnicodeNewlinesQuotesAndReorderedHeaders() throws {
        let plan = try csv("\u{FEFF}label,snippet,abbreviation\r\nGreeting,\"Hi, 🌏\r\n\"\"Daniel\"\"\",;hello\r\n")
        #expect(plan.rows.count == 1)
        #expect(plan.rows[0].original == "Hi, 🌏\r\n\"Daniel\"")
        #expect(plan.rows[0].converted == plan.rows[0].original)
        #expect(plan.rows[0].title == "Greeting")
        #expect(plan.rows[0].groupName == "Support")
    }
    @Test func malformedCSVAndDuplicateHeadersRejectBeforeImport() throws {
        #expect(throws: LibraryError.self) { try csv("abbreviation,snippet\n;a,\"unclosed") }
        #expect(throws: LibraryError.self) { try csv("abbreviation,snippet\n;a,\"value\"junk") }
        #expect(throws: LibraryError.self) { try csv("abbreviation,snippet,abbreviation\n;a,Hi,;b") }
        #expect(throws: LibraryError.self) { try csv("abbreviation,snippet\n;a,Hi,extra") }
    }
    @Test func UTF16CSVAndBinaryLegacyPlistAreAccepted() throws {
        let utf16 = "abbreviation,snippet\n;a,Hello".data(using: .utf16)!
        #expect(try TextExpanderImporter.parse(utf16, fileName: "Hello.csv").rows[0].converted == "Hello")
        let root: [String: Any] = ["groupInfo": ["groupName": "My group"], "snippetsTE2": [["abbreviation": ";a", "label": "Hello", "plainText": "Hi", "snippetType": 0], ["abbreviation": ";script", "plainText": "return 1", "snippetType": 2], ["abbreviation": ";rich", "plainText": "Formatted", "snippetType": 1]]]
        for format in [PropertyListSerialization.PropertyListFormat.binary, .xml] {
            let data = try PropertyListSerialization.data(fromPropertyList: root, format: format, options: 0)
            let plan = try TextExpanderImporter.parse(data, fileName: "Group.textexpander")
            #expect(plan.rows[0].groupName == "My group")
            #expect(plan.rows[1].converted == nil)
            #expect(plan.rows[1].problem != nil)
            #expect(plan.rows[2].warnings.contains { $0.contains("Rich text") })
        }
    }
    @Test func documentedMacrosConvertAndForeignQuillSyntaxStaysLiteral() throws {
        let result = try TextExpanderMacroConverter.convert("{{date}} %Y-%m-%d %|%filltext:name=Name:default=Guest:width=20% %fillarea:name=Notes% %fillpopup:name=Tone:Formal:default=Friendly% %%")
        let group = SnippetGroup(name: "Import")
        let item = Snippet(groupID: group.id, title: "Test", abbreviation: ";test", body: result.body)
        let rendered = try TemplateRenderer.render(item, library: Library(groups: [group], snippets: [item]), context: RenderContext(date: Date(timeIntervalSince1970: 0), timeZone: TimeZone(secondsFromGMT: 0)!, fields: ["Name": "Daniel", "Notes": "One\nTwo", "Tone": "Friendly"]))
        #expect(rendered.text == "{{date}} 1970-01-01 Daniel One\nTwo Friendly %")
        #expect(rendered.cursorUTF16Offset == 20)
        #expect(rendered.fieldDefinitions.count == 3)
        #expect(!result.warnings.isEmpty)
    }
    @Test func unsupportedMacrosCannotSilentlyBecomePlainTextOrDates() throws {
        for body in ["%clipboard", "%delay:1%", "%paste", "%fillpart%Hi%fillpartend%", "%\\", "#! /bin/sh\necho Hi", "<p>Hi</p>"] {
            let plan = try csv("abbreviation,snippet\n;a,\"\(body.replacingOccurrences(of: "\"", with: "\"\""))\"")
            #expect(plan.rows[0].problem != nil)
            #expect(plan.rows[0].converted == nil)
        }
    }
    @Test func conflictsSkipOrReplaceWithoutDestroyingExistingIdentity() throws {
        let group = SnippetGroup(name: "Support")
        let existing = Snippet(groupID: group.id, title: "Original", abbreviation: ";a", body: "Old", tags: ["keep"], isFavorite: true)
        let original = Library(groups: [group], snippets: [existing])
        let plan = try csv("abbreviation,snippet,label\n;A,New,Replacement\n;b,Other,Second\n;b,Repeated,Third")
        let selected = Set(plan.rows.map(\.id))
        let skipped = try TextExpanderImporter.merge(plan, selected: selected, into: original, policy: .skip)
        #expect(skipped.imported == 1 && skipped.skipped == 2)
        #expect(skipped.library.snippets.first == existing)
        let replaced = try TextExpanderImporter.merge(plan, selected: selected, into: original, policy: .replace)
        #expect(replaced.imported == 2 && replaced.skipped == 1)
        #expect(replaced.library.snippets[0].id == existing.id)
        #expect(replaced.library.snippets[0].body == "New")
        #expect(replaced.library.snippets[0].isFavorite)
        #expect(replaced.library.snippets[0].tags == ["keep"])
        #expect(replaced.library.groups[1].name == "Support (2)")
        #expect(original.snippets[0].body == "Old")
    }
    @Test func nestedReferencesRequireUniqueSelectedTargetsAndRejectCycles() throws {
        let original = Library(groups: [], snippets: [])
        let plan = try csv("abbreviation,snippet\n;a,%Snippet:;b%\n;b,Hello")
        #expect(throws: LibraryError.self) { try TextExpanderImporter.merge(plan, selected: [plan.rows[0].id], into: original, policy: .skip) }
        let merged = try TextExpanderImporter.merge(plan, selected: Set(plan.rows.map(\.id)), into: original, policy: .skip)
        #expect(try TemplateRenderer.render(merged.library.snippets[0], library: merged.library).text == "Hello")
        let cycle = try csv("abbreviation,snippet\n;a,%Snippet:;b%\n;b,%Snippet:;a%")
        #expect(throws: TemplateError.self) { try TextExpanderImporter.merge(cycle, selected: Set(cycle.rows.map(\.id)), into: original, policy: .skip) }
    }
    @Test @MainActor func storeImportPersistsAddsBacksUpAndUndoes() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LibraryRepository(url: directory.appending(path: "library.json"))
        let store = LibraryStore(repository: repository)
        await store.load()
        let original = store.library
        let plan = try csv("abbreviation,snippet\n;import,Hello")
        #expect(await store.importTextExpander(plan, selected: Set(plan.rows.map(\.id)), policy: .skip))
        #expect(store.library.snippets.count == original.snippets.count + 1)
        #expect(try await repository.load() == store.library)
        #expect(!store.revisions.isEmpty)
        await store.undoLastLibraryChange()
        #expect(store.library == original)
    }
}
