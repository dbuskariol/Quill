import Foundation

indirect enum TemplateToken: Equatable, Sendable {
    case text(String), date, time, field(String), snippet(String), cursor
    case input(TemplateField), formattedDate(String, Int), math(String)
    case macro(String), zendesk(String)
    case conditional(String, String, [TemplateToken], [TemplateToken])
}

struct RenderContext: Sendable {
    var date: Date = .now
    var timeZone: TimeZone = .current
    var fields: [String: String] = [:]
}

struct RenderResult: Equatable, Sendable {
    var text: String
    var cursorUTF16Offset: Int?
    var fields: [String]
    var fieldDefinitions: [TemplateField] = []
    var zendeskPlaceholders: [String] = []
    var format: ContentFormat = .plainText

    func plainTextResult() throws -> RenderResult {
        guard format == .markdown else { return self }
        let document = try MarkdownDocument(text)
        var result = self
        result.text = document.plainText
        result.cursorUTF16Offset = try cursorUTF16Offset.map { try document.plainTextCursorOffset(for: $0) }
        result.format = .plainText
        return result
    }
}

enum TemplateError: LocalizedError, Equatable {
    case invalid(String)
    var errorDescription: String? { if case let .invalid(message) = self { message } else { nil } }
}

enum TemplateRenderer {
    static func parse(_ source: String) throws -> [TemplateToken] {
        guard source.utf16.count <= 1_000_000 else { throw TemplateError.invalid("Template exceeds the safety limit.") }
        var remainder = source[...]
        func section(depth: Int) throws -> (tokens: [TemplateToken], ending: String?) {
            guard depth <= 32 else { throw TemplateError.invalid("Conditional nesting exceeds 32 levels.") }
            var tokens: [TemplateToken] = []
            while let start = remainder.range(of: "{{") {
                tokens.append(.text(String(remainder[..<start.lowerBound])))
                guard let end = remainder[start.upperBound...].range(of: "}}") else { throw TemplateError.invalid("Close the macro with }}.") }
                let name = String(remainder[start.upperBound..<end.lowerBound])
                remainder = remainder[end.upperBound...]
                if name == "else" || name == "end" { return (tokens, name) }
                switch name {
                case "date": tokens.append(.date)
                case "time": tokens.append(.time)
                case "cursor": tokens.append(.cursor)
                default:
                    if name.hasPrefix("literal:") {
                        guard let data = Data(base64Encoded: String(name.dropFirst(8))), let value = String(data: data, encoding: .utf8) else { throw TemplateError.invalid("Invalid literal text encoding.") }
                        tokens.append(.text(value))
                    } else if name.hasPrefix("if:") {
                        let condition = String(name.dropFirst(3)).split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                        guard condition.count == 2, !condition[0].isEmpty else { throw TemplateError.invalid("Condition syntax: {{if:name=value}}.") }
                        let yes = try section(depth: depth + 1)
                        let no = yes.ending == "else" ? try section(depth: depth + 1) : (tokens: [], ending: yes.ending)
                        guard no.ending == "end" else { throw TemplateError.invalid("Close conditional sections with {{end}}.") }
                        tokens.append(.conditional(String(condition[0]), String(condition[1]), yes.tokens, no.tokens))
                    } else if name.hasPrefix("input:") {
                        let parts = String(name.dropFirst(6)).split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                        guard parts.count >= 2, !parts[0].isEmpty, parts[0].count <= 128 else { throw TemplateError.invalid("Input syntax: {{input:name|kind}}.") }
                        let kind: TemplateField.Kind
                        switch parts[1] {
                        case "single" where parts.count == 2: kind = .singleLine
                        case "multiline" where parts.count == 2: kind = .multiline
                        case "optional" where parts.count == 2: kind = .optional
                        case "choice" where parts.count >= 3 && parts.count <= 102 && parts.dropFirst(2).allSatisfy({ !$0.isEmpty }) && Set(parts.dropFirst(2)).count == parts.count - 2: kind = .choice(Array(parts.dropFirst(2)))
                        case "date" where parts.count == 3 && !parts[2].isEmpty && parts[2].count <= 128: kind = .date(parts[2])
                        default: throw TemplateError.invalid("Unsupported input kind or options: \(name).")
                        }
                        tokens.append(.input(TemplateField(name: parts[0], kind: kind)))
                    } else if name.hasPrefix("date:") {
                        let parts = String(name.dropFirst(5)).split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                        guard (1...2).contains(parts.count), !parts[0].isEmpty, parts[0].count <= 128 else { throw TemplateError.invalid("Date syntax: {{date:format|day-offset}}.") }
                        let offset = parts.count == 2 ? Int(parts[1]) : 0
                        guard let offset, (-36_600...36_600).contains(offset) else { throw TemplateError.invalid("Date offset must be between -36600 and 36600 days.") }
                        tokens.append(.formattedDate(parts[0], offset))
                    } else if name.hasPrefix("math:"), name.count > 5 { tokens.append(.math(String(name.dropFirst(5)))) }
                    else if name.hasPrefix("field:"), name.count > 6 { tokens.append(.field(String(name.dropFirst(6)))) }
                    else if name.hasPrefix("snippet:"), name.count > 8 { tokens.append(.snippet(String(name.dropFirst(8)))) }
                    else if name.hasPrefix("macro:"), name.count > 6 { tokens.append(.macro(String(name.dropFirst(6)))) }
                    else if ZendeskPlaceholder.isExpression(name) { tokens.append(.zendesk(name)) }
                    else { throw TemplateError.invalid("Unknown macro: {{\(name)}}.") }
                }
            }
            if remainder.contains("}}") { throw TemplateError.invalid("Unexpected macro closing delimiter.") }
            tokens.append(.text(String(remainder)))
            remainder = ""[...]
            return (tokens, nil)
        }
        let result = try section(depth: 0)
        guard result.ending == nil else { throw TemplateError.invalid("Unexpected conditional delimiter.") }
        return result.tokens
    }

