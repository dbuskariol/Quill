import SwiftUI

struct CustomMacrosView: View {
    @Bindable var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: UUID?
    @State private var draft: CustomMacro?
    @State private var fields: [String: String] = [:]
    @State private var pendingDelete = false
    @State private var showZendesk = false
    @State private var textSelection: TextSelection?
    private var items: [CustomMacro] {
        var items = store.library.macros.map { store.macroDrafts[$0.id] ?? $0 }
        items += store.macroDrafts.values.filter { draft in !items.contains { $0.id == draft.id } }
        return items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
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
        VStack(spacing: 0) {
            HStack {
                Text("Custom Macros").font(.title2.bold())
                Spacer()
                Button("New Macro", systemImage: "plus") {
                    let item = CustomMacro(name: uniqueName, body: "")
                    textSelection = nil; store.macroDrafts[item.id] = item; selectedID = item.id; draft = item; fields = [:]
                }.disabled(store.isBusy)
            }.padding(20)
            if let message = store.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red).textSelection(.enabled).padding(.horizontal, 20).padding(.bottom, 12)
            }
            Divider()
            HSplitView {
                List(selection: Binding(get: { selectedID }, set: { id in
                    textSelection = nil; selectedID = id; draft = items.first { $0.id == id }; fields = [:]
                })) {
                    ForEach(items) { item in
                        HStack { Text(item.name); if store.macroDrafts[item.id] != nil { Image(systemName: "circle.fill").font(.system(size: 5)).accessibilityLabel("Unsaved changes") } }.tag(item.id)
                    }
                }.frame(minWidth: 180, idealWidth: 220)
                if draft != nil {
                    editor.frame(minWidth: 470)
                } else {
                    ContentUnavailableView("No Custom Macro Selected", systemImage: "curlybraces", description: Text("Create a reusable block, then insert it into any snippet with Insert Macro.")).frame(minWidth: 470)
                }
            }
            Divider()
            HStack {
                Text("Reusable blocks can include text, dates, fill-ins, Zendesk placeholders and other macros.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(16)
        }.frame(minWidth: 780, idealWidth: 880, minHeight: 560, idealHeight: 650)
            .onAppear { if let first = items.first { selectedID = first.id; draft = first } }
            .onChange(of: draft) { _, value in
                guard let value else { return }
                store.macroDrafts[value.id] = store.library.macros.contains(value) ? nil : value
            }
            .alert("Delete Custom Macro?", isPresented: $pendingDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let draft { Task { if await store.deleteMacro(draft) { self.draft = nil; selectedID = nil } } }
                }
            } message: { Text("Snippets and macros using {{macro:\(draft?.name ?? "")}} will need updating. Undo Last Library Change can restore this macro.") }
            .sheet(isPresented: $showZendesk) { ZendeskPlaceholderPicker { insertMacro($0) } }
    }
    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Macro name", text: Binding(get: { draft?.name ?? "" }, set: { draft?.name = $0 })).textFieldStyle(.roundedBorder).accessibilityLabel("Macro name")
                Text("{{macro:\(draft?.name ?? "")}}").id(draft?.name).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                HStack {
                    Text("Template").font(.headline)
                    Spacer()
                    Menu("Insert Macro") {
                        Button("Date") { insertMacro("{{date}}") }
                        Button("Fill-in Field") { insertMacro("{{field:name}}") }
                        Button("Zendesk Placeholder…") { showZendesk = true }
                        ForEach(store.library.macros.filter { $0.id != draft?.id }) { macro in
                            Button(macro.name) { insertMacro("{{macro:\(macro.name)}}") }
                        }
                    }
                }
                TextEditor(text: Binding(get: { draft?.body ?? "" }, set: { draft?.body = $0 }), selection: $textSelection).font(.system(.body, design: .monospaced)).frame(minHeight: 160).accessibilityLabel("Custom macro template")
                PreviewView(result: preview, fields: $fields, actions: store.quickActions)
                HStack {
                    Button("Delete…", role: .destructive) { pendingDelete = true }.disabled(changed || store.isBusy)
                    Spacer()
                    Button("Revert") {
                        if let id = draft?.id {
                            textSelection = nil
                            store.macroDrafts[id] = nil
                            draft = store.library.macros.first { $0.id == id }
                            if draft == nil { selectedID = nil }
                        }
                    }.disabled(!changed || store.isBusy)
                    Button("Save Macro") {
                        if let draft { Task { if await store.saveMacro(draft) { self.draft = store.library.macros.first { $0.id == draft.id } } } }
                    }.keyboardShortcut("s").buttonStyle(.borderedProminent).disabled(!changed || store.isBusy || (try? preview.get()) == nil)
                }
            }.padding(20)
        }
    }
    private func insertMacro(_ token: String) {
        guard var value = draft else { return }
        insertTemplateText(token, into: &value.body, selection: &textSelection)
        draft = value
    }
    private var uniqueName: String {
        var name = "New macro"; var suffix = 2
        while items.contains(where: { $0.name == name }) { name = "New macro \(suffix)"; suffix += 1 }
        return name
    }
}
