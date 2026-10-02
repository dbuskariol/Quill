import Foundation
import Observation

@MainActor @Observable
final class LibraryStore {
    private(set) var library = Library(groups: [], snippets: [])
    private(set) var isBusy = true
    private(set) var isLoaded = false
    var errorMessage: String?
    var selectedID: UUID?
    var filter = "all"
    var search = ""
    var pendingDelete: Snippet?
    var drafts: [UUID: Snippet] = [:] { didSet { scheduleCheckpoint() } }
    var showQuickActions = false
    var requestedSettingsPage: SettingsPage?
    enum Destination { case snippets, macros, settings }
    var destination: Destination = .snippets
    var showTextExpanderImport = false
    var selectedMacroID: UUID?
    var macroSearch = ""
    var macroDrafts: [UUID: CustomMacro] = [:] { didSet { scheduleCheckpoint() } }
    var recoveredDrafts: [DraftCheckpoint] = []
    var showDraftRecovery = false
    var historyRequest: HistoryRequest?
    var backupRequest: LibraryRevision?
    var historyLimit = 100
    var draftRecoveryMessage: String?
    private var revisionHeads: [UUID: UUID] = [:]
    private var draftBases: [UUID: UUID] = [:]
    private var trackedDraftIDs: Set<UUID> = []
    private var checkpointTask: Task<Void, Never>?
    var hasUnsavedChanges: Bool { !drafts.isEmpty || !macroDrafts.isEmpty || !recoveredDrafts.isEmpty }
    let statistics = LocalStatistics()
    let quickActions: QuickActionStore
    private var repository: LibraryRepository
    private(set) var storageURL: URL
    private(set) var revisions: [LibraryRevision] = []
    var pendingImport: Library?
    var storageMessage: String?
    private var undoLibrary: Library?
    var canUndoLibrary: Bool { undoLibrary != nil && !isBusy && !hasUnsavedChanges }

    init(repository: LibraryRepository = LibraryRepository(url: LibraryRepository.defaultURL)) {
        self.quickActions = QuickActionStore(statistics: statistics)
        self.repository = repository
        self.storageURL = repository.url
    }

