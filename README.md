# Quill

Quill is a new native macOS 26 snippet library and template editor, built with Swift 6, SwiftUI, Observation, and AppKit. It is the foundation for a modern TextExpander alternative. **A conservative expansion engine is implemented but has not passed permission-enabled target acceptance. This is not release-ready or full TextExpander parity.**

The runnable app includes five starter snippets across three groups, full-library search (including tags and body), favorites, create/edit/delete with confirmation, local atomic persistence, dry-run fill-in preview, date/time macros, cursor offsets, nested templates, cycle detection, and abbreviation collision diagnostics. It has real Settings, a menu bar entry point, conventional keyboard commands, adaptive appearance, and explicit storage errors. Expansion setup requests macOS permissions only through explicit buttons, and monitoring starts only when enabled for allowed apps. No analytics or content upload occurs; updates remain inactive until a signed Quill feed is configured.

## Run

Requires macOS 26+, Xcode 26+ with the macOS 26 SDK, and command-line tools selected for that Xcode. Open Quill.xcodeproj and run the shared Quill scheme, or use Codex's **Run** action:

```sh
./script/build_and_run.sh
```

Debug builds are ad-hoc signed for local development. DerivedData is under `~/Library/Developer/Xcode/DerivedData/Quill`. No signing team or distribution identity is inherited from Reccy. The committed Xcode project needs no generator; `project.yml` is its source specification and can be regenerated with XcodeGen when targets change.

## Use

Choose a group or Favorites, search, select a snippet, then edit the template. **Save Snippet (⌘S)** commits edits locally. **⌘N** creates a snippet; **⇧⌘D** toggles a saved snippet's favorite; **⌘Delete** requests deletion. Unsaved drafts survive navigation and are checkpointed for recovery. Normal quit flushes them; relaunch offers review and recovery. History beside Save compares and restores saved versions. Revert restores the saved snippet. Cmd-K opens Quick Actions for search, native fill-ins, resolved copying and library navigation. Repeat Last Copy retains the last chosen clipboard formats only in memory. Settings controls menu/Dock/window behavior, native launch-at-login registration, storage and expansion policy.

Supported Quill syntax (not TextExpander's import syntax): `{{date}}`, `{{time}}`, `{{field:name}}`, `{{snippet:;sig}}`, and `{{cursor}}`. Type `{{` for native token completion, including partial names such as `{{ma`, `{{sni` and `{{ticket.re`. Snippet/macro dot prefixes are discovery aliases that complete to canonical colon references. The shared Insert menu inserts at the current selection or cursor with native text undo. Date is ISO calendar date and time uses 24-hour local time. Fill-in values are literal, never interpreted as macros. Copy is disabled while required fields are empty. Plain templates copy plain text; Markdown templates offer native formatted preview and HTML/RTF copying with a plain fallback, plus Copy As Markdown or Plain Text. Cursor offset is diagnostic; external cursor placement is implemented for supported AX editors, with runtime acceptance pending.

The transactional SQLite library is at `~/Library/Application Support/Quill/library.sqlite` by default, or the location explicitly selected in Settings. Invalid templates may be saved for later repair; preview explains their validation errors. Abbreviation collisions are warnings for editing and errors when an ambiguous nested reference is resolved. Search does not change stored content. Manage Groups creates, renames or deletes groups while moving their snippets safely. Each meaningful item save creates a version; deletes remain recoverable. One current JSON schema is supported for explicit interchange; active storage is SQLite only. Settings offers retention, complete portable backups including history/drafts, reviewed restore, JSON import/export and verified complete storage relocation. Option-Command-Z undoes the last whole-library change when drafts are clear.

## Verify and contribute

```sh
./script/setup-repository.sh
./script/verify-ci.sh
```

Setup configures only this repository's author, committer, hook path, and GitHub credential helper. GitHub operations use `./script/gh-quill.sh`, which pins and verifies dbuskariol without switching the globally active account. No remote or publishing is configured.

The gate checks script syntax, metadata, whitespace, Swift Testing results with a nonzero count, and an unsigned universal Release build. CI is prepared for macOS 26 Apple silicon and Intel, but has not run remotely. See Documentation/VERIFICATION.md for local observations and gaps.

See Documentation/PRODUCT_BRIEF.md, Documentation/FEATURE_MATRIX.md, and Documentation/ARCHITECTURE.md for scope and the next milestones. Reccy informed layout and engineering conventions; Quill is a separate repository with its own identity and no recording code.

## Expanded templates and expansion setup

Typed controls: `{{input:notes|multiline}}`, `{{input:tone|choice|Formal|Friendly}}`, `{{input:extra|optional}}`, and `{{input:day|date|yyyy-MM-dd}}`. Conditions use `{{if:tone=Formal}}Hello{{else}}Hi{{end}}` and may nest. Custom ICU date formats and day offsets use `{{date:yyyy-MM-dd|7}}`; bounded arithmetic uses `{{math:(2+3)*4}}`. Field values remain literal.

**Library → Import from TextExpander…** imports CSV exports and older `.textexpander` group files through a dedicated review. Common date, cursor, nested-snippet and fill-in macros convert into Quill syntax. Review conversion warnings, choose snippets and skip or replace abbreviation conflicts. The import adds groups, backs up the saved library and supports Undo Last Library Change. Unsupported content stays excluded. See [migration compatibility and research](Documentation/TEXTEXPANDER_IMPORT.md).

Expansion is paused at every launch. In Settings → Expansion, review and explicitly request Accessibility and Input Monitoring access, add an allowed bundle identifier, refresh permission status, then enable for that session. Unknown apps, excluded apps, password fields, secure input and non-direct keyboard input methods are skipped. Supported editors must expose a writable Accessibility selected-text range. Only plain-text root templates without fill-ins expand automatically today. No clipboard read/paste or synthetic keystrokes are used. Unsupported or changed targets are left untouched where the editor permits; a failed insertion verification asks you to inspect the target and use its native Undo. Permission-enabled acceptance is still required.

Sparkle 2.10.0 supplies the update system. This development build has no feed or public key, shows that prerequisite, and does not start update checks. See [release preparation](Documentation/RELEASE.md) for local packaging and exact external inputs, and [collaboration roadmap](Documentation/COLLABORATION_ROADMAP.md) for sync/team/client milestones.

**Custom Macros** in the sidebar opens a searchable workspace editor for named reusable blocks, inserted with `{{macro:NAME}}`. **Insert → Zendesk Placeholder…** inserts message substitutions such as `{{ticket.requester.first_name}}` and custom ticket/user fields. Quill keeps Zendesk tokens unchanged for Zendesk to process; Preview explains this. See [custom macros and Zendesk placeholders](Documentation/MACROS.md).

The app icon follows the dark rounded-square style of the other native apps, with a simple off-white quill and cyan nib. Its source is in `Design`; `script/build-icon.sh` regenerates the macOS icon asset sizes.

See [workspace and UX map](Documentation/UX_MAP.md) for feature locations, navigation and completion behavior.

Current storage, native Markdown and per-item revision history are described in [content and history](Documentation/CONTENT_AND_HISTORY.md).
