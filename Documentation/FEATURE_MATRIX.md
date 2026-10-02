# Feature matrix

Research checked 2 October 2026 against official TextExpander sources. Status describes the current Quill development build: Implemented means present in this foundation; Planned means a future Mac milestone; Deferred means a separate large product milestone. Partial rows spell out the implemented subset. This is a scope review, not a parity claim.

| Capability | Status | Acceptance criteria / boundary |
| --- | --- | --- |
| Global abbreviation expansion | Partial, runtime acceptance pending | Consent buttons, session enable/pause, allowed-app policy, committed AX text matching and verified AX replacement implemented. No permissions granted in QA; fill-in insertion, adapter coverage and IME support remain open |
| Plain text library/editor | Implemented | Create/edit/save/delete with confirmation; restart round-trip and error preservation |
| Rich text, hyperlinks, images | Planned | Preserve formatting/attachments across save, preview and supported target editors |
| Groups, tags, favorites, search | Partial | Group create/rename/delete with snippet reassignment and recovery, tag editing/search, favorites implemented; tag browser and user sorting planned |
| Quick actions and command palette | Partial | Cmd-K saved-snippet search, typed form preview/copy and library navigation; global shortcut and external form insertion planned |
| Single-line fill-ins | Partial | Named plain preview fields and literal resolution implemented; expansion form validation and schema planned |
| Multiline, popup, optional fill-ins | Partial | Typed inline schemas, native preview controls and choice validation; reusable schema/defaults and external expansion forms planned |
| Conditional branches | Partial | Nested if/else/end blocks resolve only selected text, fields and references. Images and external expansion forms planned |
| Date picker fill-in | Implemented in preview | Native date chooser, explicit confirmation of today, strict date validation and custom format tests |
| Date/time macros | Partial | ISO date/time, custom ICU date formats and Gregorian day offsets implemented; broader calendar/unit math planned |
| General math | Implemented | Bounded numeric parser for +, -, *, / and parentheses; finite values, divide-by-zero and depth checks; no code evaluation |
| Clipboard | Planned | Explicit snapshot consent; preview exactly what is used; safe ownership-aware restoration |
| Cursor position | Partial | UTF-16 preview and AX cursor placement implemented; actual target acceptance and movement actions pending |
| Key macros and timed delays | Planned | Typed bounded actions, preview, app readiness/focus checks and cancellation |
| Nested snippets | Implemented (preview) | Missing/ambiguous references and cycles fail; depth/output bounded; no global insertion |
| Custom reusable macros | Implemented | Dedicated editor, insertion at selection/cursor, shared fields, nested blocks, cycle checks, atomic reference updates on rename, draft/quit protection and v2 persistence |
| Zendesk message placeholders | Implemented locally | Dedicated common/custom-field picker, supported namespace/filter preservation, unchanged escapes and clear preview; Zendesk performs substitution. No live-ticket submission claimed |
| Abbreviation conflict detection | Partial | Exact matches warn and ambiguous nesting fails; case/scope/boundary/prefix diagnostics planned |
| Delimiters, case, boundaries, aliases | Partial | Persisted delimiter/case/boundary policy and collision refusal tested; aliases and per-snippet overrides planned |
| App scope and profiles | Partial | Explicit persisted allowlist and exclusion precedence; unknown apps excluded. Per-app rule overrides and group scopes planned |
| Scripts | Planned | Explicit per-script trust bound to content hash, no trust on import, bounded execution and result preview |
| TextExpander import/export | Partial | Dedicated multi-file CSV/legacy-group import, original/converted preview, warnings, conflict handling, backup and undo. Common macros convert; unsupported items excluded. TextExpander export and broader formats planned; see migration guide |
| Autocorrect and starter libraries | Partial | Five Quill samples implemented; curated opt-in starters and autocorrect rules planned |
| Suggestions and reminders | Planned | On-device opt-in aggregation, no raw keystroke log; inspect/reset/disable and secure-input exclusion |
| Repeat last expansion | Planned | Replay resolved fields/date/clipboard/actions exactly; explicit memory retention/clear controls |
| Usage and time saved | Implemented, external expansion acceptance pending | Opt-in aggregate expansion/copy counts, characters avoided and explained adjustable estimate; local reset/export; no content/event log |
| Local persistence/privacy | Implemented | Atomic saves, actor isolation, corruption preserved, surfaced errors, no network or analytics |
| Dry-run resolved preview | Implemented (plain templates) | Frozen-context tests; literal fields; live text/cursor diagnostics; copy blocked on empty fields |
| Version history/library undo | Partial | Prior file archived before save, explicit backup/restore, corruption preservation and one-step undo implemented; revision diffs, bounded retention and full undo stack planned |
| Reusable template test cases | Planned | User-named context fixtures with text/cursor/action assertions; renderer unit tests exist today |
| Secure personal sync | Planned | Threat model, device keys/recovery/revocation and offline conflict tests before activation |
| Shared/team libraries and roles | Deferred | Separate collaboration milestone: membership, role checks, key rotation, conflict review and audited writes |
| Organization administration | Deferred | Separate service milestone: provisioning, policies, requests, roles and administrator workflows |
| Cross-platform clients | Deferred | Independent Windows/browser/mobile milestones and compatibility matrix |
| Native Settings/menu bar/commands | Partial | Native sidebar Settings, persisted Dock/menu/window controls, login service status, storage/recovery, expansion consent/policy, updater status and Cmd-K implemented. Login requires installed-bundle acceptance; opt-in Statistics settings implemented; global-shortcut settings planned |
| Distribution and update system | Partial, externally blocked | Pinned Sparkle 2.10, signed-feed/archive policy, native updater preferences and guarded local packaging script. Feed/key/Developer ID/notarization inputs absent; upgrade/failure acceptance pending |

## Official sources and current additions

- [Advanced snippet elements](https://textexpander.com/learn/using/snippets/advanced-snippet-elements) establishes macros, dynamic content and form elements. Quill implements only the plain preview subset above.
- [What is TextExpander](https://textexpander.com/what-is-textexpander) describes reusable content and team use; [Press kit](https://textexpander.com/presskit) provides broad product/platform scope. Cross-platform and organization work are separate Quill milestones.
- [What's new](https://textexpander.com/whats-new) documents recent conditional sections, repeat-last expansion, date picker, delay macros, mobile and team workflows. All are explicitly tracked above. Review again before any parity marketing or migration release.

This review is not an exhaustive release acceptance suite. Advanced feature syntax and per-platform behavior require deeper official-source research and fixtures during implementation.

Detailed external scope and acceptance: [Collaboration roadmap](COLLABORATION_ROADMAP.md). Release inputs and gates: [Release preparation](RELEASE.md). Migration compatibility: [TextExpander import](TEXTEXPANDER_IMPORT.md). Repeat Last Copy in Quick Actions is distinct from replaying a completed external expansion; the latter remains planned. Rich text, scripts, broader TextExpander migration, suggestions and reusable user test cases remain unfinished Mac work. No full parity or release-readiness claim is made.