    var selected: Snippet? { library.snippets.first { $0.id == selectedID } ?? selectedID.flatMap { drafts[$0] } }
    var visible: [Snippet] {
        (library.snippets + drafts.values.filter { draft in !library.snippets.contains { $0.id == draft.id } }).filter { item in
            (filter == "all" || (filter == "favorites" && item.isFavorite) || item.groupID.uuidString == filter)
            && (search.isEmpty || ([item.title, item.abbreviation, item.body] + item.tags).contains { $0.localizedStandardContains(search) })
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func load() async {
        guard !isLoaded else { return }
        isBusy = true
        do {
            let loaded = try await repository.load()
            library = loaded
            selectedID = visible.first?.id
            recoveredDrafts = try await repository.recoveredDrafts()
            historyLimit = try await repository.historyLimit()
            revisionHeads = try await repository.revisionHeads()
            isLoaded = true
            errorMessage = nil
            await refreshHistory()
        } catch { errorMessage = "Could not open your library. Existing data was preserved. \(error.localizedDescription)" }
        isBusy = false
    }

    @discardableResult
    func save(_ item: Snippet) async -> Bool {
        guard isLoaded, !isBusy else { return false }
        var updated = library
        var item = item
        if !updated.groups.contains(where: { $0.id == item.groupID }) {
            let group = updated.groups.first { $0.name == "Recovered" } ?? SnippetGroup(name: "Recovered")
            if !updated.groups.contains(group) { updated.groups.append(group) }
            item.groupID = group.id
        }
        if let index = updated.snippets.firstIndex(where: { $0.id == item.id }) { updated.snippets[index] = item }
        else { updated.snippets.append(item) }
        let success = await commit(updated)
        if success { drafts[item.id] = nil }
        return success
    }

    func createMacro() {
        guard isLoaded, !isBusy else { return }
        let names = Set(library.macros.map(\.name) + macroDrafts.values.map(\.name))
        var name = "New macro"; var suffix = 2
        while names.contains(name) { name = "New macro \(suffix)"; suffix += 1 }
        let macro = CustomMacro(name: name, body: "")
        macroDrafts[macro.id] = macro
        destination = .macros
        macroSearch = ""
        selectedMacroID = macro.id
    }

    func create() async {
        destination = .snippets
        guard let group = library.groups.first(where: { $0.id.uuidString == filter }) ?? library.groups.first else { return }
        let item = Snippet(groupID: group.id, title: "Untitled snippet", abbreviation: "", body: "")
        if await save(item) {
            search = ""
            if filter == "favorites" { filter = "all" }
            selectedID = item.id
        }
    }

    func delete(_ item: Snippet) async {
        var updated = library
        updated.snippets.removeAll { $0.id == item.id }
        if await commit(updated) { drafts[item.id] = nil; selectedID = visible.first?.id }
    }

    func toggleFavorite() async {
        guard let id = selectedID else { return }
        if var draft = drafts[id] {
            draft.isFavorite.toggle(); drafts[id] = draft
        } else if var item = selected {
            item.isFavorite.toggle(); await save(item)
        }
    }

    func saveMacro(_ macro: CustomMacro, reason: String = "Saved") async -> Bool {
        var updated = library
        if let index = updated.macros.firstIndex(where: { $0.id == macro.id }) {
            let oldName = updated.macros[index].name
            if oldName != macro.name {
                guard drafts.isEmpty, macroDrafts.keys.allSatisfy({ $0 == macro.id }) else {
                    errorMessage = "Save or revert other drafts before renaming a macro, so its references can be updated together."
                    return false
                }
                let oldToken = "{{macro:\(oldName)}}", newToken = "{{macro:\(macro.name)}}"
                for index in updated.snippets.indices { updated.snippets[index].body = updated.snippets[index].body.replacingOccurrences(of: oldToken, with: newToken) }
                for index in updated.macros.indices { updated.macros[index].body = updated.macros[index].body.replacingOccurrences(of: oldToken, with: newToken) }
            }
            updated.macros[index] = macro
            if oldName != macro.name { updated.macros[index].body = macro.body.replacingOccurrences(of: "{{macro:\(oldName)}}", with: "{{macro:\(macro.name)}}") }
        }
        else { updated.macros.append(macro) }
        do {
            try updated.validate()
            _ = try TemplateRenderer.render(Snippet(groupID: updated.groups.first?.id ?? UUID(), title: macro.name, abbreviation: "", body: "{{macro:\(macro.name)}}", format: macro.format), library: updated)
        }
        catch { errorMessage = error.localizedDescription; return false }
        if await commit(updated, reason: reason) { macroDrafts[macro.id] = nil; return true }
        return false
    }
    func deleteMacro(_ macro: CustomMacro) async -> Bool {
        var updated = library
        updated.macros.removeAll { $0.id == macro.id }
        if await commit(updated) { macroDrafts[macro.id] = nil; return true }
        return false
    }

    func renameGroup(_ id: UUID, to name: String) async {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = library.groups.firstIndex(where: { $0.id == id }) else { return }
        var updated = library
        updated.groups[index].name = name
        _ = await commit(updated)
    }

    func createGroup(named name: String) async {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var updated = library
        let group = SnippetGroup(name: name)
        updated.groups.append(group)
        if await commit(updated) { filter = group.id.uuidString }
    }

    func deleteGroup(_ id: UUID, movingTo target: UUID) async {
        guard id != target, library.groups.contains(where: { $0.id == target }), !hasUnsavedChanges else { return }
        var updated = library
        updated.groups.removeAll { $0.id == id }
        for index in updated.snippets.indices where updated.snippets[index].groupID == id {
            updated.snippets[index].groupID = target
        }
        if await commit(updated) { filter = target.uuidString }
    }

    func undoLastLibraryChange() async {
        guard canUndoLibrary, let previous = undoLibrary else { return }
        _ = await commit(previous)
    }

    func refreshHistory() async {
        do { revisions = try await repository.revisions() }
        catch { storageMessage = "Could not list revisions: \(error.localizedDescription)" }
    }

    func backup() async {
        do { guard await flushDrafts() else { return }; _ = try await repository.backup(); await refreshHistory(); storageMessage = "Library backup created, including history and recovery checkpoints." }
        catch { storageMessage = error.localizedDescription }
    }

    func exportStatistics(to url: URL) async throws {
        try await repository.exportData(statistics.exportData(), to: url)
    }

    func export(to url: URL) async {
        do { try await repository.export(library, to: url); storageMessage = "Saved templates exported as JSON. History and unsaved drafts are not included. Export Library Backup to include them." }
        catch { storageMessage = error.localizedDescription }
    }

    func exportBackup(to url: URL) async {
        do {
            guard await flushDrafts() else { return }
            try await repository.exportBackup(to: url)
            storageMessage = "Library backup exported, including template versions and recovery checkpoints."
        } catch { storageMessage = error.localizedDescription }
    }
    func readBackup(_ url: URL) async throws -> Library { try await repository.read(url) }
    func previewImport(from url: URL) async {
        do { pendingImport = try await repository.read(url) }
        catch { storageMessage = "Import rejected. \(error.localizedDescription)" }
    }

    func applyImport(_ imported: Library) async {
        guard !hasUnsavedChanges else { return }
        do { _ = try await repository.backup() }
        catch { storageMessage = "Import stopped because the backup failed. \(error.localizedDescription)"; return }
        if await commit(imported, reason: "Imported templates") {
            pendingImport = nil; filter = "all"; selectedID = visible.first?.id
            storageMessage = "Library replaced. Previous content is available in History."
        }
    }

    func importTextExpander(_ plan: TextExpanderImportPlan, selected: Set<UUID>, policy: TextExpanderConflictPolicy) async -> Bool {
        guard isLoaded, !isBusy, !hasUnsavedChanges else { return false }
        do {
            let merged = try TextExpanderImporter.merge(plan, selected: selected, into: library, policy: policy)
            guard merged.imported > 0 else { throw LibraryError.invalid("No snippets remain after conflict handling.") }
            _ = try await repository.backup()
            if await commit(merged.library, reason: "TextExpander import") {
                filter = "all"; search = ""; destination = .snippets
                storageMessage = "Imported \(merged.imported) TextExpander snippets. Skipped \(merged.skipped) conflicts. Previous library saved in History."
                return true
            }
        } catch { errorMessage = "Import did not change your library. \(error.localizedDescription)" }
        return false
    }

    func restore(_ revision: LibraryRevision) async -> Bool {
        guard !isBusy, !hasUnsavedChanges else { return false }
        isBusy = true
        defer { isBusy = false }
        do {
            if isLoaded { guard await flushDrafts() else { return false } }
            let restored = try await repository.recover(from: revision.url)
            recoveredDrafts = try await repository.recoveredDrafts()
            historyLimit = try await repository.historyLimit()
            revisionHeads = try await repository.revisionHeads()
            undoLibrary = isLoaded ? library : nil
            library = restored; isLoaded = true; filter = "all"; selectedID = visible.first?.id
            errorMessage = nil; storageMessage = "Revision restored. Previous file preserved in History."
            await refreshHistory()
            return true
        } catch { storageMessage = "Restore failed. \(error.localizedDescription)"; return false }
    }

    func openStorage(in directory: URL) async {
        guard !isLoaded, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let candidate = LibraryRepository(url: directory.appending(path: "library.sqlite"))
            let loaded = try await candidate.load()
            let checkpoints = try await candidate.recoveredDrafts()
            let limit = try await candidate.historyLimit()
            let heads = try await candidate.revisionHeads()
            repository = candidate; storageURL = candidate.url
            library = loaded; recoveredDrafts = checkpoints; historyLimit = limit; revisionHeads = heads
            isLoaded = true; selectedID = visible.first?.id; errorMessage = nil
            UserDefaults.standard.set(storageURL.path, forKey: "libraryPath")
            await refreshHistory()
        } catch { storageMessage = "Could not open that library folder. \(error.localizedDescription)" }
    }

    func moveStorage(to directory: URL) async {
        guard !isBusy, isLoaded, !hasUnsavedChanges else { return }
        let destination = directory.appending(path: "library.sqlite")
        guard destination.standardizedFileURL != storageURL.standardizedFileURL else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            guard !FileManager.default.fileExists(atPath: destination.path) else { throw LibraryError.invalid("The selected folder already contains a library. Choose an empty folder.") }
            let replacement = LibraryRepository(url: destination)
            _ = try await repository.backup()
            // Move the complete database, including revisions, rather than only current definitions.
            try await repository.copyStorage(to: destination)
            guard try await replacement.load() == library else { throw LibraryError.invalid("Storage verification failed.") }
            revisionHeads = try await replacement.revisionHeads()
            repository = replacement; storageURL = destination
            UserDefaults.standard.set(destination.path, forKey: "libraryPath")
            undoLibrary = nil; await refreshHistory()
            storageMessage = "Storage changed. Your previous library and history remain at their original location."
        } catch { storageMessage = "Storage unchanged. \(error.localizedDescription)" }
    }

