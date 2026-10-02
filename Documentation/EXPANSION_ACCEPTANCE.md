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
