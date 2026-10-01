# Feature matrix

Research checked 2 October 2026 against official TextExpander sources. Status describes Quill 0.1.0: Implemented means present in this foundation; Planned means a future Mac milestone; Deferred means a separate large product milestone. Partial rows spell out the implemented subset. This is a scope review, not a parity claim.

| Capability | Status | Acceptance criteria / boundary |
| --- | --- | --- |
| Global abbreviation expansion | Planned | Explicit enablement, permissions/revocation, focus-safe replacement, Unicode/IME/secure-input tests |
| Plain text library/editor | Implemented | Create/edit/save/delete with confirmation; restart round-trip and error preservation |
| Rich text, hyperlinks, images | Planned | Preserve formatting/attachments across save, preview and supported target editors |
| Groups, tags, favorites, search | Partial | Starter groups, tag editing/search, favorites and body/title/abbreviation search implemented; group CRUD, tag browser and sorting planned |
| Quick actions and command palette | Planned | Keyboard-first search and insertion; menu routes match control behavior |
| Single-line fill-ins | Partial | Named plain preview fields and literal resolution implemented; expansion form validation and schema planned |
| Multiline, popup, optional fill-ins | Planned | Typed schema, defaults, validation, preview and keyboard traversal |
| Conditional branches | Planned | Nested choices resolve only selected content, without leftover spacing; references/images/fields permitted |
| Date picker fill-in | Planned | User-chosen date and custom format preview with fixed test contexts |
| Date/time macros | Partial | Local ISO date and 24-hour time preview implemented; format choice/calendar/date math planned |
| General math | Planned | Typed deterministic arithmetic, precision/error bounds; no code execution |
| Clipboard | Planned | Explicit snapshot consent; preview exactly what is used; safe ownership-aware restoration |
| Cursor position | Partial | One marker, UTF-16 offset and text-only copy implemented; insertion cursor and movement actions planned |
| Key macros and timed delays | Planned | Typed bounded actions, preview, app readiness/focus checks and cancellation |
| Nested snippets | Implemented (preview) | Missing/ambiguous references and cycles fail; depth/output bounded; no global insertion |
| Abbreviation conflict detection | Partial | Exact matches warn and ambiguous nesting fails; case/scope/boundary/prefix diagnostics planned |
| Delimiters, case, boundaries, aliases | Planned | Policy tables tested for Unicode and multiple abbreviations; per-snippet overrides |
| App scope and profiles | Planned | Bundle-ID exclusions/overrides and unknown-app policy; profile visible before insertion |
| Scripts | Planned | Explicit per-script trust bound to content hash, no trust on import, bounded execution and result preview |
| TextExpander import/export | Planned | Versioned adapters, backup, preview and loss report; round-trip fixtures; never claim syntax compatibility today |
| Autocorrect and starter libraries | Partial | Five Quill samples implemented; curated opt-in starters and autocorrect rules planned |
| Suggestions and reminders | Planned | On-device opt-in aggregation, no raw keystroke log; inspect/reset/disable and secure-input exclusion |
| Repeat last expansion | Planned | Replay resolved fields/date/clipboard/actions exactly; explicit memory retention/clear controls |
| Usage and time saved | Planned | Opt-in local counts, explained baseline, no content/event log, reset/export |
| Local persistence/privacy | Implemented | Atomic saves, actor isolation, corruption preserved, surfaced errors, no network or analytics |
| Dry-run resolved preview | Implemented (plain templates) | Frozen-context tests; literal fields; live text/cursor diagnostics; copy blocked on empty fields |
| Version history/library undo | Planned | Atomic revision records, retention, previewed restore/delete undo; native text undo exists today |
| Reusable template test cases | Planned | User-named context fixtures with text/cursor/action assertions; renderer unit tests exist today |
| Secure personal sync | Planned | Threat model, device keys/recovery/revocation and offline conflict tests before activation |
| Shared/team libraries and roles | Deferred | Separate collaboration milestone: membership, role checks, key rotation, conflict review and audited writes |
| Organization administration | Deferred | Separate service milestone: provisioning, policies, requests, roles and administrator workflows |
| Cross-platform clients | Deferred | Independent Windows/browser/mobile milestones and compatibility matrix |
| Native Settings/menu bar/commands | Implemented | Menu-bar visibility preference, library route, storage reveal, keyboard/menu actions |
| Distribution and update system | Planned | New stable signing identity, notarization, update trust; no inherited feed or secrets |

## Official sources and current additions

- [Advanced snippet elements](https://textexpander.com/learn/using/snippets/advanced-snippet-elements) establishes macros, dynamic content and form elements. Quill implements only the plain preview subset above.
- [What is TextExpander](https://textexpander.com/what-is-textexpander) describes reusable content and team use; [Press kit](https://textexpander.com/presskit) provides broad product/platform scope. Cross-platform and organization work are separate Quill milestones.
- [What's new](https://textexpander.com/whats-new) documents recent conditional sections, repeat-last expansion, date picker, delay macros, mobile and team workflows. All are explicitly tracked above. Review again before any parity marketing or migration release.

This review is not an exhaustive release acceptance suite. Advanced feature syntax and per-platform behavior require deeper official-source research and fixtures during implementation.
