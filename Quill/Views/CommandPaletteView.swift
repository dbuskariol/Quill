import SwiftUI

struct CommandPaletteView: View {
    let store: LibraryStore
    let expansion: ExpansionController?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selectedID: String?
    @State private var filter = CommandSearchFilter()
    @State private var history = CommandHistory()
    @State private var fields: [String: String] = [:]
    @State private var contextDate = Date.now
    @State private var focusFields = false
    @State private var results: [CommandCandidate] = []
    @State private var copyError: String?
    @State private var pendingSubmit: CommandSearchRequest?
    @State private var displayedRequest: CommandSearchRequest?
    @FocusState private var searchFocused: Bool
    private var actions: [CommandCandidate] {
        var values = [
            CommandCandidate(id: "action.newSnippet", kind: .action, title: "New Snippet", subtitle: "Create a reusable reply"),
            CommandCandidate(id: "action.newMacro", kind: .action, title: "New Custom Macro", subtitle: "Create a reusable template block"),
            CommandCandidate(id: "action.import", kind: .action, title: "Import from TextExpander", subtitle: "Review an export before importing"),
            CommandCandidate(id: "action.settings", kind: .action, title: "Settings", subtitle: "Configure Quill"),
            CommandCandidate(id: "action.setup", kind: .action, title: "Set Up Quill", subtitle: "Permissions and expansion preferences")
        ]
        if let expansion {
            values.append(CommandCandidate(id: "action.expansion", kind: .action, title: expansion.isEnabled ? "Pause Expansion" : "Enable Expansion", subtitle: "Control expansion in other apps"))
        }
        if store.quickActions.lastCopiedText != nil {
            values.append(CommandCandidate(id: "action.repeat", kind: .action, title: "Repeat Last Copy", subtitle: "Copy the last resolved reply"))
        }
        return values
    }
    private var searchRequest: CommandSearchRequest {
        CommandSearchRequest(candidates: CommandSearch.candidates(library: store.library, actions: actions), query: query, filter: filter, recent: history.recent)
    }
    private var resultsAreCurrent: Bool { displayedRequest == searchRequest }
    private var selected: CommandCandidate? { results.first { $0.id == selectedID } }
    private var tags: [String] { Set(store.library.snippets.flatMap(\.tags)).sorted() }
    private var rendered: Result<RenderResult, Error>? {
        guard let selected, let id = UUID(uuidString: selected.id) else { return nil }
        return Result {
            let context = RenderContext(date: contextDate, fields: fields)
            if let saved = store.library.snippets.first(where: { $0.id == id }) {
                return try TemplateRenderer.render(saved, library: store.library, context: context)
            }
            if let macro = store.library.macros.first(where: { $0.id == id }) {
                return try TemplateRenderer.render(macro, library: store.library, context: context)
            }
            throw TemplateError.invalid("This template is no longer in your library.")
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search snippets, macros and actions", text: $query)
                    .textFieldStyle(.plain).font(.title3).focused($searchFocused)
                    .background(InputFocusOnPresentation(enabled: true) { searchFocused = true })
                    .onKeyPress(.downArrow) { moveSelection(1); return .handled }
                    .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless).accessibilityLabel("Close Quick Actions").keyboardShortcut(.cancelAction)
            }.padding(18)
            HStack {
                Picker("Result type", selection: $filter.kind) {
                    Text("All").tag(nil as CommandKind?)
                    ForEach(CommandKind.allCases) { Text($0.rawValue).tag(Optional($0)) }
                }.pickerStyle(.segmented).labelsHidden().accessibilityLabel("Result type").frame(width: 290)
                Menu {
                    Picker("Group", selection: $filter.groupID) {
                        Text("All Groups").tag(nil as UUID?)
                        ForEach(store.library.groups) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Picker("Tag", selection: $filter.tag) {
                        Text("All Tags").tag(nil as String?)
                        ForEach(tags, id: \.self) { Text($0).tag(Optional($0)) }
                    }
                    Toggle("Favorites Only", isOn: $filter.favoritesOnly)
                    Divider()
                    Button("Clear Filters") { filter = CommandSearchFilter(); query = CommandSearch.clearingFilters(in: query) }
                        .disabled(filter == CommandSearchFilter() && !CommandSearch.hasFilters(in: query))
                    Button("Clear Recent Items") { history.clear() }.disabled(history.recent.isEmpty)
                } label: { Label(filter == CommandSearchFilter() && !CommandSearch.hasFilters(in: query) ? "Filter" : "Filtered", systemImage: "line.3.horizontal.decrease") }
                .help("Filter by group, tag or favorite. Search also accepts tag:email, group:\"Work\" and is:favorite.")
                Spacer()
            }.padding(.horizontal, 18).padding(.bottom, 12)
            Divider()
            HSplitView {
                ScrollViewReader { proxy in
                    List(selection: $selectedID) {
                        ForEach(results) { item in
                            HStack(spacing: 10) {
                                Image(systemName: item.symbol).accessibilityHidden(true).foregroundStyle(.secondary).frame(width: 18)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title).lineLimit(1)
                                    HStack(spacing: 6) {
                                        Text(item.subtitle).lineLimit(1)
                                        if !item.group.isEmpty { Text("· \(item.group)").lineLimit(1) }
                                    }.font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                if item.favorite { Image(systemName: "star.fill").font(.caption).foregroundStyle(.secondary).accessibilityLabel("Favorite") }
                            }.tag(item.id).id(item.id).listRowSeparator(.hidden)
                        }
                    }.listStyle(.inset)
                    .overlay {
                        if !resultsAreCurrent { ProgressView().controlSize(.small).allowsHitTesting(false) }
                        else if results.isEmpty { ContentUnavailableView.search(text: query).allowsHitTesting(false) }
                    }
                    .onChange(of: selectedID) { _, id in if let id { proxy.scrollTo(id) } }
                }.frame(minWidth: 250, idealWidth: 290)
                ScrollView {
                    if let rendered {
                        PreviewView(result: rendered, fields: $fields, actions: store.quickActions, focusFieldsInitially: focusFields, showsCopyActions: false)
                            .id(selectedID)
                    } else if let selected {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(selected.title, systemImage: selected.symbol).font(.headline)
                            Text(selected.subtitle).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                    }
                }.frame(minWidth: 290)
            }.frame(height: 310)
            if let copyError { Text(copyError).font(.callout).foregroundStyle(.red).padding(.horizontal, 12) }
            Divider()
            HStack {
                Text(selected?.kind == .action ? "↑ ↓ Select  ·  ↵ Run" : "↑ ↓ Select  ·  ↵ \(primaryTitle)  ·  ⌘↵ Open")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if selected?.kind != .action, selected != nil {
                    Button("Open in Library", action: openSelected).keyboardShortcut(.return, modifiers: .command)
                }
                if let preview = try? rendered?.get(), preview.format == .markdown {
                    Menu("Copy As") {
                        Button("Plain Text") { copySelected(style: .plainText) }
                        Button("Markdown") { copySelected(style: .markdown) }
                    }.disabled(!preview.canSubmit(fields: fields))
                }
                Button(primaryTitle, action: execute)
                    .keyboardShortcut(.defaultAction).disabled(selected == nil || !resultsAreCurrent || (selected?.kind != .action && (try? rendered?.get()) == nil))
            }.controlSize(.small).padding(12)
        }.frame(width: 660)
        .task(id: searchRequest) {
            let request = searchRequest
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
            let task = Task.detached(priority: .userInitiated) {
                CommandSearch.results(request.candidates, query: request.query, filter: request.filter, recent: request.recent)
            }
            let matches = await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
            guard !Task.isCancelled else { return }
            if request.query != displayedRequest?.query || !matches.contains(where: { $0.id == selectedID }) {
                selectedID = matches.first?.id
            }
            results = matches
            displayedRequest = request
        }
        .onChange(of: selectedID) { _, _ in fields = [:]; contextDate = .now; focusFields = false; copyError = nil }
        .onChange(of: query) { _, value in if pendingSubmit?.query != value { pendingSubmit = nil } }
        .onChange(of: filter) { _, value in if pendingSubmit?.filter != value { pendingSubmit = nil } }
        .onChange(of: displayedRequest) { _, request in
            if pendingSubmit == request, request != nil { pendingSubmit = nil; execute() }
        }
        .onSubmit(execute)
    }
    private var primaryTitle: String {
        if selected?.kind == .action { return "Run" }
        if let preview = try? rendered?.get(), !preview.canSubmit(fields: fields) { return "Fill In" }
        return "Copy"
    }
    private func moveSelection(_ amount: Int) {
        guard !results.isEmpty else { return }
        let index = results.firstIndex { $0.id == selectedID } ?? (amount > 0 ? -1 : results.count)
        selectedID = results[min(max(index + amount, 0), results.count - 1)].id
    }
    private func execute() {
        guard resultsAreCurrent else { pendingSubmit = searchRequest; return }
        guard let selected else { return }
        if selected.kind != .action {
            copySelected()
            return
        }
        history.record(selected.id)
        if selected.id == "action.import" { store.paletteSheet = .textExpanderImport; dismiss(); return }
        if selected.id == "action.setup" { store.paletteSheet = .setup; dismiss(); return }
        dismiss()
        Task { @MainActor in
            await Task.yield()
            switch selected.id {
            case "action.newSnippet": await store.create()
            case "action.newMacro": store.createMacro()
            case "action.settings": store.destination = .settings
            case "action.repeat": store.quickActions.repeatLastCopy()
            case "action.expansion":
                if let expansion {
                    if expansion.isEnabled { expansion.pause() }
                    else {
                        expansion.enable()
                        if !expansion.isEnabled { store.requestedSettingsPage = .expansion; store.destination = .settings }
                    }
                }
            default: break
            }
        }
    }
    private func copySelected(style: QuickActionStore.CopyStyle = .formatted) {
        guard resultsAreCurrent, let selected, let rendered, let result = try? rendered.get() else { return }
        guard result.canSubmit(fields: fields) else { focusFields = true; return }
        if store.quickActions.copy(result, style: style) { history.record(selected.id); dismiss() }
        else { copyError = store.quickActions.message }
    }
    private func openSelected() {
        guard let selected, let id = UUID(uuidString: selected.id) else { return }
        history.record(selected.id)
        if selected.kind == .snippet { store.destination = .snippets; store.filter = "all"; store.search = ""; store.selectedID = id }
        else { store.destination = .macros; store.macroSearch = ""; store.selectedMacroID = id }
        dismiss()
    }
}
