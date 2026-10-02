import SwiftUI

struct CustomMacrosView: View {
    @Bindable var store: LibraryStore
    @State private var draft: CustomMacro?
    @State private var fields: [String: String] = [:]
    @State private var pendingDelete = false
    @State private var showZendesk = false
    @State private var templateEditor = TemplateEditorController()
    private var items: [CustomMacro] {
        var items = store.library.macros.map { store.macroDrafts[$0.id] ?? $0 }
        items += store.macroDrafts.values.filter { draft in !items.contains { $0.id == draft.id } }
        return items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private var visible: [CustomMacro] { items.filter { store.macroSearch.isEmpty || $0.name.localizedStandardContains(store.macroSearch) || $0.body.localizedStandardContains(store.macroSearch) } }
    private var changed: Bool { guard let draft else { return false }; return !store.library.macros.contains(draft) }
    private var preview: Result<RenderResult, Error> {
        Result {
            guard let draft else { throw TemplateError.invalid("Choose a macro.") }
            var library = store.library
            library.macros.removeAll { $0.id == draft.id }; library.macros.append(draft)
            try library.validate()
            return try TemplateRenderer.render(Snippet(groupID: library.groups.first?.id ?? UUID(), title: draft.name, abbreviation: "", body: "{{macro:\(draft.name)}}"), library: library, context: RenderContext(fields: fields))
        }
    }
    var body: some View {
        NavigationSplitView {
            SidebarView(store: store).navigationSplitViewColumnWidth(min: 170, ideal: 200, max: 260)
        } content: {
            List(selection: $store.selectedMacroID) {
                ForEach(visible) { item in
                    HStack {
                        Text(item.name)
                        if store.macroDrafts[item.id] != nil { Image(systemName: "circle.fill").font(.system(size: 5)).accessibilityLabel("Unsaved changes") }
                    }.padding(.vertical, 5).tag(item.id)
                }
            }
            .overlay {
                if visible.isEmpty && !store.macroSearch.isEmpty {
                    ContentUnavailableView.search(text: store.macroSearch)
                }
            }
            .navigationTitle("Custom Macros")
            .navigationSplitViewColumnWidth(min: 230, ideal: 280, max: 380)
        } detail: {
            if draft != nil { editor }
            else if items.isEmpty {
                ContentUnavailableView {
                    Label("No Custom Macros", systemImage: "curlybraces")
                } description: {
                    Text("Create a reusable template block to insert into your snippets.")
                } actions: {
                    Button("New Macro") { store.createMacro() }.disabled(store.isBusy || !store.isLoaded)
                }
            } else { ContentUnavailableView("Select a Custom Macro", systemImage: "curlybraces") }
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $store.macroSearch, prompt: "Search custom macros")
        .toolbar {
            ToolbarItem { Button { store.createMacro() } label: { Label("New Macro", systemImage: "plus") }.help("New Macro (⌘N)").disabled(store.isBusy || !store.isLoaded) }
        }
        .onAppear {
            if !visible.contains(where: { $0.id == store.selectedMacroID }) { store.selectedMacroID = visible.first?.id }
            selectDraft()
        }
        .onChange(of: store.selectedMacroID) { _, _ in selectDraft() }
        .onChange(of: store.macroSearch) { _, _ in if !visible.contains(where: { $0.id == store.selectedMacroID }) { store.selectedMacroID = visible.first?.id } }
        .onChange(of: draft) { _, value in
            guard let value else { return }
            store.macroDrafts[value.id] = store.library.macros.contains(value) ? nil : value
        }
        .alert("Delete Custom Macro?", isPresented: $pendingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let draft { Task { if await store.deleteMacro(draft) { self.draft = nil; store.selectedMacroID = items.first?.id } } }
            }
        } message: { Text("Snippets and macros using {{macro:\(draft?.name ?? "")}} will need updating. Undo Last Library Change can restore this macro.") }
        .sheet(isPresented: $showZendesk) { ZendeskPlaceholderPicker { templateEditor.insert($0) } }
    }
    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TextField("Macro name", text: Binding(get: { draft?.name ?? "" }, set: { draft?.name = $0 })).textFieldStyle(.roundedBorder).accessibilityLabel("Macro name")
                Text("{{macro:\(draft?.name ?? "")}}").id(draft?.name).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                HStack {
                    Text("Template").font(.headline)
                    Spacer()
                    TemplateInsertionMenu(library: store.library, excludingMacro: draft?.id, insert: templateEditor.insert, showZendesk: { showZendesk = true })
                }
                TemplateEditor(text: Binding(get: { draft?.body ?? "" }, set: { draft?.body = $0 }), library: store.library, controller: templateEditor, excludingMacro: draft?.id, accessibilityName: "Custom macro template")
                    .id(draft?.id).frame(height: 220)
                PreviewView(result: preview, fields: $fields, actions: store.quickActions)
            }.padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Button("Delete…", role: .destructive) { pendingDelete = true }.disabled(changed || store.isBusy)
                    if changed { Text("Unsaved changes").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Button("Revert") {
                        if let id = draft?.id {
                            store.macroDrafts[id] = nil
                            draft = store.library.macros.first { $0.id == id }
                            if draft == nil { store.selectedMacroID = items.first?.id }
                        }
                    }.disabled(!changed || store.isBusy)
                    Button("Save Macro") {
                        if let draft { Task { if await store.saveMacro(draft) { self.draft = store.library.macros.first { $0.id == draft.id } } } }
                    }.keyboardShortcut("s").buttonStyle(.borderedProminent).disabled(!changed || store.isBusy || (try? preview.get()) == nil)
                }.padding(.horizontal, 24).padding(.vertical, 12)
            }.background(.bar)
        }.disabled(store.isBusy)
    }
    private func selectDraft() {
        draft = items.first { $0.id == store.selectedMacroID }
        fields = [:]
    }
}
