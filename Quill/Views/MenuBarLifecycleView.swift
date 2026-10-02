import SwiftUI

/// Supplies SwiftUI's window action once; the native controller outlives library windows.
struct MenuBarLifecycleView: View {
    let controller: MenuBarController
    let store: LibraryStore
    let preferences: AppPreferences
    let expansion: ExpansionController?
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .onAppear(perform: configure)
            .onChange(of: expansion == nil) { _, _ in configure() }
    }
    private func configure() {
        controller.configure(store: store, preferences: preferences, expansion: expansion, openWindow: openWindow)
    }
}
