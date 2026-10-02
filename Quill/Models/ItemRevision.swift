import Foundation

enum TemplateSnapshot: Codable, Equatable, Sendable, Identifiable {
    case snippet(Snippet), macro(CustomMacro)
    var id: UUID { switch self { case .snippet(let s): s.id; case .macro(let m): m.id } }
    var title: String { switch self { case .snippet(let s): s.title; case .macro(let m): m.name } }
    var body: String { switch self { case .snippet(let s): s.body; case .macro(let m): m.body } }
    var format: ContentFormat { switch self { case .snippet(let s): s.format; case .macro(let m): m.format } }
    var kind: String { switch self { case .snippet: "snippet"; case .macro: "macro" } }
}
struct ItemRevision: Identifiable, Equatable, Sendable {
    let id: UUID
    let parentID: UUID?
    let transactionID: UUID
    let date: Date
    let reason: String
    let isDeleted: Bool
    let isProtected: Bool
    let snapshot: TemplateSnapshot
}
struct DraftCheckpoint: Identifiable, Codable, Equatable, Sendable {
    var id: UUID { snapshot.id }
    let snapshot: TemplateSnapshot
    let baseRevisionID: UUID?
    let date: Date
}
extension Library {
    var snapshots: [UUID: TemplateSnapshot] {
        Dictionary(uniqueKeysWithValues: snippets.map { ($0.id, TemplateSnapshot.snippet($0)) } + macros.map { ($0.id, TemplateSnapshot.macro($0)) })
    }
}

struct HistoryRequest: Identifiable {
    var itemID: UUID?
    var id: String { itemID?.uuidString ?? "deleted" }
}
