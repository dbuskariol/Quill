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
    var drafts: [UUID: Snippet] = [:]
    var showQuickActions = false
    enum Destination { case snippets, macros, settings }
    var destination: Destination = .snippets
    var isShowingSettings: Bool {
        get { destination == .settings }
        set { if newValue { destination = .settings } else if destination == .settings { destination = .snippets } }
    }
    var showTextExpanderImport = false
    var showCustomMacros: Bool {
        get { destination == .macros }
        set { if newValue { destination = .macros } else if destination == .macros { destination = .snippets } }
    }
    var selectedMacroID: UUID?
    var macroSearch = ""
    var macroDrafts: [UUID: CustomMacro] = [:]
    var hasUnsavedChanges: Bool { !drafts.isEmpty || !macroDrafts.isEmpty }
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

    var selected: Snippet? { library.snippets.first { $0.id == selectedID } }
    var visible: [Snippet] {
        library.snippets.filter { item in
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
        guard var item = selected else { return }
        item.isFavorite.toggle()
        await save(item)
    }

    func saveMacro(_ macro: CustomMacro) async -> Bool {
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
            _ = try TemplateRenderer.render(Snippet(groupID: updated.groups.first?.id ?? UUID(), title: macro.name, abbreviation: "", body: "{{macro:\(macro.name)}}"), library: updated)
        }
        catch { errorMessage = error.localizedDescription; return false }
        if await commit(updated) { macroDrafts[macro.id] = nil; return true }
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
        do { _ = try await repository.backup(); await refreshHistory(); storageMessage = "Backup created." }
        catch { storageMessage = error.localizedDescription }
    }

    func exportStatistics(to url: URL) async throws {
        try await repository.exportData(statistics.exportData(), to: url)
    }

    func export(to url: URL) async {
        do { try await repository.export(library, to: url); storageMessage = "Saved library exported. Unsaved drafts are not included." }
        catch { storageMessage = error.localizedDescription }
    }

    func previewImport(from url: URL) async {
        do { pendingImport = try await repository.read(url) }
        catch { storageMessage = "Import rejected. \(error.localizedDescription)" }
    }

    func applyImport() async {
        guard let imported = pendingImport, !hasUnsavedChanges else { return }
        if await commit(imported) {
            pendingImport = nil; filter = "all"; selectedID = visible.first?.id
            storageMessage = "Library replaced. Previous content is available in History."
        }
    }

    func importTextExpander(_ plan: TextExpanderImportPlan, selected: Set<UUID>, policy: TextExpanderConflictPolicy) async -> Bool {
        guard isLoaded, !isBusy, !hasUnsavedChanges else { return false }
        do {
            let merged = try TextExpanderImporter.merge(plan, selected: selected, into: library, policy: policy)
            guard merged.imported > 0 else { throw LibraryError.invalid("No snippets remain after conflict handling.") }
            if await commit(merged.library) {
                filter = "all"; search = ""; isShowingSettings = false
                storageMessage = "Imported \(merged.imported) TextExpander snippets. Skipped \(merged.skipped) conflicts. Previous library saved in History."
                return true
            }
        } catch { errorMessage = "Import did not change your library. \(error.localizedDescription)" }
        return false
    }

    func restore(_ revision: LibraryRevision) async {
        guard !isBusy, !hasUnsavedChanges else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let restored = try await repository.recover(from: revision.url)
            undoLibrary = isLoaded ? library : nil
            library = restored; isLoaded = true; filter = "all"; selectedID = visible.first?.id
            errorMessage = nil; storageMessage = "Revision restored. Previous file preserved in History."
            await refreshHistory()
        } catch { storageMessage = "Restore failed. \(error.localizedDescription)" }
    }

    func moveStorage(to directory: URL) async {
        guard !isBusy, isLoaded, !hasUnsavedChanges else { return }
        let destination = directory.appending(path: "library.json")
        guard destination.standardizedFileURL != storageURL.standardizedFileURL else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let replacement = LibraryRepository(url: destination)
            _ = try await repository.backup()
            try await replacement.saveNew(library)
            guard try await replacement.load() == library else { throw LibraryError.invalid("Storage verification failed.") }
            repository = replacement; storageURL = destination
            UserDefaults.standard.set(destination.path, forKey: "libraryPath")
            undoLibrary = nil; await refreshHistory()
            storageMessage = "Storage changed. Your previous library and history remain at their original location."
        } catch { storageMessage = "Storage unchanged. \(error.localizedDescription)" }
    }

    private func commit(_ updated: Library) async -> Bool {
        guard isLoaded, !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        do {
            try await repository.save(updated)
            undoLibrary = library
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
