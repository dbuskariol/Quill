import SwiftUI

struct GroupManagementView: View {
    @Bindable var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selection: UUID?
    @State private var target: UUID?
    @State private var confirmDelete = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Manage Groups").font(.title2)
            List(store.library.groups, selection: $selection) { group in
                Label(group.name, systemImage: group.symbol).tag(group.id)
            }.frame(height: 180)
            TextField("Group name", text: $name)
            HStack {
                Button("Add Group") { Task { await store.createGroup(named: name); name = "" } }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Rename Selected") { if let selection { Task { await store.renameGroup(selection, to: name) } } }
                    .disabled(selection == nil || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Divider()
            Picker("Move snippets to", selection: $target) {
                Text("Choose group").tag(UUID?.none)
                ForEach(store.library.groups.filter { $0.id != selection }) { group in Text(group.name).tag(Optional(group.id)) }
            }
            Button("Delete Selected Group…", role: .destructive) { confirmDelete = true }
                .disabled(selection == nil || target == nil || store.hasUnsavedChanges)
            Text("Deleting a group moves its snippets to the chosen group. Save or revert drafts first.").font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(24).frame(width: 460).disabled(store.isBusy)
        .onChange(of: selection) { _, id in
            name = store.library.groups.first { $0.id == id }?.name ?? ""
            target = store.library.groups.first { $0.id != id }?.id
        }
        .alert("Delete Group and Move Its Snippets?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Group", role: .destructive) {
                if let selection, let target { Task { await store.deleteGroup(selection, movingTo: target); self.selection = nil } }
            }
        }
    }
}
