import Foundation

struct TemplateField: Equatable, Sendable, Identifiable {
    enum Kind: Equatable, Sendable { case singleLine, multiline, choice([String]), optional, date(String) }
    var id: String { name }
    let name: String
    var kind: Kind = .singleLine
    var isRequired: Bool { kind != .optional }
}
