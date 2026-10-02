import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TextExpanderImportView: View {
    @Bindable var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var plan: TextExpanderImportPlan?
    @State private var selected: Set<UUID> = []
    @State private var focused: UUID?
    @State private var policy = TextExpanderConflictPolicy.skip
    @State private var loading = false
    @State private var error: String?
    @State private var importing = false
    @State private var review: (imported: Int, skipped: Int)?
    @State private var reviewError: String?
    @State private var conflictAbbreviations: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Import from TextExpander").font(.title2.bold())
                Spacer()
                Button(plan == nil ? "Choose Files…" : "Choose Different Files…", action: chooseFiles).disabled(loading || importing)
            }
            if let error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red).textSelection(.enabled) }
            if loading { ProgressView("Reading exports…").frame(maxWidth: .infinity, maxHeight: .infinity) }
            else if let plan {
                HStack {
                    Text("\(plan.rows.count) snippets · \(selected.count) selected").foregroundStyle(.secondary)
                    Spacer()
                    Button("Select Compatible") { selected = Set(plan.rows.filter { $0.problem == nil && $0.converted != nil }.map(\.id)) }
                    Button("Deselect All") { selected = [] }
                    Picker("Conflicts", selection: $policy) { ForEach(TextExpanderConflictPolicy.allCases) { Text($0.rawValue).tag($0) } }.frame(width: 270)
                }
                HSplitView {
                    List(selection: $focused) {
                        ForEach(plan.rows) { row in
                            HStack(alignment: .top) {
                                Toggle("Import \(row.title)", isOn: Binding(get: { selected.contains(row.id) }, set: { value in
                                    if value { selected.insert(row.id) } else { selected.remove(row.id) }
                                })).labelsHidden().disabled(row.problem != nil || row.converted == nil)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(row.title).lineLimit(1)
                                    Text("\(row.groupName) · \(row.abbreviation.isEmpty ? "No abbreviation" : row.abbreviation)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    if row.problem != nil { Label("Needs conversion", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange) }
                                    else if isConflict(row) { Label("Abbreviation conflict", systemImage: "arrow.triangle.branch").font(.caption).foregroundStyle(.orange) }
                                    else if !row.warnings.isEmpty { Label("Review changes", systemImage: "info.circle").font(.caption).foregroundStyle(.secondary) }
                                }
                            }.tag(row.id)
                        }
                    }.frame(minWidth: 280, idealWidth: 320)
                    ScrollView {
                        if let row = plan.rows.first(where: { $0.id == focused }) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(row.title).font(.headline)
                                Text(row.sourceFile).font(.caption).foregroundStyle(.secondary)
                                if let problem = row.problem { Label(problem, systemImage: "exclamationmark.triangle").foregroundStyle(.orange).textSelection(.enabled) }
                                if isConflict(row) { Text(policy == .skip ? "This abbreviation will be skipped. Conflicts also include case variants and repeated abbreviations within these files." : "This replaces the matching saved snippet. Repeated abbreviations within the files use the first selected row.").foregroundStyle(.orange) }
                                ForEach(row.warnings, id: \.self) { Text($0).font(.callout).foregroundStyle(.secondary) }
                                Text("Original").font(.subheadline.bold())
                                Text(row.original).font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                if let converted = row.converted {
                                    Divider()
                                    Text("Quill template").font(.subheadline.bold())
                                    Text(converted).font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }.padding()
                        } else { ContentUnavailableView("Select a Snippet", systemImage: "text.quote") }
                    }.frame(minWidth: 360)
                }
                Text(plan.notices.joined(separator: " ")).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let reviewError { Label(reviewError, systemImage: "exclamationmark.triangle").foregroundStyle(.orange).textSelection(.enabled) }
                else if let review { Text("\(review.imported) snippets will be imported; \(review.skipped) conflicts skipped. Your saved library is backed up first.").font(.callout) }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export groups from TextExpander.com → Import/Export → Export, then choose the downloaded CSV files. Older .textexpander group files are also supported.")
                    Link("TextExpander export instructions", destination: URL(string: "https://textexpander.com/learn/using/importing-and-exporting-snippet-groups")!)
                    Text("Review snippets before importing. Common dates, cursor placement, nested snippets and fill-ins convert to Quill templates. Unsupported macros and scripts remain excluded; original files are never modified.").foregroundStyle(.secondary)
                }.frame(maxHeight: .infinity, alignment: .top)
            }
            Divider()
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(importing)
                Spacer()
                if importing { ProgressView().controlSize(.small) }
                Button("Import \(review?.imported ?? 0) Snippets") {
                    guard let plan else { return }
                    importing = true
                    Task {
                        if await store.importTextExpander(plan, selected: selected, policy: policy) { dismiss() }
                        else { error = store.errorMessage ?? "Import could not be saved."; store.errorMessage = nil }
                        importing = false
                    }
                }.keyboardShortcut(.defaultAction)
                    .disabled(loading || importing || reviewError != nil || (review?.imported ?? 0) == 0 || store.isBusy || store.hasUnsavedChanges)
            }
        }.padding(20).frame(minWidth: 820, idealWidth: 900, minHeight: 560, idealHeight: 660)
            .onChange(of: selected) { _, _ in refreshReview() }
            .onChange(of: policy) { _, _ in refreshReview() }
            .onChange(of: store.library) { _, _ in refreshReview() }
    }

    private func isConflict(_ row: TextExpanderImportRow) -> Bool {
        guard !row.abbreviation.isEmpty else { return false }
        let key = row.abbreviation.lowercased()
        return conflictAbbreviations.contains(key)
    }
    private func refreshReview() {
        guard let plan else { review = nil; return }
        let counts = plan.rows.filter { selected.contains($0.id) }.reduce(into: [String: Int]()) { $0[$1.abbreviation.lowercased(), default: 0] += 1 }
        conflictAbbreviations = Set(store.library.snippets.map { $0.abbreviation.lowercased() }).union(counts.filter { $0.value > 1 }.map(\.key))
        do {
            let result = try TextExpanderImporter.merge(plan, selected: selected, into: store.library, policy: policy)
            review = (result.imported, result.skipped); reviewError = nil
        } catch { review = nil; reviewError = error.localizedDescription }
    }
    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.title = "Choose TextExpander Exports"; panel.prompt = "Review"
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.commaSeparatedText, UTType(filenameExtension: "textexpander") ?? .data, UTType(filenameExtension: "textexpanderlegacy") ?? .data]
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        loading = true; error = nil; review = nil; reviewError = nil
        Task {
            do {
                let imported = try await Task.detached(priority: .userInitiated) { try TextExpanderImporter.read(urls) }.value
                plan = imported
                selected = Set(imported.rows.filter { $0.problem == nil && $0.converted != nil }.map(\.id))
                focused = imported.rows.first?.id
                refreshReview()
            } catch let failure { error = failure.localizedDescription }
            loading = false
        }
    }
}
