# Custom macros and Zendesk placeholders

**Custom Macros** in the sidebar or **Library → Custom Macros…** opens the reusable-block editor. Give a block a unique name, add template text and save. **Insert Macro → Custom Macros** inserts `{{macro:NAME}}` into a snippet. Blocks may contain dates, literal text, fill-ins, nested snippets, other custom macros and Zendesk placeholders. Preview resolves blocks and collects shared field controls. Missing names, reference cycles, repeated cursor markers and invalid fields fail clearly; expansion does not run scripts. Renaming a saved macro updates its saved references in the same atomic library write; other drafts must be saved or reverted first. Deleting warns about references and supports library undo. Unsaved macro drafts survive navigation and receive durable recovery checkpoints, with explicit review on restart and storage/import guards. JSON export includes saved macros; complete library backups also include versions and draft recovery. Each macro has native History, format selection and Markdown preview/copy. JSON interchange uses the single current schema v3; every macro has an explicit format. Older Quill schemas are rejected.

**Insert Macro → Zendesk Placeholder…** opens a dedicated picker. Common requester, ticket, organization and current-agent values have descriptive names. Custom mode accepts ticket fields (`ticket.ticket_field_ID`), user fields (`ticket.requester.custom_fields.KEY`), dynamic content (`dc.ITEM_NAME`) and other syntactically valid supported namespaces. Paste existing Zendesk placeholders directly into templates too.

Quill copies Zendesk tokens verbatim rather than inventing ticket values. The preview explains that Zendesk processes them in the comment’s ticket context. Backslash-escaped placeholders also retain the backslash. These placeholders are distinct from Quill’s local fill-in values, which are collected in Preview before copying. Availability and behavior depend on the Zendesk account and comment context; the picker validates syntax, not remote account field existence. Liquid filters on supported placeholder namespaces are preserved for Zendesk, without local evaluation. Liquid tag text remains literal; arbitrary output variables outside the supported namespaces need explicit literal encoding.

Research checked 2 October 2026: [Zendesk placeholder reference](https://support.zendesk.com/hc/en-us/articles/4408886858138-Placeholder-reference-for-business-rules), [Using placeholders](https://support.zendesk.com/hc/en-us/articles/4408887218330-Using-placeholders), and [Creating macros and placeholder behavior](https://support.zendesk.com/hc/en-us/articles/4408844187034-Creating-macros-for-repetitive-ticket-responses-and-actions). The user clarified that “Zendesk macros” means message substitutions, not a Zendesk account connection or ticket-action importer. No credentials or ticket data are needed for this feature.

Tests cover strict current-schema decoding, persistence, shared fields, literal Zendesk tokens/custom fields/dynamic content/escapes, missing macros, cycles, duplicate names and unsaved-draft protection. An actual Zendesk ticket submission is outside local verification and has not been performed.

[Zendesk’s Liquid filter guide](https://support.zendesk.com/hc/en-us/articles/4408836545562-How-can-I-format-placeholders-with-liquid-markup) informed preservation of expressions such as `{{ ticket.ticket_field_123 | split:"::" | last }}`. Quill preserves expression whitespace, filters and escapes; it does not claim to validate Zendesk’s full Liquid grammar.


## Local template syntax

The same syntax works in snippets and reusable blocks. Insert tokens through the editor's Insert menu or native `{{` completion.

| Purpose | Syntax | Behavior |
| --- | --- | --- |
| Date / time | `{{date}}`, `{{time}}` | Current date as yyyy-MM-dd and time as HH:mm |
| Custom date | `{{date:yyyy-MM-dd|7}}` | ICU format with a Gregorian calendar day offset; current time zone |
| Named field | `{{field:name}}` or `{{input:name|single}}` | Required single-line literal answer |
| Multiline field | `{{input:notes|multiline}}` | Required literal answer with line breaks |
| Optional field | `{{input:note|optional}}` | Empty answers are allowed |
| Choice | `{{input:tone|choice|Formal|Friendly}}` | Required selection from the listed values |
| Date field | `{{input:due|date|yyyy-MM-dd}}` | Native date control; confirm today's date explicitly if desired |
| Conditional | `{{if:tone=Formal}}Hello{{else}}Hi{{end}}` | Exact, case-sensitive field comparison; only the selected branch resolves |
| Reusable block | `{{macro:Signature}}` | Resolve a unique saved macro name |
| Nested snippet | `{{snippet:;sig}}` | Resolve a unique saved abbreviation |
| Cursor | `{{cursor}}` | Place the cursor here after expansion; only one marker in the resolved reply |
| Arithmetic | `{{math:(2+3)*4}}` | Bounded numeric arithmetic; no script execution |

Shared field names produce one control; incompatible definitions fail with an explanation. Answers remain literal and never execute as Quill tokens. Markdown source displays a formatted preview, while ordinary Accessibility expansion inserts visible text. Cursor diagnostics use the same visible-text projection, including mixed-format reusable blocks and nested snippets. Copying does not move the target editor's cursor.

Expansion fill-ins keep the original abbreviation until Expand succeeds. Cancel preserves it. If the original target changes or rejects insertion, the form returns with its answers and the error for review. A paused session or changed application policy invalidates that pending transaction. External transaction acceptance is tracked in [expansion acceptance](EXPANSION_ACCEPTANCE.md).
