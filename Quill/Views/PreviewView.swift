import AppKit
import SwiftUI

struct PreviewView: View {
    let result: Result<RenderResult, Error>
    @Binding var fields: [String: String]
    let actions: QuickActionStore
    @State private var copied = false
    @State private var copyAttempted = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Preview", systemImage: "play.rectangle").font(.headline)
                Spacer()
                if case let .success(preview) = result {
                    Button(copied ? "Copied" : preview.format == .markdown ? "Copy Formatted" : "Copy Preview") {
                        copyAttempted = true
                        copied = actions.copy(preview)
                    }.disabled(preview.fields.contains { name in fields[name, default: ""].isEmpty && (preview.fieldDefinitions.first { $0.name == name }?.isRequired ?? true) })
                    if preview.format == .markdown {
                        Menu("Copy As") {
                            Button("Plain Text") { copyAttempted = true; copied = actions.copy(preview, style: .plainText) }
                            Button("Markdown") { copyAttempted = true; copied = actions.copy(preview, style: .markdown) }
                        }.disabled(preview.fields.contains { name in fields[name, default: ""].isEmpty && (preview.fieldDefinitions.first { $0.name == name }?.isRequired ?? true) })
                    }
                }
            }
            if copyAttempted, !copied, let message = actions.message { Text(message).foregroundStyle(.red) }
            switch result {
            case let .success(preview):
                if !preview.zendeskPlaceholders.isEmpty {
                    Label("Zendesk fills these placeholders when it processes your comment. Quill copies them unchanged.", systemImage: "curlybraces")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(preview.fields, id: \.self) { name in
                    fieldControl(preview.fieldDefinitions.first { $0.name == name } ?? TemplateField(name: name))
                }
                if preview.format == .markdown {
                    if let document = try? MarkdownDocument(preview.text) {
                        FormattedPreview(document: document).frame(height: 200)
                        ForEach(document.warnings, id: \.self) { warning in Label(warning, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.secondary) }
                    } else { Label("Markdown could not be rendered. Copy the source as Markdown to preserve it.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                } else {
                    Text(preview.text.isEmpty ? "Your preview will appear here." : preview.text)
                        .id(preview.text).textSelection(.enabled).frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                }
                if let offset = preview.cursorUTF16Offset, preview.format == .plainText {
                    Text("Cursor after \((preview.text as NSString).substring(to: offset).count) characters")
                        .font(.caption).foregroundStyle(.secondary)
                        .help("Used during expansion. Copy Preview copies text only.")
                }
            case let .failure(error):
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            }
        }.padding(16).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            .onChange(of: (try? result.get())?.format) { _, _ in copied = false; copyAttempted = false }
            .onChange(of: resultText) { _, _ in copied = false; copyAttempted = false }
    }
    @ViewBuilder private func fieldControl(_ field: TemplateField) -> some View {
        let binding = Binding(get: { fields[field.name, default: ""] }, set: { fields[field.name] = $0 })
        switch field.kind {
        case .singleLine, .optional:
            TextField(field.kind == .optional ? "\(field.name) (optional)" : field.name, text: binding)
                .textFieldStyle(.roundedBorder).accessibilityLabel("Preview field: \(field.name)")
        case .multiline:
            VStack(alignment: .leading) {
                Text(field.name).font(.caption)
                TextEditor(text: binding).frame(minHeight: 70).accessibilityLabel("Preview field: \(field.name)")
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
    private var resultText: String { (try? result.get().text) ?? "" }
}
