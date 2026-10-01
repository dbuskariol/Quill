import Foundation
import Testing
@testable import Quill

struct LibraryRepositoryTests {
    @Test func firstLoadPersistsStableStarterIdentifiers() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LibraryRepository(url: directory.appending(path: "library.json"))
        let first = try await repository.load()
        #expect(try await repository.load() == first)
    }

    @Test @MainActor func storeCreationFavoriteAndDeletionPersist() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LibraryRepository(url: directory.appending(path: "library.json"))
        let store = LibraryStore(repository: repository)
        await store.load()
        let count = store.library.snippets.count
        await store.create()
        let item = try #require(store.selected)
        #expect(store.library.snippets.count == count + 1)
        await store.toggleFavorite()
        #expect(store.selected?.isFavorite == true)
        #expect(try await repository.load() == store.library)
        await store.delete(item)
        #expect(store.library.snippets.count == count)
        #expect(try await repository.load() == store.library)
    }

    @Test func atomicRoundTripAndReplacement() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LibraryRepository(url: directory.appending(path: "library.json"))
        var library = Library.starter
        try await repository.save(library)
        #expect(try await repository.load() == library)
        library.snippets[0].title = "Updated"
        try await repository.save(library)
        #expect(try await repository.load() == library)
    }

    @Test func corruptDataIsPreserved() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = Data("broken JSON".utf8)
        try data.write(to: url)
        let repository = LibraryRepository(url: url)
        await #expect(throws: (any Error).self) { try await repository.load() }
        #expect(try Data(contentsOf: url) == data)
    }

    @Test func invalidSaveLeavesExistingDataIntact() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = LibraryRepository(url: url)
        let library = Library.starter
        try await repository.save(library)
        var invalid = library
        invalid.version = 99
        await #expect(throws: LibraryError.self) { try await repository.save(invalid) }
        #expect(try await repository.load() == library)
    }

    @Test func writeFailureIsSurfaced() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("file blocks directory creation".utf8).write(to: directory)
        let repository = LibraryRepository(url: directory.appending(path: "library.json"))
        await #expect(throws: (any Error).self) { try await repository.save(.starter) }
    }

    @Test @MainActor func storeDoesNotPublishFailedSave() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LibraryStore(repository: LibraryRepository(url: directory.appending(path: "library.json")))
        await store.load()
        let before = store.library
        try FileManager.default.removeItem(at: directory)
        try Data("blocked".utf8).write(to: directory)
        var item = before.snippets[0]
        item.title = "Must not publish"
        #expect(await store.save(item) == false)
        #expect(store.library == before)
        #expect(store.errorMessage != nil)
    }
}
