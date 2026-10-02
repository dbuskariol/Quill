import Foundation

struct ExpansionPolicy: Codable, Equatable, Sendable {
    var delimiters = " \t\n"
    var caseSensitive = true
    var requiresWordBoundary = true
    var excludedBundleIDs = ["com.agilebits.onepassword7", "com.1password.1password", "com.apple.Terminal", "com.googlecode.iterm2"]
    var allowedBundleIDs: [String] = []
    func allows(_ bundleID: String) -> Bool {
        !bundleID.isEmpty && !excludedBundleIDs.contains(bundleID) && allowedBundleIDs.contains(bundleID)
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
        guard let last = prefix.last, policy.delimiters.contains(last) else { return nil }
        let delimiter = String(last)
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
        return matches.count == 1 ? matches[0] : nil
    }
}
