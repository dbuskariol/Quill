import SwiftUI

struct LibraryView: View {
    @Bindable var store: LibraryStore
    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 170, ideal: 200, max: 260)
        } content: {
            List(selection: $store.selectedID) {
                ForEach(store.visible) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(item.title).fontWeight(.medium).lineLimit(1)
                            if item.isFavorite { Image(systemName: "star.fill").foregroundStyle(.secondary).accessibilityLabel("Favorite") }
                        }
                        Text(item.abbreviation.isEmpty ? "No abbreviation" : item.abbreviation)
                            .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                    }.padding(.vertical, 5).tag(item.id)
                        .contextMenu {
                            Button("Delete…", role: .destructive) { store.pendingDelete = item }
                        }
                }
            }
            .overlay {
                if store.isBusy && !store.isLoaded { ProgressView("Opening library…") }
                else if store.visible.isEmpty { ContentUnavailableView("No Snippets", systemImage: "text.badge.plus", description: Text("Create a snippet or adjust your search.")) }
            }
            .navigationTitle("Snippets")
            .navigationSplitViewColumnWidth(min: 230, ideal: 280, max: 380)
        } detail: {
            if let item = store.selected {
                SnippetEditor(store: store, original: item).id(item.id)
            } else {
                ContentUnavailableView("Your words, a shortcut away", systemImage: "text.quote", description: Text("Select a snippet to edit and preview its template."))
            }
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $store.search, prompt: "Search snippets and tags")
        .toolbar {
            ToolbarItem {
                Button { Task { await store.create() } } label: { Label("New Snippet", systemImage: "plus") }
                    .help("New Snippet (⌘N)").disabled(store.isBusy || !store.isLoaded)
            }
        }
        .frame(minWidth: 940, minHeight: 580)
        .alert("Delete Snippet?", isPresented: Binding(get: { store.pendingDelete != nil }, set: { if !$0 { store.pendingDelete = nil } }), presenting: store.pendingDelete) { item in
            Button("Cancel", role: .cancel) { store.pendingDelete = nil }
            Button("Delete", role: .destructive) { store.pendingDelete = nil; Task { await store.delete(item) } }
        } message: { item in Text("“\(item.title)” will be removed from your local library. Other snippets that reference it may need updating.") }
        .alert("Library Needs Attention", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            if !store.isLoaded { Button("Retry") { Task { await store.load() } } }
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .onChange(of: store.visible.map(\.id)) { _, ids in
            if !ids.contains(store.selectedID ?? UUID()) { store.selectedID = ids.first }
        }
    }
}
