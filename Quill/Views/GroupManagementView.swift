import SwiftUI

struct GroupManagementView: View {
    @Bindable var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selection: UUID?
    @State private var target: UUID?
    @State private var confirmDelete = false
    @FocusState private var nameFocused: Bool
    private var validName: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Manage Groups").font(.title2.weight(.semibold))
                Spacer()
                Button { selection = nil; name = ""; nameFocused = true } label: { Label("New Group", systemImage: "plus") }
            }
            List(store.library.groups, selection: $selection) { group in
                Label(group.name, systemImage: group.symbol).tag(group.id)
            }.frame(height: min(220, max(100, CGFloat(store.library.groups.count) * 30)))
            HStack {
                TextField("Group name", text: $name).textFieldStyle(.roundedBorder).accessibilityLabel("Group name").focused($nameFocused)
                    .onSubmit(saveName)
                Button(selection == nil ? "Add Group" : "Rename", action: saveName)
                    .disabled(!validName || (selection != nil && name == store.library.groups.first { $0.id == selection }?.name))
            }
            if selection != nil {
                Divider()
                Picker("Move snippets to", selection: $target) {
                    Text("Choose group").tag(UUID?.none)
                    ForEach(store.library.groups.filter { $0.id != selection }) { Text($0.name).tag(Optional($0.id)) }
                }
                HStack {
                    Text("Deleting moves this group’s snippets to the selected group.").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Delete Group…", role: .destructive) { confirmDelete = true }.disabled(target == nil || store.hasUnsavedChanges)
                }
                if store.hasUnsavedChanges { Text("Save or revert drafts before deleting a group.").font(.caption).foregroundStyle(.secondary) }
            }
            Divider()
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.cancelAction) }
        }.padding(20).frame(width: 460).disabled(store.isBusy)
        .onChange(of: selection) { _, id in
            name = store.library.groups.first { $0.id == id }?.name ?? ""
            target = store.library.groups.first { $0.id != id }?.id
        }
        .alert("Delete Group and Move Its Snippets?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Group", role: .destructive) {
                if let selection, let target { Task { await store.deleteGroup(selection, movingTo: target); self.selection = nil } }
            }
        }
    }
    private func saveName() {
        guard validName, !store.isBusy else { return }
        Task {
            if let selection { await store.renameGroup(selection, to: name) }
            else { await store.createGroup(named: name); name = ""; nameFocused = true }
        }
    }
}
