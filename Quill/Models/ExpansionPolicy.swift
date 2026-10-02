import Foundation

struct ExpansionApplication: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var name: String
    var path: String?
}

struct ExpansionPolicy: Codable, Equatable, Sendable {
    enum ApplicationScope: String, Codable, CaseIterable, Identifiable {
        case all, selected
        var id: Self { self }
        var title: String { self == .all ? "All Applications" : "Selected Applications" }
    }
    enum Trigger: String, Codable, CaseIterable, Identifiable {
        case immediately, delimiter
        var id: Self { self }
        var title: String { self == .immediately ? "Immediately" : "After Space, Tab or Return" }
    }
    var trigger = Trigger.immediately
    var delimiters = " \t\n"
    var caseSensitive = true
    var requiresWordBoundary = true
    var applicationScope = ApplicationScope.selected
    var excludedApplications: [ExpansionApplication] = [
        .init(id: "com.1password.1password", name: "1Password"),
        .init(id: "com.apple.Terminal", name: "Terminal"),
        .init(id: "com.googlecode.iterm2", name: "iTerm")
    ]
    var selectedApplications: [ExpansionApplication] = []
    var hasApplicationScope: Bool { applicationScope == .all || !selectedApplications.isEmpty }

    func allows(_ bundleID: String) -> Bool {
        !bundleID.isEmpty && !excludedApplications.contains { $0.id == bundleID }
        && (applicationScope == .all || selectedApplications.contains { $0.id == bundleID })
    }
    mutating func add(_ applications: [ExpansionApplication], excluding: Bool) {
        for app in applications {
            selectedApplications.removeAll { $0.id == app.id }
            excludedApplications.removeAll { $0.id == app.id }
            if excluding { excludedApplications.append(app) }
            else { selectedApplications.append(app) }
        }
        selectedApplications.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        excludedApplications.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

struct ExpansionMatch: Equatable, Sendable {
    let snippetID: UUID
    let range: NSRange
    let delimiter: String
}

enum AbbreviationMatcher {
    // Match committed target text only. No event characters or IME composition are retained.
    static func match(text: String, caret: Int, library: Library, policy: ExpansionPolicy) -> ExpansionMatch? {
        let source = text as NSString
        guard caret > 0, caret <= source.length else { return nil }
        let prefix = source.substring(to: caret)
        let delimiter: String
        if let last = prefix.last, policy.delimiters.contains(last) { delimiter = String(last) }
        else if policy.trigger == .immediately { delimiter = "" }
        else { return nil }
        let end = caret - delimiter.utf16.count
        var matches: [ExpansionMatch] = []
        for snippet in library.snippets {
            let count = snippet.abbreviation.utf16.count
            guard count > 0, count <= 128, count <= end else { continue }
            let range = NSRange(location: end - count, length: count)
            guard Range(range, in: text) != nil else { continue }
            let candidate = source.substring(with: range)
            let equal = policy.caseSensitive ? candidate == snippet.abbreviation : candidate.compare(snippet.abbreviation, options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX")) == .orderedSame
            guard equal else { continue }
            if policy.requiresWordBoundary, range.location > 0 {
                let preceding = source.substring(to: range.location).last
                if let preceding, preceding.isLetter || preceding.isNumber || preceding == "_" { continue }
            }
            matches.append(.init(snippetID: snippet.id, range: NSRange(location: range.location, length: count + delimiter.utf16.count), delimiter: delimiter))
        }
        // Any policy collision is rejected rather than choosing an arbitrary snippet.
        guard matches.count == 1, let match = matches.first else { return nil }
        // A short abbreviation must not consume the prefix of a longer abbreviation.
        if delimiter.isEmpty, let snippet = library.snippets.first(where: { $0.id == match.snippetID }),
           library.snippets.contains(where: { other in
               other.id != snippet.id && other.abbreviation.count > snippet.abbreviation.count &&
               (policy.caseSensitive ? other.abbreviation.hasPrefix(snippet.abbreviation) :
                   other.abbreviation.lowercased().hasPrefix(snippet.abbreviation.lowercased()))
           }) { return nil }
        return match
    }
}
