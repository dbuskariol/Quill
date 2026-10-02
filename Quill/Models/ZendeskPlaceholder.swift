import Foundation

struct ZendeskPlaceholder: Identifiable {
    let name: String
    let label: String
    var id: String { name }
    var token: String { "{{\(name)}}" }
    static let common: [Self] = [
        .init(name: "ticket.requester.first_name", label: "Requester first name"),
        .init(name: "ticket.requester.name", label: "Requester name"),
        .init(name: "ticket.requester.email", label: "Requester email"),
        .init(name: "ticket.id", label: "Ticket ID"),
        .init(name: "ticket.title", label: "Ticket subject"),
        .init(name: "ticket.link", label: "Ticket link"),
        .init(name: "ticket.organization.name", label: "Organization name"),
        .init(name: "ticket.assignee.name", label: "Assignee name"),
        .init(name: "current_user.name", label: "Current agent name"),
        .init(name: "current_user.first_name", label: "Current agent first name"),
        .init(name: "current_user.email", label: "Current agent email"),
        .init(name: "current_user.signature", label: "Current agent signature")
    ]
    static func isValid(_ name: String) -> Bool {
        guard name.count <= 256 else { return false }
        return name.range(of: #"^(ticket|current_user|user|organization|agent|satisfaction|dc|account|comment|requester|assignee|submitter)\.[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*$"#, options: .regularExpression) != nil
    }
    static func isExpression(_ expression: String) -> Bool {
        guard expression.count <= 2048, !expression.contains("{{"), !expression.contains("}}") else { return false }
        let parts = expression.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return parts.first.map(isValid) == true && parts.dropFirst().allSatisfy { !$0.isEmpty }
    }
    static func expressions(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\{\{([^{}]+)\}\}"#) else { return [] }
        var seen: Set<String> = []
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            let value = String(text[range])
            return isExpression(value) && seen.insert(value).inserted ? value : nil
        }
    }
}
