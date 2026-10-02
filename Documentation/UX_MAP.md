# Workspace and editing flow

Quill has three destinations in one window: snippets, reusable custom macros, and Settings. Sidebar selection is the source of truth. Moving between destinations preserves in-memory drafts and the selected snippet/macro. Cmd-comma opens the same embedded Settings surface; it does not create a second preferences window.

| Location | Purpose | Why it belongs here |
| --- | --- | --- |
| All Snippets, Favorites and Groups | Find and edit saved replies | Native source-list filtering, a searchable list and one detail editor keep content together |
| Custom Macros | Create named reusable template blocks | These are library content, so they use the same sidebar → list → editor flow, rather than an unrelated management sheet |
| Template editor | Compose text and insert tokens | Native completion appears at the caret after `{{`; the same catalog and Insert menu work in both editors |
| Preview | Fill local fields and check/copy the resolved reply | Context belongs beside the text being prepared. Zendesk placeholders remain intact and carry an explanation here |
| Persistent editor footer | Save or revert the current draft | The actions stay available when metadata, template or preview scrolls |
| Quick Actions (Cmd-K) | Find a saved reply and prepare a copy quickly | This is a short, dismissible task; it can also open the selected snippet in the workspace |
| Groups header action | Manage group names and membership | The action is beside the collection it changes, with confirmation and library undo |
| Library menu → Import from TextExpander | Review an incoming migration | The dedicated review sheet shows conversion, warnings and conflicts before an additive commit |
| Settings → Library | Storage location, JSON replacement/export and history/recovery | These affect the whole saved library. Destructive replacement and recovery have explicit review/confirmation, and refuse outstanding drafts |
| Settings → General | Dock/menu/window behavior and launch at login | App behavior preferences, separate from authoring content |
| Settings → Expansion | Permission setup, allowed apps and session policy | External expansion requires a distinct, explicit consent flow |
| Settings → Privacy / Statistics / Updates | Data boundaries, optional aggregate counts and updater behavior | These are app-wide policies and status, not editor controls |

## Completion interaction

Type `{{` to discover the catalog; continue with partial words such as `ma`, `sni`, `date`, `ticket.re`, or `current_user`. `macro:` narrows to saved reusable blocks; `snippet:` narrows to saved, unambiguous abbreviations. Typing `macro.` or `snippet.` is accepted as a discovery alias and the chosen completion inserts canonical colon syntax. The renderer continues to use `{{macro:NAME}}` and `{{snippet:ABBREVIATION}}`.

The AppKit text system owns the completion panel and keyboard behavior. Completion uses UTF-16 caret ranges, remains local, suppresses IME composition and filters out direct self-references and ambiguous snippet references. Existing closing braces are reused. Escape dismisses the panel; ordinary prose, custom field names and Zendesk filters remain editable. Unsupported/custom Zendesk placeholders can still be entered directly or with the Zendesk picker. Suggested placeholders are the common catalog, not a connection to an account's field schema.

Drafts are not written automatically to the saved library. Native text undo and Save/Revert are distinct from Option-Cmd-Z, which undoes the last saved whole-library operation only when drafts are clear. Search and navigation never discard drafts. Quitting asks before discarding them. Full per-window navigation state and durable recovery of unsaved drafts remain future work.

## Boundaries

Sheets remain for short review or parameter-entry tasks: import, group management, Zendesk custom placeholders and Quick Actions. Primary authoring and preferences stay in the workspace. There is no account setup, Zendesk API connection, script editor or decorative category heading mixed into these flows.

The completion bridge follows Apple's [NSTextView completion contract](https://developer.apple.com/documentation/appkit/nstextview/rangeforusercompletion). The macOS source list, split views, search, toolbar, menus, forms, native text system and semantic colors provide the design language; no custom web-style suggestion panel or glass overlay is needed.
