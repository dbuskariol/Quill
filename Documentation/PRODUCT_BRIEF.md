# Product brief · Quill

Working name, version 0.1.0. A native Mac workspace for reusable words: fast abbreviation expansion, reliable templates, and confidence about what will be inserted. The first audience is individuals managing personal and work snippets who value privacy and native keyboard workflows.

The current development milestone adds effective native preferences, revision recovery, typed preview forms, a command palette, a conservative consent-gated expansion engine and Sparkle integration to the tested library/editor. Success means snippets survive restart, failed writes remain visible and recoverable, templates can be inspected before copying, and basic editing is equally reachable from keyboard and controls. It is not a shipping TextExpander replacement.

## Product direction

1. Library foundation (implemented): explicit save, local storage, search, favorites, typed rendering, dry-run fields, nested references and diagnostics.
2. Safe Mac expansion (partial; runtime acceptance open): consent-led onboarding, abbreviation policies, per-app profiles, secure-input suspension, expansion transaction/recovery, and a native quick action palette.
3. Advanced content and migration: rich text/images, reusable form schemas, conditional branches, date math, clipboard/key actions, trusted scripts, TextExpander migration with a loss report.
4. Personal reliability: version history, undo across library transactions, reusable template test cases, local usage statistics, and opt-in on-device suggestions.
5. Optional secure sync: independent threat model and key lifecycle before implementation. Shared/team permissions require conflict resolution, membership revocation, and audited writes.
6. Separate large milestones: cross-platform clients and organization administration/cloud collaboration. No release may imply these are included in the current Mac prototype.

## Concrete differentiators

- Local-first: default library remains on disk, no accounts or network required. Optional sync never silently enables itself.
- Dry-run: field values and resolved text visible before insertion; current prototype supports plain fields, dates, nesting and cursor diagnostics. Future preview also shows clipboard snapshot, target app, key actions and selected branches.
- Collision diagnostics: current exact-abbreviation warnings; future policy-aware analysis distinguishes overlapping app scopes, boundary and case rules, aliases, and prefix conflicts.
- Per-app profiles: bundle-ID based overrides for enabled groups, delimiters, paste/type insertion, and excluded sensitive apps. Unknown applications default to a conservative profile.
- History/undo: append revision before each transaction, restore by previewed diff, preserve previous revisions after delete, bounded local retention controlled by the user.
- Testable templates: named input fixtures, frozen date/clipboard context, expected text/cursor/actions, run before edits replace a trusted version.
- Private suggestions: explicitly opt-in, derive aggregate patterns on device from allowed text contexts; never retain raw keystrokes. Secure input, excluded apps and fields always suspend collection. Users can inspect/reset aggregates.

## Boundaries

No analytics, implicit diagnostics uploads, silent permission grants, or scripts executed merely by browsing a snippet. No inherited Reccy distribution/update settings. Pricing, brand, distribution and signing remain decisions for later milestones.
