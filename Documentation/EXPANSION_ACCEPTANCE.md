# Core workflow acceptance — 2 October 2026

Release is gated on actual external replacement, not just matching unit tests.

## Build and permission identity

Interactive Debug and distribution builds use `com.dbuskariol.quill`, Developer ID team `BJCVJ5G7MJ`, and the same certificate-derived designated requirement. CI explicitly uses an ad-hoc test host; do not grant that host permissions or launch it for acceptance. Run installs one interactive build at `/Applications/Quill.app` and refuses to terminate a running app, preserving normal draft-flush behavior.

The previous interactive build was ad-hoc signed with a requirement containing its individual cdhash. Its permission entry can appear enabled while macOS refuses access to a different build. Remove that stale Quill entry and add the signed interactive app once through System Settings. Rebuild acceptance must then confirm that both grants survive without reauthorizing.

Both setup buttons request the corresponding system permission and open its settings pane. On this macOS 27 host, the Accessibility pane is called Device Control and Data Access; the Input Monitoring route retains its specific list. Refresh is explicit, and returning to Quill refreshes automatically. No launch or enable operation requests permission.

## Completed observations

- Older user session was quit normally after saving its Timestamp and New macro drafts; no process was forcibly terminated.
- Acceptance uses `/tmp/Quill-Expansion-Acceptance/library.sqlite`, separate from the user library.
- The signed interactive Debug build's designated requirement matches the published 0.1.1 app's requirement.
- Native app chooser selected TextEdit; Selected Applications scope contains only TextEdit.
- Immediate matching appears as the default; delimiter matching is an explicit alternative.
- Custom macro QA Reply was created and saved through the editor with a local name field and `{{ticket.id}}`.
- Typing `{{ma` opened AppKit completion; keyboard selection inserted `{{macro:QA Reply}}` into a new snippet.
- Filling the preview produced `Hello Casey. Ticket {{ticket.id}}.`; Copy Preview followed by ordinary Paste into a newly created TextEdit document produced that exact text.
- A second source edit/save created another revision. History displayed the content difference; confirmation and Restore produced the previous content as a new save.
- Both Setup buttons visibly opened the correct System Settings permission list.
- Earlier expansion repair gate passed 80 tests and an arm64/x86_64 universal Release build (`/tmp/quill-permission-gate.log`). Signed interactive build and installed copy passed strict nested signature verification.
- Automated matching coverage includes Unicode, immediate matching, incomplete abbreviations, overlapping-prefix disambiguation, delimiter mode, collisions, case/boundaries and app exclusions.

- Markdown native preview and Copy Formatted were verified visually; ordinary TextEdit Paste retained bold and list layout while preserving `{{ticket.id}}`.
- An unsaved Markdown edit survived normal Quit and real relaunch; Review showed the exact change, Recover returned it to the unsaved editor, and Revert restored the saved source.
- Back Up Now created a complete backup. Restore opened a definition review and confirmation; the transaction preserved the previous file and all seven saved snippets remained available afterward.
- A documented two-row TextExpander CSV was chosen through the native panel, reviewed and imported. The imported group and both snippets appeared; converted single-line and multiline fields accepted literal answers, and required validation enabled copying only after completion.
- A typed form combined native choice and date controls, an optional field, a conditional greeting and a cursor marker. Choosing Formal, confirming Today and entering Casey resolved the expected branch; leaving the optional field empty did not block copying.

## Required before release

- Completed: grant the signed Quill identity Accessibility and Input Monitoring; refresh and explicitly enable for TextEdit.
- Type `;now` in TextEdit: verify replacement on the final character, with no Space required. Test rapid continued typing and one-step target Undo.
- Type `;sig`: verify native fill-in form, required-empty validation, insertion back into the original document, and Cancel preserving the abbreviation.
- Test multiline, choice, optional, date and conditional fields, nested macro/snippet references and Zendesk literal tokens through the same external transaction.
- Verify cursor placement, case/boundary rules, delimiter alternative, excluded apps, Pause, relaunch/permission continuity and focus drift cancellation.
- Verify Markdown copying and visible-text expansion, imported template insertion, backups/reviewed restore and draft recovery through the native workflow.
- Test composition commit separately; the engine never expands on intermediate IME candidate keystrokes.
- Run the final automated gate, then Developer ID archive, notarization/stapling, signed updater verification, publish and download verification.

Both permissions are confirmed. Physical typing, external transaction and distribution acceptance remain runtime dependencies; the observations above do not claim automatic expansion or release acceptance.


## Duration and background lifecycle — 2 October 2026

