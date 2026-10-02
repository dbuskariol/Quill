import Foundation

struct TextExpanderImportRow: Identifiable, Sendable {
    let id = UUID()
    var sourceFile: String
    var groupName: String
    var title: String
    var abbreviation: String
    var original: String
    var converted: String?
    var warnings: [String]
    var problem: String?
    var references: [String] = []
}

struct TextExpanderImportPlan: Sendable {
    var rows: [TextExpanderImportRow]
    var notices: [String]
}

enum TextExpanderConflictPolicy: String, CaseIterable, Identifiable {
    case skip = "Skip conflicts", replace = "Replace existing"
    var id: Self { self }
}

enum TextExpanderImporter {
    static let maximumBytes = 50_000_000
    static let maximumRows = 10_000

    // Called from a detached task: importing never runs a script or decodes an object archive.
    static func read(_ urls: [URL]) throws -> TextExpanderImportPlan {
        guard !urls.isEmpty, urls.count <= 100 else { throw LibraryError.invalid("Choose between 1 and 100 export files.") }
        var plan = TextExpanderImportPlan(rows: [], notices: ["Imports add groups to your library. TextExpander app rules, sharing and expansion preferences are not imported."])
        var total = 0
        for url in urls {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? maximumBytes + 1
            guard size <= maximumBytes - total else { throw LibraryError.invalid("Selected exports exceed 50 MB.") }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            total += data.count
            guard total <= maximumBytes else { throw LibraryError.invalid("Selected exports exceed 50 MB.") }
            let result = try parse(data, fileName: url.lastPathComponent)
            plan.rows += result.rows; plan.notices += result.notices
            guard plan.rows.count <= maximumRows else { throw LibraryError.invalid("Imports support up to 10,000 snippets at once.") }
        }
        plan.notices = Array(Set(plan.notices)).sorted()
        return plan
    }

