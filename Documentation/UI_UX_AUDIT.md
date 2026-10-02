# Native UI/UX audit · Quill 0.1.5 (6)

The audit combined source review with Computer Use against the signed app installed in Applications. Editing, imports, recovery and screenshots used separate disposable SQLite libraries. The personal library was not edited. Reccy was inspected as a read-only reference for embedded Settings and native navigation.

## Changes

Snippet and custom-macro editors share one source section and insertion catalog. Native source/preview height follows content within bounded scrolling regions. Text measurement uses an independent offscreen text system: measuring the live container caused an AppKit constraint-update exception during search-result switching. Real hosted-window regression tests now exercise repeated width/content changes.

New snippets and macros focus their name immediately, without stealing focus when selecting existing content. Macro metadata, toolbar access, padding and persistent footer match the snippet editor. Group, placeholder, history, draft and backup review sheets have compact dimensions and consistent action placement. Application lists size to their contents. Settings separates template retention from full-library backups, keeps its category row accessible at smaller widths, and uses the same restart option wording throughout.

File pickers attach asynchronously to their requesting window or review sheet. Custom Zendesk placeholders submit with Return. Statistics reset confirmation is owned by the Settings container; attaching it to a Form section prevented the alert from appearing. JSON replacement review now includes macros in its counts.

## Observed native coverage

| Page or component | Computer Use checks |
| --- | --- |
| Snippet workspace, Favorites and groups | Navigation, search, new-name focus, save/revert, native insertion menus, short/long source scrolling, plain/Markdown/error previews and copy validation |
| Custom Macros | Matching metadata/source layout, new-name focus, save/revert, reusable preview, deletion confirmation and restored selection |
| Completion and Zendesk picker | Partial `{{ma` suggestions, keyboard acceptance, canonical token insertion; predefined/custom picker, focused input and Return insertion/dismissal |
| Preview inputs | Required single-line, multiline, choice, optional and date controls; explicit today selection, resolved output and enabled copy only after required answers |
| Quick Actions | Initial search focus, all four result types, typed favorite/tag/group filters, empty results, fill-in focus, Return copy, Command-Return open and Escape dismissal; repeated result switching after the layout fix |
| Groups | Add with focused name, rename, delete/reassign confirmation, compact list and Done dismissal |
| History and Deleted Templates | Changes/saved-content tabs, keep a revision, restore as a new save, disabled restore for current content, deleted recovery and empty history |
| Draft recovery | Edit, normal Quit/relaunch, recovery banner, comparison, discard confirmation cancellation and recovery into the editor |
| TextExpander import | Native file chooser attached to review, converted content/warnings, unsupported item exclusion, conflict counts, commit into the disposable library and cancellation |
| Backup review | Native file chooser, snippet/macro/group counts, reviewed full restore, preservation status and undo of the restore |
| Setup | All three pages, existing granted permission status, application chooser cancellation, explicit enable/resume option and completion |
| Settings: General | Setup reopening, menu/Dock/window-close and login controls inspected |
| Settings: Library | Separate history/backups, retention, backup creation/refresh/review, JSON import confirmation and native file panels |
| Settings: Expansion | Granted permissions, enabled/paused state, duration, immediate matching, named selections/exclusions and compact app lists |
| Settings: Privacy | Consistent restart wording and local data/update boundaries |
| Settings: Statistics | Native export panel/cancel; reset opens the correct confirmation and Cancel preserves totals |
| Settings: Updates | Version/build display, manual signed-feed check and native newer-than-public-build message dismissal |
| Window/layout | Dark appearance at normal size and native left tiling at approximately 941-point width; all six Settings destinations remain reachable; restored original size |

The README images are actual native captures from a separate anonymous demonstration library. No permission grants, OS appearance changes or login registration changes were made in this audit.

## Verification and limits

The local gate passes 96 Swift Testing tests across 15 suites, including the two native text-layout regressions, and builds universal Release for arm64/x86_64. Final distribution and public-asset evidence is recorded separately in VERIFICATION.md.

Directed Computer Use typing into TextEdit did not trigger external expansion in this session, so it does not independently establish physical-keyboard insertion, external Undo or IME acceptance. The engine was unchanged; earlier user-confirmed notes insertion and native nonactivating-panel focus tests remain separate evidence. The menu bar surface was unavailable to this automation session; its unchanged native NSMenu and earlier user-confirmed dismissal were reviewed, but dismissal was not reverified by Computer Use here.

Light appearance, extreme minimum height, spoken VoiceOver, increased contrast, actual Zendesk channel paste, broad editor coverage and a real Sparkle update installation/rollback were not established. The audit is coverage of observed flows, not a claim of perfect or universal acceptance.
