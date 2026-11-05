import AppKit
import ApplicationServices
import Carbon

/// Does not require AX text setters or a complete document value.
@MainActor struct PasteExpansionTarget {
    static let eventMarker: Int64 = 0x5155494C4C
    let pid: pid_t
    let element: AXUIElement
    let window: AXUIElement
    let text: String?
    let selection: CFRange?
    var matchingText: String? {
        guard let text, let selection, selection.location <= text.utf16.count else { return nil }
        return text
    }

    static func capture(pid: pid_t) -> Self? {
        guard AXIsProcessTrusted(), !IsSecureEventInputEnabled(), NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
              let element = AccessibilityTextTarget.focusedElement(pid: pid),
              let role = attribute(element, kAXRoleAttribute) as? String,
              isEditableRole(role, editable: attribute(element, "AXEditable") as? Bool),
              attribute(element, kAXEnabledAttribute) as? Bool != false,
              attribute(element, kAXSubroleAttribute) as? String != kAXSecureTextFieldSubrole,
              attribute(element, "AXProtectedContent") as? Bool != true,
              let windowValue = attribute(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute),
              CFGetTypeID(windowValue) == AXUIElementGetTypeID() else { return nil }
        AXUIElementSetMessagingTimeout(element, 0.15)
        let rawText = attribute(element, kAXValueAttribute) as? String
        let text = rawText.flatMap { $0.utf16.count <= 1_000_000 ? $0 : nil }
        let selection = selectedRange(element)
        guard selection?.length ?? 0 == 0 else { return nil }
        return Self(pid: pid, element: element, window: windowValue as! AXUIElement, text: text, selection: selection)
    }
    static func isEditableRole(_ role: String, editable: Bool?) -> Bool {
        if editable == false { return false }
        return [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role) || editable == true
    }
    func validate() throws {
        guard !Task.isCancelled, let current = Self.capture(pid: pid), CFEqual(current.element, element), CFEqual(current.window, window),
              current.text == text, Self.sameRange(current.selection, selection) else {
            throw LibraryError.invalid("The active editor, text or insertion point changed. Your abbreviation was kept.")
        }
    }
    func awaitKeyboardReturn() async throws {
        for _ in 0..<20 {
            if (try? validate()) != nil { return }
            guard !Task.isCancelled, !IsSecureEventInputEnabled(), NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { break }
            try await Task.sleep(for: .milliseconds(15))
        }
        try validate()
    }
    func insertionBounds() -> NSRect {
        if let selection {
            let direct = AccessibilityTextTarget(pid: pid, element: element, text: text ?? "", selection: selection)
            if let bounds = try? direct.insertionBounds() { return bounds }
        }
        // An editor without caret geometry still gets the same compact, nonactivating form.
        return NSRect(origin: NSEvent.mouseLocation, size: NSSize(width: 1, height: 18))
    }
    func replace(_ match: ExpansionMatch, suffix: String, with result: RenderResult) async throws -> ExpansionInsertionResult {
        try validate()
        guard !suffix.isEmpty, suffix.count <= 256 else { throw LibraryError.invalid("The abbreviation could not be verified.") }
        let clipboard = try ExpansionClipboard()
        try clipboard.write(result.text + match.delimiter)
        defer { clipboard.restore() }
        try validate()
        // Allocate every event before changing the target. The native editor handles paste/Undo.
        let source = CGEventSource(stateID: .privateState)
        func pair(_ key: CGKeyCode, flags: CGEventFlags = []) throws -> [CGEvent] {
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else { throw LibraryError.invalid("macOS could not prepare the paste command.") }
            for event in [down, up] { event.flags = flags; event.setIntegerValueField(.eventSourceUserData, value: Self.eventMarker) }
            return [down, up]
        }
        if let text = matchingText, let selection {
            guard selection.location == NSMaxRange(match.range), let range = Range(match.range, in: text), String(text[range]) == suffix else {
                throw LibraryError.invalid("The abbreviation changed. No text was inserted.")
            }
        }
        var events: [CGEvent] = []
        for _ in suffix { events += try pair(CGKeyCode(kVK_LeftArrow), flags: .maskShift) }
        events += try pair(CGKeyCode(kVK_ANSI_V), flags: .maskCommand)
        try validate()
        for event in events { event.postToPid(pid) }
        // Readable targets acknowledge insertion; opaque editors get a bounded paste window.
        let expected: String? = text.flatMap { value in
            guard selection?.location == NSMaxRange(match.range), let range = Range(match.range, in: value), String(value[range]) == suffix else { return nil }
            return (value as NSString).replacingCharacters(in: match.range, with: result.text + match.delimiter)
        }
        var confirmed = false
        for _ in 0..<40 {
            if Task.isCancelled {
                // A paste already sent cannot be recalled. Do not restore the clipboard
                // early just because Pause cancelled the surrounding detection task.
                await Task.detached { try? await Task.sleep(for: .milliseconds(600)) }.value
                break
            }
            try? await Task.sleep(for: .milliseconds(15))
            guard !IsSecureEventInputEnabled(), NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
                  let focused = AccessibilityTextTarget.focusedElement(pid: pid), CFEqual(focused, element) else {
                await Task.detached { try? await Task.sleep(for: .milliseconds(600)) }.value
                break
            }
            if let expected, Self.attribute(element, kAXValueAttribute) as? String == expected { confirmed = true; break }
        }
        var cursorPlaced = result.cursorUTF16Offset == nil
        if confirmed, let cursor = result.cursorUTF16Offset,
           !IsSecureEventInputEnabled(), NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
           let focused = AccessibilityTextTarget.focusedElement(pid: pid), CFEqual(focused, element),
           Self.attribute(element, kAXValueAttribute) as? String == expected {
            var position = CFRange(location: match.range.location + cursor, length: 0)
            if let value = AXValueCreate(.cfRange, &position) {
                cursorPlaced = AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value) == .success
            }
            if !cursorPlaced, let current = Self.selectedRange(element), current.length == 0,
               current.location == match.range.location + result.text.utf16.count + match.delimiter.utf16.count,
               let count = Self.cursorSteps(text: result.text, offset: cursor, delimiter: match.delimiter) {
                var moves: [CGEvent] = []
                for _ in 0..<count {
                    guard let pair = try? pair(CGKeyCode(kVK_LeftArrow)) else { return .init(confirmed: true, cursorPlaced: false) }
                    moves += pair
                }
                for event in moves { event.postToPid(pid) }
                cursorPlaced = true
            }
        }
        return .init(confirmed: confirmed, cursorPlaced: cursorPlaced)
    }
    static func cursorSteps(text: String, offset: Int, delimiter: String) -> Int? {
        guard offset >= 0, offset <= text.utf16.count else { return nil }
        let index = String.Index(utf16Offset: offset, in: text)
        guard index == text.endIndex || text.indices.contains(index) else { return nil }
        return text[index...].count + delimiter.count
    }
    private static func selectedRange(_ element: AXUIElement) -> CFRange? {
        guard let value = attribute(element, kAXSelectedTextRangeAttribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        return AXValueGetValue(value as! AXValue, .cfRange, &range) && range.location >= 0 && range.length >= 0 ? range : nil
    }
    private static func sameRange(_ lhs: CFRange?, _ rhs: CFRange?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): true
        case let (lhs?, rhs?): lhs.location == rhs.location && lhs.length == rhs.length
        default: false
        }
    }
    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
}

@MainActor enum ExpansionDestination {
    case direct(AccessibilityTextTarget), paste(PasteExpansionTarget)
    var text: String? { switch self { case .direct(let target): target.text; case .paste(let target): target.matchingText } }
    var caret: Int? { switch self { case .direct(let target): target.selection.location; case .paste(let target): target.selection?.location } }
    var element: AXUIElement { switch self { case .direct(let target): target.element; case .paste(let target): target.element } }
    func insertionBounds() throws -> NSRect { switch self { case .direct(let target): try target.insertionBounds(); case .paste(let target): target.insertionBounds() } }
    func awaitKeyboardReturn() async throws { switch self { case .direct(let target): try await target.awaitKeyboardReturn(); case .paste(let target): try await target.awaitKeyboardReturn() } }
    func replace(_ match: ExpansionMatch, suffix: String, with result: RenderResult) async throws -> ExpansionInsertionResult {
        switch self {
        case .direct(let target): try target.replace(match, with: result); return .init(confirmed: true, cursorPlaced: true)
        case .paste(let target): return try await target.replace(match, suffix: suffix, with: result)
        }
    }
}

struct ExpansionInsertionResult {
    let confirmed: Bool
    let cursorPlaced: Bool
}
