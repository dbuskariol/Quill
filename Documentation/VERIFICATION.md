# Development verification · 2 October 2026

## Automated evidence

- `script/verify-ci.sh`: 53 Swift Testing tests in nine suites passed, with a nonzero count confirmed from xcresult. Debug test host is ad-hoc signed; unsigned universal Release contains arm64 and x86_64. Script syntax, native plist validation and whitespace checks passed.
- `script/build_and_run.sh`: rebuilt and opened the current Debug bundle in external DerivedData; confirmed the Quill process. Compiled Info.plist points to AppIcon. The 1024-pixel icon has alpha; the asset catalog supplies every standard macOS 1x/2x icon size.
- Host: Apple silicon arm64, macOS 27.0 build 26A5425a, Xcode 27.0 build 27A5228h. Deployment target remains macOS 26.0. Intel and macOS 26 runtime acceptance have not been performed.
- Effective author and committer are Daniel Buskariol <32349796+dbuskariol@users.noreply.github.com>; the local identity guard passes. Earlier foundation verification checked GitHub dbuskariol, ID 32349796, without changing the global active account. No push or publishing was performed.

Coverage includes the original deterministic renderer/persistence tests, typed input/conditional/date/math validation, corruption preservation and recovery, stale/concurrent writer refusal, protected export paths, group reassignment, history/undo, updater configuration guards, matching policy and Unicode UTF-16 boundaries, aggregate statistics consent/reset, CSV and legacy TextExpander migration, conflict handling, nested migration references/cycles, custom macro persistence/rename/cycles/drafts, Zendesk token/filter/escape preservation and Unicode-aware insertion at the editor selection.

Libraries containing custom macros use schema v2, preserving older v1 read compatibility while preventing an older v1-only Quill build from silently stripping saved macros.

## Observed native UI

Computer Use inspected real windows and screenshots. Settings uses the same workspace/window identifier as the library, reached from the bottom-left sidebar and Cmd-comma. Its horizontal category navigation follows Reccy’s reference, with native controls and selection accessibility traits. Redundant Settings category text, Local library badge, snippet-count footer and editor/instructional filler are gone. Group management is next to the Groups heading; Settings is the sole bottom action. Earlier navigation QA preserved an unsaved snippet draft and category selection; temporary edits were reverted.

A synthetic four-row TextExpander CSV was selected through the native open panel. Review showed original/converted text, a converted single-line fill-in, date warnings, a disabled unsupported clipboard macro and a saved-abbreviation conflict. The action correctly previewed two imported snippets and one skipped conflict. Review was cancelled, leaving the user library unchanged. Persisted import, backup and undo are exercised by isolated repository/store tests.

Custom Macros opens from the sidebar. A temporary draft combining a Zendesk requester placeholder and a local agent fill-in showed the correct resolved text and Zendesk preservation explanation. Copy Preview remained disabled until the local fill-in was supplied. The dedicated Zendesk picker opened from Insert Macro with descriptive choices and source reference. During that earlier pass, the QA macro was reverted before closing; no QA macro was saved to the user library and no clipboard copy or ticket submission was performed.

Foundation UI checks also exercised snippet search, Cmd-N creation, edit/Cmd-S save, favorite selection, nested previews, delete confirmation/cancellation and quit/relaunch persistence. The retained Getting started runtime snippet is separate from the committed five starter samples. Dynamic preview text and macro-name token text use stable-content identity to avoid stale SwiftUI static accessibility snapshots; a full spoken VoiceOver pass remains open.

The completion/navigation follow-up used a separately built QA bundle identifier and temporary JSON libraries. The original running app had an unsaved Timestamp draft and was left running; the same draft was confirmed afterward. Native UI inspection verified a compact nine-entry opening helper, partial `{{ma` / `{{sni` filtering, `{{snippet.` conversion to a colon reference, staged custom-macro completion, Zendesk requester suggestions, Down+Return / Down+Tab acceptance, Escape dismissal, native Undo, and completion inside existing braces after an emoji with the caret left after the token. Suggestions remained uncommitted until selection, including a single-result list. Custom Macros is a selected source-list destination with contextual Cmd-N, search, shared completion and persistent Save/Revert controls. Drafts survived navigation to Settings and back. A synthetic greeting was saved only to a temporary QA library; the empty macro workspace has one useful creation prompt. Seven added tests cover matching, boundaries, bounded results, native insertion/undo, existing-brace/conditional completion and destination/draft behavior.

## Release and integration boundaries

Expansion permission setup was not invoked and no Accessibility/Input Monitoring grants were made. Attempting enable without permissions remained paused with a setup explanation. Secure-input/focus protections and matching are covered in code/tests; actual external replacement, revoked permissions, IMEs and broad editor support require an explicit runtime acceptance session.

Development-location login registration reports unavailable; installed-bundle login and actual menu-bar interactions remain untested. Sparkle is pinned and guarded but has no configured feed/public signing key. Local packaging guards rejected missing inputs and an invalid public key; Developer ID signing, notarization, real update/rollback/failure acceptance and publishing were not performed. See RELEASE.md for required inputs.

Full keyboard traversal, Light appearance, increased contrast, reduced motion, compact/extreme resizing, spoken VoiceOver and real user-owned TextExpander export variants remain acceptance work. Prepared GitHub CI has not run because no remote is configured. Test-host linkd autoShortcut diagnostics and skipped AppIntents extraction are host messages; the verification gate had no failing tests or remaining Swift compiler errors.

Broader product work is tracked honestly in FEATURE_MATRIX.md and COLLABORATION_ROADMAP.md; this development milestone does not establish full TextExpander parity or release readiness.