- The user manually granted Accessibility and Input Monitoring to `/Applications/Quill.app`. Input Monitoring required the native + button; setup now explains that path.
- Rebuilt and reinstalled through `script/build_and_run.sh`; both permissions still report Granted against the changed signed binary.
- Choosing Across Launches alone stays paused. Explicit Enable, normal Quit, and relaunch of the isolated library resumed expansion. Timed mode displayed the scheduled stop time.
- Hiding the Dock icon prevented disabling the menu bar entry. Closing the library left PID 81273 running; reopening showed the same fixture and preferences.
- Native Launch at login registration reported enabled, then unregistration reported off; restored original setting. Removed the incorrect development-location warning for an unregistered service.
- The 81-test gate passed with universal Release. The final menu-routing and login-status changes also passed the 81-test universal gate (`/tmp/quill-background-final-gate.log`).
- Directed CUA key presses typed `;now` in TextEdit but produced no expansion or callback status change. A physical typing check was requested; this is not recorded as a successful automatic expansion test. Menu bar click-through, timer expiry, external fill-in insertion, and final distribution acceptance remain outstanding.

- Installed Copy Formatted was retested after removing serialized foreground/background colors. Ordinary TextEdit Paste retained bold, lists and Zendesk tokens, with native automatic text color rather than a hardcoded white clipboard color.


## Native status-menu correction

User reported that clicking the status item again or clicking outside did not dismiss the SwiftUI extra. Replaced that scene with one `NSStatusItem` attached to an `NSMenu`; AppKit owns tracking and dismissal, without custom outside-click monitors or popover windows. Library and Quick Actions reopen through the shared SwiftUI window action. Menu items refresh permission/state on opening; Observation updates visibility and icon state while library windows are closed. Duration choices use native checked submenu items. Generation-scoped observation prevents old workspace configurations from subscribing repeatedly.

`/tmp/quill-native-menu-install.log` built, strictly verified and installed the corrected signed app. `/tmp/quill-native-menu-gate.log` passed 81 tests and universal Release. Both permissions still show Granted. Physical click-again/outside/Escape acceptance remains pending. The isolated library is active, TextEdit is the only selected app, Until Quill Quits is enabled, and `/tmp/Quill-Expansion-Acceptance/Quill Expansion Test.txt` is open and blank for physical `;now` and `;sig` acceptance. No new release has been cut.


## Fill-in transaction and Markdown cursor repair

The fill-in panel now retains the hosted form and answers while returning focus to the captured target. Successful insertion closes it; a rejected transaction restores the same panel with its error and literal answers. Transaction IDs invalidate an outstanding submit when expansion is paused or policy changes. Cancel keeps the abbreviation. External keyboard/form acceptance remains pending.

`RenderResult.plainTextResult()` is the single visible-text projection shared by expansion and cursor preview. Foundation Markdown source positions survive Quill's token/literal masking through an original-source boundary map; semantic run alignment maps removed syntax, decoded entities, indentation and generated list prefixes. The regression test covers plain/Markdown cursor boundaries, Unicode/decoded emoji, lists, links, code, escapes, HTML literals, escaped URLs and multiple Zendesk tokens. `/tmp/quill-cursor-boundaries-gate.log` passed 82 tests and universal Release.

Directed typing was retried after launching TextEdit in the foreground through the normal app opener. The named test document still received literal `;now`; it was cleared and saved afterward. This does not prove hardware-keyboard expansion. The acceptance fixture, selected TextEdit-only scope and both grants were rechecked.

`/tmp/quill-final-interactive-gate.log` passed 82 tests and universal Release after the final status-accessibility change. `/tmp/quill-cursor-transaction-install.log` built and installed the signed repair; the installed bundle passed strict nested verification with the same Developer ID designated requirement. Both grants still report Granted. Native preview of `**Reply**{{cursor}}` reports Cursor after 5 characters; the temporary edit was reverted. The status accessibility parent now changes with the visible status instead of retaining its old Paused label.

A real 15-minute session was enabled in the isolated fixture at approximately 15:58 Sydney time, with a displayed 16:13 stop time and PID 98450 confirmed running at 05:59:06 UTC. Expiry observation is pending; no shortened timer or permission override was used.

Typing-trigger and mixed-format fixes: `/tmp/quill-nested-cursor-gate.log` passed 84 tests and universal Release. Navigation/deletion/function/source-toggle keys cannot trigger immediate matching; delimiter commits include keypad Enter. Nested Markdown blocks now use the same complete-document cursor projection when inserted into plain templates. Native external typing acceptance remains separate.


## Observed timer expiry with the library closed

