import AppKit
import ApplicationServices
import Carbon
import Combine
import Observation

@MainActor @Observable final class ExpansionController {
    var policy: ExpansionPolicy {
        didSet {
            resetTyping()
            persistPolicy()
            pending?.cancel()
            prompt.cancel(); awaitingFields = false; formTransaction = nil
            if isEnabled && !policy.hasApplicationScope {
                pause()
                status = "Paused. Choose an application or select All Applications."
            }
        }
    }
    var duration: ExpansionDuration {
        didSet {
            defaults.set(duration.rawValue, forKey: "expansionDuration")
            if isEnabled { configureDuration() }
        }
    }
    private(set) var endsAt: Date?
    private var expiration: Task<Void, Never>?
    private(set) var isEnabled = false
    private(set) var accessibilityGranted = false
    private(set) var inputGranted = false
    private(set) var status = "Paused. Set up permissions and choose where expansion runs."
    private let store: LibraryStore
    private let defaults: UserDefaults
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let prompt = ExpansionPrompt()
    private var awaitingFields = false
    private var formTransaction: UUID?
    private var pending: Task<Void, Never>?
    private var typing = ExpansionTypingBuffer()
    private var typingFocus: AXUIElement?
    private var typingPID: pid_t?
    private var lastTypingTime: UInt64 = 0
    private var inserting = false
    private var activationObservation: AnyCancellable?
    var insertionMethod: ExpansionInsertionMethod {
        didSet {
            defaults.set(insertionMethod.rawValue, forKey: "expansionInsertionMethod")
            pending?.cancel(); prompt.cancel(); awaitingFields = false; formTransaction = nil
            resetTyping()
        }
    }
    private func resetTyping() { typing.reset(); typingFocus = nil; typingPID = nil }

