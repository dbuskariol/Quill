import SwiftUI

struct SidebarView: View {
    @Bindable var store: LibraryStore
    @State private var manageGroups = false
    var body: some View {
        List(selection: Binding<String?>(get: { store.isShowingSettings ? nil : store.filter }, set: { value in
            if let value { store.isShowingSettings = false; store.filter = value }
        })) {
            Section {
                Label("All Snippets", systemImage: "text.quote").tag("all")
                Label("Favorites", systemImage: "star").tag("favorites")
                Button { store.showCustomMacros = true } label: { Label("Custom Macros", systemImage: "curlybraces") }.buttonStyle(.plain)
            }
            Section {
                ForEach(store.library.groups) { group in
                    Label(group.name, systemImage: group.symbol).tag(group.id.uuidString)
                }
            } header: {
                HStack {
                    Text("Groups")
                    Spacer()
                    Button { manageGroups = true } label: { Image(systemName: "folder.badge.gearshape") }
                        .buttonStyle(.borderless).help("Manage Groups").accessibilityLabel("Manage Groups")
                        .disabled(!store.isLoaded || store.isBusy)
                }
            }
        }
        .sheet(isPresented: $manageGroups) { GroupManagementView(store: store) }
        .listStyle(.sidebar)
        .navigationTitle("Quill")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                Button { store.isShowingSettings = true } label: {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).frame(height: 32)
                        .foregroundStyle(store.isShowingSettings ? Color(nsColor: .alternateSelectedControlTextColor) : Color.primary)
                        .background(store.isShowingSettings ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityAddTraits(store.isShowingSettings ? .isSelected : [])
                    .padding(.horizontal, 9).padding(.vertical, 9)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
