import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

private enum SettingsPage: String, CaseIterable, Identifiable {
    case general = "General", storage = "Library", expansion = "Expansion", privacy = "Privacy", statistics = "Statistics", updates = "Updates"
    var id: Self { self }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .storage: "folder"
        case .expansion: "text.cursor"
        case .privacy: "hand.raised"
        case .statistics: "chart.bar"
        case .updates: "arrow.triangle.2.circlepath"
        }
    }
}

struct SettingsView: View {
    @Bindable var preferences: AppPreferences
    @Bindable var store: LibraryStore
    @Bindable var updates: SoftwareUpdateController
    let expansion: ExpansionController?
    @Environment(\.scenePhase) private var scenePhase
    @SceneStorage("settings.category") private var pageName = SettingsPage.general.rawValue
    private var page: SettingsPage { SettingsPage(rawValue: pageName) ?? .general }
    @State private var restoreRevision: LibraryRevision?
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(SettingsPage.allCases) { item in
                    Button { pageName = item.rawValue } label: {
                        Label(item.rawValue, systemImage: item.symbol)
                            .font(.callout.weight(.medium)).padding(.horizontal, 11).frame(height: 32)
                            .background(page == item ? Color.accentColor.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain).foregroundStyle(page == item ? .primary : .secondary)
                        .accessibilityAddTraits(page == item ? .isSelected : []).help(item.rawValue)
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 22).frame(height: 52).background(.bar)
            Divider()
            Form {
                switch page {
                case .statistics: StatisticsSettingsView(statistics: store.statistics, store: store)
                case .expansion: if let expansion { ExpansionSettingsView(expansion: expansion) }
                case .general: general
                case .storage: storage
                case .privacy: privacy
                case .updates: updateSettings
                }
            }.formStyle(.grouped).scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Settings")
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { preferences.refreshLoginStatus(); Task { await store.refreshHistory() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { preferences.refreshLoginStatus(); expansion?.refreshPermissions() } }
        .alert("Replace Library?", isPresented: Binding(get: { store.pendingImport != nil }, set: { if !$0 { store.pendingImport = nil } })) {
            Button("Cancel", role: .cancel) { store.pendingImport = nil }
            Button("Replace", role: .destructive) { Task { await store.applyImport() } }
                .disabled(store.hasUnsavedChanges || store.isBusy)
        } message: {
            Text("Import \(store.pendingImport?.snippets.count ?? 0) snippets in \(store.pendingImport?.groups.count ?? 0) groups? Your current saved library will be backed up first. Save or revert all drafts before replacing it.")
        }
        .alert("Restore Revision?", isPresented: Binding(get: { restoreRevision != nil }, set: { if !$0 { restoreRevision = nil } })) {
            Button("Cancel", role: .cancel) { restoreRevision = nil }
            Button("Restore", role: .destructive) {
                if let revision = restoreRevision { Task { await store.restore(revision) } }
                restoreRevision = nil
            }
        } message: { Text("This replaces the saved library. The current file, including damaged data, is preserved in History first.") }
    }
    private var general: some View {
        Group {
            Section {
                Toggle("Show Quill in the menu bar", isOn: $preferences.showMenuBar)
                    .disabled(!preferences.showDock).help("Keep the Dock or menu bar entry available.")
                Toggle("Show Quill in the Dock", isOn: $preferences.showDock)
                    .disabled(!preferences.showMenuBar).help("Keep the Dock or menu bar entry available.")
                Toggle("Quit when the last window closes", isOn: $preferences.quitWhenLastWindowCloses)
            }
            Section {
                Toggle("Launch at login", isOn: Binding(get: { preferences.loginStatus == .enabled }, set: { preferences.setLaunchAtLogin($0) }))
                if preferences.loginStatus == .requiresApproval {
                    Text("Approval is required in macOS Login Items.")
                    Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                }
                if preferences.loginStatus == .notFound { Text("Launch at login is unavailable from this development location.").foregroundStyle(.secondary) }
                if let error = preferences.loginError { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
            }
        }
    }
    private var storage: some View {
        Group {
            Section("Location") {
                Text(store.storageURL.path).font(.caption).textSelection(.enabled)
                HStack {
                    Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([store.storageURL]) }
                    Button("Choose Location…", action: chooseLocation).disabled(!canReplace)
                        .help("Copies your saved library to the selected folder and keeps the original.")
                }
            }
            Section {
                Button("Import from TextExpander…") { store.showTextExpanderImport = true }.disabled(!canReplace)
                HStack {
                    Button("Import Quill JSON…", action: importLibrary).disabled(!canReplace)
                    Button("Export Quill JSON…", action: exportLibrary).disabled(!store.isLoaded || store.isBusy)
                }
            }
            Section("History & Recovery") {
                HStack {
                    Button("Back Up Now") { Task { await store.backup() } }.disabled(store.isBusy)
                    Button("Reveal History") { NSWorkspace.shared.open(store.storageURL.deletingLastPathComponent().appending(path: "Quill History")) }
                    Button("Refresh") { Task { await store.refreshHistory() } }
                }
                Text("Previous versions are backed up automatically.").font(.caption).foregroundStyle(.secondary)
                ForEach(store.revisions.prefix(20)) { revision in
                    LabeledContent {
                        Button("Restore…") { restoreRevision = revision }.disabled(store.isBusy || store.hasUnsavedChanges)
                    } label: {
                        Text(revision.date, format: .dateTime.year().month().day().hour().minute().second())
                    }
                }
                if store.revisions.isEmpty { Text("No revisions yet.").foregroundStyle(.secondary) }
                if let message = store.storageMessage { Text(message).textSelection(.enabled) }
            }
        }
    }
    private var privacy: some View {
        Group {
            Section("Local Data") {
                Text("Quill does not upload snippets, read the clipboard, or retain keystroke logs. Optional aggregate usage totals stay on this Mac. Copy Preview writes only when you choose it.")
            }
            Section("Expansion Permissions") {
                Text("Expansion starts only after you grant access through the Expansion setup controls and explicitly enable it. Secure input and password fields are excluded.")
            }
            Section("Update Connections") {
                Text("When a signed release feed is configured, checking for updates contacts that feed. Automatic checks are off by default; library content is never sent.")
            }
        }
    }
    private var updateSettings: some View {
        Group {
            Section {
                LabeledContent("Version", value: updates.version)
                Text(updates.status).textSelection(.enabled)
            }
            Section {
                Toggle("Automatically check for updates", isOn: Binding(get: { updates.automaticallyChecks }, set: { updates.setAutomaticChecks($0) })).disabled(!updates.isConfigured)
                Toggle("Download verified updates automatically", isOn: Binding(get: { updates.automaticallyDownloads }, set: { updates.setAutomaticDownloads($0) })).disabled(!updates.isConfigured || !updates.automaticallyChecks)
                Button("Check for Updates…") { updates.checkNow() }.disabled(!updates.canCheck)
            }
        }
    }
    private var canReplace: Bool { store.isLoaded && !store.isBusy && !store.hasUnsavedChanges }
    private func chooseLocation() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.prompt = "Use Folder"
        if panel.runModal() == .OK, let url = panel.url { Task { await store.moveStorage(to: url) } }
    }
    private func importLibrary() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { Task { await store.previewImport(from: url) } }
    }
    private func exportLibrary() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "Quill Library.json"
        if panel.runModal() == .OK, let url = panel.url { Task { await store.export(to: url) } }
    }
}
