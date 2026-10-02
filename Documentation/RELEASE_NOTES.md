# Quill 0.1.1

Clearer native application controls and cleaner defaults.

- Choose All Applications or Selected Applications for abbreviation expansion.
- Add apps through the macOS application chooser, with recognizable names and icons instead of bundle identifiers.
- Edit exclusions using native +/− controls, Delete, or the Remove Application context menu.
- Keep application rules consistent when moving an app between the selected and excluded lists.
- Pause expansion when the last selected app is removed. Password fields and secure input remain protected in every mode.
- Place the smaller Groups management button on the right of the sidebar header, with additional trailing padding.
- Use a name fill-in in the starter email signature. Existing saved templates are preserved.

## Install or update

Requires macOS 26 or later. The universal app supports Apple silicon and Intel Macs. Open the disk image and drag Quill into Applications, or choose Check for Updates in Quill.

## Current limitations

Expansion supports plain-text templates without fill-ins in supported Accessibility editors and starts paused at launch. Permission-enabled expansion and Zendesk rich-editor paste behavior still need broader acceptance. This release uses the current expansion-preferences format; preferences from 0.1.0 reset to Selected Applications with expansion paused. Existing library definitions, history and drafts use the same storage schema.
