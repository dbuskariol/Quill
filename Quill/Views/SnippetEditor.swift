import AppKit
import SwiftUI

struct SnippetEditor: View {
    let store: LibraryStore
    let original: Snippet
    @State private var draft: Snippet
    @State private var fields: [String: String] = [:]
    @State private var saved = false
    @State private var showZendesk = false
    @State private var textSelection: TextSelection?

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
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        Text("Title")
                        HStack {
                            TextField("Snippet title", text: $draft.title)
                            Toggle(isOn: $draft.isFavorite) { Label("Favorite", systemImage: draft.isFavorite ? "star.fill" : "star") }
                                .toggleStyle(.button).labelsHidden().help("Favorite").accessibilityLabel("Favorite")
                        }
                    }
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
                            Button("Zendesk Placeholder…") { showZendesk = true }
                            if !store.library.macros.isEmpty {
                                Menu("Custom Macros") {
                                    ForEach(store.library.macros) { macro in Button(macro.name) { insertMacro("{{macro:\(macro.name)}}") } }
                                }
                            }
                            Button("Manage Custom Macros…") { store.showCustomMacros = true }
                            Divider()
                            Button("Date") { insertMacro("{{date}}") }
                            Button("Time") { insertMacro("{{time}}") }
                            Button("Fill-in Field") { insertMacro("{{field:name}}") }
                            Button("Multiline Field") { insertMacro("{{input:notes|multiline}}") }
                            Button("Popup Choice") { insertMacro("{{input:tone|choice|Formal|Friendly}}") }
                            Button("Optional Field") { insertMacro("{{input:extra|optional}}") }
                            Button("Date Picker") { insertMacro("{{input:date|date|yyyy-MM-dd}}") }
                            Button("Conditional Section") { insertMacro("{{if:tone=Formal}}Hello{{else}}Hi{{end}}") }
                            Button("Date in Seven Days") { insertMacro("{{date:yyyy-MM-dd|7}}") }
                            Button("Arithmetic") { insertMacro("{{math:(2+3)*4}}") }
                            Button("Cursor Position") { insertMacro("{{cursor}}") }
                        }
                    }
                    TextEditor(text: $draft.body, selection: $textSelection).font(.system(.body, design: .monospaced))
                        .frame(minHeight: 170).padding(8).background(.background, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
                        .accessibilityLabel("Snippet template")
                }
                if !conflicts.isEmpty {
                    Label("Abbreviation also used by: \(conflicts.map(\.title).joined(separator: ", "))", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange).font(.callout)
                }
                PreviewView(result: result, fields: $fields, actions: store.quickActions)
                HStack {
                    if changed || saved {
                        Text(changed ? "Unsaved changes" : "Saved").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Revert") { if let current = store.selected { textSelection = nil; draft = current } }.disabled(!changed)
                    Button("Save Snippet") {
                        Task { if await store.save(draft) { saved = true } }
                    }.keyboardShortcut("s").buttonStyle(.borderedProminent)
                        .disabled(!changed || store.isBusy || draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }.padding(24)
        }
        .navigationTitle(draft.title)
        .disabled(store.isBusy)
        .sheet(isPresented: $showZendesk) { ZendeskPlaceholderPicker { insertMacro($0) } }
        .onChange(of: draft) { _, value in store.drafts[value.id] = value == store.selected ? nil : value }
        .onChange(of: original.isFavorite) { _, value in draft.isFavorite = value }
        .onChange(of: original.body) { _, value in if store.drafts[original.id] == nil { draft.body = value } }
    }
    private func insertMacro(_ token: String) { insertTemplateText(token, into: &draft.body, selection: &textSelection) }
}
