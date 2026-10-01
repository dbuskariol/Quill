import AppKit
import SwiftUI

struct PreviewView: View {
    let result: Result<RenderResult, Error>
    @Binding var fields: [String: String]
    @State private var copied = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Dry-run Preview", systemImage: "play.rectangle").font(.headline)
                Spacer()
                if case let .success(preview) = result {
                    Button(copied ? "Copied" : "Copy Preview") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(preview.text, forType: .string)
                        copied = true
                    }.disabled(preview.fields.contains { fields[$0, default: ""].isEmpty })
                }
            }
            switch result {
            case let .success(preview):
                ForEach(preview.fields, id: \.self) { name in
                    TextField(name, text: Binding(get: { fields[name, default: ""] }, set: { fields[name] = $0 }))
                        .textFieldStyle(.roundedBorder).accessibilityLabel("Preview field: \(name)")
                }
                Text(preview.text.isEmpty ? "Your preview will appear here." : preview.text)
                    .textSelection(.enabled).frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                if let offset = preview.cursorUTF16Offset {
                    Text("Cursor marker at UTF-16 offset \(offset). Copy includes text only.").font(.caption).foregroundStyle(.secondary)
                }
            case let .failure(error):
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            }
        }.padding(16).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            .onChange(of: resultText) { _, _ in copied = false }
    }
    private var resultText: String { (try? result.get().text) ?? "" }
}
