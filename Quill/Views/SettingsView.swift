import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var preferences: AppPreferences
    @Bindable var store: LibraryStore
    @Bindable var updates: SoftwareUpdateController
    let expansion: ExpansionController?
    @Environment(\.scenePhase) private var scenePhase
    @SceneStorage("settings.category") private var pageName = SettingsPage.general.rawValue
    @State private var proposedHistoryLimit: Int?
    private var page: SettingsPage { SettingsPage(rawValue: pageName) ?? .general }
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
        .onAppear { applyRequestedPage(); preferences.refreshLoginStatus(); Task { await store.refreshHistory() } }
        .onChange(of: store.requestedSettingsPage) { _, _ in applyRequestedPage() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { preferences.refreshLoginStatus(); expansion?.refreshPermissions() } }
        .alert("Keep Fewer Versions?", isPresented: Binding(get: { proposedHistoryLimit != nil }, set: { if !$0 { proposedHistoryLimit = nil } }), presenting: proposedHistoryLimit) { limit in
            Button("Cancel", role: .cancel) { proposedHistoryLimit = nil }
            Button("Apply", role: .destructive) {
                Task { await store.changeHistoryLimit(limit) }
                proposedHistoryLimit = nil
            }
        } message: { limit in Text("Older versions beyond the newest \(limit) per template will be removed. Versions marked Keep stay available. Export a library backup first if you want to preserve all history.") }
        .alert("Replace Library?", isPresented: Binding(get: { store.pendingImport != nil }, set: { if !$0 { store.pendingImport = nil } }), presenting: store.pendingImport) { imported in
            Button("Cancel", role: .cancel) { store.pendingImport = nil }
            Button("Replace", role: .destructive) { Task { await store.applyImport(imported) } }
                .disabled(store.hasUnsavedChanges || store.isBusy)
        } message: { imported in
            Text("Import \(imported.snippets.count) snippets in \(imported.groups.count) groups? Your current saved library will be backed up first. Save or revert all drafts before replacing it.")
        }

    }
    private func applyRequestedPage() {
        if let requested = store.requestedSettingsPage {
            pageName = requested.rawValue
            store.requestedSettingsPage = nil
        }
    }
    private var general: some View {
        Group {
            Section {
                Toggle("Show Quill in the menu bar", isOn: $preferences.showMenuBar)
                    .disabled(!preferences.showDock).help("Keep the Dock or menu bar entry available.")
                Toggle("Show Quill in the Dock", isOn: $preferences.showDock)
                    .disabled(!preferences.showMenuBar).help("Keep the Dock or menu bar entry available.")
                Picker("When the library window closes", selection: $preferences.quitWhenLastWindowCloses) {
                    Text("Keep Quill Running").tag(false)
                    Text("Quit Quill").tag(true)
                }
                Text(preferences.quitWhenLastWindowCloses
                     ? "Closing the last window quits Quill and stops expansion."
                     : "Quill stays available in the menu bar or Dock. Use Quit Quill to stop it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Launch at login", isOn: Binding(get: { preferences.loginStatus == .enabled }, set: { preferences.setLaunchAtLogin($0) }))
                if preferences.loginStatus == .requiresApproval {
                    Text("Approval is required in macOS Login Items.")
                    Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                }
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
                    Button(store.isLoaded ? "Choose Location…" : "Open Library Folder…", action: chooseLocation).disabled(store.isBusy || store.hasUnsavedChanges)
                        .help("Copies your saved library to the selected folder and keeps the original.")
                }
            }
            Section {
                Button("Import from TextExpander…") { store.showTextExpanderImport = true }.disabled(!canReplace)
                HStack {
                    Button("Import Quill JSON…", action: importLibrary).disabled(!canReplace)
                    Menu("Export…") {
                        Button("Quill JSON — Saved Templates…", action: exportLibrary)
                        Button("Library Backup — Includes History…", action: exportBackup)
                    }.disabled(!store.isLoaded || store.isBusy)
                }
            }
            Section("History & Recovery") {
                Button("Open Backup…", action: openBackup).disabled(store.isBusy || store.hasUnsavedChanges)
                Picker("Versions per template", selection: Binding(get: { store.historyLimit }, set: { value in if value < store.historyLimit { proposedHistoryLimit = value } else { Task { await store.changeHistoryLimit(value) } } })) {
                    Text("30").tag(30); Text("100").tag(100); Text("500").tag(500)
                }.disabled(!store.isLoaded || store.isBusy)
                Text("Kept versions stay until you stop keeping them. The newest versions include deleted content. Complete library backups stay until you remove them.").font(.caption).foregroundStyle(.secondary)
                Button("Deleted Templates…") { store.historyRequest = HistoryRequest(itemID: nil) }.disabled(!store.isLoaded)

                HStack {
                    Button("Back Up Now") { Task { await store.backup() } }.disabled(store.isBusy)
                    Button("Reveal History") { NSWorkspace.shared.open(store.storageURL.deletingLastPathComponent().appending(path: "Quill History")) }
                    Button("Refresh") { Task { await store.refreshHistory() } }
                }
                Text("Saved template versions live in History beside each editor. These backups recover the whole saved library.").font(.caption).foregroundStyle(.secondary)
                ForEach(store.revisions.prefix(20)) { revision in
                    LabeledContent {
                        Button("Restore…") { store.backupRequest = revision }.disabled(store.isBusy || store.hasUnsavedChanges || !revision.isRecoverable)
                    } label: {
                        VStack(alignment: .leading) { Text(revision.date, format: .dateTime.year().month().day().hour().minute().second()); Text(!revision.isRecoverable ? "Preserved damaged database" : revision.url.pathExtension == "quillbackup" ? "Complete library backup" : "Saved templates snapshot").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                if store.revisions.isEmpty { Text("No library backups yet.").foregroundStyle(.secondary) }
                if let message = store.storageMessage { Text(message).textSelection(.enabled) }
            }
        }
    }
    private var privacy: some View {
        Group {
            Section("Local Data") {
                Text("Quill does not upload snippets, read the clipboard, or retain keystroke logs. Optional aggregate usage totals stay on this Mac. Authored drafts are checkpointed for recovery; fill-in values and resolved previews are never saved to history. Copy writes only when you choose it.")
            }
            Section("Expansion Permissions") {
                Text("Expansion starts only after you grant access through the Expansion setup controls and explicitly enable it. Across Launches resumes expansion only after you choose that mode and enable it. Secure input and password fields are excluded.")
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
        if panel.runModal() == .OK, let url = panel.url { Task { if store.isLoaded { await store.moveStorage(to: url) } else { await store.openStorage(in: url) } } }
    }
    private func importLibrary() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { Task { await store.previewImport(from: url) } }
    }
    private func openBackup() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = false; panel.allowedContentTypes = [QuillFileTypes.libraryBackup, .json]
        if panel.runModal() == .OK, let url = panel.url { store.backupRequest = LibraryRevision(url: url, date: .now) }
    }
    private func exportBackup() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [QuillFileTypes.libraryBackup]; panel.nameFieldStringValue = "Quill Library.quillbackup"
        if panel.runModal() == .OK, let url = panel.url { Task { await store.exportBackup(to: url) } }
    }
    private func exportLibrary() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "Quill Library.json"
        if panel.runModal() == .OK, let url = panel.url { Task { await store.export(to: url) } }
    }
}
