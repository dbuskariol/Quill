import Foundation

enum ContentFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case plainText, markdown
    var id: Self { self }
    var label: String { self == .plainText ? "Plain Text" : "Markdown" }
}
