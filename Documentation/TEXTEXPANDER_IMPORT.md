# TextExpander migration

Choose **Library → Import from TextExpander…** or the same action in **Settings → Library**. Select one or more CSV or legacy `.textexpander` group files. Review original text beside the converted Quill template, select compatible snippets, then import. The import adds new groups; it does not replace the entire library. Conflicts are case-insensitive, even when Quill currently uses case-sensitive matching. Choose Skip conflicts or Replace existing. Repeated incoming abbreviations use the first selected row. Replacement preserves the existing Quill identifier, tags and favorite state. The prior library is backed up automatically and Undo Last Library Change reverses the import.

## Sources researched on 2 October 2026

- [TextExpander’s import/export guide](https://textexpander.com/learn/using/importing-and-exporting-snippet-groups): current web exports are CSV; required headers are `abbreviation` and `snippet`, with optional `label`. Multiline cells are quoted and quotes doubled. Web export requires edit/manage access to the group.
- [TextExpander’s special codes](https://textexpander.com/learn/using/snippets/advanced-snippet-elements/special-codes): percent escaping, cursor position, nested snippets, clipboard and key macros.
- [TextExpander’s advanced fill-in syntax](https://textexpander.com/learn/using/snippets/snippet-fill-ins/advanced-fill-in-syntax): text, multiline, popup, defaults and optional sections.
- [TextExpander’s date formats](https://textexpander.com/learn/using/snippets/advanced-snippet-elements/advanced-date-time): legacy percent date codes and Unicode date formats; localized month/day names follow system language in TextExpander.
- [Original public legacy exports by their author](https://github.com/ttscoff/Brett-s-TextExpander-Snippets/blob/master/iOSMarkdown.textexpander): direct inspection confirmed plist `groupInfo.groupName`, `snippetsTE2`, `abbreviation`, `label`, `plainText`, `snippetType` and `abbreviationMode`. This is an observed legacy format, not an assertion that every TextExpander settings/backup format is compatible. No third-party snippet content is bundled in Quill.

## Compatibility

CSV supports UTF-8 (with or without BOM) and BOM-marked UTF-16; XML/binary legacy group plists are read using Foundation. CSV preserves quoted line breaks, commas, doubled quotes and Unicode. Invalid quoting, inconsistent columns, missing/duplicate required headers, unknown plist structures and excessive size fail before writing. Limits: 100 files, 50 MB total, 10,000 snippets, one million UTF-16 units per snippet and 128 UTF-16 units per abbreviation.

Conversions: `%%`, `%|`, `%Snippet:abbreviation%`, named or unnamed `%filltext...%`, `%fillarea...%`, `%fillpopup...%`, `%date:ICU-format%`, and documented year/month/day/hour/minute/second/AM-PM codes. Nested references must have one unique target after selection/conflict handling. Cycles, unresolved references, incompatible field definitions and repeated cursor markers fail before writing. Foreign text containing Quill macro delimiters is encoded as literal text, so an imported `{{date}}` cannot accidentally become a Quill macro.

Defaults and fill-in dimensions produce explicit review warnings: values are entered/chosen in Quill, and native controls determine dimensions. Quill dates currently use English/POSIX localization; the importer warns rather than promising TextExpander language equivalence. Legacy rich-text snippets with a plain-text representation warn that formatting, links and images are lost.

Scripts and unknown legacy content types are excluded. Clipboard, keyboard/delay/selection macros, date arithmetic, optional/conditional sections and other unknown macros need manual conversion and are excluded. HTML is flagged for a plain-text export instead of silently stripping markup. CSV lacks reliable content-type metadata; review source before importing. No code, object archive or script is executed, no app permissions are requested, and no source file is modified. Group sharing, app restrictions, prefixes, delimiter rules, case-adaptation settings and usage history are not migrated. Quill’s consentful expansion policy applies.

## Evidence and remaining acceptance

Synthetic fixtures derived from the documented schemas exercise both CSV encodings, XML/binary legacy groups, Unicode/quoted multiline cells, malformed inputs, literal preservation, date/field/cursor conversion, blocked macros/scripts, duplicate handling, nested references/cycles, persisted additive import, history and undo. Actual user-owned exports have not yet been supplied; use the preview to identify additional vendor serialization variants before extending compatibility.
