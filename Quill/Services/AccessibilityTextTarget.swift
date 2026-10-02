import AppKit
import ApplicationServices
import Carbon

@MainActor struct AccessibilityTextTarget {
    let pid: pid_t
    let element: AXUIElement
    let text: String
    let selection: CFRange

    static func focusedElement(pid: pid_t) -> AXUIElement? {
        guard AXIsProcessTrusted(), !IsSecureEventInputEnabled() else { return nil }
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.15)
        guard let focused = attribute(application, kAXFocusedUIElementAttribute), CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        return (focused as! AXUIElement)
    }

    static func capture(pid: pid_t) -> Self? {
        guard AXIsProcessTrusted(), !IsSecureEventInputEnabled(), NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return nil }
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.15)
        guard let focused = attribute(application, kAXFocusedUIElementAttribute), CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.15)
        guard let role = attribute(element, kAXRoleAttribute) as? String,
              [kAXTextFieldRole, kAXTextAreaRole].contains(role),
              attribute(element, kAXSubroleAttribute) as? String != kAXSecureTextFieldSubrole,
              attribute(element, "AXProtectedContent") as? Bool != true,
              settable(element, kAXSelectedTextAttribute), settable(element, kAXSelectedTextRangeAttribute),
              let text = attribute(element, kAXValueAttribute) as? String, text.utf16.count <= 1_000_000,
              let rangeValue = attribute(element, kAXSelectedTextRangeAttribute), CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }
        var selection = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &selection), selection.length == 0,
              selection.location >= 0, selection.location <= text.utf16.count else { return nil }
        return Self(pid: pid, element: element, text: text, selection: selection)
    }

    func replace(_ match: ExpansionMatch, with result: RenderResult) throws {
        guard let current = Self.capture(pid: pid), CFEqual(element, current.element), current.text == text,
              current.selection.location == selection.location, current.selection.length == selection.length, match.range.location >= 0,
              match.range.location + match.range.length == selection.location,
              Range(match.range, in: text) != nil else { throw LibraryError.invalid("Focus or target text changed. Expansion cancelled.") }
        var replacementRange = CFRange(location: match.range.location, length: match.range.length)
        guard let rangeValue = AXValueCreate(.cfRange, &replacementRange),
              AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, rangeValue) == .success else {
            restoreSelectionIfUnchanged()
            throw LibraryError.invalid("The target editor could not select the abbreviation.")
        }
        // Revalidate focus and selected content after changing the selection, before writing.
        guard !IsSecureEventInputEnabled(), AXIsProcessTrusted(), NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
              let focused = Self.attribute(AXUIElementCreateApplication(pid), kAXFocusedUIElementAttribute), CFEqual(focused, element),
              Self.attribute(element, kAXSelectedTextAttribute) as? String == (text as NSString).substring(with: match.range),
              Self.attribute(element, kAXValueAttribute) as? String == text else {
            restoreSelectionIfUnchanged()
            throw LibraryError.invalid("Target changed during expansion. No text was inserted.")
        }
        let insertion = result.text + match.delimiter
        let expected = (text as NSString).replacingCharacters(in: match.range, with: insertion)
        let write = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, insertion as CFString)
        guard write == .success, Self.attribute(element, kAXValueAttribute) as? String == expected else {
            // Do not inject a recovery string into a target that may have partially changed.
            restoreSelectionIfUnchanged()
            throw LibraryError.invalid("The editor did not confirm insertion. Inspect its text and use its Undo command if needed.")
        }
        if let cursor = result.cursorUTF16Offset, !IsSecureEventInputEnabled(), NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
           let focused = Self.attribute(AXUIElementCreateApplication(pid), kAXFocusedUIElementAttribute), CFEqual(focused, element),
           Self.attribute(element, kAXValueAttribute) as? String == expected {
            var position = CFRange(location: match.range.location + cursor, length: 0)
            if let value = AXValueCreate(.cfRange, &position) {
                guard AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value) == .success else {
                    throw LibraryError.invalid("Text was expanded, but this editor did not accept the cursor position.")
                }
            }
        }
    }
    private func restoreSelectionIfUnchanged() {
        guard !IsSecureEventInputEnabled(), NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
              let focused = Self.attribute(AXUIElementCreateApplication(pid), kAXFocusedUIElementAttribute), CFEqual(focused, element),
              Self.attribute(element, kAXValueAttribute) as? String == text else { return }
        var original = selection
        if let value = AXValueCreate(.cfRange, &original) { _ = AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value) }
    }
    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    private static func settable(_ element: AXUIElement, _ name: String) -> Bool {
        var value: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(element, name as CFString, &value) == .success && value.boolValue
    }
}
