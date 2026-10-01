# Foundation verification · 2 October 2026

## Automated evidence

- `script/verify-ci.sh`: passed. 14 Swift Testing tests in two suites; xcresult summary confirms totalTestCount 14, failedTests 0. Debug test host ad-hoc signed; unsigned Release contains arm64 and x86_64. Script syntax, plist and whitespace checks passed.
- `script/build_and_run.sh --verify`: passed; rebuilt current Debug app, opened the .app bundle and confirmed the Quill process.
- Host: Apple silicon arm64, macOS 27.0 build 26A5425a, Xcode 27.0 build 27A5228h. Deployment target is macOS 26.0. This is not direct runtime acceptance on macOS 26 or Intel.
- Effective Git author and committer both Daniel Buskariol <32349796+dbuskariol@users.noreply.github.com>. Pinned GitHub API returned dbuskariol, ID 32349796, public name Daniel Buskariol. Mismatched author was rejected by the identity guard. Global gh active account was not switched.

Tests cover deterministic date/time, literal fields, UTF-16 cursor offsets, nested fields, cycles, malformed macros, missing/ambiguous references, atomic round-trip and replacement, corruption preservation, invalid-version rejection without replacement, failed writes, store state after a failed save, stable first-launch IDs, and create/favorite/delete persistence.

The initial generated project had no test source entries; the nonzero-count gate identified this, and project regeneration corrected it. The final suite contains 14 tests; an Xcode success banner alone is never used as proof. The gate uses native plutil for result checks, avoiding the host's broken pyenv Python shim.

## Observed native UI

Computer Use inspected actual Quill windows and screenshots. Verified three-column adaptive native layout, sample list/selection, live nested snippet preview, empty-field copy disabling and enabling after entry, resolved text visible in screenshots, tag search narrowing to Meeting notes, Cmd-N creation, title/abbreviation/body editing, Cmd-S saving, Cmd-Delete native confirmation and cancellation, Cmd-comma General/Privacy Settings, and quit/relaunch persistence. A harmless Getting started snippet was created in the local runtime library and retained after relaunch; this is separate from the committed five starter examples.

Some SwiftUI accessibility text snapshots retained old static text while screenshots showed updated preview text; editable values and enabled states updated. Full spoken VoiceOver acceptance remains open.

## Remaining acceptance

No actual global expansion, key monitoring, permission request, clipboard read, script execution, cloud sync, remote publishing, or hardware-sensitive functionality was exercised or claimed. Menu bar route exists in code but its actual menu interaction remains untested. Full keyboard traversal, unsaved-quit alert, resizing extremes, Light appearance, increased contrast, reduced motion and spoken VoiceOver need a focused acceptance pass. Code/tests establish favorite/delete logic; UI deletion execution was not needed to inspect the confirmation/cancellation path.

Unsigned universal Release compilation does not prove Intel runtime behavior. Prepared GitHub CI has not run because there is no remote. Stable signing, notarization, privacy permission identity and macOS 26 runtime acceptance are future gates. System test-host logs include unavailable linkd autoShortcut service messages and AppIntents metadata extraction was skipped because this app has no AppIntents dependency; no failing tests or Swift compiler errors remained.

Saved-project registration is not exposed by the available Codex connector. Add `/Users/nftdannyboy/Documents/Codex/2026-10-02/quill` manually as a saved project; its local Run action is already configured.
