import SwiftUI

/// Shared by preview, quick actions and automatic expansion.
struct TemplateFieldsView: View {
    let result: RenderResult
    @Binding var fields: [String: String]
    var focusInitially = false
    @FocusState private var focusedField: String?
    var body: some View {
        ForEach(result.fields, id: \.self) { name in
            fieldControl(result.fieldDefinitions.first { $0.name == name } ?? TemplateField(name: name))
        }
        .onAppear { if focusInitially { focusedField = result.fields.first } }
    }
    @ViewBuilder private func fieldControl(_ field: TemplateField) -> some View {
        let binding = Binding(get: { fields[field.name, default: ""] }, set: { fields[field.name] = $0 })
        switch field.kind {
        case .singleLine, .optional:
            TextField(field.kind == .optional ? "\(field.name) (optional)" : field.name, text: binding)
                .textFieldStyle(.roundedBorder).accessibilityLabel("Fill-in: \(field.name)").focused($focusedField, equals: field.name)
        case .multiline:
            VStack(alignment: .leading) {
                Text(field.name).font(.caption)
                TextEditor(text: binding).frame(minHeight: 70).accessibilityLabel("Fill-in: \(field.name)").focused($focusedField, equals: field.name)
            }
        case let .choice(choices):
            Picker(field.name, selection: binding) {
                Text("Choose…").tag("")
                ForEach(choices, id: \.self) { Text($0).tag($0) }
            }
        case .date:
            DatePicker(field.name, selection: Binding(get: {
                dateFormatter.date(from: binding.wrappedValue) ?? .now
            }, set: { binding.wrappedValue = dateFormatter.string(from: $0) }), displayedComponents: .date)
            if binding.wrappedValue.isEmpty {
                Button("Use Today for \(field.name)") { binding.wrappedValue = dateFormatter.string(from: .now) }
            }
        }
    }
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
