# Quill 0.1.6

Broader editor compatibility through an explicit native paste insertion method.

- Choose **Native Paste (Recommended)** in Settings → Expansion → Insert using. Quill uses the editor’s normal paste handling without requiring writable Accessibility text setters. Existing installations keep their previous method until you choose; setup explains clipboard use before Enable.
- Editors without a complete readable document can use a bounded, temporary typing suffix. It clears on app/focus changes, navigation, clicks, shortcuts, pause and inactivity. Unknown word boundaries are refused rather than guessed.
- Native Paste preserves clipboard formats locally and restores them only while Quill still owns the clipboard. Newer copies are never overwritten; concealed, promised or oversized clipboard content is refused before changing editor text.
- Fill-ins keep the compact nonactivating panel, using caret geometry when available and the pointer location otherwise. Generated insertion keys cannot trigger recursive expansion. Readable targets verify their result; opaque targets report that paste was sent without claiming confirmation.
- Cursor positioning uses exact Accessibility placement where available and native movement after confirmed insertion where the editor cannot set the range.
- Direct Accessibility remains available without clipboard use. Application scope, exclusions, secure input and password-field protections apply to both methods.

## Install or update

Requires macOS 26 or later. The signed and notarized universal app supports Apple silicon and Intel. Install in Applications or use Check for Updates. Check **Expand in** as well: Selected Applications limits expansion to the apps listed there; All Applications retains your exclusions.
