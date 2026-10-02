import Foundation

/// Foundation parses Markdown; this adapter produces a safe, local semantic document.
/// HTML is generated from allowed elements, never imported or executed from the source.
struct MarkdownDocument: Sendable {
    struct Run: Sendable {
        let text: String
        let path: [PresentationIntent.IntentType]
        let bold: Bool
        let italic: Bool
        let code: Bool
        let strike: Bool
        let link: URL?
    }
    let runs: [Run]
    let warnings: [String]
    init(_ source: String) throws {
        guard source.utf16.count <= 1_000_000 else { throw TemplateError.invalid("Formatted content exceeds the safety limit.") }
        // Tokens must survive Markdown underscores, pipes, quotes and filters unchanged.
        var masked = source
        var literals: [String: (text: String, code: String)] = [:]
        let prefix = "QuillLiteral" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let regex = try NSRegularExpression(pattern: #"\{\{[^{}]*\}\}|(?<!\\)<[^>\n]+>"#)
        for (index, match) in regex.matches(in: masked, range: NSRange(masked.startIndex..., in: masked)).enumerated().reversed() {
            guard let range = Range(match.range, in: masked) else { continue }
            let marker = prefix + "n\(index)z"
            let value = String(masked[range])
            // Let safe Markdown autolinks use Foundation's native link parsing.
            if value.hasPrefix("<"), let url = URL(string: String(value.dropFirst().dropLast())), Self.safeLink(url) { continue }
            literals[marker] = (value, value); masked.replaceSubrange(range, with: marker)
        }
        // Foundation's URL detector retains backslash escapes inside bare URLs.
        // Mask those literals before parsing, but preserve source bytes inside code.
        let escapedURL = try NSRegularExpression(pattern: #"https?://[^\s<>`]+"#)
        let punctuation = try NSRegularExpression(pattern: ##"\\([!\"#$%&'()*+,\-./:;<=>?@\[\\\]\^_`{|}~])"##)
        for (index, match) in escapedURL.matches(in: masked, range: NSRange(masked.startIndex..., in: masked)).enumerated().reversed() {
            guard let range = Range(match.range, in: masked) else { continue }
            let original = String(masked[range])
            guard original.contains("\\") else { continue }
            let marker = prefix + "url\(index)z"
            let decoded = punctuation.stringByReplacingMatches(in: original, range: NSRange(original.startIndex..., in: original), withTemplate: "$1")
            literals[marker] = (decoded, original); masked.replaceSubrange(range, with: marker)
        }
        let parsed = try AttributedString(markdown: masked, options: .init(interpretedSyntax: .full))
        var result: [Run] = [], issues: Set<String> = []
        for run in parsed.runs {
            var text = String(parsed.characters[run.range])
            let intent = run.inlinePresentationIntent ?? []
            let isCode = intent.contains(.code) || (run.presentationIntent?.components.contains { if case .codeBlock = $0.kind { true } else { false } } ?? false)
            for (marker, value) in literals {
                if !isCode && value.text.hasPrefix("<") && text.contains(marker) { issues.insert("Raw HTML is shown as literal text. Use Markdown formatting instead.") }
                text = text.replacingOccurrences(of: marker, with: isCode ? value.code : value.text)
            }
            var link = run.link
            if let image = run.imageURL {
                issues.insert("Images appear as descriptive links. Inline image attachments are not supported yet.")
                link = image; if text.isEmpty { text = "Image" }
            }
            if let url = link, !Self.safeLink(url) { issues.insert("An unsupported link was kept as text."); link = nil }
            let path = Array((run.presentationIntent?.components ?? []).reversed())
            if path.contains(where: { switch $0.kind { case .table, .tableCell, .tableHeaderRow, .tableRow: true; default: false } }) {
                issues.insert("Tables have limited native preview support. Check the copied result in Zendesk.")
            }
            result.append(Run(text: text, path: path, bold: intent.contains(.stronglyEmphasized), italic: intent.contains(.emphasized), code: intent.contains(.code), strike: intent.contains(.strikethrough), link: link))
        }
        runs = result; warnings = issues.sorted()
    }
    static func safeLink(_ url: URL) -> Bool { ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") }
    static func escapeHTML(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#39;")
    }
    static func escapeLiteral(_ value: String) -> String {
        // Preserve Zendesk expressions while escaping Markdown-significant literal content.
        var result = "", remainder = value[...]
        while let start = remainder.range(of: "{{"), let end = remainder[start.upperBound...].range(of: "}}") {
            result += escapeCharacters(String(remainder[..<start.lowerBound]))
            result += String(remainder[start.lowerBound..<end.upperBound]); remainder = remainder[end.upperBound...]
        }
        return result + escapeCharacters(String(remainder))
    }
    private static func escapeCharacters(_ value: String) -> String { value.map { "\\`*_[]()#!+-.~><&".contains($0) ? "\\\($0)" : String($0) }.joined() }
    var html: String {
        var result = "", path: [PresentationIntent.IntentType] = []
        for run in runs {
            let shared = zip(path, run.path).prefix { $0.identity == $1.identity }.count
            for element in path.dropFirst(shared).reversed() { result += Self.tags(element.kind).close }
            for element in run.path.dropFirst(shared) { result += Self.tags(element.kind).open }
            var text = Self.escapeHTML(run.text).replacingOccurrences(of: "\n", with: run.path.contains(where: { if case .codeBlock = $0.kind { true } else { false } }) ? "\n" : "<br>")
            if run.code { text = "<code>\(text)</code>" }
            if run.bold { text = "<strong>\(text)</strong>" }
            if run.italic { text = "<em>\(text)</em>" }
            if run.strike { text = "<s>\(text)</s>" }
            if let link = run.link { text = "<a href=\"\(Self.escapeHTML(link.absoluteString))\">\(text)</a>" }
            result += text; path = run.path
        }
        for element in path.reversed() { result += Self.tags(element.kind).close }
        return "<!DOCTYPE html><html><head><meta charset=\"utf-8\"></head><body>\(result)</body></html>"
    }
    private static func tags(_ kind: PresentationIntent.Kind) -> (open: String, close: String) {
        switch kind {
        case .paragraph: ("<p>", "</p>")
        case .header(let level): ("<h\(max(1,min(6,level)))>", "</h\(max(1,min(6,level)))>")
        case .orderedList: ("<ol>", "</ol>")
        case .unorderedList: ("<ul>", "</ul>")
        case .listItem: ("<li>", "</li>")
        case .blockQuote: ("<blockquote>", "</blockquote>")
        case .codeBlock: ("<pre><code>", "</code></pre>")
        case .thematicBreak: ("<hr>", "")
        case .table: ("<table>", "</table>")
        case .tableHeaderRow, .tableRow: ("<tr>", "</tr>")
        case .tableCell: ("<td>", "</td>")
        @unknown default: ("", "")
        }
    }
    struct Segment: Sendable { let text: String; let run: Run }
    var segments: [Segment] {
        var result: [Segment] = [], leaf: Int?
        for run in runs {
            var prefix = ""
            let current = run.path.last?.identity
            if leaf != nil && current != leaf { prefix = "\n" }
            if current != leaf, let item = run.path.last(where: { if case .listItem = $0.kind { true } else { false } }), case .listItem(let ordinal) = item.kind {
                let depth = run.path.filter { if case .listItem = $0.kind { true } else { false } }.count
                let ordered = run.path.dropLast().last(where: { $0.kind == .orderedList || $0.kind == .unorderedList })?.kind == .orderedList
                prefix += String(repeating: "  ", count: max(0, depth-1)) + (ordered ? "\(ordinal). " : "• ")
            }
            result.append(Segment(text: prefix + run.text, run: run)); leaf = current
        }
        return result
    }
    var plainText: String { segments.map(\.text).joined() }
}
