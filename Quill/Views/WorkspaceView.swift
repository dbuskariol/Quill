import SwiftUI

struct WorkspaceView: View {
    @Bindable var store: LibraryStore
    let preferences: AppPreferences
    let updates: SoftwareUpdateController
    let expansion: ExpansionController?
    var body: some View {
        Group {
            if (store.destination == .settings) {
                NavigationSplitView {
                    SidebarView(store: store)
                        .navigationSplitViewColumnWidth(min: 170, ideal: 200, max: 260)
                } detail: {
                    SettingsView(preferences: preferences, store: store, updates: updates, expansion: expansion)
                }.navigationSplitViewStyle(.balanced)
            } else if (store.destination == .macros) { CustomMacrosView(store: store) }
            else { LibraryView(store: store) }
        }
        .safeAreaInset(edge: .top) {
            if !store.recoveredDrafts.isEmpty {
                HStack {
                    Label("Unsaved edits are available to recover", systemImage: "clock.arrow.circlepath")
                    Spacer()
                    Button("Review…") { store.showDraftRecovery = true }
                }.font(.callout).padding(.horizontal, 20).padding(.vertical, 10).background(.bar)
            }
            if let message = store.draftRecoveryMessage {
                Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.callout).padding(10)
            }
        }
        .onOpenURL { url in
            if url.isFileURL && url.pathExtension == "quillbackup" { store.backupRequest = LibraryRevision(url: url, date: .now) }
        }
        .sheet(item: $store.backupRequest) { revision in BackupReviewView(store: store, revision: revision) }
        .sheet(item: $store.historyRequest) { request in TemplateHistoryView(store: store, itemID: request.itemID) }
        .sheet(isPresented: $store.showDraftRecovery) { DraftRecoveryView(store: store) }
        .frame(minWidth: 940, minHeight: 580)
        .sheet(isPresented: $store.showQuickActions) { CommandPaletteView(store: store) }
        .sheet(isPresented: $store.showTextExpanderImport) { TextExpanderImportView(store: store) }
        .alert("Delete Snippet?", isPresented: Binding(get: { store.pendingDelete != nil }, set: { if !$0 { store.pendingDelete = nil } }), presenting: store.pendingDelete) { item in
            Button("Cancel", role: .cancel) { store.pendingDelete = nil }
            Button("Delete", role: .destructive) { store.pendingDelete = nil; Task { await store.delete(item) } }
        } message: { item in Text("“\(item.title)” will be removed from your local library. Other snippets that reference it may need updating.") }
        .alert("Library Needs Attention", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            if !store.isLoaded {
                Button("Retry") { Task { await store.load() } }
                Button("Library Settings…") { store.errorMessage = nil; store.destination = .settings }
            }
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
}