    static func render(_ snippet: Snippet, library: Library, context: RenderContext = .init()) throws -> RenderResult {
        var fields: [String] = []
        var definitions: [TemplateField] = []
        var cursor: Int?
        var output = ""
        func register(_ field: TemplateField) throws {
            if let existing = definitions.first(where: { $0.name == field.name }) {
                guard existing == field else { throw TemplateError.invalid("Conflicting definitions for field \(field.name).") }
            } else {
                guard fields.count < 100 || fields.contains(field.name) else { throw TemplateError.invalid("Templates support up to 100 fields.") }
                definitions.append(field); if !fields.contains(field.name) { fields.append(field.name) }
            }
        }
        func formatDate(_ date: Date, format: String) -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = context.timeZone; formatter.dateFormat = format
            return formatter.string(from: date)
        }
        func expand(_ item: Snippet, stack: Set<UUID>, destinationFormat: ContentFormat) throws {
            guard !stack.contains(item.id), stack.count < 32 else { throw TemplateError.invalid("Nested snippet cycle or depth limit reached at \(item.title).") }
            let next = stack.union([item.id])
            let startOffset = output.utf16.count
            try expandTokens(parse(item.body), stack: next, format: item.format)
            if item.format != destinationFormat {
                let start = String.Index(utf16Offset: startOffset, in: output)
                let segment = String(output[start...])
                let converted = item.format == .markdown ? try MarkdownDocument(segment).plainText : MarkdownDocument.escapeLiteral(segment)
                if let offset = cursor, offset >= startOffset {
                    let prefix = (segment as NSString).substring(to: offset - startOffset)
                    cursor = startOffset + (item.format == .markdown ? try MarkdownDocument(prefix).plainText : MarkdownDocument.escapeLiteral(prefix)).utf16.count
                }
                output.replaceSubrange(start..., with: converted)
            }
        }
        func expandTokens(_ tokens: [TemplateToken], stack: Set<UUID>, format: ContentFormat) throws {
            func literal(_ value: String) -> String { format == .markdown ? MarkdownDocument.escapeLiteral(value) : value }
            for token in tokens {
                switch token {
                case let .text(value): output += value
                case .date, .time:
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.timeZone = context.timeZone
                    formatter.dateFormat = token == .date ? "yyyy-MM-dd" : "HH:mm"
                    output += formatter.string(from: context.date)
                case let .field(name):
                    try register(TemplateField(name: name))
                    output += literal(context.fields[name] ?? "‹\(name)›")
                case let .input(field):
                    try register(field)
                    let value = context.fields[field.name] ?? ""
                    switch field.kind {
                    case let .choice(choices):
                        guard value.isEmpty || choices.contains(value) else { throw TemplateError.invalid("Choose a listed value for \(field.name).") }
                        output += literal(value.isEmpty ? "‹\(field.name)›" : value)
                    case let .date(format):
                        if value.isEmpty { output += "‹\(field.name)›" }
                        else {
                            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = context.timeZone
                            formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
                            guard let date = formatter.date(from: value), formatter.string(from: date) == value else { throw TemplateError.invalid("Choose a valid date for \(field.name).") }
                            output += formatDate(date, format: format)
                        }
                    case .optional: output += literal(value)
                    case .singleLine, .multiline: output += literal(value.isEmpty ? "‹\(field.name)›" : value)
                    }
                case let .formattedDate(format, offset):
                    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = context.timeZone
                    guard let date = calendar.date(byAdding: .day, value: offset, to: context.date) else { throw TemplateError.invalid("Date offset could not be resolved.") }
                    output += formatDate(date, format: format)
                case let .math(expression): output += try ArithmeticEvaluator.evaluate(expression)
                case let .conditional(name, expected, yes, no):
                    if !fields.contains(name) {
                        guard fields.count < 100 else { throw TemplateError.invalid("Templates support up to 100 fields.") }
                        fields.append(name)
                    }
                    try expandTokens(context.fields[name] == expected ? yes : no, stack: stack, format: format)
                case .cursor:
                    guard cursor == nil else { throw TemplateError.invalid("Use only one cursor marker in the resolved template.") }
                    cursor = output.utf16.count
                case let .snippet(abbreviation):
                    let matches = library.snippets.filter { $0.abbreviation == abbreviation }
                    guard matches.count == 1, let nested = matches.first else { throw TemplateError.invalid("Nested abbreviation \(abbreviation) is missing or ambiguous.") }
                    try expand(nested, stack: stack, destinationFormat: format)
                case let .macro(name):
                    let matches = library.macros.filter { $0.name == name }
                    guard matches.count == 1, let macro = matches.first else { throw TemplateError.invalid("Custom macro \(name) is missing or ambiguous.") }
                    try expand(Snippet(id: macro.id, groupID: itemGroupID(library), title: macro.name, abbreviation: "", body: macro.body, format: macro.format), stack: stack, destinationFormat: format)
                case let .zendesk(name):
                    output += "{{\(name)}}"
                }
                guard output.utf16.count <= 1_000_000 else { throw TemplateError.invalid("Resolved template exceeds the safety limit.") }
            }
        }
        try expand(snippet, stack: [], destinationFormat: snippet.format)
        return RenderResult(text: output, cursorUTF16Offset: cursor, fields: fields.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }, fieldDefinitions: definitions, zendeskPlaceholders: ZendeskPlaceholder.expressions(in: output), format: snippet.format)
    }

    static func conflicts(for item: Snippet, in library: Library) -> [Snippet] {
        library.snippets.filter { $0.id != item.id && !$0.abbreviation.isEmpty && $0.abbreviation == item.abbreviation }
    }
    private static func itemGroupID(_ library: Library) -> UUID { library.groups.first?.id ?? UUID() }
}
