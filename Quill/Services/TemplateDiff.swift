import Foundation

struct TemplateDiff {
    enum Kind { case unchanged, added, removed }
    struct Line: Identifiable {
        let id: Int
        let kind: Kind
        let text: String
    }
    static func lines(from old: String, to new: String) -> [Line] {
        let a = old.components(separatedBy: "\n"), b = new.components(separatedBy: "\n")
        // Avoid quadratic work for exceptionally large templates; compare complete before/after instead.
        guard a.count <= 1500, b.count <= 1500 else {
            return [.init(id: 0, kind: .removed, text: old), .init(id: 1, kind: .added, text: new)]
        }
        let changes = b.difference(from: a)
        var removed = Set<Int>(), added = Set<Int>()
        for change in changes { switch change { case .remove(let i, _, _): removed.insert(i); case .insert(let i, _, _): added.insert(i) } }
        var result: [Line] = [], i = 0, j = 0
        func append(_ text: String, _ kind: Kind) { result.append(Line(id: result.count, kind: kind, text: text)) }
        while i < a.count || j < b.count {
            if i < a.count && removed.contains(i) { append(a[i], .removed); i += 1 }
            else if j < b.count && added.contains(j) { append(b[j], .added); j += 1 }
            else if i < a.count && j < b.count { append(b[j], .unchanged); i += 1; j += 1 }
            else if i < a.count { append(a[i], .removed); i += 1 }
            else { append(b[j], .added); j += 1 }
        }
        return result
    }
    static func metadata(_ snapshot: TemplateSnapshot, groups: [SnippetGroup] = []) -> String {
        switch snapshot {
        case .snippet(let s): "Title: \(s.title)\nAbbreviation: \(s.abbreviation)\nGroup: \(groups.first { $0.id == s.groupID }?.name ?? "Removed group")\nTags: \(s.tags.joined(separator: ", "))\nFavorite: \(s.isFavorite ? "Yes" : "No")\nFormat: \(s.format.label)"
        case .macro(let m): "Name: \(m.name)\nFormat: \(m.format.label)"
        }
    }
}
