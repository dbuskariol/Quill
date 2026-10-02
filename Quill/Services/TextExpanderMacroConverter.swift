import Foundation

enum TextExpanderMacroConverter {
    struct Result { var body: String; var warnings: [String]; var references: [String] }
    static func convert(_ source: String) throws -> Result {
        var remaining = source[...]
        var output = ""; var literal = ""; var warnings: [String] = []; var references: [String] = []
        var unnamed = 0; var macroCount = 0
        let dates = ["Y": "yyyy", "y": "yy", "B": "MMMM", "b": "MMM", "m": "MM", "1m": "M", "A": "EEEE", "a": "EEE", "d": "dd", "e": "d", "H": "HH", "1H": "H", "I": "hh", "1I": "h", "M": "mm", "1M": "m", "S": "ss", "1S": "s", "p": "a"]
        func flush() {
            // Literal foreign {{macros}} must never acquire Quill behavior on import.
            if literal.contains("{{") || literal.contains("}}") { output += "{{literal:\(Data(literal.utf8).base64EncodedString())}}" }
            else { output += literal }
            literal = ""
        }
        func safe(_ value: String) throws -> String {
            guard !value.isEmpty, value.count <= 128, !value.contains("|"), !value.contains("{{"), !value.contains("}}"), !value.contains("="), !value.contains(where: { $0.isNewline }) else {
                throw LibraryError.invalid("A macro name or option cannot be represented in Quill: \(value.prefix(80)).")
            }
            return value
        }
        while let character = remaining.first {
            guard character == "%" else { literal.append(character); remaining = remaining.dropFirst(); continue }
            if remaining.hasPrefix("%%") { literal += "%"; remaining = remaining.dropFirst(2); continue }
            if remaining.hasPrefix("%|") { flush(); output += "{{cursor}}"; remaining = remaining.dropFirst(2); continue }
            let recognized = ["%filltext", "%fillarea", "%fillpopup", "%date:", "%Snippet:", "%snippet:"]
            if recognized.contains(where: { remaining.hasPrefix($0) }) {
                guard let end = remaining.dropFirst().firstIndex(of: "%") else { throw LibraryError.invalid("An unfinished TextExpander macro needs review.") }
                let macro = String(remaining[remaining.index(after: remaining.startIndex)..<end])
                remaining = remaining[remaining.index(after: end)...]
                macroCount += 1
                guard macroCount <= 1000 else { throw LibraryError.invalid("Snippet exceeds 1,000 macros.") }
                flush()
                if macro.hasPrefix("date:") {
                    let format = String(macro.dropFirst(5))
                    guard !format.isEmpty, format.count <= 128, !format.contains("|"), !format.contains("{{"), !format.contains("}}") else { throw LibraryError.invalid("Date format needs manual conversion.") }
                    output += "{{date:\(format)}}"
                    warnings.append("Dates use Quill’s English/POSIX locale and current time zone; review localized formats.")
                } else if macro.lowercased().hasPrefix("snippet:") {
                    let abbreviation = try safe(String(macro.dropFirst(8)))
                    output += "{{snippet:\(abbreviation)}}"; references.append(abbreviation)
                } else {
                    let parts = macro.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
                    let kind = parts[0]
                    var name: String?; var choices: [String] = []
                    for part in parts.dropFirst() {
                        if part.hasPrefix("name=") { name = try safe(String(part.dropFirst(5))) }
                        else if part.hasPrefix("default=") {
                            if kind == "fillpopup" { choices.append(try safe(String(part.dropFirst(8)))) }
                            warnings.append("TextExpander default fill-in values are not preselected; choose or enter values in Quill.")
                        } else if part.hasPrefix("width=") || part.hasPrefix("height=") {
                            warnings.append("Fill-in dimensions use Quill’s native layout.")
                        } else if kind == "fillpopup" { choices.append(try safe(part)) }
                        else { throw LibraryError.invalid("Unsupported fill-in option: \(part.prefix(80)).") }
                    }
                    if name == nil { unnamed += 1; name = "Imported field \(unnamed)" }
                    let field = name!
                    if kind == "fillpopup" {
                        guard !choices.isEmpty, Set(choices).count == choices.count, choices.count <= 100 else { throw LibraryError.invalid("Popup choices are empty, repeated or exceed 100.") }
                        output += "{{input:\(field)|choice|\(choices.joined(separator: "|"))}}"
                    } else { output += "{{input:\(field)|\(kind == "fillarea" ? "multiline" : "single")}}" }
                }
            } else {
                if ["%delay", "%paste", "%fill", "%date", "%Snippet", "%snippet", "%script", "%key", "%clipboard"].contains(where: { remaining.hasPrefix($0) }) {
                    throw LibraryError.invalid("Unsupported or incomplete TextExpander macro near \(remaining.prefix(60)).")
                }
                let suffix = remaining.dropFirst()
                let code = suffix.first == "1" ? String(suffix.prefix(2)) : String(suffix.prefix(1))
                if let format = dates[code] {
                    flush(); output += "{{date:\(format)}}"; remaining = remaining.dropFirst(1 + code.count)
                    warnings.append("Dates use Quill’s English/POSIX locale and current time zone; review localized formats.")
                } else if suffix.first?.isLetter == true || suffix.first.map({ "\\<>^+-".contains($0) }) == true {
                    throw LibraryError.invalid("Unsupported TextExpander macro near \(remaining.prefix(60)). Clipboard, scripts, optional/conditional sections, date math and key actions need manual conversion.")
                } else { literal += "%"; remaining = remaining.dropFirst() }
            }
        }
        flush()
        return Result(body: output, warnings: Array(Set(warnings)).sorted(), references: references)
    }
}
