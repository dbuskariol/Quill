import Foundation
import Observation

struct UsageTotals: Codable, Equatable, Sendable {
    var expansions = 0
    var charactersAvoided = 0
    var copies = 0
}

@MainActor @Observable final class LocalStatistics {
    var isEnabled: Bool { didSet { defaults.set(isEnabled, forKey: "statisticsEnabled") } }
    var wordsPerMinute: Double { didSet {
        if !wordsPerMinute.isFinite || wordsPerMinute < 10 || wordsPerMinute > 200 { wordsPerMinute = 40 }
        defaults.set(wordsPerMinute, forKey: "statisticsWPM")
    } }
    private(set) var totals: UsageTotals
    private let defaults: UserDefaults
    var estimatedSecondsSaved: Double { Double(totals.charactersAvoided) / (wordsPerMinute * 5) * 60 }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: "statisticsEnabled")
        let baseline = defaults.double(forKey: "statisticsWPM")
        wordsPerMinute = baseline.isFinite && (10...200).contains(baseline) ? baseline : 40
        let loaded = defaults.data(forKey: "statisticsTotals").flatMap { try? JSONDecoder().decode(UsageTotals.self, from: $0) } ?? .init()
        totals = loaded.expansions >= 0 && loaded.copies >= 0 && loaded.charactersAvoided >= 0 ? loaded : .init()
    }
    func recordExpansion(outputCharacters: Int, abbreviationCharacters: Int) {
        guard isEnabled, (0...1_000_000).contains(outputCharacters), (0...128).contains(abbreviationCharacters), totals.expansions < Int.max,
              totals.charactersAvoided <= Int.max - 1_000_000 else { return }
        totals.expansions += 1
        totals.charactersAvoided += max(0, outputCharacters - abbreviationCharacters)
        persist()
    }
    func recordCopy() { guard isEnabled, totals.copies < Int.max else { return }; totals.copies += 1; persist() }
    func reset() { totals = .init(); persist() }
    func exportData() throws -> Data { try JSONEncoder().encode(totals) }
    private func persist() { if let data = try? JSONEncoder().encode(totals) { defaults.set(data, forKey: "statisticsTotals") } }
}
