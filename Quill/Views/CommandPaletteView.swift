import SwiftUI

struct CommandPaletteView: View {
    let store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selectedID: UUID?
    @State private var fields: [String: String] = [:]
    @State private var contextDate = Date.now
    @FocusState private var searchFocused: Bool
    private var items: [Snippet] {
        store.library.snippets.filter { item in
            query.isEmpty || ([item.title, item.abbreviation, item.body] + item.tags).contains { $0.localizedStandardContains(query) }
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
    private var selected: Snippet? { items.first { $0.id == selectedID } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Quick Actions").font(.title2)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            TextField("Find a snippet", text: $query).textFieldStyle(.roundedBorder).focused($searchFocused)
            HSplitView {
                List(items, selection: $selectedID) { item in
                    VStack(alignment: .leading) {
                        Text(item.title)
                        Text(item.abbreviation).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }.tag(item.id)
                }.frame(minWidth: 220, minHeight: 300)
                ScrollView {
                    if let selected {
                        PreviewView(result: Result { try TemplateRenderer.render(selected, library: store.library, context: RenderContext(date: contextDate, fields: fields)) }, fields: $fields, actions: store.quickActions)
                        Button("Open in Library") {
                            store.isShowingSettings = false; store.filter = "all"; store.search = ""; store.selectedID = selected.id; dismiss()
                        }
                    } else { ContentUnavailableView("Choose a Snippet", systemImage: "text.quote") }
                }.frame(minWidth: 340)
            }
            HStack {
                Button("Repeat Last Copy") { store.quickActions.repeatLastCopy() }.disabled(store.quickActions.lastCopiedText == nil)
                    .help("Copies the exact last resolved text. Kept in memory until cleared or Quill quits.")
                Button("Clear Last Copy") { store.quickActions.clear() }.disabled(store.quickActions.lastCopiedText == nil)
                Spacer()
            }
        }.padding(20).frame(width: 720, height: 500)
        .onAppear { selectedID = items.first?.id; searchFocused = true }
        .onChange(of: query) { _, _ in if !items.contains(where: { $0.id == selectedID }) { selectedID = items.first?.id } }
        .onChange(of: selectedID) { _, _ in fields = [:]; contextDate = .now }
    }
}
