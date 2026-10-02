import Foundation

struct SnippetGroup: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var name: String
    var symbol: String = "folder"
}

struct Snippet: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var groupID: UUID
    var title: String
    var abbreviation: String
    var body: String
    var tags: [String] = []
    var isFavorite: Bool = false
    var format: ContentFormat = .plainText

    init(id: UUID = UUID(), groupID: UUID, title: String, abbreviation: String, body: String, tags: [String] = [], isFavorite: Bool = false, format: ContentFormat = .plainText) {
        self.id = id; self.groupID = groupID; self.title = title; self.abbreviation = abbreviation
        self.body = body; self.tags = tags; self.isFavorite = isFavorite; self.format = format
    }
}

struct Library: Codable, Equatable, Sendable {
    static let schemaVersion = 3
    var version = schemaVersion
    var groups: [SnippetGroup]
    var snippets: [Snippet]
    var macros: [CustomMacro] = []

    init(groups: [SnippetGroup], snippets: [Snippet], macros: [CustomMacro] = []) {
        self.groups = groups; self.snippets = snippets; self.macros = macros
    }

    static var starter: Library {
        let personal = SnippetGroup(name: "Personal", symbol: "person")
        let work = SnippetGroup(name: "Work", symbol: "briefcase")
        let templates = SnippetGroup(name: "Templates", symbol: "curlybraces")
        return Library(groups: [personal, work, templates], snippets: [
            Snippet(groupID: personal.id, title: "Email signature", abbreviation: ";sig",
                    body: "Best regards,\n{{field:your name}}", tags: ["email"], isFavorite: true),
            Snippet(groupID: work.id, title: "Friendly follow-up", abbreviation: ";follow",
                    body: "Hi {{field:name}},\n\nJust following up on our conversation. Let me know if you have any questions.\n\n{{snippet:;sig}}", tags: ["email", "follow-up"], isFavorite: true),
            Snippet(groupID: templates.id, title: "Meeting notes", abbreviation: ";notes",
                    body: "Meeting · {{date}}\nTopic: {{field:topic}}\n\nNotes\n{{cursor}}\n\nNext steps\n• ", tags: ["meetings"]),
            Snippet(groupID: work.id, title: "Thanks for your message", abbreviation: ";thanks",
                    body: "Thanks for reaching out, {{field:name}}. I'll get back to you shortly.", tags: ["support"]),
            Snippet(groupID: templates.id, title: "Timestamp", abbreviation: ";now",
                    body: "{{date}} at {{time}}", tags: ["utility"])
        ])
    }

    func validate() throws {
        guard version == Self.schemaVersion else { throw LibraryError.invalid("Unsupported library version: \(version).") }
        guard Set(groups.map(\.id)).count == groups.count,
              Set(snippets.map(\.id)).count == snippets.count,
              snippets.allSatisfy({ item in groups.contains { $0.id == item.groupID } }) else {
            throw LibraryError.invalid("The library contains duplicate identifiers or missing groups.")
        }
        guard Set(macros.map(\.name)).count == macros.count,
              Set(macros.map(\.id) + snippets.map(\.id)).count == macros.count + snippets.count,
              macros.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.name.count <= 128 && !$0.name.contains("{{") && !$0.name.contains("}}") && !$0.name.contains(where: { $0.isNewline }) }) else {
            throw LibraryError.invalid("Custom macros need unique names and identifiers, with names up to 128 characters.")
        }
    }
}

enum LibraryError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case let .invalid(message) = self { message } else { nil } }
}
