# Quill 0.1.2

Control expansion sessions from a native menu bar, with clearer permission setup and reusable template fill-ins.

- Expand abbreviations immediately, or choose expansion after Space, Tab or Return. Prefix overlaps wait for the longer abbreviation or an explicit delimiter.
- Complete single-line, multiline, choice, optional and date fields in a native expansion form. The form retains answers when the original editor rejects insertion or its focus changes.
- Choose Until Quill Quits, 15 Minutes, 1 Hour or Across Launches. Across Launches resumes after explicit enablement; Pause disarms resumption.
- Keep Quill running when its library closes, hide its Dock icon while retaining menu bar access, and launch at login.
- Open the library, Quick Actions and Settings, change session duration, pause expansion or quit from a native status menu.
- Set up Accessibility and Input Monitoring with specific settings routes and guidance for manually adding Quill when needed. Interactive builds use the release signing identity at `/Applications/Quill.app`.
- Preserve cursor placement when Markdown becomes visible text, including mixed-format reusable blocks, nested snippets, lists, Unicode and Zendesk placeholders.
- Exclude navigation, deletion and function keys from expansion matching.
- Copy formatted replies with destination-native text colors. The README includes a native screenshot gallery and installation instructions.

## Install or update

Requires macOS 26 or later. The universal app supports Apple silicon and Intel Macs. Open the disk image and drag Quill into Applications, or choose Check for Updates in Quill. Review the selected applications in Expansion settings, grant both permissions, and explicitly enable expansion.

## Content and privacy

Expansion inserts visible text into editors that expose writable Accessibility text selections. Quick Actions offers formatted Markdown copying. Zendesk resolves its own placeholders; Quill preserves them locally. Secure input and password fields stay excluded. The library keeps its current SQLite and JSON interchange schemas, with no legacy migration layer. Existing saved definitions, history and authored drafts remain in the current library.
