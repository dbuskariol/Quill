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
        var policy = ExpansionPolicy(); policy.trigger = .delimiter; policy.caseSensitive = false
        #expect(AbbreviationMatcher.match(text: "sig ", caret: 4, library: items, policy: policy) == nil)
        #expect(AbbreviationMatcher.match(text: "xsig ", caret: 5, library: library(["sig"]), policy: .init()) == nil)
        policy.requiresWordBoundary = false
        #expect(AbbreviationMatcher.match(text: "xsig ", caret: 5, library: library(["sig"]), policy: policy) != nil)
        #expect(AbbreviationMatcher.match(text: "sig", caret: 3, library: items, policy: policy) == nil)
    }
    @Test func immediatelyMatchesLastCharacterWithoutDelimiter() throws {
        let text = "🙂 ;café"
        let match = try #require(AbbreviationMatcher.match(text: text, caret: text.utf16.count,
                                                          library: library([";café"]), policy: .init()))
        #expect(match.range == NSRange(location: 3, length: 5))
        #expect(match.delimiter.isEmpty)
        #expect(AbbreviationMatcher.match(text: ";caf", caret: 4, library: library([";café"]), policy: .init()) == nil)
    }
    @Test func overlappingAbbreviationsWaitForDisambiguation() {
        let items = library([";sig", ";signature"])
        #expect(AbbreviationMatcher.match(text: ";sig", caret: 4, library: items, policy: .init()) == nil)
        #expect(AbbreviationMatcher.match(text: ";sig ", caret: 5, library: items, policy: .init()) != nil)
        #expect(AbbreviationMatcher.match(text: ";signature", caret: 10, library: items, policy: .init()) != nil)
        var policy = ExpansionPolicy(); policy.trigger = .delimiter
        #expect(AbbreviationMatcher.match(text: ";signature", caret: 10, library: items, policy: policy) == nil)
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
    @Test @MainActor func navigationAndDeletionNeverTriggerImmediateExpansion() {
        var policy = ExpansionPolicy()
        for key: Int64 in [51, 117, 53, 114, 123, 124, 125, 126, 115, 119, 116, 121, 71, 104, 102, 122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90] {
            #expect(!ExpansionController.isTextTrigger(key: key, characters: "", policy: policy))
        }
        // Empty Unicode payloads are valid hardware keys; AX confirms the committed text.
        #expect(ExpansionController.isTextTrigger(key: 13, characters: "", policy: policy))
        policy.trigger = .delimiter
        #expect(!ExpansionController.isTextTrigger(key: 13, characters: "w", policy: policy))
        for key: Int64 in [36, 76, 48, 49] {
            #expect(ExpansionController.isTextTrigger(key: key, characters: "", policy: policy))
        }
        policy.delimiters = " "
        #expect(!ExpansionController.isTextTrigger(key: 36, characters: "", policy: policy))
        #expect(!ExpansionController.isTextTrigger(key: 48, characters: "", policy: policy))
        #expect(ExpansionController.isTextTrigger(key: 49, characters: "", policy: policy))
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
    @Test @MainActor func durationIsExplicitAndPauseDisarmsLaunchResume() {
        let suite = "QuillTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = ExpansionController(store: LibraryStore(), defaults: defaults)
        #expect(controller.duration == .untilQuit)
        #expect(!controller.isEnabled)
        controller.duration = .always
        // Selecting a mode alone never enables monitoring.
        #expect(!controller.isEnabled)
        #expect(!defaults.bool(forKey: "expansionAcrossLaunches"))
        defaults.set(true, forKey: "expansionAcrossLaunches")
        controller.pause()
        #expect(!defaults.bool(forKey: "expansionAcrossLaunches"))
        let reopened = ExpansionController(store: LibraryStore(), defaults: defaults)
        #expect(reopened.duration == .always)
        #expect(!reopened.isEnabled)
        #expect(reopened.endsAt == nil)
        #expect(ExpansionDuration.fifteenMinutes.interval == 900)
        #expect(ExpansionDuration.oneHour.interval == 3600)
        #expect(ExpansionDuration.always.interval == nil)
    }

}
