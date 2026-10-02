import Foundation

struct CustomMacro: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var body: String
}
