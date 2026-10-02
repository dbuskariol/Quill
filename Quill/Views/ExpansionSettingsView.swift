import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ExpansionSettingsView: View {
    @Bindable var expansion: ExpansionController
    var body: some View {
        Section {
            Text(expansion.status).id(expansion.status).textSelection(.enabled)
            Button(expansion.isEnabled ? "Pause Expansion" : "Enable Expansion") {
                if expansion.isEnabled { expansion.pause() } else { expansion.enable() }
            }
            Picker("Keep expansion enabled", selection: $expansion.duration) {
                ForEach(ExpansionDuration.allCases) { Text($0.title).tag($0) }
            }
            Text(expansion.duration.explanation).font(.caption).foregroundStyle(.secondary)
            if let deadline = expansion.endsAt {
                LabeledContent("Pauses at", value: deadline.formatted(date: .omitted, time: .shortened))
            }
            Text("Type a saved abbreviation in an application you allow. Templates with fill-ins open a form before insertion.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Permission Setup") {
            LabeledContent("Accessibility", value: expansion.accessibilityGranted ? "Granted" : "Not granted")
            Button("Set Up Accessibility…") { expansion.requestAccessibility() }.disabled(expansion.accessibilityGranted)
            LabeledContent("Input Monitoring", value: expansion.inputGranted ? "Granted" : "Not granted")
            Button("Set Up Input Monitoring…") { expansion.requestInputMonitoring() }.disabled(expansion.inputGranted)
            if !expansion.inputGranted {
                Text("If Quill isn’t listed in Input Monitoring, click + and choose Quill in Applications. Reopen Quill if macOS asks.").font(.caption).foregroundStyle(.secondary)
                Button("Show Quill in Finder") { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
            }
            Button("Refresh Permission Status") { expansion.refreshPermissions() }
            Text("These permissions let Quill detect abbreviations and replace text in allowed apps. Password fields and secure input are excluded; keystrokes are not recorded.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Matching") {
            Picker("Expand abbreviations", selection: $expansion.policy.trigger) {
                ForEach(ExpansionPolicy.Trigger.allCases) { Text($0.title).tag($0) }
            }
            Text("When one abbreviation starts another, finish the longer abbreviation or press Space to expand the shorter one.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Match abbreviation case", isOn: $expansion.policy.caseSensitive)
            Toggle("Require a word boundary before abbreviations", isOn: $expansion.policy.requiresWordBoundary)
        }
        Section {
            Picker("Expand in", selection: $expansion.policy.applicationScope) {
                ForEach(ExpansionPolicy.ApplicationScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            Text(expansion.policy.applicationScope == .all
                 ? "Expand in every supported application except those excluded below."
                 : "Expand only in the applications you choose below.")
                .font(.caption).foregroundStyle(.secondary)
        }
        if expansion.policy.applicationScope == .selected {
            Section("Selected Applications") {
                ExpansionApplicationList(applications: expansion.policy.selectedApplications,
                                         emptyMessage: "Choose an application to enable expansion in it.",
                                         addLabel: "Add Application…") { apps in
                    expansion.policy.add(apps, excluding: false)
                } remove: { ids in
                    expansion.policy.selectedApplications.removeAll { ids.contains($0.id) }
                }
            }
        }
        Section("Excluded Applications") {
            ExpansionApplicationList(applications: expansion.policy.excludedApplications,
                                     emptyMessage: "No applications excluded.",
                                     addLabel: "Exclude Application…") { apps in
                expansion.policy.add(apps, excluding: true)
            } remove: { ids in
                expansion.policy.excludedApplications.removeAll { ids.contains($0.id) }
            }
            Text("Excluded applications never expand. Password fields and secure input are always protected, including in All Applications mode.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            expansion.refreshPermissions()
        }
    }
}

private struct ExpansionApplicationList: View {
    let applications: [ExpansionApplication]
    let emptyMessage: String
    let addLabel: String
    let add: ([ExpansionApplication]) -> Void
    let remove: (Set<String>) -> Void
    @State private var selection: Set<String> = []
    @State private var pickerError: String?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(applications) { app in
                    ExpansionApplicationRow(application: app).tag(app.id)
                        .contextMenu {
                            Button("Remove Application") { remove([app.id]); selection.remove(app.id) }
                        }
                }
            }
            .onDeleteCommand(perform: removeSelected)
            .listStyle(.inset)
            .frame(height: 140)
            .overlay {
                if applications.isEmpty {
                    Text(emptyMessage).foregroundStyle(.secondary)
                        .font(.callout).padding().allowsHitTesting(false)
                }
            }
            Divider()
            HStack(spacing: 12) {
                Button(action: chooseApplications) { Image(systemName: "plus") }
                    .accessibilityLabel(addLabel).help(addLabel)
                Button { removeSelected() } label: { Image(systemName: "minus") }
                    .disabled(selection.isEmpty)
                    .accessibilityLabel("Remove selected applications").help("Remove selected applications")
                Spacer()
            }
            .buttonStyle(.borderless).controlSize(.small).padding(8)
        }
        .border(Color(nsColor: .separatorColor))
        .onChange(of: applications) { _, items in selection.formIntersection(Set(items.map(\.id))) }
        .alert("Could Not Add Application", isPresented: Binding(get: { pickerError != nil }, set: { if !$0 { pickerError = nil } })) {
            Button("OK") { pickerError = nil }
        } message: { Text(pickerError ?? "") }
    }
    private func removeSelected() {
        remove(selection)
        selection.removeAll()
    }
    private func chooseApplications() {
        let panel = NSOpenPanel()
        panel.title = addLabel
        panel.prompt = "Add"
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let complete: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK else { return }
            var chosen: [ExpansionApplication] = []
            for url in panel.urls {
                guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier, !id.isEmpty else {
                    pickerError = "\(url.deletingPathExtension().lastPathComponent) is not a valid macOS application."
                    return
                }
                chosen.append(.init(id: id, name: FileManager.default.displayName(atPath: url.path)
                    .replacingOccurrences(of: ".app", with: ""), path: url.path))
            }
            add(chosen)
            selection = Set(chosen.map(\.id))
        }
        if let window = NSApp.keyWindow { panel.beginSheetModal(for: window, completionHandler: complete) }
        else { panel.begin(completionHandler: complete) }
    }
}

private struct ExpansionApplicationRow: View {
    let application: ExpansionApplication
    private var url: URL? {
        if let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: application.id) { return installed }
        if let path = application.path, FileManager.default.fileExists(atPath: path) { return URL(fileURLWithPath: path) }
        return nil
    }
    var body: some View {
        HStack(spacing: 8) {
            if let url {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.dashed").frame(width: 24, height: 24).foregroundStyle(.secondary)
            }
            Text(application.name)
            Spacer()
            if url == nil { Text("Not installed").font(.caption).foregroundStyle(.secondary) }
        }
    }
}
