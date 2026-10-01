import Foundation

enum TemplateToken: Equatable, Sendable {
    case text(String), date, time, field(String), snippet(String), cursor
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
}

enum TemplateError: LocalizedError, Equatable {
    case invalid(String)
    var errorDescription: String? { if case let .invalid(message) = self { message } else { nil } }
}

enum TemplateRenderer {
    static func parse(_ source: String) throws -> [TemplateToken] {
        var remainder = source[...]
        var tokens: [TemplateToken] = []
        while let start = remainder.range(of: "{{") {
            tokens.append(.text(String(remainder[..<start.lowerBound])))
            guard let end = remainder[start.upperBound...].range(of: "}}") else {
                throw TemplateError.invalid("Close the macro with }}.")
            }
            let name = String(remainder[start.upperBound..<end.lowerBound])
            switch name {
            case "date": tokens.append(.date)
            case "time": tokens.append(.time)
            case "cursor": tokens.append(.cursor)
            default:
                if name.hasPrefix("field:"), name.count > 6 { tokens.append(.field(String(name.dropFirst(6)))) }
                else if name.hasPrefix("snippet:"), name.count > 8 { tokens.append(.snippet(String(name.dropFirst(8)))) }
                else { throw TemplateError.invalid("Unknown macro: {{\(name)}}.") }
            }
            remainder = remainder[end.upperBound...]
        }
        if remainder.contains("}}") { throw TemplateError.invalid("Unexpected macro closing delimiter.") }
        tokens.append(.text(String(remainder)))
        return tokens
    }

    static func render(_ snippet: Snippet, library: Library, context: RenderContext = .init()) throws -> RenderResult {
        var fields: [String] = []
        var cursor: Int?
        var output = ""
        func expand(_ item: Snippet, stack: Set<UUID>) throws {
            guard !stack.contains(item.id), stack.count < 32 else { throw TemplateError.invalid("Nested snippet cycle or depth limit reached at \(item.title).") }
            let next = stack.union([item.id])
            for token in try parse(item.body) {
                switch token {
                case let .text(value): output += value
                case .date, .time:
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.timeZone = context.timeZone
                    formatter.dateFormat = token == .date ? "yyyy-MM-dd" : "HH:mm"
                    output += formatter.string(from: context.date)
                case let .field(name):
                    if !fields.contains(name) { fields.append(name) }
                    output += context.fields[name] ?? "‹\(name)›"
                case .cursor:
                    guard cursor == nil else { throw TemplateError.invalid("Use only one cursor marker in the resolved template.") }
                    cursor = output.utf16.count
                case let .snippet(abbreviation):
                    let matches = library.snippets.filter { $0.abbreviation == abbreviation }
                    guard matches.count == 1, let nested = matches.first else { throw TemplateError.invalid("Nested abbreviation \(abbreviation) is missing or ambiguous.") }
                    try expand(nested, stack: next)
                }
                guard output.utf16.count <= 1_000_000 else { throw TemplateError.invalid("Resolved template exceeds the safety limit.") }
            }
        }
        try expand(snippet, stack: [])
        return RenderResult(text: output, cursorUTF16Offset: cursor, fields: fields)
    }

    static func conflicts(for item: Snippet, in library: Library) -> [Snippet] {
        library.snippets.filter { $0.id != item.id && !$0.abbreviation.isEmpty && $0.abbreviation == item.abbreviation }
    }
}