    static func parse(_ data: Data, fileName: String) throws -> TextExpanderImportPlan {
        guard data.count <= maximumBytes else { throw LibraryError.invalid("Export exceeds 50 MB.") }
        let name = (fileName as NSString).deletingPathExtension
        var rows: [TextExpanderImportRow] = []
        var notices: [String] = []
        if (fileName as NSString).pathExtension.lowercased() == "csv" {
            let text: String?
            if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) { text = String(data: data, encoding: .utf16) }
            else { text = String(data: data, encoding: .utf8) }
            guard var text else { throw LibraryError.invalid("\(fileName): use a UTF-8 or BOM-marked UTF-16 CSV export.") }
            if text.first == "\u{FEFF}" { text.removeFirst() }
            let records = try CSVRecords.parse(text)
            guard let header = records.first else { throw LibraryError.invalid("\(fileName) is empty.") }
            let columns = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            guard Set(columns).count == columns.count, let abbreviation = columns.firstIndex(of: "abbreviation"), let body = columns.firstIndex(of: "snippet") else {
                throw LibraryError.invalid("\(fileName): expected unique abbreviation and snippet column headers, with an optional label column.")
            }
            let label = columns.firstIndex(of: "label")
            if columns.contains(where: { !["abbreviation", "snippet", "label"].contains($0) }) { notices.append("\(fileName): extra CSV columns are not imported.") }
            for (index, record) in records.dropFirst().enumerated() {
                if record.allSatisfy(\.isEmpty) { continue }
                guard record.count == columns.count else { throw LibraryError.invalid("\(fileName): record \(index + 2) has \(record.count) columns; expected \(columns.count).") }
                rows.append(row(file: fileName, group: name, title: label.map { record[$0] } ?? "", abbreviation: record[abbreviation], body: record[body]))
            }
            notices.append("CSV does not carry reliable content-type or group-rule metadata. Review scripts, markup and converted dates before importing.")
        } else {
            let value = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let root = value as? [String: Any], let info = root["groupInfo"] as? [String: Any], let snippets = root["snippetsTE2"] as? [[String: Any]] else {
                throw LibraryError.invalid("\(fileName): unsupported TextExpander file. Choose a group export with groupInfo/snippetsTE2, or export CSV from TextExpander.com.")
            }
            let group = (info["groupName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? name
            guard snippets.count <= maximumRows else { throw LibraryError.invalid("Export exceeds 10,000 snippets.") }
            for snippet in snippets {
                guard let abbreviation = snippet["abbreviation"] as? String, let body = snippet["plainText"] as? String, let type = snippet["snippetType"] as? Int else {
                    throw LibraryError.invalid("\(fileName): a snippet is missing abbreviation, plainText or snippetType.")
                }
                var item = row(file: fileName, group: group, title: snippet["label"] as? String ?? "", abbreviation: abbreviation, body: body)
                if type == 1 { item.warnings.append("Rich text becomes plain text. Formatting, links and images are not preserved.") }
                else if type != 0 { item.problem = "Script or unsupported content type (\(type)) cannot be imported as an executable snippet."; item.converted = nil }
                if let mode = snippet["abbreviationMode"] as? Int, mode != 0 { item.warnings.append("Per-snippet case behavior is not imported; Quill’s matching policy applies.") }
                rows.append(item)
            }
            notices.append("Legacy group preferences, prefixes, delimiters and app restrictions are not carried over; review abbreviations and Quill’s expansion policy.")
        }
        guard !rows.isEmpty, rows.count <= maximumRows else { throw LibraryError.invalid("Export has no snippets, or exceeds 10,000 snippets.") }
        return TextExpanderImportPlan(rows: rows, notices: notices)
    }

    private static func row(file: String, group: String, title: String, abbreviation: String, body: String) -> TextExpanderImportRow {
        let label = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var item = TextExpanderImportRow(sourceFile: file, groupName: group, title: label.isEmpty ? (abbreviation.isEmpty ? "Untitled snippet" : abbreviation) : label, abbreviation: abbreviation, original: body, warnings: [])
        do {
            guard abbreviation.utf16.count <= 128, !abbreviation.contains(where: { $0.isNewline }) else { throw LibraryError.invalid("Abbreviation is longer than 128 characters or contains a line break.") }
            guard body.utf16.count <= 1_000_000 else { throw LibraryError.invalid("Snippet exceeds one million characters.") }
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.hasPrefix("#!") else { throw LibraryError.invalid("This looks like a script. Script execution is not supported.") }
            if trimmed.range(of: #"(?i)<(?:html|body|div|p|br|span|img|a|b|strong)(?:\s|>|/)"#, options: .regularExpression) != nil {
                throw LibraryError.invalid("HTML content needs a plain-text export; markup is not silently stripped.")
            }
            let result = try TextExpanderMacroConverter.convert(body)
            item.converted = result.body; item.warnings = result.warnings; item.references = result.references
            _ = try TemplateRenderer.parse(result.body)
            if abbreviation.isEmpty { item.warnings.append("No abbreviation: available in the library and Quick Actions only.") }
        } catch { item.problem = error.localizedDescription }
        return item
    }

    // Build against current library at confirmation, rather than trusting an old preview.
    static func merge(_ plan: TextExpanderImportPlan, selected: Set<UUID>, into library: Library, policy: TextExpanderConflictPolicy) throws -> (library: Library, imported: Int, skipped: Int) {
        var result = library
        var groups: [String: UUID] = [:]
        var importedIDs: Set<UUID> = []
        var importedRows: [TextExpanderImportRow] = []
        var skipped = 0
        var seen: Set<String> = []
        var indicesByKey: [String: [Int]] = [:]
        for index in result.snippets.indices where !result.snippets[index].abbreviation.isEmpty {
            indicesByKey[result.snippets[index].abbreviation.lowercased(), default: []].append(index)
        }
        for row in plan.rows where selected.contains(row.id) {
            guard let body = row.converted, row.problem == nil else { throw LibraryError.invalid("\(row.title) cannot be converted.") }
            let key = row.abbreviation.lowercased()
            let matches = (indicesByKey[key] ?? []).map { result.snippets[$0] }
            if !key.isEmpty && (seen.contains(key) || (!matches.isEmpty && policy == .skip)) { skipped += 1; continue }
            guard matches.count <= 1 else { throw LibraryError.invalid("\(row.abbreviation) matches multiple existing snippets. Resolve that conflict before replacing.") }
            if !key.isEmpty { seen.insert(key) }
            let groupKey = row.sourceFile + "\u{0}" + row.groupName
            let groupID: UUID
            if let existing = groups[groupKey] { groupID = existing }
            else {
                var name = row.groupName.isEmpty ? "TextExpander" : row.groupName
                let base = name; var suffix = 2
                while result.groups.contains(where: { $0.name == name }) { name = "\(base) (\(suffix))"; suffix += 1 }
                let group = SnippetGroup(name: name)
                result.groups.append(group); groups[groupKey] = group.id; groupID = group.id
            }
            if let existing = matches.first, policy == .replace {
                let index = indicesByKey[key]!.first!
                // Preserve identifiers so existing Quill references/drafts do not lose identity.
                result.snippets[index] = Snippet(id: existing.id, groupID: groupID, title: row.title, abbreviation: row.abbreviation, body: body, tags: existing.tags, isFavorite: existing.isFavorite)
                importedIDs.insert(existing.id)
            } else {
                let item = Snippet(groupID: groupID, title: row.title, abbreviation: row.abbreviation, body: body)
                if !key.isEmpty { indicesByKey[key, default: []].append(result.snippets.count) }
                result.snippets.append(item); importedIDs.insert(item.id)
            }
            importedRows.append(row)
        }
        let referenceCounts = result.snippets.reduce(into: [String: Int]()) { $0[$1.abbreviation, default: 0] += 1 }
        for row in importedRows {
            for reference in row.references {
                guard referenceCounts[reference] == 1 else { throw LibraryError.invalid("\(row.title) references \(reference), which is missing or ambiguous. Include its snippet or resolve the conflict.") }
            }
        }
        // Rendering detects reference cycles and field/schema errors before any write.
        for item in result.snippets where importedIDs.contains(item.id) { _ = try TemplateRenderer.render(item, library: result) }
        try result.validate()
        return (result, importedIDs.count, skipped)
    }
}

private enum CSVRecords {
    static func parse(_ text: String) throws -> [[String]] {
        let values = Array(text.unicodeScalars)
        var records: [[String]] = []; var record: [String] = []; var field = ""
        var quoted = false; var closed = false; var index = 0; var fieldUnits = 0
        func finishField() { record.append(field); field = ""; closed = false; fieldUnits = 0 }
        func finishRecord() throws {
            finishField(); records.append(record); record = []
            guard records.count <= TextExpanderImporter.maximumRows + 1 else { throw LibraryError.invalid("CSV exceeds 10,000 records.") }
        }
        while index < values.count {
            let scalar = values[index]
            if quoted {
                if scalar == "\"" {
                    if index + 1 < values.count, values[index + 1] == "\"" { field.append("\""); index += 1 }
                    else { quoted = false; closed = true }
                } else { field.unicodeScalars.append(scalar) }
            } else if scalar == "," { finishField() }
            else if scalar == "\r" || scalar == "\n" {
                try finishRecord()
                if scalar == "\r", index + 1 < values.count, values[index + 1] == "\n" { index += 1 }
            } else if scalar == "\"", field.isEmpty, !closed { quoted = true }
            else {
                guard !closed, scalar != "\"" else { throw LibraryError.invalid("Malformed CSV quotation near record \(records.count + 1).") }
                field.unicodeScalars.append(scalar)
            }
            fieldUnits += scalar.value > 0xFFFF ? 2 : 1
            guard fieldUnits <= 1_000_000, record.count <= 100 else { throw LibraryError.invalid("CSV field or column count exceeds the import limit.") }
            index += 1
        }
        guard !quoted else { throw LibraryError.invalid("CSV has an unclosed quoted field.") }
        if !field.isEmpty || !record.isEmpty || closed { try finishRecord() }
        return records
    }
}
