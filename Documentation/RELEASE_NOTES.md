# Quill 0.1.0

The first Quill release brings a native macOS snippet workspace with reusable template blocks and replies prepared for Zendesk.

- Organize, search and favorite snippets in a native library.
- Edit reusable custom macros with inline completion from `{{`.
- Insert Zendesk message placeholders without changing their contents.
- Import supported TextExpander CSV and `.textexpander` exports through a reviewed conversion.
- Preview Plain Text and Markdown templates, fill native input controls, and copy formatted replies.
- Compare and restore saved versions, recover deleted templates and review recovered drafts.
- Keep the complete library locally in SQLite, with portable backups and reviewed restore.
- Manage Settings inside the workspace, with menu-bar access and keyboard commands.

## Install

Requires macOS 26 or later. The universal app supports Apple silicon and Intel Macs. Open the disk image and drag Quill into Applications before launching it.

## Current limitations

Quill is an early release. Automatic abbreviation expansion is limited to plain-text templates without fill-ins in explicitly allowed, supported Accessibility editors. Permission-enabled expansion and Zendesk rich-editor paste behavior still need broader acceptance. Zendesk resolves its placeholders; Quill does not connect to a Zendesk account. Full WYSIWYG editing, cloud sync and shared team libraries are not included.

Back up an existing library before replacing a development build. Quill supports one current schema and does not migrate older development JSON libraries automatically. Automatic update checks are off by default; manual checks use the signed Quill feed.
