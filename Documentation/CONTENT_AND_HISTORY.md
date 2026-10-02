# Content formats and revision history

Design assessment, 2 October 2026. This is a recommendation; structured rich content and per-item history are not implemented by the current completion milestone.

## What ships in this development build

`CustomMacro` has a stable UUID, name and a plain-text `body`. It is stored in the `macros` array of the same JSON library as groups and snippets. The default file is `~/Library/Application Support/Quill/library.json`; Settings → Library shows the actual location and can relocate it. Library schema version 2 adds macros; that version number is a compatibility marker, not a content revision counter.

Saved changes validate, archive the previous complete JSON library under the adjacent `Quill History` directory, then atomically replace the active file. There is a cooperating-writer lock, stale-file detection, backup/restore and one-step whole-library undo. History is whole-library snapshots, with no per-macro diff or bounded retention policy yet. Drafts live only in memory and quitting asks before discarding them; this is not crash recovery for unsaved edits.

Markdown characters and Zendesk placeholders can be stored and copied verbatim today. Preview does not render Markdown, and Quill does not produce rich HTML/RTF clipboard content. Zendesk substitutions are preserved for Zendesk; Quill does not resolve them locally or connect to a ticket account.

## Zendesk's formatting boundary

Zendesk documents a combined CKEditor rich-content toolbar and Markdown input experience in its ticket composer. That combined experience does not apply to its macro editor. Zendesk's rich-content macro comments can also carry an alternate plain-text fallback for channels without rich text.

Pasting Markdown from a plain-text editor into the ticket composer can format it automatically, but code blocks and nested lists have documented paste limitations. Source editor type, paste-as-plain-text, channel and account configuration affect the result. Quill's current plain-text copy is useful for Markdown, but is not a guarantee of formatting parity.

For API comment output, Zendesk recommends `html_body` for Agent Workspace. Markdown belongs in `body`, not `html_body`, and Markdown rendering there is restricted to agent-authored comments. Quill has no ticket API integration; these distinctions inform a future output adapter rather than authorizing ticket submission.

## Recommended native content model

Use one canonical, versioned template document per item. Introduce explicit formats rather than interpreting every plain string as Markdown: plain text and Markdown first, with a structured rich-document variant when rich editing ships. Keep the existing plain-text format lossless during migration. A native formatted editor should share the same token catalog/completion and renderer, with placeholders represented as semantic inline nodes so formatting cannot split a `{{...}}` expression.

The rich document should represent paragraphs, supported inline marks, lists, links, code blocks, attachments and template tokens in a deterministic schema. Generate plain text, a defined Markdown subset and sanitized Zendesk-compatible HTML from that source. Escape literal fill-in values for the destination format; do not reinterpret them as markup or template tokens. Do not maintain independently editable Markdown, HTML and RTF copies: they will drift. Markdown cannot losslessly represent every rich-text attribute, including colors and some layout; flag lossy exports instead of silently dropping them.

For the initial formatting milestone, native Markdown editing/preview and a tested Zendesk paste profile are smaller than a complete WYSIWYG editor. A later constrained native WYSIWYG editor can edit the structured document; rich clipboard output should include HTML/RTF plus a plain-text fallback. Test token preservation, links, lists, nested lists, code blocks, Unicode, sanitization and channel-specific fallback in real Zendesk before claiming compatibility. Never fetch remote images merely to render a local preview.

## Recommended history model

For this app-managed library, favor transactional per-item revisions over an invisible Git repository. As the library grows, migrate to a native local SQLite-backed store, with explicit schema migrations and portable JSON/document export. Whether implemented directly or through an Apple persistence layer, require atomic current-item + revision + attachment-reference writes and test rollback/crash behavior.

Each meaningful save should create an immutable revision containing item UUID, revision UUID, parent revision, timestamp, content format/schema, metadata and canonical content/hash. Deletions should retain a recoverable tombstone. Restoring an older revision creates a new revision; it never rewrites history. No-op saves create no revision. Revisions store authored templates and metadata; transient fill-in values, resolved previews, clipboard contents and ticket context do not become history. Group edits/imports should also record a transaction ID so related changes can be reviewed together. Hashing can deduplicate identical bodies; it is not encryption or a tamper-proof audit trail.

Draft recovery is a separate, debounced checkpoint, not a visible history entry for every keystroke. Keep the latest recoverable draft and restore it after a crash without publishing it as saved content. Define retention by age/storage budget with protected restore points; deleting current content must include a clear policy for revisions and attachments. Local history is a recovery feature, not a substitute for an export or independent backup.

Expose a small History action beside the selected snippet/macro's Save controls. It opens a native revision list with readable dates, a diff/preview and Restore. Avoid branch/commit/hash vocabulary. Settings → Library remains the home for whole-library disaster recovery, export and storage policy. This keeps authoring history near its content and global maintenance in preferences.

## Why not hidden Git by default

Git is useful when users intentionally want files, branches, developer collaboration and external tooling. For this workspace it adds a repository/index/working-tree recovery model, a merge model that does not understand template references or rich-document structure, and a second persistence boundary. It would still need per-item metadata, migration, draft recovery, retention and native history UI. Bundling/executing Git or a library also adds distribution and maintenance cost; installed command-line tools cannot be assumed.

Keep Git an optional export/integration for people who want it. The recommendation is a product and architecture choice for Quill, not a claim that one storage technology is universally industry-leading. Apple's NSDocument/NSFileVersion architecture is appropriate if Quill later exposes user-owned library documents; it is not automatically a per-item history UI for this app-owned collection.

## Primary sources

- [Zendesk formatting options for agents](https://support.zendesk.com/hc/en-us/articles/4408884153242-Formatting-options-for-agents): combined composer and macro-editor distinction.
- [Zendesk Markdown and paste behavior](https://support.zendesk.com/hc/en-us/articles/4408846544922-Formatting-text-with-Markdown/): supported syntax and paste limitations.
- [Zendesk macro comments and plain-text fallback](https://support.zendesk.com/hc/en-us/articles/4408844187034-Creating-macros-for-repetitive-ticket-responses-and-actions): rich macro content and fallback.
- [Zendesk Ticket Comments API](https://developer.zendesk.com/api-reference/ticketing/tickets/ticket_comments/): body/html_body, sanitization and placeholder handling.
- [Apple NSFileVersion](https://developer.apple.com/documentation/foundation/nsfileversion) and [NSDocument version preservation](https://developer.apple.com/documentation/appkit/nsdocument/preservesversions): native file/document versions.