    init(store: LibraryStore, defaults: UserDefaults = .standard) {
        self.store = store; self.defaults = defaults
        insertionMethod = defaults.string(forKey: "expansionInsertionMethod").flatMap(ExpansionInsertionMethod.init(rawValue:)) ?? .directText
        policy = defaults.data(forKey: "expansionPolicy").flatMap { try? JSONDecoder().decode(ExpansionPolicy.self, from: $0) } ?? ExpansionPolicy()
        duration = defaults.string(forKey: "expansionDuration").flatMap(ExpansionDuration.init(rawValue:)) ?? .untilQuit
        activationObservation = NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.resetTyping()
                    if self?.inserting == false { self?.pending?.cancel() }
                }
            }
        refreshPermissions()
        // Resuming is opt-in: a successful explicit Enable with Across Launches arms this.
        if duration == .always && defaults.bool(forKey: "expansionAcrossLaunches") { enable() }
    }
    func refreshPermissions() {
        accessibilityGranted = AXIsProcessTrusted()
        inputGranted = CGPreflightListenEventAccess()
        if isEnabled && (!accessibilityGranted || !inputGranted) { pause(); status = "Permission was revoked. Expansion is paused." }
    }
    // These are called only by separate user-initiated setup buttons, never during launch or enablement.
    func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        openPermissionSettings("Privacy_Accessibility")
        refreshPermissions()
        if !accessibilityGranted { status = "Allow Quill in the Accessibility settings, then return here to enable expansion." }
    }
    func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
        openPermissionSettings("Privacy_ListenEvent")
        refreshPermissions()
        if !inputGranted { status = "Allow Quill in Input Monitoring. If Quill is missing, click + and choose Quill in Applications. Quit and reopen Quill if macOS asks." }
    }
    private func openPermissionSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
    func enable() {
        refreshPermissions()
        guard accessibilityGranted, inputGranted else { status = "Grant both permissions through Setup, then refresh. No monitoring started."; return }
        guard policy.hasApplicationScope else { status = "Choose an application or select All Applications first."; return }
        guard tap == nil else { configureDuration(); return }
        let mask = [CGEventType.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel, .flagsChanged]
            .reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
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
        isEnabled = true
        configureDuration()
        status = "Expansion is enabled. Excluded apps, secure input and unsupported editors are skipped."
    }
    private func configureDuration() {
        expiration?.cancel(); expiration = nil
        defaults.set(duration == .always, forKey: "expansionAcrossLaunches")
        endsAt = duration.interval.map { Date.now.addingTimeInterval($0) }
        if let interval = duration.interval {
            expiration = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(interval)) } catch { return }
                guard let self, !Task.isCancelled else { return }
                self.pause()
                self.status = "Timer ended. Expansion is paused."
            }
        }
    }
    func pause() {
        expiration?.cancel(); expiration = nil; endsAt = nil
        defaults.set(false, forKey: "expansionAcrossLaunches")
        pending?.cancel(); pending = nil
        resetTyping()
        prompt.cancel(); awaitingFields = false; formTransaction = nil
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        source = nil; tap = nil; isEnabled = false; status = "Paused. No input monitoring is active."
    }
    private func receive(_ type: CGEventType, event: CGEvent) {
        // Generated selection/paste keys must never recursively match or cancel their transaction.
        guard event.getIntegerValueField(.eventSourceUserData) != PasteExpansionTarget.eventMarker else { return }
        if type != .keyDown && type != .tapDisabledByTimeout && type != .tapDisabledByUserInput {
            if type != .flagsChanged || !event.flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty {
                resetTyping()
                if !inserting { pending?.cancel(); pending = nil }
            }
            return
        }
        guard !inserting else { resetTyping(); return }
        pending?.cancel(); pending = nil
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            pause(); status = "macOS stopped monitoring. Enable again after reviewing permissions."; return
        }
        guard isEnabled, !awaitingFields else { return }
        refreshPermissions()
        guard isEnabled, !IsSecureEventInputEnabled() else { resetTyping(); status = "Suspended while secure input is active."; return }
        guard event.flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty,
              event.getIntegerValueField(.keyboardEventAutorepeat) == 0,
              let app = NSWorkspace.shared.frontmostApplication, let bundleID = app.bundleIdentifier,
              bundleID != Bundle.main.bundleIdentifier, policy.allows(bundleID) else { resetTyping(); return }
        let characters = ExpansionKeyboardText.characters(for: event)
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        // IME candidate keystrokes are not committed text. Inspect only after Return commits.
        guard isDirectKeyboardLayout() || Self.isCompositionCommit(key) else { resetTyping(); return }
        let pid = app.processIdentifier
        guard let originalFocus = AccessibilityTextTarget.focusedElement(pid: pid) else { resetTyping(); return }
        if typingPID != pid || typingFocus.map({ !CFEqual($0, originalFocus) }) ?? true || event.timestamp &- lastTypingTime > 5_000_000_000 {
            typing.reset(atBeginning: PasteExpansionTarget.capture(pid: pid)?.selection?.location == 0)
        }
        typingPID = pid; typingFocus = originalFocus; lastTypingTime = event.timestamp
        if key == kVK_Delete { typing.backspace(); return }
        guard !Self.nonTextKeys.contains(key) else { resetTyping(); return }
        if characters.isEmpty { typing.reset() } else { typing.append(characters) }
        guard Self.isTextTrigger(key: key, characters: characters, policy: policy) else { return }
        let buffered = typing
        let method = insertionMethod
        pending = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(45)) } catch { return }
            guard let self, !Task.isCancelled, self.isEnabled, !self.store.isBusy,
                  self.policy.allows(bundleID) else { return }
            let destination: ExpansionDestination?
            switch method {
            case .directText: destination = AccessibilityTextTarget.capture(pid: pid).map(ExpansionDestination.direct)
            case .nativePaste: destination = PasteExpansionTarget.capture(pid: pid).map(ExpansionDestination.paste)
            }
            guard let target = destination else {
                self.resetTyping()
                self.status = method == .directText
                    ? "\(app.localizedName ?? "This editor") does not expose writable text. Choose Native Paste in Expansion settings for broader compatibility."
                    : "\(app.localizedName ?? "This editor") does not expose a safe editable field, or its input is protected."
                return
            }
            guard CFEqual(target.element, originalFocus) else { self.resetTyping(); return }
            let match: ExpansionMatch?
            let source: String
            if let text = target.text, let caret = target.caret {
                source = text
                match = AbbreviationMatcher.match(text: text, caret: caret, library: self.store.library, policy: self.policy)
            } else {
                source = buffered.text
                match = buffered.match(library: self.store.library, policy: self.policy)
            }
            guard let match, let range = Range(match.range, in: source),
                  let snippet = self.store.library.snippets.first(where: { $0.id == match.snippetID }) else { return }
            let suffix = String(source[range])
            do {
                let rendered = try TemplateRenderer.render(snippet, library: self.store.library)
                if rendered.fields.isEmpty {
                    try await self.insert(rendered, target: target, match: match, suffix: suffix, snippet: snippet)
                } else {
                    let anchor = try target.insertionBounds()
                    self.awaitingFields = true
                    let transactionID = UUID()
                    self.formTransaction = transactionID
                    self.status = "Complete the fill-ins to expand \(snippet.title)."
                    self.prompt.show(snippet: snippet, library: self.store.library, anchor: anchor) { [weak self] result in
                        guard let self, self.formTransaction == transactionID else { return }
                        guard let result else {
                            self.awaitingFields = false; self.formTransaction = nil
                            self.status = "Expansion cancelled. Your abbreviation was kept."
                            return
                        }
                        guard self.isEnabled, self.policy.allows(bundleID), self.formTransaction == transactionID else {
                            throw LibraryError.invalid("Expansion was paused or its application settings changed.")
                        }
                        // The editor remains active while the nonactivating panel accepts fields.
                        try await target.awaitKeyboardReturn()
                        guard self.isEnabled, self.policy.allows(bundleID), self.formTransaction == transactionID else {
                            throw LibraryError.invalid("Expansion was paused or its application settings changed.")
                        }
                        do {
                            try await self.insert(result, target: target, match: match, suffix: suffix, snippet: snippet)
                            self.awaitingFields = false; self.formTransaction = nil
                        } catch {
                            self.status = error.localizedDescription
                            throw error
                        }
                    }
                }
            } catch { self.status = error.localizedDescription }
        }
    }
    private func insert(_ result: RenderResult, target: ExpansionDestination, match: ExpansionMatch, suffix: String, snippet: Snippet) async throws {
        // Accessibility insertion and cursor preview share the exact visible-text projection.
        let output = try result.plainTextResult()
        inserting = true
        defer { inserting = false; resetTyping() }
        let inserted = try await target.replace(match, suffix: suffix, with: output)
        if inserted.confirmed {
            store.statistics.recordExpansion(outputCharacters: output.text.count, abbreviationCharacters: snippet.abbreviation.count)
            status = inserted.cursorPlaced ? "Expanded \(snippet.title)." : "Expanded \(snippet.title), but this editor could not position the cursor."
        } else {
            status = "Sent \(snippet.title) using native paste. This editor does not confirm its text; check the result."
        }
    }
    private static let nonTextKeys: Set<Int64> = Set([
        kVK_Delete, kVK_ForwardDelete, kVK_Escape, kVK_Help,
        kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow,
        kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown, kVK_ANSI_KeypadClear,
        kVK_JIS_Kana, kVK_JIS_Eisu,
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8,
        kVK_F9, kVK_F10, kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15,
        kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20
    ].map(Int64.init))

    private static func isCompositionCommit(_ key: Int64) -> Bool {
        key == kVK_Return || key == kVK_ANSI_KeypadEnter
    }

    static func isTextTrigger(key: Int64, characters: String, policy: ExpansionPolicy) -> Bool {
        guard !nonTextKeys.contains(key) else { return false }
        // Text targets remain authoritative; hardware CGEvents need not carry Unicode text.
        if policy.trigger == .immediately { return true }
        return characters.contains(where: { policy.delimiters.contains($0) }) ||
            (isCompositionCommit(key) && policy.delimiters.contains("\n")) ||
            (key == kVK_Tab && policy.delimiters.contains("\t")) ||
            (key == kVK_Space && policy.delimiters.contains(" "))
    }

    private func isDirectKeyboardLayout() -> Bool {
        guard let input = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let type = TISGetInputSourceProperty(input, kTISPropertyInputSourceType) else { return false }
        return CFEqual(Unmanaged<CFString>.fromOpaque(type).takeUnretainedValue(), kTISTypeKeyboardLayout)
    }
    private func persistPolicy() {
        if let data = try? JSONEncoder().encode(policy) { defaults.set(data, forKey: "expansionPolicy") }
    }
}
