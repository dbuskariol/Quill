# Content formats and revision history

Implementation and design boundaries, 2 October 2026.

## Current storage and history

Snippets and reusable macros have stable UUIDs, metadata, canonical `body` source and explicit `plainText` or `markdown` format. The default store is `~/Library/Application Support/Quill/library.sqlite`; Settings → Library shows the actual location. SQLite database schema v1 is separate from current JSON interchange schema v3. Every definition requires its format and metadata; the macros collection is required. Older/incomplete Quill exports are rejected with an actionable error. There are no runtime legacy decoders, inferred-field defaults, automatic JSON storage migration or alternate storage paths. JSON is explicit interchange only.

A meaningful saved change writes the current library and affected immutable item revisions in one `BEGIN IMMEDIATE` transaction, with SQLite full synchronous rollback journaling. Revisions include UUID, parent, shared transaction ID, timestamp, reason, canonical content/metadata/format and SHA-256 digest. No-op saves add no version. Deletion retains a tombstone; restore creates a new version. Group names remain library metadata, while template versions preserve group IDs. Deleted groups recover into a Recovered group. Macro rename and its saved reference changes commit together. Hashes are content identifiers, not encryption or tamper-proof auditing.

History beside each snippet/macro opens a native revision list with metadata/body comparison, saved-source view, Keep Version and Restore. Deleted Templates is available from Library commands and Settings → Library. Retention keeps the newest 100 versions per item by default; 30/100/500 are selectable. Kept versions are additional and exempt. Lowering retention requires confirmation; tombstones remain eligible as the newest version of deleted items. Revision links can end at pruned parents. No invisible Git repository or Git dependency exists.

Drafts are separate, debounced 400 ms recovery checkpoints. They capture authored definitions and the saved revision on which editing began, never field answers, resolved previews, clipboard content or ticket context. Navigation preserves in-memory drafts. Normal quit flushes checkpoints before exiting; failure offers Keep Editing. A sudden crash can lose edits since the last checkpoint. On relaunch, a Review banner opens native comparison and explicit Recover Draft / Discard Draft; recovery does not publish saved content. Save/Revert and the next checkpoint clear active recovery data. Pending recovery must be reviewed before whole-library replacement or relocation.

## Portable backups

**Export → Library Backup** and **Back Up Now** create `.quillbackup` SQLite snapshots containing current definitions, per-item versions, kept flags, retention preference and recovery drafts. SQLite's backup API supplies a consistent snapshot. Opening a backup shows its contents before confirmation. Healthy restore merges portable item history and records restored current definitions as new versions; existing newer versions remain. Disaster restore preserves damaged bytes and reinstalls a complete backup. Portable JSON export/import contains saved definitions only. Current-schema JSON snapshots restore definitions through review; JSON contains no per-item history. Older Quill formats are deliberately unsupported.

An adjacent `Quill History` directory keeps complete SQLite backups and preserved damaged databases. Imports, relocation and healthy whole-library restore create complete safety backups first. Ordinary saves use transactional per-item history; no parallel automatic JSON archive remains. Complete backups are not automatically pruned. Storage relocation copies and verifies the complete database without overwriting an existing library, and leaves the previous location intact. Older whole-library backup files remain in their original directory. Local revisions are recovery, not an independent backup; export a complete backup to another location for that purpose. Content is local, unencrypted, and never uploaded.

## Native formatting

The same native source editor and token completion edit plain text or Markdown. Foundation parses Markdown into a semantic document; an AppKit read-only attributed-text preview uses native fonts, selection and links without HTML import, WebKit or remote image loading. Formatted Copy writes allowlisted HTML, native RTF and readable plain text in one clipboard item. Copy As offers plain text or Markdown source. Repeat Last Copy retains and replays those formats in process memory until Clear or quit. Required local fields must be filled before copy.

