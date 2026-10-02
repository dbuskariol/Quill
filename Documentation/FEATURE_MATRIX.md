# Feature matrix

Research checked 2 October 2026 against official TextExpander sources. Status describes the current Quill development build: Implemented means present in this foundation; Planned means a future Mac milestone; Deferred means a separate large product milestone. Partial rows spell out the implemented subset. This is a scope review, not a parity claim.

| Capability | Status | Acceptance criteria / boundary |
| --- | --- | --- |
| First-launch setup | Implemented | Shared permission actions, native application scope chooser, explicit Enable, optional resume/login and deferral; completed setup remains dismissed after relaunch |
| Command palette | Implemented | Native ⌘K search across snippets/macros/actions, ranked and compact fuzzy matching, group/tag/favorite filters, recents, previews and keyboard copy/open/run |
| Global abbreviation expansion | Partial, runtime acceptance pending | Consent setup, immediate/delimiter matching, typed expansion forms, application scope and verified AX replacement implemented. Signed installed grants and rebuild continuity confirmed; physical typing, external form transactions, editor coverage and IME acceptance remain open |
| Plain text library/editor | Implemented | Create/edit/save/delete with confirmation; restart round-trip and error preservation |
| Markdown and formatted copy | Implemented locally | Explicit formats, native Markdown source/preview, HTML/RTF/plain clipboard output, token preservation and mixed-format references; live Zendesk paste acceptance pending |
| Full WYSIWYG and images | Planned | Structured rich editing, attachments and lossless rich target round trips |
| Groups, tags, favorites, search | Partial | Group create/rename/delete with snippet reassignment and recovery, tag editing/search, favorites implemented; tag browser and user sorting planned |
| Quick actions and command palette | Partial | Cmd-K saved-snippet search, typed form preview/copy and library navigation; global shortcut and external form insertion planned |
| Single-line fill-ins | Implemented, TextEdit acceptance confirmed | Named literal fields, required validation and shared compact native expansion controls. User confirmed notes insertion; native presentation tests verify first responder without clicking |
| Multiline, popup, optional fill-ins | Partial | Typed inline schemas, shared native preview/expansion controls and choice validation; native initial keyboard focus tested; external typed-form coverage and reusable schemas/defaults pending |
| Conditional branches | Partial | Nested if/else/end blocks resolve only selected text, fields and references. Native expansion forms implemented; external transaction acceptance pending; images planned |
| Date picker fill-in | Implemented in preview | Shared native date chooser in preview and expansion form, explicit confirmation of today, strict date validation and format tests |
| Date/time macros | Partial | ISO date/time, custom ICU date formats and Gregorian day offsets implemented; broader calendar/unit math planned |
| General math | Implemented | Bounded numeric parser for +, -, *, / and parentheses; finite values, divide-by-zero and depth checks; no code evaluation |
| Clipboard | Planned | Explicit snapshot consent; preview exactly what is used; safe ownership-aware restoration |
| Cursor position | Partial | Shared visible-text cursor projection for plain text/Markdown preview and AX insertion, with native source-position mapping and boundary regression cases; actual target acceptance and movement actions pending |
| Key macros and timed delays | Planned | Typed bounded actions, preview, app readiness/focus checks and cancellation |
| Nested snippets | Implemented (preview) | Missing/ambiguous references and cycles fail; depth/output bounded; expansion uses the same resolver, external acceptance pending |
| Inline template completion | Implemented | Shared native text-system helper in snippet and custom-macro editors, partial words, snippet/macro dot discovery aliases, common Zendesk paths, UTF-16 ranges and bounded suggestions; custom account schemas are entered manually |
| Custom reusable macros | Implemented | Searchable workspace editor, insertion at selection/cursor, shared fields, nested blocks, cycle checks, atomic reference updates on rename, draft recovery, native history and current-schema interchange |
| Zendesk message placeholders | Implemented locally | Dedicated common/custom-field picker, supported namespace/filter preservation, unchanged escapes and clear preview; Zendesk performs substitution. No live-ticket submission claimed |
| Abbreviation conflict detection | Partial | Exact matches warn and ambiguous nesting fails; case/scope/boundary/prefix diagnostics planned |
| Delimiters, case, boundaries, aliases | Partial | Immediate/delimiter, case/boundary policy, prefix disambiguation and collision refusal tested; aliases and per-snippet overrides planned |
| App scope and profiles | Partial | All Applications or Selected Applications with named app rows, a native app chooser, editable exclusions and exclusion precedence. Per-app rule overrides and group scopes planned |
| Scripts | Planned | Explicit per-script trust bound to content hash, no trust on import, bounded execution and result preview |
| TextExpander import/export | Partial | Dedicated multi-file CSV/legacy-group import, original/converted preview, warnings, conflict handling, backup and undo. Common macros convert; unsupported items excluded. TextExpander export and broader formats planned; see migration guide |
| Autocorrect and starter libraries | Partial | Five Quill samples implemented; curated opt-in starters and autocorrect rules planned |
| Suggestions and reminders | Planned | On-device opt-in aggregation, no raw keystroke log; inspect/reset/disable and secure-input exclusion |
| Repeat last expansion | Planned | Replay resolved fields/date/clipboard/actions exactly; explicit memory retention/clear controls |
| Usage and time saved | Implemented, external expansion acceptance pending | Opt-in aggregate expansion/copy counts, characters avoided and explained adjustable estimate; local reset/export; no content/event log |
| Local persistence/privacy | Implemented | Atomic saves, actor isolation, corruption preserved, surfaced errors, no network or analytics |
| Dry-run resolved preview | Implemented (plain/Markdown templates) | Frozen-context tests; literal fields; live text/cursor diagnostics; copy blocked on empty fields |
| Version history/library undo | Implemented, full undo stack planned | Transactional item versions, metadata/body comparison, restore-as-new, deletion recovery, protected versions and retention; complete backups/reviewed restore and one-step library undo |
| Unsaved draft recovery | Implemented | Separate debounced authored checkpoints, flush on normal quit, review/recover/discard on relaunch, original revision conflict detection; no field answers or clipboard history |
| Reusable template test cases | Planned | User-named context fixtures with text/cursor/action assertions; renderer unit tests exist today |
| Secure personal sync | Planned | Threat model, device keys/recovery/revocation and offline conflict tests before activation |
| Shared/team libraries and roles | Deferred | Separate collaboration milestone: membership, role checks, key rotation, conflict review and audited writes |
| Organization administration | Deferred | Separate service milestone: provisioning, policies, requests, roles and administrator workflows |
| Cross-platform clients | Deferred | Independent Windows/browser/mobile milestones and compatibility matrix |
| Native Settings/menu bar/commands | Partial | Native sidebar Settings, persisted Dock/menu/window controls, login service status, storage/recovery, expansion consent/policy, updater status and Cmd-K implemented. Installed login registration/unregistration verified; opt-in Statistics settings implemented; global-shortcut settings planned |
| Distribution and update system | Implemented distribution pipeline | Published 0.1.3 uses Developer ID signing, notarization/stapling and an app-specific signed Sparkle feed. All six public assets, provenance and Sparkle signatures verified after download; actual updater installation and failure acceptance remain pending |
| Expansion duration and background use | Implemented, acceptance partial | Until Quill Quits, 15 Minutes, 1 Hour and explicitly armed Every Time Quill Opens; pause disarms launch resumption. Signed relaunch resumption and deadline display verified. Actual 15-minute expiry while the window is closed is verified; native menu dismissal confirmed by the user; candidate accepted by the user for publication. Directed external form/Undo/composition checks remain incomplete |
| Menu bar, Dock and window closing | Implemented, acceptance partial | Native menu bar library/Quick Actions/Settings/enable/pause/duration/quit controls; Dock hiding, reachability guard and keep-running close behavior. Background process and library reopen verified; native menu dismissal confirmed by the user |

