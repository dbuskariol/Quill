import AppKit
import Observation
import SwiftUI

/// AppKit owns menu tracking, click-outside dismissal, Escape, and the status button.
@MainActor final class MenuBarController: NSObject, NSMenuDelegate {
    private var item: NSStatusItem?
    private let menu = NSMenu(title: "Quill")
    private var store: LibraryStore?
    private var preferences: AppPreferences?
    private var expansion: ExpansionController?
    private var openWindow: OpenWindowAction?
    private var observationGeneration = 0

    func configure(store: LibraryStore, preferences: AppPreferences,
                   expansion: ExpansionController?, openWindow: OpenWindowAction) {
        self.store = store; self.preferences = preferences
        self.expansion = expansion; self.openWindow = openWindow
        menu.delegate = self
        menu.autoenablesItems = false
        observationGeneration += 1
        observeState(generation: observationGeneration)
    }

    private func observeState(generation: Int) {
        guard generation == observationGeneration else { return }
        withObservationTracking {
            updateItem(visible: preferences?.showMenuBar == true, enabled: expansion?.isEnabled == true)
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeState(generation: generation) }
        }
    }

    private func updateItem(visible: Bool, enabled: Bool) {
        guard visible else {
            if let item { NSStatusBar.system.removeStatusItem(item) }
            item = nil
            return
        }
        if item == nil {
            item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item?.menu = menu
            item?.button?.setAccessibilityLabel("Quill")
        }
        let image = NSImage(systemSymbolName: enabled ? "text.quote" : "pause.circle", accessibilityDescription: "Quill")
        image?.isTemplate = true
        item?.button?.image = image
        item?.button?.toolTip = enabled ? "Quill — Expansion Enabled" : "Quill — Expansion Paused"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        expansion?.refreshPermissions()
        menu.removeAllItems()
        add("Open Quill Library", action: #selector(openLibrary))
        add("Quick Actions…", action: #selector(openQuickActions), enabled: store?.isLoaded == true && store?.isBusy == false)
        add("Settings…", action: #selector(openSettings))
        menu.addItem(.separator())
        if let expansion {
            add(expansion.isEnabled ? "Expansion Enabled" : "Expansion Paused", enabled: false)
            if let deadline = expansion.endsAt {
                add("Pauses at \(deadline.formatted(date: .omitted, time: .shortened))", enabled: false)
            }
            let duration = NSMenu(title: "Expansion Duration")
            for value in ExpansionDuration.allCases {
                let entry = NSMenuItem(title: value.title, action: #selector(chooseDuration(_:)), keyEquivalent: "")
                entry.target = self; entry.representedObject = value.rawValue
                entry.state = expansion.duration == value ? .on : .off
                duration.addItem(entry)
            }
            let durationItem = add("Expansion Duration")
            durationItem.submenu = duration
            if expansion.accessibilityGranted && expansion.inputGranted && expansion.policy.hasApplicationScope {
                add(expansion.isEnabled ? "Pause Expansion" : "Enable Expansion", action: #selector(toggleExpansion))
            } else {
                add("Set Up Expansion…", action: #selector(setUpExpansion))
            }
        }
        menu.addItem(.separator())
        let quit = add("Quit Quill", action: #selector(quit))
        quit.keyEquivalent = "q"
    }

    @discardableResult private func add(_ title: String, action: Selector? = nil, enabled: Bool = true) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self; entry.isEnabled = enabled
        menu.addItem(entry)
        return entry
    }
    private func showWorkspace() {
        guard let openWindow else { return }
        showQuillWorkspace(openWindow: openWindow)
    }
    @objc private func openLibrary() { store?.destination = .snippets; showWorkspace() }
    @objc private func openSettings() { store?.destination = .settings; showWorkspace() }
    @objc private func openQuickActions() { showWorkspace(); store?.showQuickActions = true }
    @objc private func toggleExpansion() {
        guard let expansion else { return }
        if expansion.isEnabled { expansion.pause() } else { expansion.enable() }
    }
    @objc private func chooseDuration(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let duration = ExpansionDuration(rawValue: raw) else { return }
        expansion?.duration = duration
    }
    @objc private func setUpExpansion() {
        store?.requestedSettingsPage = .expansion
        openSettings()
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