At 06:09:21 UTC, the native library window was closed and PID 98450 remained running. At 06:14:16 UTC, after the displayed 16:13 Sydney deadline, the same PID was still running. Reopening the library and Expansion settings showed **Timer ended. Expansion is paused.**, an Enable Expansion button, no active deadline, and both grants still Granted. This exercised the actual 15-minute task without altering its clock or interval.

The next distribution candidate is 0.1.2 (build 3). Local signing/notarization can be prepared while external typing acceptance is pending; publication remains gated on that acceptance.


## Notarized 0.1.2 candidate and observed replacement

`/tmp/quill-0.1.2-candidate-gate.log` passed 84 tests and universal Release. Commit/tag `eab9e6a07cce8eeb3b76397e7fbc206481d64983` / `v0.1.2` produced the private candidate at `/Users/nftdannyboy/Library/Developer/Quill-0.1.2-release-20261002`. `/tmp/quill-0.1.2-release.log` completed the universal archive, Developer ID export, accepted app/DMG notarization, stapling, Gatekeeper checks, Sparkle ZIP/feed/notes signatures, expanded ZIP/mounted DMG comparison, checksums and exact-source manifest. The remote tag and GitHub release have not been published.

The notarized candidate was installed atomically at `/Applications/Quill.app` after normal Quit. Installed metadata reports 0.1.2 (3), strict signature and stapled ticket validation passed, and native Settings still shows both grants Granted. The acceptance fixture is active, TextEdit remains the only selected app, and Until Quill Quits / Immediately were explicitly enabled.

Before that install, Quill reported **Expanded Timestamp.** and the named TextEdit test document contained `2026-10-02 at 16:25 `, proving an external replacement succeeded. A local screenshot was preserved at `/tmp/Quill-Expansion-Acceptance/timestamp-expanded.png`, and the document was preserved. Attribution to physical vs directed input and expansion before vs after Space were not established by that observation. The next user check asks for immediate `;now`, the `;sig` expansion form, and native status-menu dismissal against the notarized candidate. Required transaction/focus/Undo/composition acceptance and publication are still pending.

The user initially reported failed status-menu dismissal, then rechecked and explicitly confirmed it works. No menu code changed between those reports. The user subsequently reported “all is good” and instructed publication of the installed candidate. This is user runtime acceptance; it does not change the recorded limits of directed automation. A directed TextEdit `;sig` attempt had left the literal abbreviation while Settings reported enabled / Immediately / TextEdit selected and both permissions Granted. That automation attempt did not independently prove an external fill-in transaction, Undo or input-method behavior.

## Published 0.1.2 — 2026-10-02

