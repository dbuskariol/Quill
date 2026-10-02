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
        guard let store, store.isLoaded else { return .terminateNow }
        Task {
            if await store.flushDrafts() { NSApp.reply(toApplicationShouldTerminate: true) }
            else {
                let alert = NSAlert()
                alert.messageText = "Draft Recovery Could Not Be Saved"
                alert.informativeText = "Keep editing to save your changes or repair storage access before quitting. Quitting now may lose recent edits."
                alert.addButton(withTitle: "Keep Editing")
                alert.addButton(withTitle: "Quit Anyway")
                NSApp.reply(toApplicationShouldTerminate: alert.runModal() == .alertSecondButtonReturn)
            }
        }
        return .terminateLater
    }
}

@main
struct QuillApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = LibraryStore(repository: LibraryRepository(url:
        QuillLaunchConfiguration.libraryURL))
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
            store.destination = .settings
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

private enum QuillLaunchConfiguration {
    static let libraryURL: URL = {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil {
            return FileManager.default.temporaryDirectory.appending(path: "Quill-TestHost-\(UUID())/library.sqlite")
        }
        return UserDefaults.standard.string(forKey: "libraryPath").map { URL(fileURLWithPath: $0) } ?? LibraryRepository.defaultURL
    }()
}
