import SwiftUI

struct BackupReviewView: View {
    let store: LibraryStore
    let revision: LibraryRevision
    @Environment(\.dismiss) private var dismiss
    @State private var library: Library?
    @State private var error: String?
    @State private var confirm = false
    @State private var restoring = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Restore Library Backup").font(.title2.bold())
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text(revision.url.lastPathComponent).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            if let library {
                HStack {
                    LabeledContent("Snippets", value: "\(library.snippets.count)")
                    LabeledContent("Custom Macros", value: "\(library.macros.count)")
                    LabeledContent("Groups", value: "\(library.groups.count)")
                }
                List {
                    ForEach(library.snippets) { item in Label(item.title, systemImage: "text.quote") }
                    ForEach(library.macros) { item in Label(item.name, systemImage: "curlybraces") }
                }
                Text(revision.url.pathExtension == "quillbackup" ? "This backup includes template history and unsaved recovery checkpoints. Current versions remain recoverable when restoring a healthy library." : "This JSON backup restores saved templates. It does not contain per-template history or unsaved checkpoints.")
                    .font(.callout).foregroundStyle(.secondary)
            } else if error == nil { ProgressView("Checking backup…").frame(maxWidth: .infinity, minHeight: 200) }
            if store.hasUnsavedChanges { Label("Save, revert or review recovered drafts before restoring the library.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            if let error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            HStack { Spacer(); Button("Restore…") { confirm = true }.buttonStyle(.borderedProminent).disabled(library == nil || store.hasUnsavedChanges || store.isBusy || restoring) }
        }.padding(20).frame(width: 660, height: 500)
            .task { do { library = try await store.readBackup(revision.url) } catch { self.error = "Backup rejected. \(error.localizedDescription)" } }
            .alert("Restore This Library?", isPresented: $confirm) {
                Button("Cancel", role: .cancel) {}
                Button("Restore", role: .destructive) {
                    restoring = true
                    Task {
                        if await store.restore(revision) { dismiss() }
                        else { error = store.storageMessage }
                        restoring = false
                    }
                }
            } message: { Text("This replaces the current saved templates. Current content or damaged storage is preserved first. Recovery checkpoints from a full backup are offered for review afterward.") }
    }
}
