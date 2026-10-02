import Foundation
import Testing
@testable import Quill

struct LocalStatisticsTests {
    @Test @MainActor func consentPersistenceAndReset() throws {
        let suite = "QuillTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let stats = LocalStatistics(defaults: defaults)
        stats.recordExpansion(outputCharacters: 100, abbreviationCharacters: 4)
        stats.recordCopy()
        #expect(stats.totals == UsageTotals())
        stats.isEnabled = true
        stats.recordExpansion(outputCharacters: 100, abbreviationCharacters: 4)
        stats.recordExpansion(outputCharacters: 2, abbreviationCharacters: 4)
        stats.recordCopy()
        #expect(stats.totals.expansions == 2)
        #expect(stats.totals.charactersAvoided == 96)
        #expect(abs(stats.estimatedSecondsSaved - 28.8) < 0.000001)
        #expect(try JSONDecoder().decode(UsageTotals.self, from: stats.exportData()) == stats.totals)
        let reopened = LocalStatistics(defaults: defaults)
        #expect(reopened.totals == stats.totals)
        reopened.isEnabled = false
        reopened.recordCopy()
        #expect(reopened.totals.copies == 1)
        reopened.reset()
        #expect(LocalStatistics(defaults: defaults).totals == UsageTotals())
    }
}
