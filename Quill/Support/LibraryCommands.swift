import AppKit
import SwiftUI

struct LibraryCommands: Commands {
    let store: LibraryStore
    @Environment(\.openWindow) private var openWindow
    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                store.destination = .settings
                showQuillWorkspace(openWindow: openWindow)
            }.keyboardShortcut(",")
        }
        CommandGroup(replacing: .newItem) {
            Button((store.destination == .macros) ? "New Macro" : "New Snippet") {
                if (store.destination == .macros) { store.createMacro() } else { Task { await store.create() } }
            }
                .keyboardShortcut("n").disabled(store.isBusy || !store.isLoaded)
        }
        CommandMenu("Library") {
            Button("Custom Macros") { store.destination = .macros; showQuillWorkspace(openWindow: openWindow) }.disabled(!store.isLoaded || store.isBusy)
            Button("Import from TextExpander…") {
                showQuillWorkspace(openWindow: openWindow)
                store.showTextExpanderImport = true
            }.disabled(!store.isLoaded || store.isBusy || store.hasUnsavedChanges)
            Button("Quick Actions…") { store.showQuickActions = true }.keyboardShortcut("k").disabled(!store.isLoaded || store.isBusy)
            Button("Repeat Last Copy") { store.quickActions.repeatLastCopy() }.disabled(store.quickActions.lastCopiedText == nil)
            Button("Clear Last Copy") { store.quickActions.clear() }.disabled(store.quickActions.lastCopiedText == nil)
            Button("Template History…") { store.historyRequest = HistoryRequest(itemID: (store.destination == .macros) ? store.selectedMacroID : store.selectedID) }
                .disabled(store.destination == .settings || ((store.destination == .macros) ? store.selectedMacroID == nil : store.selectedID == nil))
            Button("Deleted Templates…") { store.historyRequest = HistoryRequest(itemID: nil); showQuillWorkspace(openWindow: openWindow) }.disabled(!store.isLoaded)
            Button("Undo Last Library Change") { Task { await store.undoLastLibraryChange() } }
                .keyboardShortcut("z", modifiers: [.command, .option]).disabled(!store.canUndoLibrary)
        }
        CommandMenu("Snippet") {
            Button("Toggle Favorite") { Task { await store.toggleFavorite() } }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(store.selected == nil || store.isBusy || store.destination != .snippets)
            Button("Delete Snippet…") { store.pendingDelete = store.selected }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(store.selected == nil || store.isBusy || store.destination != .snippets)
        }
    }
}
