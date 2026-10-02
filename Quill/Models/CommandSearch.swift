import Foundation

enum CommandKind: String, CaseIterable, Identifiable, Sendable {
    case snippet = "Snippets", macro = "Macros", action = "Actions"
    var id: Self { self }
}

struct CommandCandidate: Identifiable, Equatable, Sendable {
    let id: String
    let kind: CommandKind
    let title: String
    var subtitle = ""
    var body = ""
    var tags: [String] = []
    var group = ""
    var groupID: UUID?
    var favorite = false
    var symbol: String { kind == .snippet ? "text.quote" : kind == .macro ? "curlybraces" : "command" }
}

struct CommandSearchFilter: Equatable, Sendable {
    var kind: CommandKind?
    var groupID: UUID?
    var tag: String?
    var favoritesOnly = false
}

struct CommandSearchRequest: Equatable, Sendable {
    let candidates: [CommandCandidate]
    let query: String
    let filter: CommandSearchFilter
    let recent: [String]
}

enum CommandSearch {
    static func candidates(library: Library, actions: [CommandCandidate]) -> [CommandCandidate] {
        library.snippets.map { snippet in
            CommandCandidate(id: snippet.id.uuidString, kind: .snippet, title: snippet.title,
                             subtitle: snippet.abbreviation, body: snippet.body, tags: snippet.tags,
                             group: library.groups.first { $0.id == snippet.groupID }?.name ?? "", groupID: snippet.groupID, favorite: snippet.isFavorite)
        } + library.macros.map { CommandCandidate(id: $0.id.uuidString, kind: .macro, title: $0.name, subtitle: "Custom macro", body: $0.body) } + actions
    }

    static func results(_ candidates: [CommandCandidate], query: String, filter: CommandSearchFilter, recent: [String] = []) -> [CommandCandidate] {
        let terms = tokens(query).map(normalize)
        return candidates.compactMap { item -> (CommandCandidate, Int)? in
            guard !Task.isCancelled else { return nil }
            guard filter.kind == nil || item.kind == filter.kind,
                  filter.groupID == nil || item.groupID == filter.groupID,
                  filter.tag == nil || item.tags.contains(where: { normalize($0) == normalize(filter.tag!) }),
                  !filter.favoritesOnly || item.favorite else { return nil }
            var score = item.favorite ? 4 : 0
            if terms.isEmpty, let index = recent.firstIndex(of: item.id) { score += 1000 - index * 10 }
            for term in terms {
                if term.hasPrefix("tag:") {
                    guard item.tags.contains(where: { normalize($0) == String(term.dropFirst(4)) }) else { return nil }
                } else if term.hasPrefix("group:") {
                    guard normalize(item.group) == String(term.dropFirst(6)) else { return nil }
                } else if term == "is:favorite" {
                    guard item.favorite else { return nil }
                } else if term.hasPrefix("type:") {
                    let value = String(term.dropFirst(5))
                    guard value == item.kind.rawValue.lowercased() || value == String(item.kind.rawValue.lowercased().dropLast()) else { return nil }
                } else {
                    let title = normalize(item.title), subtitle = normalize(item.subtitle)
                    let rank: Int
                    if title == term || subtitle == term { rank = 300 }
                    else if title.hasPrefix(term) || subtitle.hasPrefix(term) { rank = 160 }
                    else if title.contains(term) || subtitle.contains(term) { rank = 100 }
                    else if (item.tags + [item.group]).contains(where: { normalize($0).contains(term) }) { rank = 60 }
                    else if normalize(item.body).contains(term) { rank = 20 }
                    else if term.count >= 2, subsequence(term, in: title) || subsequence(term, in: subtitle) { rank = 10 }
                    else { return nil }
                    score += rank
                }
            }
            return (item, score)
        }.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            let order = $0.0.title.localizedStandardCompare($1.0.title)
            return order == .orderedSame ? $0.0.id < $1.0.id : order == .orderedAscending
        }.map(\.0)
    }
    static func hasFilters(in query: String) -> Bool { tokens(query).contains(where: isFilterToken) }
    static func clearingFilters(in query: String) -> String {
        tokens(query).filter { !isFilterToken($0) }.map { term in
            term.contains(where: \.isWhitespace) ? "\"\(term)\"" : term
        }.joined(separator: " ")
    }
    private static func isFilterToken(_ term: String) -> Bool {
        let term = normalize(term)
        return term.hasPrefix("tag:") || term.hasPrefix("group:") || term.hasPrefix("type:") || term == "is:favorite"
    }
    private static func normalize(_ value: String) -> String { value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
    private static func subsequence(_ term: String, in value: String) -> Bool {
        var remaining = term[...]
        var firstMatch: Int?
        for (index, character) in value.enumerated() where remaining.first == character {
            if firstMatch == nil { firstMatch = index }
            remaining = remaining.dropFirst()
            if remaining.isEmpty { return index - (firstMatch ?? index) + 1 <= term.count * 2 + 2 }
        }
        return false
    }
    /// Quotes keep multiword group/tag values together; ordinary words remain AND terms.
    static func tokens(_ query: String) -> [String] {
        var result: [String] = [], current = "", quoted = false
        for character in query.prefix(512) {
            if character == "\"" { quoted.toggle() }
            else if character.isWhitespace && !quoted { if !current.isEmpty { result.append(current); current = "" } }
            else { current.append(character) }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}
