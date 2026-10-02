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
        policy.allowedBundleIDs = ["com.apple.TextEdit", "com.apple.Terminal"]
        #expect(policy.allows("com.apple.TextEdit"))
        #expect(!policy.allows("com.apple.Terminal"))
    }
    @Test @MainActor func controllerNeverEnablesOrRequestsPermissionOnLaunch() {
        let suite = "QuillTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = ExpansionController(store: LibraryStore(), defaults: defaults)
        #expect(!controller.isEnabled)
        #expect(controller.policy.allowedBundleIDs.isEmpty)
        controller.pause()
        #expect(!controller.isEnabled)
    }
}
