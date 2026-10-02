import Foundation
import Testing
@testable import Quill

struct AbbreviationMatcherTests {
    private func library(_ abbreviations: [String]) -> Library {
        let group = SnippetGroup(name: "Test")
        return Library(groups: [group], snippets: abbreviations.map { Snippet(groupID: group.id, title: $0, abbreviation: $0, body: "result") })
    }
    @Test func matchesCommittedUnicodeAndReturnsUTF16Range() throws {
        let text = "🙂 ;café "
        let match = try #require(AbbreviationMatcher.match(text: text, caret: text.utf16.count, library: library([";café"]), policy: .init()))
        #expect(match.range == NSRange(location: 3, length: 6))
        #expect((text as NSString).substring(with: match.range) == ";café ")
    }
    @Test func respectsCaseBoundaryAndAmbiguity() {
        let items = library(["sig", "SIG"])
        #expect(AbbreviationMatcher.match(text: "sig ", caret: 4, library: items, policy: .init()) != nil)
        var policy = ExpansionPolicy(); policy.caseSensitive = false
        #expect(AbbreviationMatcher.match(text: "sig ", caret: 4, library: items, policy: policy) == nil)
        #expect(AbbreviationMatcher.match(text: "xsig ", caret: 5, library: library(["sig"]), policy: .init()) == nil)
        policy.requiresWordBoundary = false
        #expect(AbbreviationMatcher.match(text: "xsig ", caret: 5, library: library(["sig"]), policy: policy) != nil)
        #expect(AbbreviationMatcher.match(text: "sig", caret: 3, library: items, policy: policy) == nil)
    }
    @Test func refusesInvalidRangesAndUnknownApps() {
        let items = library([";x"])
        #expect(AbbreviationMatcher.match(text: ";x ", caret: 99, library: items, policy: .init()) == nil)
        var policy = ExpansionPolicy()
        #expect(!policy.allows("com.apple.TextEdit"))
        policy.selectedApplications = [.init(id: "com.apple.TextEdit", name: "TextEdit"), .init(id: "com.apple.Terminal", name: "Terminal")]
        #expect(policy.allows("com.apple.TextEdit"))
        #expect(!policy.allows("com.apple.Terminal"))
    }
    @Test func allApplicationsRespectsEditableExclusionsAndPersists() throws {
        var policy = ExpansionPolicy()
        policy.applicationScope = .all
        #expect(policy.hasApplicationScope)
        #expect(policy.allows("com.apple.TextEdit"))
        #expect(!policy.allows(""))
        #expect(!policy.allows("com.apple.Terminal"))
        policy.excludedApplications.removeAll { $0.id == "com.apple.Terminal" }
        #expect(policy.allows("com.apple.Terminal"))
        policy.add([.init(id: "com.apple.TextEdit", name: "TextEdit")], excluding: true)
        #expect(!policy.allows("com.apple.TextEdit"))
        #expect(try JSONDecoder().decode(ExpansionPolicy.self, from: JSONEncoder().encode(policy)) == policy)
    }
    @Test func movingApplicationBetweenListsHasOneRule() {
        var policy = ExpansionPolicy()
        let app = ExpansionApplication(id: "com.apple.TextEdit", name: "TextEdit")
        policy.add([app, app], excluding: false)
        #expect(policy.selectedApplications.count == 1)
        #expect(policy.allows(app.id))
        policy.add([app], excluding: true)
        #expect(policy.selectedApplications.isEmpty)
        #expect(!policy.allows(app.id))
        policy.add([app], excluding: false)
        #expect(!policy.excludedApplications.contains { $0.id == app.id })
        #expect(policy.allows(app.id))
    }
    @Test @MainActor func controllerNeverEnablesOrRequestsPermissionOnLaunch() {
        let suite = "QuillTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = ExpansionController(store: LibraryStore(), defaults: defaults)
        #expect(!controller.isEnabled)
        #expect(controller.policy.selectedApplications.isEmpty)
        controller.pause()
        #expect(!controller.isEnabled)
    }
}