    func itemHistory(_ id: UUID) async throws -> [ItemRevision] { try await repository.itemHistory(id) }
    func deletedItems() async throws -> [ItemRevision] { try await repository.deletedItems() }
    func keepRevision(_ id: UUID, keep: Bool) async throws { try await repository.protectRevision(id, protected: keep) }
    func changeHistoryLimit(_ limit: Int) async {
        do { try await repository.setHistoryLimit(limit); historyLimit = limit }
        catch { storageMessage = error.localizedDescription }
    }
    func restoreItem(_ revision: ItemRevision) async -> Bool {
        guard drafts[revision.snapshot.id] == nil, macroDrafts[revision.snapshot.id] == nil else {
            errorMessage = "Save or revert this template's draft before restoring a version."; return false
        }
        switch revision.snapshot {
        case .macro(let macro):
            if await saveMacro(macro, reason: "Restored version") {
                destination = .macros; selectedMacroID = macro.id; macroSearch = ""; return true
            }
        case .snippet(var item):
            var updated = library
            if !updated.groups.contains(where: { $0.id == item.groupID }) {
                let recovered = updated.groups.first { $0.name == "Recovered" } ?? SnippetGroup(name: "Recovered")
                if !updated.groups.contains(recovered) { updated.groups.append(recovered) }
                item.groupID = recovered.id
            }
            updated.snippets.removeAll { $0.id == item.id }; updated.snippets.append(item)
            if await commit(updated, reason: "Restored version") {
                destination = .snippets; filter = "all"; search = ""; selectedID = item.id; return true
            }
        }
        return false
    }
    private func scheduleCheckpoint() {
        guard isLoaded else { return }
        let ids = Set(drafts.keys).union(macroDrafts.keys)
        for id in ids.subtracting(trackedDraftIDs) { draftBases[id] = revisionHeads[id] }
        for id in trackedDraftIDs.subtracting(ids) { draftBases[id] = nil }
        trackedDraftIDs = ids
        checkpointTask?.cancel()
        checkpointTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
            guard let self, !Task.isCancelled else { return }
            _ = await self.writeCheckpoint()
        }
    }
    private func writeCheckpoint() async -> Bool {
        do {
            let snapshots = drafts.values.map(TemplateSnapshot.snippet) + macroDrafts.values.map(TemplateSnapshot.macro)
            try await repository.checkpoint(snapshots, preserving: Set(recoveredDrafts.map(\.id)), bases: draftBases)
            draftRecoveryMessage = nil; return true
        } catch { draftRecoveryMessage = "Draft recovery could not be saved: \(error.localizedDescription)"; return false }
    }
    func flushDrafts() async -> Bool {
        checkpointTask?.cancel(); await checkpointTask?.value
        return await writeCheckpoint()
    }
    func recoverDraft(_ checkpoint: DraftCheckpoint) {
        switch checkpoint.snapshot {
        case .snippet(var item):
            if !library.groups.contains(where: { $0.id == item.groupID }), let group = library.groups.first { item.groupID = group.id }
            drafts[item.id] = item; filter = "all"; search = ""; selectedID = item.id; destination = .snippets
        case .macro(let item):
            macroDrafts[item.id] = item; selectedMacroID = item.id; macroSearch = ""; destination = .macros
        }
        recoveredDrafts.removeAll { $0.id == checkpoint.id }
    }
    func discardRecoveredDraft(_ id: UUID) async -> Bool {
        do { try await repository.discardCheckpoint(id); recoveredDrafts.removeAll { $0.id == id }; return true }
        catch { draftRecoveryMessage = error.localizedDescription; return false }
    }

    private func commit(_ updated: Library, reason: String = "Saved") async -> Bool {
        guard isLoaded, !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        do {
            checkpointTask?.cancel()
            await checkpointTask?.value
            try await repository.save(updated, reason: reason)
            undoLibrary = library
            revisionHeads = (try? await repository.revisionHeads()) ?? [:]
            library = updated
            errorMessage = nil
            await refreshHistory()
            return true
        } catch {
            errorMessage = "Could not save your library. Retry after checking storage access. \(error.localizedDescription)"
            return false
        }
    }
}
