# Development verification · 2 October 2026

## Automated evidence

- `script/verify-ci.sh`: 53 Swift Testing tests in nine suites passed, with a nonzero count confirmed from xcresult. Debug test host is ad-hoc signed; unsigned universal Release contains arm64 and x86_64. Script syntax, native plist validation and whitespace checks passed.
- `script/build_and_run.sh`: rebuilt and opened the current Debug bundle in external DerivedData; confirmed the Quill process. Compiled Info.plist points to AppIcon. The 1024-pixel icon has alpha; the asset catalog supplies every standard macOS 1x/2x icon size.
- Host: Apple silicon arm64, macOS 27.0 build 26A5425a, Xcode 27.0 build 27A5228h. Deployment target remains macOS 26.0. Intel and macOS 26 runtime acceptance have not been performed.
- Effective author and committer are Daniel Buskariol <32349796+dbuskariol@users.noreply.github.com>; the local identity guard passes. Earlier foundation verification checked GitHub dbuskariol, ID 32349796, without changing the global active account. No push or publishing was performed.

Coverage includes the original deterministic renderer/persistence tests, typed input/conditional/date/math validation, corruption preservation and recovery, stale/concurrent writer refusal, protected export paths, group reassignment, history/undo, updater configuration guards, matching policy and Unicode UTF-16 boundaries, aggregate statistics consent/reset, CSV and legacy TextExpander migration, conflict handling, nested migration references/cycles, custom macro persistence/rename/cycles/drafts, Zendesk token/filter/escape preservation and Unicode-aware insertion at the editor selection.

Current JSON schema v3 requires explicit formats and a macros collection. Old Quill schemas and incomplete definitions are rejected; automatic JSON migration and navigation compatibility aliases were removed at the user’s request.

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

## Native content and history milestone — 2 October 2026

`script/verify-ci.sh` passed with **76 Swift Testing tests in 11 suites** and a universal unsigned Release build containing arm64/x86_64. The normal ad-hoc Debug build was rebuilt separately without terminating the user's original app. Current-schema JSON rejects missing/outdated fields with a readable path. Active storage is SQLite only; there are no runtime JSON migration paths, inferred content formats, automatic JSON archives or navigation compatibility aliases.

Added coverage verifies linked/no-op per-item saves, SQL-trigger rollback, deletion/restore-as-new, protected retention, altered revision digest refusal, complete portable backup/disaster recovery, healthy restore retaining newer versions, exclusive full-database copying, authored draft checkpoints/restart/save/discard, original edit-base detection, metadata/body line diffs and favorite commands preserving unsaved bodies. Markdown coverage includes native styles/RTF, safe HTML, links/lists/fences, literal fields and entities, Zendesk tokens, mixed-format references and exact multi-format Repeat Last Copy on an owned test pasteboard. No user clipboard read or write was performed.

A separate QA bundle and temporary current-schema SQLite library verified embedded Settings, explicit JSON import confirmation, native Markdown preview with Zendesk placeholders, saving a new version, native History comparison, keeping an older version and restoring it as a new save. Quit/relaunch displayed the recovery banner, native draft comparison and Recover Draft; saved content remained unchanged until Save. Revert cleared the recovered draft. Back Up Now created a complete backup, and its native review displayed saved snippet/macro contents before confirmation. The final retention confirmation and history dates include explicit actions and second precision; manual full VoiceOver/high-contrast acceptance remains open.

Native QA exposed a confirmation lifetime bug: the pending JSON import was cleared on alert dismissal before its async action read it. The action now receives the captured reviewed library directly, with a regression test. A deliberately incomplete synthetic fixture produced the reported “missing” alert; the schema error now identifies its required field. The user's six saved definitions and open Timestamp draft were transferred once through the current repository contract into the new store, verified, and the original JSON/app remained untouched. That one-time transfer is not runtime compatibility code.

