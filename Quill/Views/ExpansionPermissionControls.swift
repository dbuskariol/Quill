import AppKit
import SwiftUI

/// Setup and Settings share permission status, recovery guidance and explicit actions.
struct ExpansionPermissionControls: View {
    let expansion: ExpansionController
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            permission("Accessibility", detail: "Replace abbreviations in your editor.", granted: expansion.accessibilityGranted,
                       action: expansion.requestAccessibility)
            permission("Input Monitoring", detail: "Recognize the abbreviations you type.", granted: expansion.inputGranted,
                       action: expansion.requestInputMonitoring)
            if !expansion.inputGranted {
                Text("If Quill isn’t listed, click + in Input Monitoring and choose Quill in Applications. Reopen Quill if macOS asks.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Show Quill in Finder") { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
            }
            Text("Password fields are protected. Quill doesn’t record keystrokes.")
                .font(.caption).foregroundStyle(.secondary)
            if !expansion.accessibilityGranted || !expansion.inputGranted {
                Button("Refresh Status") { expansion.refreshPermissions() }.controlSize(.small)
            }
        }
        .onAppear { expansion.refreshPermissions() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in expansion.refreshPermissions() }
    }
    private func permission(_ title: String, detail: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.medium)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if granted { Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.callout) }
            else { Button("Open Settings…", action: action).accessibilityLabel("Set Up \(title)") }
        }
    }
}
