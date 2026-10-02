import SwiftUI

struct TemplateHistoryView: View {
    let store: LibraryStore
    let itemID: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var revisions: [ItemRevision] = []
    @State private var selectedID: UUID?
    @State private var showChanges = true
    @State private var loading = true
    @State private var error: String?
    @State private var restoring = false
    @State private var confirmRestore = false
    private var selected: ItemRevision? { revisions.first { $0.id == selectedID } }
    private var current: TemplateSnapshot? { selected.flatMap { store.library.snapshots[$0.snapshot.id] } }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(itemID == nil ? "Deleted Templates" : "History").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(20)
            Divider()
            HSplitView {
                List(selection: $selectedID) {
                    ForEach(revisions) { revision in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(itemID == nil ? revision.snapshot.title : revision.date.formatted(.dateTime.month(.abbreviated).day().hour().minute().second())).lineLimit(1)
                                if revision.isProtected { Image(systemName: "pin.fill").accessibilityLabel("Kept version") }
                            }
                            Text(itemID == nil ? revision.date.formatted(.dateTime.month(.abbreviated).day().hour().minute().second()) : revision.reason).font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 4).tag(revision.id)
                    }
                }.frame(minWidth: 210, idealWidth: 250, maxWidth: 330)
                VStack(alignment: .leading, spacing: 12) {
                    if let selected {
                        HStack {
                            Text(selected.snapshot.title).font(.headline)
                            Spacer()
                            Text(selected.snapshot.format.label).font(.caption).foregroundStyle(.secondary)
                        }
                        if current != nil {
                            Picker("View", selection: $showChanges) { Text("Changes from Current").tag(true); Text("Saved Content").tag(false) }.pickerStyle(.segmented).labelsHidden()
                        }
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                if showChanges, let current {
                                    diff(TemplateDiff.metadata(current, groups: store.library.groups), TemplateDiff.metadata(selected.snapshot, groups: store.library.groups))
                                    Divider()
                                    diff(current.body, selected.snapshot.body)
                                } else {
                                    Text(TemplateDiff.metadata(selected.snapshot, groups: store.library.groups)).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                                    Divider()
                                    Text(selected.snapshot.body).font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        if selected.isDeleted { Text("Deleted content is recoverable here. Restoring creates a new saved version.").font(.callout).foregroundStyle(.secondary) }
                    } else if loading { ProgressView("Loading history…") }
                    else { ContentUnavailableView(itemID == nil ? "No Deleted Templates" : "No Versions Yet", systemImage: "clock.arrow.circlepath") }
                }.padding(20).frame(minWidth: 430, maxWidth: .infinity)
            }
            Divider()
            HStack {
                if let selected {
                    Button(selected.isProtected ? "Stop Keeping Version" : "Keep Version", systemImage: selected.isProtected ? "pin.slash" : "pin") {
                        Task { do { try await store.keepRevision(selected.id, keep: !selected.isProtected); await load() } catch { self.error = error.localizedDescription } }
                    }.help("Kept versions are excluded from automatic history retention.")
                    Spacer()
                    Button("Restore…") { confirmRestore = true }.buttonStyle(.borderedProminent)
                        .disabled(restoring || store.isBusy || store.drafts[selected.snapshot.id] != nil || store.macroDrafts[selected.snapshot.id] != nil || (!selected.isDeleted && current == selected.snapshot))
                } else { Spacer() }
            }.padding(16)
            if let error { Text(error).foregroundStyle(.red).textSelection(.enabled).padding(.horizontal, 16).padding(.bottom, 12) }
        }.frame(minWidth: 760, idealWidth: 900, minHeight: 560)
            .task { await load() }
            .alert("Restore This Version?", isPresented: $confirmRestore) {
                Button("Cancel", role: .cancel) {}
                Button("Restore") {
                    guard let selected else { return }
                    restoring = true
                    Task {
                        if await store.restoreItem(selected) { dismiss() }
                        else { error = store.errorMessage; store.errorMessage = nil }
                        restoring = false
                    }
                }
            } message: { Text("This creates a new saved version. Current content stays in history. Snippets whose group no longer exists go into Recovered.") }
    }
    private func load() async {
        do {
            if let itemID { revisions = try await store.itemHistory(itemID) } else { revisions = try await store.deletedItems() }
            if !revisions.contains(where: { $0.id == selectedID }) { selectedID = revisions.first?.id }
        } catch { self.error = error.localizedDescription }
        loading = false
    }
    private func diff(_ old: String, _ new: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(TemplateDiff.lines(from: old, to: new)) { line in
                Text((line.kind == .added ? "+ " : line.kind == .removed ? "− " : "  ") + line.text)
                    .font(.system(.callout, design: .monospaced)).foregroundStyle(line.kind == .added ? Color.green : line.kind == .removed ? Color.red : Color.secondary)
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel((line.kind == .added ? "Added: " : line.kind == .removed ? "Removed: " : "") + line.text)
            }
        }
    }
}
