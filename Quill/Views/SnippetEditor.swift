import AppKit
import SwiftUI

struct SnippetEditor: View {
    let store: LibraryStore
    let original: Snippet
    @State private var draft: Snippet
    @State private var fields: [String: String] = [:]
    @State private var saved = false
    @State private var showZendesk = false
    @State private var templateEditor = TemplateEditorController()

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
    private var changed: Bool { !store.library.snippets.contains(draft) }

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
                        Text("Format")
                        Picker("Content format", selection: $draft.format) { ForEach(ContentFormat.allCases) { Text($0.label).tag($0) } }.labelsHidden()
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
                        TemplateInsertionMenu(library: store.library, excludingSnippet: original.id, insert: insertMacro, showZendesk: { showZendesk = true })
                    }
                    TemplateEditor(text: $draft.body, library: store.library, controller: templateEditor, excludingSnippet: original.id, accessibilityName: "Snippet template")
                        .frame(height: 220)
                }
                if !conflicts.isEmpty {
                    Label("Abbreviation also used by: \(conflicts.map(\.title).joined(separator: ", "))", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange).font(.callout)
                }
                PreviewView(result: result, fields: $fields, actions: store.quickActions)

            }.padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Button("History", systemImage: "clock.arrow.circlepath") { store.historyRequest = HistoryRequest(itemID: original.id) }
                    if changed || saved {
                        Text(changed ? "Unsaved changes" : "Saved").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Revert") { store.drafts[original.id] = nil; if let current = store.library.snippets.first(where: { $0.id == original.id }) { draft = current } else { store.selectedID = store.library.snippets.first?.id } }.disabled(!changed)
                    Button("Save Snippet") {
                        Task { if await store.save(draft) { saved = true } }
                    }.keyboardShortcut("s").buttonStyle(.borderedProminent)
                        .disabled(!changed || store.isBusy || draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                    .padding(.horizontal, 24).padding(.vertical, 12)
            }.background(.bar)
        }
        .navigationTitle(draft.title)
        .disabled(store.isBusy)
        .sheet(isPresented: $showZendesk) { ZendeskPlaceholderPicker { insertMacro($0) } }
        .onChange(of: draft) { _, value in store.drafts[value.id] = store.library.snippets.contains(value) ? nil : value }
        .onChange(of: original) { _, value in if store.drafts[original.id] == nil { draft = value } }
        .onChange(of: store.drafts[original.id]) { _, value in if let value, value != draft { draft = value } }
    }
    private func insertMacro(_ token: String) { templateEditor.insert(token) }
}
