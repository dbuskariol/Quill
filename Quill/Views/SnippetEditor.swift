import AppKit
import SwiftUI

struct SnippetEditor: View {
    let store: LibraryStore
    let original: Snippet
    @State private var draft: Snippet
    @State private var fields: [String: String] = [:]
    @State private var saved = false

    init(store: LibraryStore, original: Snippet) {
        self.store = store
        self.original = original
        _draft = State(initialValue: store.drafts[original.id] ?? original)
    }

    private var previewLibrary: Library {
        var library = store.library
        if let index = library.snippets.firstIndex(where: { $0.id == draft.id }) { library.snippets[index] = draft }
        return library
    }
    private var result: Result<RenderResult, Error> {
        Result { try TemplateRenderer.render(draft, library: previewLibrary, context: RenderContext(fields: fields)) }
    }
    private var conflicts: [Snippet] { TemplateRenderer.conflicts(for: draft, in: store.library) }
    private var changed: Bool { draft != store.selected }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Snippet editor").font(.title2).fontWeight(.semibold)
                        Text("Build a reusable template, then test it before use.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(isOn: $draft.isFavorite) { Label("Favorite", systemImage: draft.isFavorite ? "star.fill" : "star") }
                        .toggleStyle(.button).labelsHidden().help("Favorite")
                }
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow { Text("Title"); TextField("Snippet title", text: $draft.title) }
                    GridRow { Text("Abbreviation"); TextField(";shortcut", text: $draft.abbreviation).font(.system(.body, design: .monospaced)) }
                    GridRow {
                        Text("Group")
                        Picker("Group", selection: $draft.groupID) { ForEach(store.library.groups) { Text($0.name).tag($0.id) } }.labelsHidden()
                    }
                    GridRow {
                        Text("Tags")
                        TextField("Comma-separated tags", text: Binding(get: { draft.tags.joined(separator: ", ") }, set: { draft.tags = $0.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) } }))
                    }
                }.textFieldStyle(.roundedBorder)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Template").font(.headline)
                        Spacer()
                        Menu("Insert Macro") {
                            Button("Date") { draft.body += "{{date}}" }
                            Button("Time") { draft.body += "{{time}}" }
                            Button("Fill-in Field") { draft.body += "{{field:name}}" }
                            Button("Cursor Position") { draft.body += "{{cursor}}" }
                        }
                    }
                    TextEditor(text: $draft.body).font(.system(.body, design: .monospaced))
                        .frame(minHeight: 170).padding(8).background(.background, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
                        .accessibilityLabel("Snippet template")
                    Text("Macros: {{date}}, {{time}}, {{field:name}}, {{snippet:;sig}}, {{cursor}}").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
                if !conflicts.isEmpty {
                    Label("Abbreviation also used by: \(conflicts.map(\.title).joined(separator: ", "))", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange).font(.callout)
                }
                PreviewView(result: result, fields: $fields)
                HStack {
                    Text(changed ? "Unsaved changes" : (saved ? "Saved locally" : "Local template"))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Revert") { if let current = store.selected { draft = current } }.disabled(!changed)
                    Button("Save Snippet") {
                        Task { if await store.save(draft) { saved = true } }
                    }.keyboardShortcut("s").buttonStyle(.borderedProminent)
                        .disabled(!changed || store.isBusy || draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Text("Library preview only. Quill does not yet expand text in other apps.").font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }
        .navigationTitle(draft.title)
        .disabled(store.isBusy)
        .onChange(of: draft) { _, value in store.drafts[value.id] = value == store.selected ? nil : value }
        .onChange(of: original.isFavorite) { _, value in draft.isFavorite = value }
    }
}
