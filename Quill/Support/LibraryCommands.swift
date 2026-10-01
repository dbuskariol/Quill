import SwiftUI

struct LibraryCommands: Commands {
    let store: LibraryStore
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Snippet") { Task { await store.create() } }
                .keyboardShortcut("n").disabled(store.isBusy || !store.isLoaded)
        }
        CommandMenu("Snippet") {
            Button("Toggle Favorite") { Task { await store.toggleFavorite() } }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(store.selected == nil || store.isBusy)
            Button("Delete Snippet…") { store.pendingDelete = store.selected }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(store.selected == nil || store.isBusy)
        }
    }
}
