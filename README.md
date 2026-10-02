# Quill

Quill is a native snippet library and template editor for macOS 26. It brings reusable replies, custom macros, Zendesk message placeholders, TextExpander import, Markdown preview, and local revision history into one focused Mac workspace.

<img src="Design/Quill-Icon-1024.png" alt="Quill app icon" width="128">

## A useful snippet library

Organize snippets into groups, mark favorites, and search titles, abbreviations, tags, and template content. The source-list sidebar keeps Snippets, Custom Macros, and Settings together; Settings opens inside the workspace from the bottom-left button or Command-comma.

Select a snippet, edit its source, preview the resolved reply, then save or copy. Drafts survive navigation and receive durable recovery checkpoints. Relaunch offers an explicit review of recovered edits. Validation errors explain what needs attention without preventing a snippet from being saved for later repair.

- Create snippets with Command-N and save with Command-S.
- Open Quick Actions with Command-K to find, fill, and copy a reply.
- Toggle favorites with Shift-Command-D and confirm deletion with Command-Delete.
- Manage groups beside the Groups heading, and edit tags alongside snippet metadata.
- Repeat the last copy from the app's in-memory clipboard payload.

See the [workspace and UX map](Documentation/UX_MAP.md) for feature placement and editing flows.

## Compose replies from reusable blocks

Custom Macros are named template blocks with their own editor, search, format, and history. Insert a macro with `{{macro:Signature}}` or another snippet with `{{snippet:;sig}}`. Blocks can contain dates, fill-ins, conditionals, and other blocks. Missing references, ambiguous abbreviations, and recursive cycles produce clear preview errors.

Type `{{` to open native completion, or continue with a partial name such as `{{ma`, `{{sni`, or `{{ticket.re`. The shared Insert menu uses the same catalog and inserts at the current cursor or selection, with native text undo.

| Need | Template example |
| --- | --- |
| Current date or time | `{{date}}`, `{{time}}` |
| Reusable block | `{{macro:Signature}}` |
| Simple field | `{{field:name}}` |
| Multiline input | `{{input:notes\|multiline}}` |
| Choice | `{{input:tone\|choice\|Formal\|Friendly}}` |
| Conditional text | `{{if:tone=Formal}}Hello{{else}}Hi{{end}}` |
| Date seven days ahead | `{{date:yyyy-MM-dd\|7}}` |

Fill-in values remain literal text and required empty fields prevent copying. See [macro syntax and Zendesk placeholders](Documentation/MACROS.md) for the complete contract.

## Prepare replies for Zendesk

Insert Zendesk message substitutions such as `{{ticket.requester.first_name}}` through the placeholder picker, including custom ticket and user fields. Quill preserves these tokens for Zendesk to resolve when the reply is used there. No Zendesk account connection is required.

Choose Plain Text or Markdown for each snippet and macro. Markdown receives a native formatted preview; formatted copying supplies HTML, RTF, and plain-text clipboard representations. Copy As Markdown and Copy As Plain Text provide explicit alternatives. Quill edits template source rather than providing a WYSIWYG composer. Unsupported Markdown constructs show preview limitations, and actual Zendesk editor/channel paste acceptance remains to be verified.

## Bring your TextExpander library

**Library → Import from TextExpander…** opens a dedicated review for CSV exports and older `.textexpander` group files. Quill converts supported date, cursor, nested-snippet, and fill-in macros into its own syntax.

Review source and conversion warnings, select the snippets to import, and choose whether to skip or replace abbreviation conflicts. Unsupported content stays excluded. Imports add groups, create a complete safety backup, and support Undo Last Library Change. See the [format research and compatibility matrix](Documentation/TEXTEXPANDER_IMPORT.md) for supported exports and limitations.

## Keep local history without managing Git

Each meaningful save creates an immutable item revision in a transactional SQLite library. History beside Save compares metadata and source, keeps selected versions, and restores a previous version as a new revision. Deleted templates remain recoverable. Settings offers retention of 30, 100, or 500 versions, with kept versions protected separately.

