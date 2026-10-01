import AppKit
import SwiftUI

struct SettingsView: View {
    @AppStorage("showMenuBar") private var showMenuBar = true
    var body: some View {
        TabView {
            Form {
                Section("Quill") {
                    Toggle("Show Quill in the menu bar", isOn: $showMenuBar)
                    LabeledContent("Appearance", value: "Follows macOS")
                    LabeledContent("Version", value: "0.1.0 · Library foundation")
                }
                Section("Storage") {
                    Text("Your snippets stay on this Mac. Saves use atomic file replacement.")
                    Text(LibraryRepository.defaultURL.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    Button("Reveal Library in Finder") { NSWorkspace.shared.activateFileViewerSelecting([LibraryRepository.defaultURL]) }
                }
            }.formStyle(.grouped).tabItem { Label("General", systemImage: "gearshape") }
            Form {
                Section("Privacy") {
                    Label("No analytics or network transmission", systemImage: "lock.shield")
                    Text("Quill does not monitor keystrokes or read your clipboard. Copy Preview writes only when you click it.")
                }
                Section("Global Expansion · Planned") {
                    Text("Accessibility and Input Monitoring are not requested in this milestone. An expansion engine will require an explicit setup flow, secure-input safeguards, and per-app exclusions before activation.")
                }
            }.formStyle(.grouped).tabItem { Label("Privacy", systemImage: "hand.raised") }
        }.frame(width: 560, height: 420)
    }
}
