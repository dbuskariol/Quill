import AppKit
import SwiftUI

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var store: LibraryStore?
    var preferences: AppPreferences?
    func applicationDidFinishLaunching(_ notification: Notification) {
        preferences?.applyActivationPolicy()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        preferences?.quitWhenLastWindowCloses ?? false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store, store.hasUnsavedChanges else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Discard Unsaved Changes?"
        alert.informativeText = "Save your edited snippets and custom macros before quitting to keep your changes."
        alert.addButton(withTitle: "Keep Editing")
        alert.addButton(withTitle: "Discard and Quit")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
}

@main
struct QuillApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = LibraryStore(repository: LibraryRepository(url:
        UserDefaults.standard.string(forKey: "libraryPath").map { URL(fileURLWithPath: $0) } ?? LibraryRepository.defaultURL))
    @State private var preferences = AppPreferences()
    @State private var updates = SoftwareUpdateController()
    @State private var expansion: ExpansionController?

    var body: some Scene {
        WindowGroup("Quill", id: "library") {
            WorkspaceView(store: store, preferences: preferences, updates: updates, expansion: expansion)
                .onAppear { delegate.store = store; delegate.preferences = preferences; preferences.applyActivationPolicy() }
                .task { await store.load(); if expansion == nil { expansion = ExpansionController(store: store) } }
        }
        .defaultSize(width: 1120, height: 740)
        .commands { LibraryCommands(store: store) }
        MenuBarExtra("Quill", systemImage: "text.quote", isInserted: $preferences.showMenuBar) {
            MenuBarView(store: store, expansion: expansion)
        }
    }
}

private struct MenuBarView: View {
    let store: LibraryStore
    let expansion: ExpansionController?
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Open Quill Library") {
            store.destination = .snippets
            showQuillWorkspace(openWindow: openWindow)
        }
        Button("Settings…") {
            store.isShowingSettings = true
            showQuillWorkspace(openWindow: openWindow)
        }
        Divider()
        if let expansion {
            Button(expansion.isEnabled ? "Pause Expansion" : "Enable Expansion") {
                if expansion.isEnabled { expansion.pause() } else { expansion.enable() }
            }
        }
        Divider()
        Button("Quit Quill") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
