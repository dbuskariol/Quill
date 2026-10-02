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
    @State private var menuBar = MenuBarController()
    @State private var expansion: ExpansionController?

    var body: some Scene {
        WindowGroup("Quill", id: "library") {
            WorkspaceView(store: store, preferences: preferences, updates: updates, expansion: expansion)
                .background(MenuBarLifecycleView(controller: menuBar, store: store, preferences: preferences, expansion: expansion))
                .onAppear { delegate.store = store; delegate.preferences = preferences; preferences.applyActivationPolicy() }
                .task {
                    await store.load()
                    if expansion == nil { expansion = ExpansionController(store: store) }
                    if store.isLoaded, !QuillLaunchConfiguration.isTesting, preferences.setupDisposition.shouldPresentAutomatically {
                        store.showOnboarding = true
                    }
                }
        }
        .defaultSize(width: 1120, height: 740)
        .commands { LibraryCommands(store: store) }

    }
}

private enum QuillLaunchConfiguration {
    static var isTesting: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil
    }
    static let libraryURL: URL = {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil {
            return FileManager.default.temporaryDirectory.appending(path: "Quill-TestHost-\(UUID())/library.sqlite")
        }
        return UserDefaults.standard.string(forKey: "libraryPath").map { URL(fileURLWithPath: $0) } ?? LibraryRepository.defaultURL
    }()
}
