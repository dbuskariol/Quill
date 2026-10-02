import Foundation

/// One catalog powers explicit insertion and native text completion in every template editor.
struct TemplateCompletion {
    struct Item: Identifiable, Equatable {
        let label: String
        let expression: String
        var id: String { expression }
        var token: String { "{{\(expression)}}" }
    }
    static let builtins: [Item] = [
        .init(label: "Date", expression: "date"),
        .init(label: "Time", expression: "time"),
        .init(label: "Fill-in Field", expression: "field:name"),
        .init(label: "Multiline Field", expression: "input:notes|multiline"),
        .init(label: "Popup Choice", expression: "input:tone|choice|Formal|Friendly"),
        .init(label: "Optional Field", expression: "input:extra|optional"),
        .init(label: "Date Picker", expression: "input:day|date|yyyy-MM-dd"),
        .init(label: "Date in Seven Days", expression: "date:yyyy-MM-dd|7"),
        .init(label: "Arithmetic", expression: "math:(2+3)*4"),
        .init(label: "Cursor Position", expression: "cursor")
    ]
    static let conditional = "{{if:tone=Formal}}Hello{{else}}Hi{{end}}"

    struct Context: Equatable {
        /// Everything after the opening braces, up to the caret (UTF-16, as used by AppKit).
        let range: NSRange
        let query: String
        let closingBraces: Bool
    }
    static func context(in text: String, selection: NSRange) -> Context? {
        let value = text as NSString
        guard selection.length == 0, selection.location >= 0, selection.location != NSNotFound, selection.location <= value.length else { return nil }
        // Completion never crosses a paragraph or a closed/foreign brace expression.
        let scanStart = max(0, selection.location - 258)
        let before = value.substring(with: NSRange(location: scanStart, length: selection.location - scanStart))
        guard let opening = before.range(of: "{{", options: .backwards) else { return nil }
        let query = String(before[opening.upperBound...])
        guard query.utf16.count <= 256, !query.contains(where: { $0 == "{" || $0 == "}" || $0.isNewline }), !query.contains("|") else { return nil }
        let start = selection.location - query.utf16.count
        let after = value.substring(from: selection.location)
        let hasClosing = after.hasPrefix("}}")
        // Do not insert a second token terminator into the middle of an existing expression.
        if !hasClosing, let closing = after.range(of: "}}") {
            let tail = after[..<closing.lowerBound]
            if !tail.contains("{{"), !tail.contains(where: { $0.isNewline }) { return nil }
        }
        return Context(range: NSRange(location: start, length: query.utf16.count), query: query, closingBraces: hasClosing)
    }

    static func suggestions(for context: Context, library: Library, excludingSnippet: UUID? = nil, excludingMacro: UUID? = nil) -> [String] {
        var query = context.query.trimmingCharacters(in: .whitespaces)
        // Dot is a discovery alias; persisted Quill references retain their canonical colon syntax.
        for namespace in ["macro", "snippet"] {
            if query.lowercased().hasPrefix(namespace + ".") { query = namespace + ":" + query.dropFirst(namespace.count + 1) }
        }
        let suffix = context.closingBraces ? "" : "}}"
        // Keep the opening menu compact; typing any prefix searches the full catalog.
        if query.isEmpty {
            return ["date" + suffix, "time" + suffix, "field:name" + suffix, "input:notes|multiline" + suffix,
                    "cursor" + suffix, "macro:", "snippet:", "ticket.", "current_user."]
        }
        var candidates: [String] = []
        if !query.contains(":"), !query.contains(".") { candidates += ["macro:", "snippet:"] }
        candidates += builtins.map { $0.expression + suffix }
        candidates += [String(conditional.dropFirst(2).dropLast(2)) + suffix, "else" + suffix, "end" + suffix]
        candidates += ZendeskPlaceholder.common.map { $0.name + suffix }
        let prefix = query.lowercased()
        if "macro:".hasPrefix(prefix) || prefix.hasPrefix("macro:") {
            candidates += availableMacros(in: library, excluding: excludingMacro).map { "macro:" + $0.name + suffix }
        }
        if "snippet:".hasPrefix(prefix) || prefix.hasPrefix("snippet:") {
            candidates += availableSnippets(in: library, excluding: excludingSnippet).map { "snippet:" + $0.abbreviation + suffix }
        }
        var seen = Set<String>()
        return Array(candidates.filter { $0.lowercased().hasPrefix(prefix) && seen.insert($0).inserted }.prefix(60))
    }
    static func availableMacros(in library: Library, excluding id: UUID? = nil) -> [CustomMacro] {
        library.macros.filter { $0.id != id }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    static func availableSnippets(in library: Library, excluding id: UUID? = nil) -> [Snippet] {
        let counts = Dictionary(grouping: library.snippets.filter { !$0.abbreviation.isEmpty }, by: \.abbreviation)
        return library.snippets.filter { $0.id != id && !$0.abbreviation.isEmpty && counts[$0.abbreviation]?.count == 1 }
            .sorted { $0.abbreviation.localizedStandardCompare($1.abbreviation) == .orderedAscending }
    }

}
