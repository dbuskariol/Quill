# Architecture and native design

## Reference and separation

Read-only Reccy review covered AGENTS.md, README.md, root folders, RootView.swift, LibraryView.swift, Configuration contents, and verify-ci.sh. Quill adopts the native workspace/persistence/verification quality bar and external DerivedData convention, with a source-list sidebar, snippet browser and detail editor. It uses standard macOS 26 split views, toolbar glass and adaptive semantic styles. There are no copied capture pipelines, recording permissions, update feeds, signing identities, media frameworks or unrelated packages.

## Ownership

`App` owns the shared `@MainActor @Observable LibraryStore` and native scenes. `Models` holds Codable/Sendable value records with stable UUIDs and a versioned library. `Services` contains an actor repository and a pure typed token parser/renderer. `Stores` serializes UI mutations through one async commit path. `Views` are small, feature-oriented surfaces. `Support` exposes shared menu actions. No unchecked Sendable, detached tasks, or external runtime dependencies.

The store publishes saved library state only after persistence succeeds. `isBusy` rejects overlapping mutations; actions disable appropriately. The repository actor performs JSON/filesystem work away from UI isolation and uses Foundation atomic writes. Corrupt/unsupported data is never treated as an empty library and never overwritten by starters. Startup validates before publishing. First launch persists starters for stable IDs. Errors identify the failed operation and preserve committed state; drafts remain available to retry.

Drafts are separate in-memory edits keyed by snippet UUID. Search or group changes preserve them; save commits and clears the draft, Revert discards it, delete confirms removal, and application quit asks before losing edits. TextEditor provides native text undo; whole-library undo and disk version history are future work. Windows share library selection and drafts in this milestone; independent scene navigation and cross-process writer coordination need a later design. Do not run multiple app instances against the same library.

## Rendering contract

Quill syntax is intentionally small and distinct from TextExpander syntax. Tokens are text/date/time/field/reference/cursor. Parse errors fail preview. Rendering takes an explicit context with date, time zone and literal field values, detects missing/ambiguous references, cycles and maximum nesting (32), and bounds resolved text to one million UTF-16 units. Cursor offsets use UTF-16 for eventual AppKit text insertion. Only one cursor marker may exist after resolution. No scripts, clipboard reads, synthetic keys, or global expansion side effects occur. Tests freeze dynamic context and cover failures.

## Expansion engine design gate (not implemented)

Consent is a state machine: inactive → explanation → user-initiated system permission request → verified availability → explicitly enabled. Revocation returns to inactive with actionable status. Accessibility and Input Monitoring requirements must be established against the chosen API on a stable signed build; do not request both speculatively. Permissions are tied to identity; ad-hoc QA cannot prove distribution acceptance.

Use a bounded transient abbreviation buffer only while enabled in allowed apps. Secure Event Input immediately suspends capture and expansion, clears buffers, and never attempts bypass; passwords and known sensitive contexts are excluded. Window/app changes clear context. No keystroke log or persisted raw event stream. Keep input callback work bounded and route rendering off the callback path.

Expansion is a transaction: identify target/focus and policy, resolve an immutable context, show fields if required, validate conflicts, verify focus/secure-input again, replace exactly the matched abbreviation, insert through an app-compatible strategy, place cursor, and record only opt-in aggregate statistics. Focus drift cancels rather than typing into the wrong app. Clipboard strategies require snapshot/restore ownership checks and user consent; never overwrite a newer user clipboard. Failure must preserve/recover abbreviation where possible and explain what happened. Synthetic keys and delays are typed actions, previewed and bounded, not hidden text characters. Test permissions denied/revoked, secure-input transitions, Unicode, IMEs, rich editors, remote desktops, and target focus loss before release.

## Optional sync threat model (design only)

Protect snippet content, history, fields and metadata from service operators and passive network observers. Encrypt locally with per-library keys; keys stay in Keychain, explicit device enrollment distributes encrypted key envelopes, and users receive a recovery/export path. Define metadata leakage (membership and traffic), offline conflicts, deletion tombstones, compromised devices, key rotation and revocation before shipping. Revocation cannot retract already decrypted content. Teams need distinct library keys, role checks, signed writes and audit logs; server authorization alone is insufficient. Backups and clipboard remain separate leakage boundaries. No sync dependency or network client exists today.

## Native design acceptance

Standard source-list selection, searchable split hierarchy, resizeable columns, toolbar creation, Cmd-N/Cmd-S/menu deletion, native alerts, real Settings and menu bar route. Monospaced template text, semantic errors, no fixed appearance palette, accessible labels for symbol-only controls. Manual VoiceOver, increased contrast, reduced motion, keyboard traversal and full-size/compact-window passes remain required before shipping. Avoid decorative custom glass when system controls already supply it.
