# Quill

Quill is a new native macOS 26 snippet library and template editor, built with Swift 6, SwiftUI, Observation, and AppKit. It is the foundation for a modern TextExpander alternative. **Global abbreviation expansion is not implemented yet.**

The runnable app includes five starter snippets across three groups, full-library search (including tags and body), favorites, create/edit/delete with confirmation, local atomic persistence, dry-run fill-in preview, date/time macros, cursor offsets, nested templates, cycle detection, and abbreviation collision diagnostics. It has real Settings, a menu bar entry point, conventional keyboard commands, adaptive appearance, and explicit storage errors. No permission prompts, analytics, or network transmission occur.

## Run

Requires macOS 26+, Xcode 26+ with the macOS 26 SDK, and command-line tools selected for that Xcode. Open Quill.xcodeproj and run the shared Quill scheme, or use Codex's **Run** action:

```sh
./script/build_and_run.sh
```

Debug builds are ad-hoc signed for local development. DerivedData is under `~/Library/Developer/Xcode/DerivedData/Quill`. No signing team or distribution identity is inherited from Reccy. The committed Xcode project needs no generator; `project.yml` is its source specification and can be regenerated with XcodeGen when targets change.

## Use

Choose a group or Favorites, search, select a snippet, then edit the template. **Save Snippet (⌘S)** commits edits locally. **⌘N** creates a snippet; **⇧⌘D** toggles a saved snippet's favorite; **⌘Delete** requests deletion. Unsaved drafts survive selection changes in memory, and quitting warns before discarding them. Revert restores the saved snippet. Menu bar opens the library; Settings controls its visibility and reveals storage.

Supported Quill syntax (not TextExpander's import syntax): `{{date}}`, `{{time}}`, `{{field:name}}`, `{{snippet:;sig}}`, and `{{cursor}}`. Insert Macro appends at the end. Date is ISO calendar date and time uses 24-hour local time. Fill-in values are literal, never interpreted as macros. Copy Preview is disabled while fields are empty and writes plain text only, with the cursor marker removed. Cursor offset is diagnostic; no external insertion occurs.

The JSON library is at `~/Library/Application Support/Quill/library.json`. Invalid templates may be saved for later repair; preview explains their validation errors. Abbreviation collisions are warnings for editing and errors when an ambiguous nested reference is resolved. Search does not change stored content. Group names are starter configuration in this milestone; group CRUD is planned.

## Verify and contribute

```sh
./script/setup-repository.sh
./script/verify-ci.sh
```

Setup configures only this repository's author, committer, hook path, and GitHub credential helper. GitHub operations use `./script/gh-quill.sh`, which pins and verifies dbuskariol without switching the globally active account. No remote or publishing is configured.

The gate checks script syntax, metadata, whitespace, Swift Testing results with a nonzero count, and an unsigned universal Release build. CI is prepared for macOS 26 Apple silicon and Intel, but has not run remotely. See Documentation/VERIFICATION.md for local observations and gaps.

See Documentation/PRODUCT_BRIEF.md, Documentation/FEATURE_MATRIX.md, and Documentation/ARCHITECTURE.md for scope and the next milestones. Reccy informed layout and engineering conventions; Quill is a separate repository with its own identity and no recording code.
