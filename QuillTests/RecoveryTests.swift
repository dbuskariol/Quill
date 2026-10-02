import Foundation
import Testing
@testable import Quill

struct RecoveryTests {
    @Test func revisionRestorePreservesCorruptBytes() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "library.json")
        let repository = LibraryRepository(url: url)
        let original = try await repository.load()
        let backup = try await repository.backup()
        let damaged = Data("damaged data to preserve".utf8)
        try damaged.write(to: url)
        #expect(try await repository.recover(from: backup) == original)
        let revisions = try await repository.revisions()
        #expect(try revisions.contains { try Data(contentsOf: $0.url) == damaged })
        #expect(try await repository.load() == original)
    }

    @Test func externalChangeBlocksSave() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "library.json")
        let first = LibraryRepository(url: url)
        var library = try await first.load()
        let second = LibraryRepository(url: url)
        var other = try await second.load()
        other.snippets[0].title = "External change"
        try await second.save(other)
        library.snippets[0].title = "Stale edit"
        await #expect(throws: LibraryError.self) { try await first.save(library) }
        #expect(try await second.load() == other)
    }

    @Test @MainActor func importAndUndoPreserveSavedLibrary() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LibraryStore(repository: LibraryRepository(url: directory.appending(path: "library.json")))
        await store.load()
        let original = store.library
        var imported = original
        imported.snippets.removeLast()
        let source = directory.appending(path: "import.json")
        try LibraryRepository.encode(imported).write(to: source)
        await store.previewImport(from: source)
        #expect(store.library == original)
        await store.applyImport()
        #expect(store.library == imported)
        #expect(!store.revisions.isEmpty)
        await store.undoLastLibraryChange()
        #expect(store.library == original)
    }

    @Test @MainActor func groupDeleteMovesSnippetsWithoutDataLoss() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LibraryStore(repository: LibraryRepository(url: directory.appending(path: "library.json")))
        await store.load()
        let before = store.library.snippets
        let group = store.library.groups[0].id
        let target = store.library.groups[1].id
        await store.deleteGroup(group, movingTo: target)
        #expect(store.library.snippets.map(\.id) == before.map(\.id))
        #expect(store.library.snippets.filter { $0.groupID == group }.isEmpty)
        try store.library.validate()
    }

    @Test func aggregateExportCannotReplaceActiveLibraryThroughSymlink() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "library.json")
        let repository = LibraryRepository(url: url)
        let original = try await repository.load()
        let alias = directory.appending(path: "alias.json")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: url)
        await #expect(throws: LibraryError.self) { try await repository.exportData(Data("{}".utf8), to: alias) }
        await #expect(throws: LibraryError.self) { try await repository.saveNew(.starter) }
        #expect(try await repository.load() == original)
    }

    @Test func concurrentRepositoriesCannotBothPublishStaleWrites() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "library.json")
        let first = LibraryRepository(url: url)
        let second = LibraryRepository(url: url)
        var a = try await first.load()
        var b = try await second.load()
        a.snippets[0].title = "Writer A"; b.snippets[0].title = "Writer B"
        func attempt(_ repository: LibraryRepository, _ library: Library) async -> Bool {
            do { try await repository.save(library); return true } catch { return false }
        }
        async let one = attempt(first, a)
        async let two = attempt(second, b)
        let outcomes = await [one, two]
        #expect(outcomes.filter { $0 }.count == 1)
        let persisted = try await first.load()
        #expect(persisted == a || persisted == b)
    }

    @Test func updaterRejectsInvalidTrustConfiguration() {
        let key = Data(repeating: 7, count: 32).base64EncodedString()
        #expect(UpdateConfiguration.validated(feed: nil, publicKey: key) == nil)
        #expect(UpdateConfiguration.validated(feed: "http://updates.example.org/quill.xml", publicKey: key) == nil)
        #expect(UpdateConfiguration.validated(feed: "https://user:password@updates.example.org/quill.xml", publicKey: key) == nil)
        #expect(UpdateConfiguration.validated(feed: "https://updates.example.org/quill.xml", publicKey: "invalid") == nil)
        #expect(UpdateConfiguration.validated(feed: "https://updates.example.org/quill.xml", publicKey: key) != nil)
    }
}