## Official sources and current additions

- [Advanced snippet elements](https://textexpander.com/learn/using/snippets/advanced-snippet-elements) establishes macros, dynamic content and form elements. Quill’s implemented subset and external acceptance boundaries are listed above.
- [What is TextExpander](https://textexpander.com/what-is-textexpander) describes reusable content and team use; [Press kit](https://textexpander.com/presskit) provides broad product/platform scope. Cross-platform and organization work are separate Quill milestones.
- [What's new](https://textexpander.com/whats-new) documents recent conditional sections, repeat-last expansion, date picker, delay macros, mobile and team workflows. All are explicitly tracked above. Review again before any parity marketing or migration release.

This review is not an exhaustive release acceptance suite. Advanced feature syntax and per-platform behavior require deeper official-source research and fixtures during implementation.

Detailed external scope and acceptance: [Collaboration roadmap](COLLABORATION_ROADMAP.md). Release inputs and gates: [Release preparation](RELEASE.md). Migration compatibility: [TextExpander import](TEXTEXPANDER_IMPORT.md). Repeat Last Copy in Quick Actions is distinct from replaying a completed external expansion; the latter remains planned. Full WYSIWYG/attachments, scripts, broader TextExpander migration, suggestions and reusable user test cases remain unfinished Mac work. No full parity or release-readiness claim is made.