Zendesk expressions, including underscore paths and filters, are masked during Markdown parsing and preserved literally. Literal fill-ins are escaped; mixed-format references convert Markdown to readable plain text or escape plain blocks for Markdown. Raw HTML is displayed literally. Unsafe link schemes stay as text, images become descriptive links, and tables warn about limited native preview support. Native headings, emphasis, links, lists, quotes and code have automated coverage. Actual Zendesk channel/paste acceptance remains untested. Automatic Accessibility expansion accepts plain-text root templates only; it does not insert rich clipboard content.

This is a native Markdown source-editing milestone. A full constrained WYSIWYG editor, attachments, account-specific formatting profiles and lossless arbitrary rich-text round trips remain future work. There are no independently editable HTML/RTF copies that can drift from canonical source.

## Zendesk's formatting boundary

Zendesk documents a combined CKEditor rich-content toolbar and Markdown input experience in its ticket composer. That combined experience does not apply to its macro editor. Zendesk's rich-content macro comments can also carry an alternate plain-text fallback for channels without rich text.

Pasting Markdown from a plain-text editor into the ticket composer can format it automatically, but code blocks and nested lists have documented paste limitations. Source editor type, paste-as-plain-text, channel and account configuration affect the result. Quill offers Markdown-source and HTML/RTF copying with plain fallback, but neither is a guarantee of Zendesk formatting parity.

For API comment output, Zendesk recommends `html_body` for Agent Workspace. Markdown belongs in `body`, not `html_body`, and Markdown rendering there is restricted to agent-authored comments. Quill has no ticket API integration; these distinctions inform a future output adapter rather than authorizing ticket submission.

## Future rich document boundary

A later constrained WYSIWYG editor should use a structured document for paragraphs, supported marks, lists, links, code, attachments and semantic template nodes. Source, native preview and destination output must share one renderer and completion catalog. Define loss warnings for attributes Markdown cannot represent, and test real Zendesk composers/channels before claiming fidelity. Do not fetch remote images merely to render a local preview. NSDocument/NSFileVersion may suit user-owned library documents later, but does not replace the current per-item recovery model.

## Why not hidden Git by default

Git is useful when users intentionally want files, branches, developer collaboration and external tooling. For this workspace it adds a repository/index/working-tree recovery model, a merge model that does not understand template references or rich-document structure, and a second persistence boundary. It would still need per-item metadata, migration, draft recovery, retention and native history UI. Bundling/executing Git or a library also adds distribution and maintenance cost; installed command-line tools cannot be assumed.

Keep Git an optional export/integration for people who want it. The recommendation is a product and architecture choice for Quill, not a claim that one storage technology is universally industry-leading. Apple's NSDocument/NSFileVersion architecture is appropriate if Quill later exposes user-owned library documents; it is not automatically a per-item history UI for this app-owned collection.

## Primary sources

- [Zendesk formatting options for agents](https://support.zendesk.com/hc/en-us/articles/4408884153242-Formatting-options-for-agents): combined composer and macro-editor distinction.
- [Zendesk Markdown and paste behavior](https://support.zendesk.com/hc/en-us/articles/4408846544922-Formatting-text-with-Markdown/): supported syntax and paste limitations.
- [Zendesk macro comments and plain-text fallback](https://support.zendesk.com/hc/en-us/articles/4408844187034-Creating-macros-for-repetitive-ticket-responses-and-actions): rich macro content and fallback.
- [Zendesk Ticket Comments API](https://developer.zendesk.com/api-reference/ticketing/tickets/ticket_comments/): body/html_body, sanitization and placeholder handling.
- [Apple NSFileVersion](https://developer.apple.com/documentation/foundation/nsfileversion) and [NSDocument version preservation](https://developer.apple.com/documentation/appkit/nsdocument/preservesversions): native file/document versions.

- [SQLite atomic commit](https://www.sqlite.org/atomiccommit.html) and [transactions](https://www.sqlite.org/lang_transaction.html): current content and revisions share one database transaction.
- [Apple Foundation Markdown parsing](https://developer.apple.com/documentation/foundation/instantiating-attributed-strings-with-markdown-syntax): native semantic formatting.
