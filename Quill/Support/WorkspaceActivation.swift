import AppKit
import SwiftUI

@MainActor func showQuillWorkspace(openWindow: OpenWindowAction) {
    if let window = NSApp.windows.first(where: { $0.canBecomeMain && ($0.isVisible || $0.isMiniaturized) }) {
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
    } else { openWindow(id: "library") }
    NSApp.activate(ignoringOtherApps: true)
}
