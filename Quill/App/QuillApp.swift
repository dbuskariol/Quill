import AppKit
import SwiftUI

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var store: LibraryStore?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store, !store.drafts.isEmpty else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Discard Unsaved Changes?"
        alert.informativeText = "Save your edited snippets before quitting to keep your changes."
        alert.addButton(withTitle: "Keep Editing")
        alert.addButton(withTitle: "Discard and Quit")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
}

@main
struct QuillApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = LibraryStore()
    @AppStorage("showMenuBar") private var showMenuBar = true

    var body: some Scene {
        WindowGroup("Quill", id: "library") {
            LibraryView(store: store)
                .onAppear { delegate.store = store }
                .task { await store.load() }
        }
        .defaultSize(width: 1120, height: 740)
        .commands { LibraryCommands(store: store) }
        Settings { SettingsView() }
        MenuBarExtra("Quill", systemImage: "text.quote", isInserted: $showMenuBar) {
            MenuBarView()
        }
    }
}

private struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Open Quill Library") {
            openWindow(id: "library")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink()
        Divider()
        Text("Global expansion is planned")
        Divider()
        Button("Quit Quill") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