The default library lives at `~/Library/Application Support/Quill/library.sqlite`; Settings can move the complete library to a chosen folder. Portable `.quillbackup` files include definitions, history, retention, and draft checkpoints. Restore presents a review before applying changes. JSON import/export provides saved-definition interchange through one current schema. Corrupt data is surfaced and preserved.

See [content, storage, and history](Documentation/CONTENT_AND_HISTORY.md) for recovery and backup behavior.

## Native controls everywhere

Quill uses SwiftUI split views, system toolbars, menus, SF Symbols, native panels, and a narrow AppKit text editor. Settings manages storage, history, appearance, menu/Dock behavior, launch at login, and expansion policy within the existing workspace.

Abbreviation expansion starts paused on every launch. Explicit setup and session enablement are required, and only allowed applications with supported writable Accessibility text ranges can receive an expansion. The current engine handles plain-text root templates without fill-ins; secure input, password fields, unknown apps, and non-direct input methods are excluded. Permission-enabled target acceptance remains open.

## Architecture

Quill targets macOS 26 with Swift 6 complete strict concurrency.

| Layer | Technology |
| --- | --- |
| Workspace and state | SwiftUI, Observation, shared library store |
| Source editing and completion | AppKit `NSTextView`, shared typed completion catalog |
| Template resolution | Pure bounded parser and renderer with literal inputs |
| Markdown | Foundation semantics and native attributed text |
| Persistence | Actor-owned SQLite transactions, immutable revisions, draft checkpoints |
| Expansion | Consent-gated event monitoring and verified Accessibility replacement |
| Updates | Sparkle 2.10.0; distribution configuration pending |

The active library has one current storage schema, with no legacy migration or runtime storage fallback. Read the [architecture](Documentation/ARCHITECTURE.md) for ownership, rendering boundaries, and persistence decisions.

## Build and verify

Requires macOS 26 or later, Xcode 26 or later with the macOS 26 SDK, and Swift 6. Open `Quill.xcodeproj`, choose the shared **Quill** scheme, and run on **My Mac**, or use:

```sh
./script/build_and_run.sh
```

The committed Xcode project runs without a generator; `project.yml` is its XcodeGen source specification. Build artifacts live in external DerivedData. Debug builds use ad-hoc signing for local development; stable signing is required for reliable macOS permission acceptance.

Run the CI-equivalent gate with:

```sh
./script/verify-ci.sh
```

The gate validates scripts, metadata, whitespace, a nonzero Swift Testing result, and an unsigned universal Release build. GitHub Actions runs it on macOS 26 Apple silicon and Intel. The latest local verification passed 76 tests across 11 suites and the universal Release build. See [verification evidence](Documentation/VERIFICATION.md) for observations and remaining acceptance.

Repository maintainers use `./script/setup-repository.sh` to configure the required local author/committer identity and hooks. `./script/gh-quill.sh` pins GitHub operations to `dbuskariol` without changing the globally active account.

## Privacy

Templates, history, draft checkpoints, and fill-in values stay on the Mac. Quill does not upload content, log keystrokes, read the clipboard silently, or connect to Zendesk. Optional aggregate usage statistics are local and opt-in. Markdown preview does not fetch remote images. The last copied payload stays in process memory until cleared or the app quits.

## Status and release

Quill is in active development. The library, embedded Settings, TextExpander import, reusable macros, Zendesk placeholders, native completion, Markdown copying, history, backups, and draft recovery are implemented. Full WYSIWYG editing, rich automatic expansion, cloud sync, and team libraries remain future work.

This is a development build. Permission-enabled expansion, Zendesk paste behavior, full accessibility acceptance, signing, and distribution still need acceptance. Update checks remain inactive until a signed feed and public key are configured. See [release preparation](Documentation/RELEASE.md), the [feature matrix](Documentation/FEATURE_MATRIX.md), and the [collaboration roadmap](Documentation/COLLABORATION_ROADMAP.md).
