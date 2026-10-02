import SwiftUI

struct SidebarView: View {
    @Bindable var store: LibraryStore
    @State private var manageGroups = false
    var body: some View {
        List(selection: Binding<String?>(get: { (store.destination == .settings) ? nil : ((store.destination == .macros) ? "macros" : store.filter) }, set: { value in
            if let value {
                if value == "macros" { store.destination = .macros }
                else { store.destination = .snippets; store.filter = value }
            }
        })) {
            Section {
                Label("All Snippets", systemImage: "text.quote").tag("all")
                Label("Favorites", systemImage: "star").tag("favorites")
                Label("Custom Macros", systemImage: "curlybraces").tag("macros")
            }
            Section {
                ForEach(store.library.groups) { group in
                    Label(group.name, systemImage: group.symbol).tag(group.id.uuidString)
                }
            } header: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Groups")
                    Button { manageGroups = true } label: {
                        Image(systemName: "folder.badge.gearshape").font(.body)
                    }.buttonStyle(.borderless).help("Manage Groups").accessibilityLabel("Manage Groups")
                        .disabled(!store.isLoaded || store.isBusy)
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $manageGroups) { GroupManagementView(store: store) }
        .listStyle(.sidebar)
        .navigationTitle("Quill")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                Button { store.destination = .settings } label: {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).frame(height: 32)
                        .foregroundStyle((store.destination == .settings) ? Color(nsColor: .alternateSelectedControlTextColor) : Color.primary)
                        .background((store.destination == .settings) ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityAddTraits((store.destination == .settings) ? .isSelected : [])
                    .padding(.horizontal, 9).padding(.vertical, 9)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
