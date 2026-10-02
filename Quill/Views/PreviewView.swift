import AppKit
import SwiftUI

struct PreviewView: View {
    let result: Result<RenderResult, Error>
    @Binding var fields: [String: String]
    let actions: QuickActionStore
    var focusFieldsInitially = false
    var showsCopyActions = true
    @State private var copied = false
    @State private var copyAttempted = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preview").font(.headline)
                Spacer()
                if case let .success(preview) = result, showsCopyActions {
                    Button(copied ? "Copied" : preview.format == .markdown ? "Copy Formatted" : "Copy Preview") {
                        copyAttempted = true
                        copied = actions.copy(preview)
                    }.disabled(!preview.canSubmit(fields: fields))
                    if preview.format == .markdown {
                        Menu("Copy As") {
                            Button("Plain Text") { copyAttempted = true; copied = actions.copy(preview, style: .plainText) }
                            Button("Markdown") { copyAttempted = true; copied = actions.copy(preview, style: .markdown) }
                        }.disabled(!preview.canSubmit(fields: fields))
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
                TemplateFieldsView(result: preview, fields: $fields, focusInitially: focusFieldsInitially)
                if preview.format == .markdown {
                    if let document = try? MarkdownDocument(preview.text) {
                        FormattedPreview(document: document)
                        ForEach(document.warnings, id: \.self) { warning in Label(warning, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.secondary) }
                    } else { Label("Markdown could not be rendered. Copy the source as Markdown to preserve it.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                } else {
                    Text(preview.text.isEmpty ? "Your preview will appear here." : preview.text)
                        .id(preview.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .topLeading)
                }
                if preview.cursorUTF16Offset != nil, let visible = try? preview.plainTextResult(), let offset = visible.cursorUTF16Offset {
                    Text("Cursor after \((visible.text as NSString).substring(to: offset).count) characters")
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
    private var resultText: String { (try? result.get().text) ?? "" }
}
