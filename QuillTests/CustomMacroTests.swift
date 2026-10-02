import Foundation
import Testing
import SwiftUI
@testable import Quill

struct CustomMacroTests {
    @Test @MainActor func insertMacrosAtUnicodeSelectionAndRenameReferencesAtomically() async throws {
        var text = "Hi 🌏 friend"
        let start = text.index(text.startIndex, offsetBy: 3)
        let end = text.index(after: start)
        var selection: TextSelection? = TextSelection(range: start..<end)
        insertTemplateText("{{ticket.id}}", into: &text, selection: &selection)
        #expect(text == "Hi {{ticket.id}} friend")
        insertTemplateText("!", into: &text, selection: &selection)
        #expect(text == "Hi {{ticket.id}}! friend")
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LibraryStore(repository: LibraryRepository(url: directory.appending(path: "library.json")))
        await store.load()
        var macro = CustomMacro(name: "old", body: "Hello")
        #expect(await store.saveMacro(macro))
        var item = store.library.snippets[0]
        item.body = "{{macro:old}}"
        #expect(await store.save(item))
        macro.name = "new"
        #expect(await store.saveMacro(macro))
        #expect(store.library.snippets[0].body == "{{macro:new}}")
        #expect(try TemplateRenderer.render(store.library.snippets[0], library: store.library).text == "Hello")
    }
    @Test func oldLibrariesDecodeAndCustomMacrosRoundTrip() throws {
        let legacy = Data(#"{"version":1,"groups":[],"snippets":[]}"#.utf8)
        let library = try JSONDecoder().decode(Library.self, from: legacy)
        #expect(library.macros.isEmpty)
        var updated = library
        updated.macros = [CustomMacro(name: "signature", body: "Daniel")]
        #expect(updated.version == 2)
        #expect(try JSONDecoder().decode(Library.self, from: LibraryRepository.encode(updated)) == updated)
    }
    @Test func reusableMacrosShareFieldsAndPreserveZendeskTokens() throws {
        let group = SnippetGroup(name: "Support")
        let macros = [CustomMacro(name: "signoff", body: "Thanks, {{field:agent}}"), CustomMacro(name: "reply", body: "Hi {{ticket.requester.first_name}},\n{{macro:signoff}}")]
        let snippet = Snippet(groupID: group.id, title: "Reply", abbreviation: ";reply", body: "{{macro:reply}} / {{macro:signoff}}")
        let library = Library(groups: [group], snippets: [snippet], macros: macros)
        let result = try TemplateRenderer.render(snippet, library: library, context: RenderContext(fields: ["agent": "Daniel"]))
        #expect(result.text == "Hi {{ticket.requester.first_name}},\nThanks, Daniel / Thanks, Daniel")
        #expect(result.fields == ["agent"])
        #expect(result.zendeskPlaceholders == ["ticket.requester.first_name"])
    }
    @Test func macroCyclesMissingNamesAndDuplicateNamesFailClearly() throws {
        let group = SnippetGroup(name: "Support")
        let snippet = Snippet(groupID: group.id, title: "Reply", abbreviation: ";reply", body: "{{macro:a}}")
        let cycle = Library(groups: [group], snippets: [snippet], macros: [CustomMacro(name: "a", body: "{{macro:b}}"), CustomMacro(name: "b", body: "{{macro:a}}")])
        #expect(throws: TemplateError.self) { try TemplateRenderer.render(snippet, library: cycle) }
        #expect(throws: TemplateError.self) { try TemplateRenderer.render(snippet, library: Library(groups: [group], snippets: [snippet])) }
        #expect(throws: LibraryError.self) { try Library(groups: [], snippets: [], macros: [CustomMacro(name: "a", body: "One"), CustomMacro(name: "a", body: "Two")]).validate() }
    }
    @Test func zendeskCustomFieldsAndEscapesStayVerbatimWithoutTicketAccess() throws {
        let group = SnippetGroup(name: "Support")
        let body = "{{ticket.ticket_field_123456}} {{ticket.requester.custom_fields.plan}} {{dc.refund_policy}} \\{{ticket.id}} {{ ticket.ticket_field_123 | split:\"::\" | last }}"
        let snippet = Snippet(groupID: group.id, title: "Zendesk", abbreviation: ";z", body: body)
        let result = try TemplateRenderer.render(snippet, library: Library(groups: [group], snippets: [snippet]))
        #expect(result.text == body)
        #expect(result.fields.isEmpty)
        #expect(result.zendeskPlaceholders.count == 5)
        #expect(!ZendeskPlaceholder.isValid("ticket..id"))
        #expect(!ZendeskPlaceholder.isValid("ticket.id | evil"))
        #expect(!ZendeskPlaceholder.isValid("unknown.name"))
        #expect(try ZendeskPlaceholder.common.allSatisfy { placeholder in
            try TemplateRenderer.parse(placeholder.token) == [.text(""), .zendesk(placeholder.name), .text("")]
        })
    }
    @Test @MainActor func macroSaveRejectsCyclesPersistsAndProtectsDrafts() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LibraryRepository(url: directory.appending(path: "library.json"))
        let store = LibraryStore(repository: repository)
        await store.load()
        let macro = CustomMacro(name: "signature", body: "Daniel")
        #expect(await store.saveMacro(macro))
        #expect(try await repository.load().macros == [macro])
        let before = store.library
        #expect(!(await store.saveMacro(CustomMacro(name: "cycle", body: "{{macro:cycle}}"))))
        #expect(store.library == before)
        store.macroDrafts[macro.id] = CustomMacro(id: macro.id, name: macro.name, body: "Draft")
        #expect(store.hasUnsavedChanges)
        #expect(!store.canUndoLibrary)
        let plan = try TextExpanderImporter.parse(Data("abbreviation,snippet\n;a,Hello".utf8), fileName: "Test.csv")
        #expect(!(await store.importTextExpander(plan, selected: Set(plan.rows.map(\.id)), policy: .skip)))
        #expect(store.library == before)
    }
}
