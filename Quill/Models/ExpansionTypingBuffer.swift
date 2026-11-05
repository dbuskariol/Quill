import Foundation

/// Only a bounded, in-memory suffix. Never stored, logged or used across focus changes.
struct ExpansionTypingBuffer {
    private(set) var text = ""
    private var hasBeginning = false
    mutating func reset(atBeginning: Bool = false) {
        text = ""; hasBeginning = atBeginning
    }
    mutating func append(_ committed: String) {
        guard !committed.isEmpty else { return }
        text += committed
        if text.count > 256 { text = String(text.suffix(256)); hasBeginning = false }
    }
    mutating func backspace() {
        if !text.isEmpty { text.removeLast() }
        else { hasBeginning = false }
    }
    func match(library: Library, policy: ExpansionPolicy) -> ExpansionMatch? {
        guard let match = AbbreviationMatcher.match(text: text, caret: text.utf16.count, library: library, policy: policy),
              !policy.requiresWordBoundary || match.range.location > 0 || hasBeginning else { return nil }
        return match
    }
}

enum ExpansionInsertionMethod: String, CaseIterable, Identifiable {
    case directText, nativePaste
    var id: Self { self }
    var title: String { self == .nativePaste ? "Native Paste (Recommended)" : "Direct Accessibility" }
    var explanation: String {
        self == .nativePaste
            ? "Works with more editors. Temporarily uses your clipboard and restores its contents unless you copy something newer. Clipboard contents stay on this Mac."
            : "Does not use the clipboard. Requires the editor to expose writable text and selection through Accessibility."
    }
}
