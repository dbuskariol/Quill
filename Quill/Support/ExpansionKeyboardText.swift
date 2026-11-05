import AppKit
import Carbon

@MainActor enum ExpansionKeyboardText {
    static func characters(for event: CGEvent) -> String {
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if key == kVK_Return || key == kVK_ANSI_KeypadEnter { return "\n" }
        if key == kVK_Tab { return "\t" }
        if key == kVK_Space { return " " }
        var units = [UniChar](repeating: 0, count: 128)
        var count = 0
        event.keyboardGetUnicodeString(maxStringLength: units.count, actualStringLength: &count, unicodeString: &units)
        if count > 0 { return String(utf16CodeUnits: units, count: min(count, units.count)) }
        if let text = NSEvent(cgEvent: event)?.characters, !text.isEmpty { return text }
        // Hardware events need not carry Unicode. Translate the active keyboard layout,
        // without retaining dead-key state or interpreting IME candidate keystrokes.
        guard let input = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(input, kTISPropertyUnicodeKeyLayoutData) else { return "" }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return "" }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var modifiers: UInt32 = 0
        if event.flags.contains(.maskShift) { modifiers |= UInt32(shiftKey) }
        if event.flags.contains(.maskAlphaShift) { modifiers |= UInt32(alphaLock) }
        var dead: UInt32 = 0
        var length = 0
        let status = UCKeyTranslate(layout, UInt16(key), UInt16(kUCKeyActionDown), modifiers >> 8,
                                    UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysMask), &dead,
                                    units.count, &length, &units)
        guard status == noErr, length > 0 else { return "" }
        return String(utf16CodeUnits: units, count: min(length, units.count))
    }
}
