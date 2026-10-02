import AppKit
import SwiftUI

struct ExpansionSettingsView: View {
    @Bindable var expansion: ExpansionController
    @State private var bundleID = ""
    var body: some View {
        Section {
            Text(expansion.status).textSelection(.enabled)
            Button(expansion.isEnabled ? "Pause Expansion" : "Enable Expansion") {
                if expansion.isEnabled { expansion.pause() } else { expansion.enable() }
            }
            Text("Paused at launch. Supports plain templates in allowed text editors; fill-ins and composing input methods are not supported yet.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Permission Setup") {
            LabeledContent("Accessibility", value: expansion.accessibilityGranted ? "Granted" : "Not granted")
            Button("Set Up Accessibility…") { expansion.requestAccessibility() }.disabled(expansion.accessibilityGranted)
            LabeledContent("Input Monitoring", value: expansion.inputGranted ? "Granted" : "Not granted")
            Button("Set Up Input Monitoring…") { expansion.requestInputMonitoring() }.disabled(expansion.inputGranted)
            Button("Refresh Permission Status") { expansion.refreshPermissions() }
            Text("These permissions let Quill detect delimiters and replace text in allowed apps. Password fields and secure input are excluded; keystrokes are not recorded.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Matching") {
            TextField("Delimiters", text: $expansion.policy.delimiters)
            Button("Use Space, Tab and Return") { expansion.policy.delimiters = " \t\n" }
            Toggle("Match abbreviation case", isOn: $expansion.policy.caseSensitive)
            Toggle("Require a word boundary before abbreviations", isOn: $expansion.policy.requiresWordBoundary)
        }
        Section("Allowed Applications") {
            Text("Unknown apps are excluded. Add the bundle identifier of an editor you want to test.").font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("Bundle identifier", text: $bundleID)
                Button("Allow") {
                    let id = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !id.isEmpty && !expansion.policy.allowedBundleIDs.contains(id) { expansion.policy.allowedBundleIDs.append(id) }
                    bundleID = ""
                }.disabled(bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ForEach(expansion.policy.allowedBundleIDs, id: \.self) { id in
                LabeledContent(id) { Button("Remove") { expansion.policy.allowedBundleIDs.removeAll { $0 == id } } }
            }
        }
        Section("Excluded Applications") {
            Text("Exclusions take precedence over the allowed list.").font(.caption).foregroundStyle(.secondary)
            ForEach(expansion.policy.excludedBundleIDs, id: \.self) { id in Text(id) }
        }
    }
}
