import SwiftUI

struct SidebarView: View {
    @Bindable var store: LibraryStore
    var body: some View {
        List(selection: $store.filter) {
            Section("Library") {
                Label("All Snippets", systemImage: "text.quote").tag("all")
                Label("Favorites", systemImage: "star").tag("favorites")
            }
            Section("Groups") {
                ForEach(store.library.groups) { group in
                    Label(group.name, systemImage: group.symbol).tag(group.id.uuidString)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Quill")
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Label("Local library", systemImage: "internaldrive").font(.caption)
                Text("\(store.library.snippets.count) snippets · No network access").font(.caption2).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding()
        }
    }
}
