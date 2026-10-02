import SwiftUI

struct DraftRecoveryView: View {
    let store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: UUID?
    @State private var confirmDiscard = false
    @State private var savedChanged = false
    private var selected: DraftCheckpoint? { store.recoveredDrafts.first { $0.id == selectedID } }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recover Unsaved Edits").font(.title2.bold())
                Spacer()
                Button("Review Later") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(20)
            Divider()
            HSplitView {
                List(selection: $selectedID) {
                    ForEach(store.recoveredDrafts) { checkpoint in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(checkpoint.snapshot.title)
                            Text(checkpoint.date, format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(.secondary)
                        }.tag(checkpoint.id)
                    }
                }.frame(minWidth: 200, idealWidth: 230)
                ScrollView {
                    if let selected {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(selected.snapshot.title).font(.headline)
                            Text("\(selected.snapshot.format.label) · Unsaved draft").font(.caption).foregroundStyle(.secondary)
                            if savedChanged { Label("The saved template changed after this edit began. Compare before saving the recovered draft.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                            if let current = store.library.snapshots[selected.id] {
                                Text("Changes from Saved").font(.headline)
                                ForEach(TemplateDiff.lines(from: TemplateDiff.metadata(current, groups: store.library.groups), to: TemplateDiff.metadata(selected.snapshot, groups: store.library.groups))) { line in
                                    if line.kind != .unchanged { Text((line.kind == .added ? "+ " : "− ") + line.text).font(.callout).foregroundStyle(line.kind == .added ? Color.green : Color.red) }
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(TemplateDiff.lines(from: current.body, to: selected.snapshot.body)) { line in
                                        Text((line.kind == .added ? "+ " : line.kind == .removed ? "− " : "  ") + line.text).font(.system(.callout, design: .monospaced)).foregroundStyle(line.kind == .added ? Color.green : line.kind == .removed ? Color.red : .secondary).textSelection(.enabled)
                                            .accessibilityLabel((line.kind == .added ? "Added: " : line.kind == .removed ? "Removed: " : "") + line.text)
                                    }
                                }
                            } else { Text(selected.snapshot.body).font(.system(.body, design: .monospaced)).textSelection(.enabled) }
                        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.frame(minWidth: 440)
            }
            Divider()
            HStack {
                Button("Discard Draft…", role: .destructive) { confirmDiscard = true }.disabled(selected == nil)
                Spacer()
                Button("Recover Draft") {
                    if let selected { store.recoverDraft(selected); dismiss() }
                }.buttonStyle(.borderedProminent).disabled(selected == nil)
            }.padding(16)
            if let message = store.draftRecoveryMessage { Text(message).foregroundStyle(.red).padding(16) }
        }.frame(minWidth: 740, minHeight: 520)
            .onAppear { selectedID = store.recoveredDrafts.first?.id }
            .task(id: selectedID) {
                guard let selected else { savedChanged = false; return }
                do { savedChanged = try await store.itemHistory(selected.id).first?.id != selected.baseRevisionID }
                catch { savedChanged = true }
            }
            .alert("Discard This Unsaved Draft?", isPresented: $confirmDiscard) {
                Button("Cancel", role: .cancel) {}
                Button("Discard", role: .destructive) {
                    guard let selected else { return }
                    Task { if await store.discardRecoveredDraft(selected.id) { selectedID = store.recoveredDrafts.first?.id; if selectedID == nil { dismiss() } } }
                }
            } message: { Text("Only the recovery checkpoint is removed. Your saved template and its history stay intact.") }
    }
}
