# Quill engineering guide

Quill is a native macOS 26, local-first snippet app. Read README.md and Documentation/ARCHITECTURE.md before changes. The current milestone is a library/editor prototype, not system-wide expansion or TextExpander parity.

- Use Swift 6 complete strict concurrency, Observation, SwiftUI, and narrow AppKit integration. Keep Models/Services/Stores/Views/App/Support separated. No third-party runtime dependencies without a concrete need.
- Follow macOS appearance, standard source lists, toolbars, Settings, commands, confirmation alerts, keyboard access, and VoiceOver labels. Never replace native controls with web-like chrome.
- Inspect git status and diffs first; preserve unrelated edits. Reccy at /Users/nftdannyboy/.codex/worktrees/8576/Reccy is a read-only design reference. Do not import its media functionality, credentials, signing, bundle identity, update feeds, or dependencies.
- No analytics, implicit networking, keystroke logs, silent clipboard reads, OS permission prompts, or global input monitoring. Design the permission/secure-input boundary before expansion work.
- File corruption must be surfaced and preserved. Publish changes only after successful atomic writes. Keep filesystem work off the main actor.
- All commits and GitHub operations MUST use dbuskariol (GitHub user ID 32349796). Author AND committer: Daniel Buskariol <32349796+dbuskariol@users.noreply.github.com>. Run script/setup-repository.sh after cloning; use script/gh-quill.sh for GitHub. Do not alter global identity or the active gh account. Hooks reject mismatches; never bypass them. No pushing or publishing without user authorization.
- Build artifacts belong in external DerivedData. Use script/build_and_run.sh for the Codex Run action and script/verify-ci.sh for the gate. Confirm a nonzero test count from xcresult, build universal Release, and inspect native UI when available.
- Update the product matrix with honest implemented/planned/deferred status and acceptance criteria. Do not claim untested permission, signing, hardware, accessibility, or cloud acceptance.

Hooks are local safeguards, not an unbypassable security boundary. CI checks product behavior; publishing and account policy need separate review when a remote is authorized.
