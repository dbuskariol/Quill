import AppKit

/// File operations stay attached to the window or review sheet that requested them.
@MainActor enum NativeFilePanel {
    static func present(_ panel: NSSavePanel) async -> NSApplication.ModalResponse {
        guard var window = NSApp.keyWindow else { return .cancel }
        while let attached = window.attachedSheet { window = attached }
        return await withCheckedContinuation { continuation in
            panel.beginSheetModal(for: window) { continuation.resume(returning: $0) }
        }
    }
}
