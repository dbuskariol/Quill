import SwiftUI

struct ZendeskPlaceholderPicker: View {
    @Environment(\.dismiss) private var dismiss
    let insert: (String) -> Void
    @State private var choice = ZendeskPlaceholder.common[0].name
    @State private var custom = ""
    @State private var useCustom = false
    @FocusState private var customFocused: Bool
    private var name: String { useCustom ? custom.trimmingCharacters(in: .whitespacesAndNewlines) : choice }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Zendesk Placeholder").font(.title2.weight(.semibold))
            Picker("Placeholder", selection: $choice) {
                ForEach(ZendeskPlaceholder.common) { Text($0.label).tag($0.name) }
            }.disabled(useCustom)
            Toggle("Custom placeholder", isOn: $useCustom)
            if useCustom {
                TextField("ticket.ticket_field_123456", text: $custom).textFieldStyle(.roundedBorder).accessibilityLabel("Zendesk placeholder name").focused($customFocused).onSubmit(insertAndDismiss)
                    .background(InputFocusOnPresentation(enabled: true) { customFocused = true })
                Text("Use ticket.ticket_field_ID, ticket.requester.custom_fields.KEY or dc.ITEM_NAME. Liquid filters, such as | capitalize, are kept for Zendesk.").font(.caption).foregroundStyle(.secondary)
            }
            Text("{{\(name)}}").id(name).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            Text("Quill keeps this token unchanged. Zendesk resolves it using the ticket when it processes the comment. Only use fields available in your account.").foregroundStyle(.secondary)
            Link("Zendesk placeholder reference", destination: URL(string: "https://support.zendesk.com/hc/en-us/articles/4408886858138-Placeholder-reference-for-business-rules")!)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Insert Placeholder", action: insertAndDismiss).keyboardShortcut(.defaultAction).disabled(!ZendeskPlaceholder.isExpression(name))
            }
        }.padding(20).frame(width: 500)
    }
    private func insertAndDismiss() {
        guard ZendeskPlaceholder.isExpression(name) else { return }
        insert("{{\(name)}}"); dismiss()
    }
}
