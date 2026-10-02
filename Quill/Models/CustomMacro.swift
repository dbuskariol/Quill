import Foundation

struct CustomMacro: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var body: String
    var format: ContentFormat = .plainText
    init(id: UUID = UUID(), name: String, body: String, format: ContentFormat = .plainText) {
        self.id = id; self.name = name; self.body = body; self.format = format
    }
}
