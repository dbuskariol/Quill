import Foundation
import Testing
@testable import Quill

struct CommandSearchTests {
    private let reply = CommandCandidate(id: "reply", kind: .snippet, title: "Café refund reply", subtitle: ";refund", body: "Order details", tags: ["support", "email"], group: "Customer Care", favorite: true)
    private let macro = CommandCandidate(id: "macro", kind: .macro, title: "Refund signature", body: "Regards")
    private let action = CommandCandidate(id: "action.settings", kind: .action, title: "Settings", subtitle: "Configure Quill")
    @Test func ranksAbbreviationsAndTitlesBeforeBodyAndFuzzyMatches() {
        let body = CommandCandidate(id: "body", kind: .snippet, title: "Miscellaneous", body: "refund")
        let results = CommandSearch.results([body, macro, reply], query: "refund", filter: .init())
        #expect(results.map(\.id) == ["macro", "reply", "body"])
        #expect(CommandSearch.results([reply], query: "cafe rfrp", filter: .init()).map(\.id) == ["reply"])
        #expect(CommandSearch.results([reply], query: ";refund", filter: .init()).map(\.id) == ["reply"])
        let unrelated = CommandCandidate(id: "pause", kind: .action, title: "Pause Expansion", subtitle: "Control expansion in other apps")
        #expect(CommandSearch.results([unrelated], query: "notes", filter: .init()).isEmpty)
    }
    @Test func typedFiltersComposeWithMultiwordAndQuotedSearch() {
        let items = [reply, macro, action]
        #expect(CommandSearch.results(items, query: "group:\"Customer Care\" tag:email is:favorite cafe", filter: .init()).map(\.id) == ["reply"])
        #expect(CommandSearch.results(items, query: "type:macro refund", filter: .init()).map(\.id) == ["macro"])
        #expect(CommandSearch.results(items, query: "type:actions settings", filter: .init()).map(\.id) == ["action.settings"])
        #expect(CommandSearch.results(items, query: "tag:missing", filter: .init()).isEmpty)
        #expect(CommandSearch.hasFilters(in: "group:\"Customer Care\" refund"))
        #expect(CommandSearch.clearingFilters(in: "group:\"Customer Care\" tag:email is:favorite refund") == "refund")
        #expect(CommandSearch.clearingFilters(in: "type:macro \"refund reply\"") == "\"refund reply\"")
        #expect(CommandSearch.results(items, query: "cafe absent", filter: .init()).isEmpty)
        #expect(CommandSearch.results(items, query: "", filter: .init(kind: .macro, favoritesOnly: true)).isEmpty)
    }
    @Test func filterControlsAndRecentRankingRemainDeterministic() {
        #expect(CommandSearch.results([reply, macro, action], query: "", filter: .init(tag: "email")).map(\.id) == ["reply"])
        #expect(CommandSearch.results([reply, macro, action], query: "", filter: .init(), recent: ["macro", "reply"]).map(\.id) == ["macro", "reply", "action.settings"])
        let duplicateTitle = CommandCandidate(id: "aaa", kind: .action, title: "Settings")
        #expect(CommandSearch.results([action, duplicateTitle], query: "Settings", filter: .init()).map(\.id) == ["aaa", "action.settings"])
    }
    @Test func macroResultsRenderTheirOwnIdentityAndKeepRealCycleChecks() throws {
        let signature = CustomMacro(name: "Signature", body: "**Regards**, {{field:name}}", format: .markdown)
        let reply = CustomMacro(name: "Reply", body: "{{macro:Signature}}")
        let library = Library(groups: [], snippets: [], macros: [signature, reply])
        let candidates = CommandSearch.candidates(library: library, actions: [])
        #expect(candidates.count == 2)
        #expect(CommandSearch.results(candidates, query: "type:macro signature", filter: .init()).first?.id == signature.id.uuidString)
        let rendered = try TemplateRenderer.render(signature, library: library, context: .init(fields: ["name": "Casey"]))
        #expect(rendered.text == "**Regards**, Casey")
        #expect(try rendered.plainTextResult().text == "Regards, Casey")
        let nested = try TemplateRenderer.render(reply, library: library, context: .init(fields: ["name": "Casey"]))
        #expect(nested.text == "Regards, Casey")
        let recursive = CustomMacro(name: "Cycle", body: "{{macro:Cycle}}")
        #expect(throws: TemplateError.self) { try TemplateRenderer.render(recursive, library: Library(groups: [], snippets: [], macros: [recursive])) }
    }
    @Test @MainActor func historyIsBoundedAndPersistsIdentifiersWithoutReplyContent() throws {
        let suite = "quill-command-history-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let history = CommandHistory(defaults: defaults)
        for number in 0..<12 { history.record("id-\(number)") }
        history.record("id-10")
        #expect(history.recent.count == 8)
        #expect(history.recent.first == "id-10")
        #expect(CommandHistory(defaults: defaults).recent == history.recent)
        history.clear()
        #expect(CommandHistory(defaults: defaults).recent.isEmpty)
    }
    @Test @MainActor func setupIsShownOnceAndCanBeDeferredWithoutEnablingExpansion() throws {
        let suite = "quill-setup-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = AppPreferences(defaults: defaults)
        #expect(preferences.setupDisposition.shouldPresentAutomatically)
        preferences.setupDisposition = .deferred
        #expect(!AppPreferences(defaults: defaults).setupDisposition.shouldPresentAutomatically)
        #expect(!defaults.bool(forKey: "expansionAcrossLaunches"))
        preferences.setupDisposition = .completed
        #expect(AppPreferences(defaults: defaults).setupDisposition == .completed)
    }
}
