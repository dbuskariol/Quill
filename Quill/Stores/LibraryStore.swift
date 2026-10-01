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
    private let repository: LibraryRepository

    init(repository: LibraryRepository = LibraryRepository(url: LibraryRepository.defaultURL)) {
        self.repository = repository
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

    func create() async {
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

    private func commit(_ updated: Library) async -> Bool {
        guard isLoaded, !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        do {
            try await repository.save(updated)
            library = updated
            return true
        } catch {
            errorMessage = "Could not save your library. Retry after checking storage access. \(error.localizedDescription)"
            return false
        }
    }
}