[Quill 0.1.2](https://github.com/dbuskariol/Quill/releases/tag/v0.1.2) is public, non-prerelease and latest. The annotated tag resolves to `eab9e6a07cce8eeb3b76397e7fbc206481d64983`, matching the notarized manifest. All six assets were downloaded anonymously from the public latest URLs to `/Users/nftdannyboy/Library/Developer/Quill-0.1.2-public-verification-20261002`. Checksums passed and each file exactly matched the verified local release. `/tmp/quill-0.1.2-public-sparkle-verification.log` passed feed/archive/notes signatures, expanded ZIP comparison, nested Developer ID signatures and notarized Gatekeeper assessment. Actual Sparkle installation and its failure/rollback behavior were not exercised by this artifact check.

## External fill-in panel observed after publication

The signed 0.1.2 app reopened the isolated acceptance library and retained both grants. Until Quill Quits / Immediately / TextEdit-only scope was explicitly enabled. A real external trigger opened **Expand Email signature** while TextEdit contained `;sig `. The required empty name disabled Expand. Entering Casey enabled Expand and updated the native preview. Submission returned **Focus or target text changed. Expansion cancelled.**; the same form retained Casey, and no signature was inserted. Cancel subsequently closed the panel; Quill reported that the abbreviation was kept, and a refreshed TextEdit observation confirmed `;sig ` was intact.

This proves required validation, answer retention on a rejected transaction, and cancellation without destructive replacement. It does not prove a successful insertion or Undo. The available directed keyboard controls have not produced a repeatable global expansion trigger, and the user is now away. No confirmed product defect has been established from the rejected transaction: the captured target and current focus/text did not pass validation. The published 0.1.2 assets have not been replaced.

## 0.1.3 compact fill-in repair in progress

The user reported that `;notes` raised Quill and rejected insertion. Native inspection of installed 0.1.2 reproduced the visible failure: **Expand Meeting notes**, topic `aaa`, the generic focus/target-change error, and literal `;notes ` remaining in the dedicated TextEdit test document. The old centered form activated Quill; returning focus used a blind 80 ms delay.

The repair uses a 320-point-wide nonactivating utility panel anchored to AX caret bounds, with first-field focus, no library activation, no large preview, native cancellation, and bounded focus validation before insertion. Three regressions cover off-screen/multi-display placement, AX coordinate conversion and the starter notes date/topic/UTF-16 cursor. `/tmp/quill-0.1.3-final-gate.log` passed 87 tests and universal Release at version 0.1.3/build 4. The first signed interactive panel prototype was installed at `/Applications/Quill.app`; both grants still report Granted. TextEdit-only expansion was enabled and the library window closed, leaving the same process running. Live compact-panel positioning, keyboard input, notes insertion/cursor and Undo remain pending, including final Command-Return changes. No 0.1.3 release has been published.

The zero-width-caret display correction passed `/tmp/quill-0.1.3-display-gate.log` with 87 tests and universal Release. Candidate tag `v0.1.3` resolves locally to `a826819cc9617a9dadcb5475fc3e1442f3e8ed12`; the tag remains unpublished. The initial archive was stopped before finalization when the display issue was found. The replacement private candidate at `/Users/nftdannyboy/Library/Developer/Quill-0.1.3-release-20261002-caret` passed the full pipeline in `/tmp/quill-0.1.3-caret-release.log`, including app and DMG notarization/stapling, nested signatures, Gatekeeper, Sparkle signatures and source-exact manifest. It was installed atomically at `/Applications/Quill.app` after normal Quit. Both grants remain Granted; TextEdit-only / Immediately / Until Quill Quits was enabled, and the library closed while PID 80798 remained running. Live panel/input/insertion/cursor/Undo acceptance remains pending, and no GitHub release has been created.

GitHub [run 36984068947](https://github.com/dbuskariol/Quill/actions/runs/36984068947) completed successfully for the exact candidate source `a826819`, with both macos-26 and macos-26-intel jobs passing. Native reinspection found no newly opened panel or notes insertion; the old literal abbreviation remains in the dedicated test document. The library was closed again for the pending physical trigger. Automated and distribution gates are complete; native anchored-panel/Return/insertion/cursor acceptance is not yet established.


## User-confirmed notes insertion and initial-focus follow-up

The user confirmed the installed 0.1.3 caret candidate successfully expanded Meeting notes. Native inspection of the owned TextEdit test document showed `Meeting · 2026-10-02`, `Topic: test`, Notes and Next steps. The user reported that the field did not initially receive focus and supplied a screenshot of the oversized form with a clipped-looking focus ring.

The shared focus bridge now waits for its hosting window to become key, then requests SwiftUI focus on the next main run-loop turn. Quick Actions search uses the same presentation lifecycle. Fields use standard automatic macOS text-field styling; inset content protects the native focus ring from the scroll viewport. The panel is 280 points wide, with a short single-field content height under 90 points; longer forms remain bounded and scrollable. Native presentation tests create the real nonactivating panel without a click and verify an editable field editor for single-line input plus keyboard-responder readiness for optional, multiline, choice and date input. `/tmp/quill-0.1.3-native-input-gate.log` passed 88 tests across 13 suites and universal Release. Physical focus acceptance of this final refinement, external Undo and broader editor/input-method coverage are separate from those tests.


## Published 0.1.3 — 2026-10-02

[Quill 0.1.3](https://github.com/dbuskariol/Quill/releases/tag/v0.1.3) is public, non-prerelease and latest. The annotated tag resolves to `3a330c767b018112a3b49d32b39e5489a039b08b`, matching the source-exact notarized manifest. GitHub [run 36988994367](https://github.com/dbuskariol/Quill/actions/runs/36988994367) passed on both macos-26 and macos-26-intel. The replacement pipeline passed `/tmp/quill-0.1.3-focus-release.log`; the exact notarized app is installed at `/Applications/Quill.app`, with both grants retained and TextEdit-only / Immediately / Until Quill Quits enabled while the library is closed. Native Quick Actions inspection confirmed its search field focused on presentation and accepted typing without a click; the shared fill-in control showed a complete native focus ring.

All six published assets were fetched anonymously through fresh latest-download requests into `/Users/nftdannyboy/Library/Developer/Quill-0.1.3-public-verification-20261002-published`. Each hash matches the approved local candidate; checksums, release provenance, feed/archive/notes Sparkle signatures, expanded ZIP comparison, nested signatures and notarized Gatekeeper assessment passed `/tmp/quill-0.1.3-public-published-verification.log`. The initial cached latest redirects still referenced 0.1.2, so fresh requests used a release-specific query parameter. Actual updater installation/rollback, physical input focus in the final external panel, Undo and broader editor/input-method coverage remain separate acceptance work.
