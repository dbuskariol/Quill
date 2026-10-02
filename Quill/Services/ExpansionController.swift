import AppKit
import ApplicationServices
import Carbon
import Observation

@MainActor @Observable final class ExpansionController {
    var policy: ExpansionPolicy { didSet { persistPolicy(); pending?.cancel() } }
    private(set) var isEnabled = false
    private(set) var accessibilityGranted = false
    private(set) var inputGranted = false
    private(set) var status = "Paused. Set up permissions and allow an app before enabling."
    private let store: LibraryStore
    private let defaults: UserDefaults
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var pending: Task<Void, Never>?

    init(store: LibraryStore, defaults: UserDefaults = .standard) {
        self.store = store; self.defaults = defaults
        policy = defaults.data(forKey: "expansionPolicy").flatMap { try? JSONDecoder().decode(ExpansionPolicy.self, from: $0) } ?? ExpansionPolicy()
        refreshPermissions()
    }
    func refreshPermissions() {
        accessibilityGranted = AXIsProcessTrusted()
        inputGranted = CGPreflightListenEventAccess()
        if isEnabled && (!accessibilityGranted || !inputGranted) { pause(); status = "Permission was revoked. Expansion is paused." }
    }
    // These are called only by separate user-initiated setup buttons, never during launch or enablement.
    func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        refreshPermissions()
    }
    func requestInputMonitoring() { _ = CGRequestListenEventAccess(); refreshPermissions() }
    func enable() {
        refreshPermissions()
        guard accessibilityGranted, inputGranted else { status = "Grant both permissions through Setup, then refresh. No monitoring started."; return }
        guard !policy.allowedBundleIDs.isEmpty else { status = "Choose at least one allowed application first."; return }
        guard tap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            // The source is installed exclusively in the main run loop.
            MainActor.assumeIsolated {
                Unmanaged<ExpansionController>.fromOpaque(context).takeUnretainedValue().receive(type, event: event)
            }
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
                                         eventsOfInterest: mask, callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()),
              let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            status = "macOS could not start input monitoring. Refresh permissions or restart Quill."; return
        }
        self.tap = tap; self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isEnabled = true; status = "Enabled in allowed applications. Secure input and unsupported editors are skipped."
    }
    func pause() {
        pending?.cancel(); pending = nil
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        source = nil; tap = nil; isEnabled = false; status = "Paused. No input monitoring is active."
    }
    private func receive(_ type: CGEventType, event: CGEvent) {
        pending?.cancel(); pending = nil
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            pause(); status = "macOS stopped monitoring. Enable again after reviewing permissions."; return
        }
        guard isEnabled else { return }
        refreshPermissions()
        guard isEnabled, !IsSecureEventInputEnabled() else { status = "Suspended while secure input is active."; return }
        guard event.flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty,
              event.getIntegerValueField(.keyboardEventAutorepeat) == 0,
              let app = NSWorkspace.shared.frontmostApplication, let bundleID = app.bundleIdentifier,
              bundleID != Bundle.main.bundleIdentifier, policy.allows(bundleID), isDirectKeyboardLayout() else { return }
        var units = [UniChar](repeating: 0, count: 8)
        var count = 0
        event.keyboardGetUnicodeString(maxStringLength: units.count, actualStringLength: &count, unicodeString: &units)
        let characters = String(utf16CodeUnits: units, count: count)
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        guard characters.contains(where: { policy.delimiters.contains($0) }) || (key == 36 && policy.delimiters.contains("\n")) || (key == 48 && policy.delimiters.contains("\t")) else { return }
        let pid = app.processIdentifier
        guard let originalFocus = AccessibilityTextTarget.focusedElement(pid: pid) else { return }
        pending = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(45)) } catch { return }
            guard let self, !Task.isCancelled, self.isEnabled, !self.store.isBusy,
                  self.policy.allows(bundleID), self.isDirectKeyboardLayout(),
                  let target = AccessibilityTextTarget.capture(pid: pid), CFEqual(target.element, originalFocus),
                  let match = AbbreviationMatcher.match(text: target.text, caret: target.selection.location, library: self.store.library, policy: self.policy),
                  let snippet = self.store.library.snippets.first(where: { $0.id == match.snippetID }), snippet.format == .plainText else { return }
            do {
                let rendered = try TemplateRenderer.render(snippet, library: self.store.library)
                try target.replace(match, with: rendered)
                self.store.statistics.recordExpansion(outputCharacters: rendered.text.count, abbreviationCharacters: snippet.abbreviation.count)
                self.status = "Expanded successfully."
            } catch { self.status = error.localizedDescription }
        }
    }
    private func isDirectKeyboardLayout() -> Bool {
        guard let input = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let type = TISGetInputSourceProperty(input, kTISPropertyInputSourceType) else { return false }
        let value = Unmanaged<CFString>.fromOpaque(type).takeUnretainedValue()
        return CFEqual(value, kTISTypeKeyboardLayout)
    }
    private func persistPolicy() {
        if let data = try? JSONEncoder().encode(policy) { defaults.set(data, forKey: "expansionPolicy") }
    }
}