Full WYSIWYG, attachments, arbitrary rich-format fidelity, actual Zendesk paste/channel acceptance and permission-enabled external expansion remain unverified/future work. Markdown root templates are excluded from automatic Accessibility expansion.

An existing SQLite file without saved state is surfaced and preserved, never replaced with starters. Group management now uses standard 8-point header spacing and baseline alignment beside the Groups title.

## Application selection and sidebar refinement — 2026-10-02

The final local gate passed 78 Swift Testing tests and an unsigned universal Release build. New policy tests cover all-apps scope, editable exclusions, empty identifiers, Codable persistence, duplicate selection and moving an app between opposing lists. Native QA used a separate app identity and temporary library: selected-app addition through the macOS app chooser, selected-app removal, exclusion removal and addition, and switching to All Applications were exercised. App names/icons and the right-aligned, smaller Groups control were visually inspected. A fresh library showed the neutral signature name fill-in. No OS expansion permission was requested or monitoring enabled during this QA; external-target acceptance remains separate. Existing user templates and drafts were not modified.

## Current expansion repair acceptance

See [EXPANSION_ACCEPTANCE.md](EXPANSION_ACCEPTANCE.md) for the signed interactive identity, observed native workflows and required external expansion gate. Current-source verification passed 80 tests and the universal Release build. The interactive app is installed at `/Applications/Quill.app`; both grants are confirmed, while real automatic replacement remains pending. No next release has been cut.

Expansion duration/background repair: `/tmp/quill-background-final-gate.log` passed 81 tests and universal Release. `/tmp/quill-duration-install.log` built, strictly verified and installed the signed app through the Run script. Both grants survived changed-binary reinstall. Native Across Launches resumption, timed deadline, hide-Dock reachability, continued process after window close, library reopen and login registration/unregistration were observed. Physical keyboard and external expansion transactions remain pending; no release readiness claim.


## Visible cursor and fill-in transaction repair — 2026-10-02

`/tmp/quill-cursor-boundaries-gate.log` passed 82 tests in 11 suites plus the universal Release build. Markdown expansion now shares its visible-text and cursor projection with preview; native source mapping and cursor regression cases cover list prefixes, entities/Unicode, links, code and protected literal content. Fill-in submissions retain the existing form and answers on failure, and invalidated transaction IDs cannot write after a policy change or pause. Native external transaction acceptance remains pending. The README now includes four actual native screenshots captured against a separate sample library.

The final interactive gate `/tmp/quill-final-interactive-gate.log` passed the same 82 tests and universal Release. The signed repair was installed and strictly verified; both permission grants survived. The native Markdown cursor diagnostic was observed and the disposable edit reverted. Status text now recreates its selectable accessibility node on state changes; Enabled is reported consistently by parent and child.


## Typing triggers and mixed-format references — 2026-10-02

`/tmp/quill-typing-trigger-gate.log` passed 83 tests and universal Release. Immediate expansion now excludes navigation, deletion, function keys and input-source toggles; hardware events with no Unicode payload remain eligible for authoritative AX text matching. Delimiter mode recognizes native Space, Tab, Return and keypad Enter.

`/tmp/quill-nested-cursor-gate.log` passed 84 tests in 11 suites and universal Release. Mixed-format Markdown-to-plain references project the cursor through the complete semantic document, rather than parsing a truncated prefix. Tests exercise reusable macros, nested snippet links, plain-to-Markdown literal blocks, and escaped literal fields containing emoji and Zendesk expressions. GitHub CI for commit `2d7daed` completed successfully at [run 36971587942](https://github.com/dbuskariol/Quill/actions/runs/36971587942); the subsequent trigger/nested-cursor changes have passed the local gate.


The actual 15-minute expansion session expired while its library window was closed. The same process remained alive; reopening after the displayed deadline showed Timer ended, expansion paused, and both grants still Granted. See the timestamped acceptance record. No clock override was used.
