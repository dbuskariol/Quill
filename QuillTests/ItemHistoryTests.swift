import Foundation
import Testing
@testable import Quill

struct ItemHistoryTests {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url
    }
    @Test func incompleteAndOutdatedJSONIsRejectedWithAnActionableFieldPath() throws {
        let missing = #"{"version":3,"groups":[{"id":"D398E141-1310-4A87-B55F-4E361924E601","name":"Support"}],"snippets":[],"macros":[]}"#
        do { _ = try LibraryRepository.decode(Data(missing.utf8)); Issue.record("Incomplete data was accepted") }
        catch { #expect(error.localizedDescription.contains("groups.0.symbol")) }
        var outdated = Library.starter; outdated.version = 2
        #expect(throws: LibraryError.self) { try LibraryRepository.encode(outdated) }
    }
    @Test func JSONIsExplicitInterchangeAndNeverAnAutomaticStorageFallback() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appending(path: "library.json")
        let bytes = Data("old or invalid format".utf8); try bytes.write(to: source)
        let repository = LibraryRepository(url: folder.appending(path: "library.sqlite"))
        #expect(try await repository.load().version == Library.schemaVersion)
        #expect(try Data(contentsOf: source) == bytes)
        let unsupported = LibraryRepository(url: source)
        await #expect(throws: LibraryError.self) { try await unsupported.load() }
        #expect(try Data(contentsOf: source) == bytes)
    }
    @Test func existingEmptyDatabaseNeverFallsBackToStarterContent() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "library.sqlite")
        do { _ = try LibraryDatabase(url: url) }
        let before = try Data(contentsOf: url), repository = LibraryRepository(url: url)
        await #expect(throws: LibraryError.self) { try await repository.load() }
        #expect(try Data(contentsOf: url) == before)
    }
    @Test func revisionsArePerItemLinkedAndSkipNoOpSaves() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let repository = LibraryRepository(url: folder.appending(path: "library.sqlite"))
        var library = try await repository.load(); let id = library.snippets[0].id
        let initial = try #require(await repository.itemHistory(id).first)
        try await repository.save(library)
        #expect(try await repository.itemHistory(id).count == 1)
        library.snippets[0].body = "New {{ticket.id}}"; library.snippets[0].format = .markdown
        try await repository.save(library)
        let history = try await repository.itemHistory(id)
        #expect(history.count == 2); #expect(history[0].parentID == initial.id)
        #expect(history[0].snapshot.format == .markdown)
        #expect(try await repository.itemHistory(library.snippets[1].id).count == 1)
        #expect(try await repository.load() == library)
    }
    @Test func historyFailureRollsBackTheCurrentTemplateAndAllRevisions() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "library.sqlite"), repository = LibraryRepository(url: folder.appending(path: "library.sqlite"))
        let original = try await repository.load()
        let db = try LibraryDatabase(url: url)
        try db.execute("CREATE TRIGGER reject_revision BEFORE INSERT ON item_revisions BEGIN SELECT RAISE(ABORT,'forced history failure'); END")
        var updated = original; updated.snippets[0].body = "Cannot commit"
        await #expect(throws: LibraryError.self) { try await repository.save(updated) }
        #expect(try await repository.load() == original)
        #expect(try await repository.itemHistory(original.snippets[0].id).count == 1)
    }
    @Test @MainActor func deletionAndRestoreCreateVersionsWithoutRewritingHistory() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let repository = LibraryRepository(url: folder.appending(path: "library.sqlite")), store = LibraryStore(repository: LibraryRepository(url: folder.appending(path: "library.sqlite")))
        await store.load()
        let item = try #require(store.selected), initial = try #require(await repository.itemHistory(item.id).first)
        await store.delete(item)
        let deleted = try #require(await store.deletedItems().first)
        #expect(deleted.isDeleted); #expect(deleted.parentID == initial.id)
        #expect(await store.restoreItem(deleted))
        let history = try await store.itemHistory(item.id)
        #expect(history.count == 3); #expect(history[0].parentID == deleted.id)
        #expect(history[0].reason == "Restored version")
        #expect(store.library.snippets.contains(item)); #expect(try await store.deletedItems().isEmpty)
    }
    @Test func retentionKeepsPinnedVersionsAndNewestDeletion() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let repository = LibraryRepository(url: folder.appending(path: "library.sqlite"))
        var library = try await repository.load(); let id = library.snippets[0].id
        let first = try #require(await repository.itemHistory(id).first)
        try await repository.protectRevision(first.id, protected: true)
        try await repository.setHistoryLimit(30)
        for number in 0..<32 { library.snippets[0].body = "Version \(number)"; try await repository.save(library) }
        library.snippets.removeAll { $0.id == id }; try await repository.save(library)
        let history = try await repository.itemHistory(id)
        #expect(history.count == 31); #expect(history.contains { $0.id == first.id && $0.isProtected })
        #expect(history.first?.isDeleted == true)
        try await repository.protectRevision(first.id, protected: false)
        try await repository.setHistoryLimit(30)
        #expect(try await repository.itemHistory(id).count == 30)
    }
    @Test @MainActor func draftCheckpointRecoversAfterRestartAndIsSeparateFromHistory() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let repository = LibraryRepository(url: folder.appending(path: "library.sqlite")), store = LibraryStore(repository: LibraryRepository(url: folder.appending(path: "library.sqlite")))
        await store.load(); var item = try #require(store.selected)
        item.body = "Unsaved **draft** {{ticket.id}}"; item.format = .markdown
        store.drafts[item.id] = item
        let macro = CustomMacro(name: "Unsaved block", body: "Hi", format: .markdown); store.macroDrafts[macro.id] = macro
        #expect(await store.flushDrafts())
        #expect(try await repository.itemHistory(item.id).count == 1)
        let restarted = LibraryStore(repository: LibraryRepository(url: repository.url)); await restarted.load()
        #expect(restarted.recoveredDrafts.count == 2)
        #expect(restarted.library.snippets.first { $0.id == item.id }?.body != item.body)
        let checkpoint = try #require(restarted.recoveredDrafts.first { $0.id == item.id })
        restarted.recoverDraft(checkpoint)
        #expect(restarted.drafts[item.id] == item)
        #expect(await restarted.save(item))
        #expect(await restarted.flushDrafts())
        #expect(try await repository.recoveredDrafts().count == 1)
        #expect(try await repository.itemHistory(item.id).count == 2)
        #expect(await restarted.discardRecoveredDraft(macro.id))
        #expect(try await repository.recoveredDrafts().isEmpty)
    }
    @Test func fullBackupPreservesVersionsProtectedHistoryAndDraftsAfterDisaster() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let repository = LibraryRepository(url: folder.appending(path: "library.sqlite"))
        var library = try await repository.load(); let id = library.snippets[0].id
        let initial = try #require(await repository.itemHistory(id).first)
        try await repository.protectRevision(initial.id, protected: true)
        library.snippets[0].body = "Saved **Markdown**"; library.snippets[0].format = .markdown
        try await repository.save(library)
        var draft = library.snippets[0]; draft.body = "Unsaved reply"
        try await repository.checkpoint([.snippet(draft)])
        let history = try await repository.itemHistory(id), checkpoints = try await repository.recoveredDrafts()
        let backup = folder.appending(path: "portable.quillbackup")
        try await repository.exportBackup(to: backup)
        try Data("damaged database".utf8).write(to: repository.url)
        #expect(try await repository.recover(from: backup) == library)
        #expect(try await repository.itemHistory(id) == history)
        #expect(try await repository.recoveredDrafts() == checkpoints)
        #expect(try await repository.revisions().contains { $0.url.pathExtension == "damaged-sqlite" })
    }
    @Test func healthyRestoreKeepsNewerVersionsAndImportsPortableHistory() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let source = LibraryRepository(url: folder.appending(path: "source.sqlite"))
        var library = try await source.load(); let id = library.snippets[0].id
        library.snippets[0].body = "Portable version"; try await source.save(library)
        let backup = folder.appending(path: "source.quillbackup"); try await source.exportBackup(to: backup)
        let destination = LibraryRepository(url: folder.appending(path: "destination.sqlite"))
        _ = try await destination.load()
        try await destination.save(library)
        var newer = library; newer.snippets[0].body = "Newer version"; try await destination.save(newer)
        _ = try await destination.recover(from: backup)
        let history = try await destination.itemHistory(id)
        #expect(history.contains { $0.snapshot.body == "Newer version" })
        #expect(history.first?.snapshot.body == "Portable version")
        #expect(history.first?.reason == "Restored library")
        #expect(try await destination.load() == library)
    }
    @Test func storageCopyPreservesHistoryAndNeverOverwritesAnExistingFile() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let repository = LibraryRepository(url: folder.appending(path: "library.sqlite"))
        var library = try await repository.load(); let id = library.snippets[0].id
        library.snippets[0].body = "Version two"; try await repository.save(library)
        let copy = folder.appending(path: "moved.sqlite"); try await repository.copyStorage(to: copy)
        let replacement = LibraryRepository(url: copy)
        #expect(try await replacement.load() == library)
        let originalHistory = try await repository.itemHistory(id)
        #expect(try await replacement.itemHistory(id) == originalHistory)
        let before = try Data(contentsOf: copy)
        await #expect(throws: (any Error).self) { try await repository.copyStorage(to: copy) }
        #expect(try Data(contentsOf: copy) == before)
    }
    @Test @MainActor func draftBaseIsCapturedBeforeAnExternalSaveOrCheckpoint() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let repository = LibraryRepository(url: folder.appending(path: "library.sqlite"))
        let store = LibraryStore(repository: LibraryRepository(url: repository.url)); await store.load()
        var draft = try #require(store.selected)
        let first = try #require(await repository.itemHistory(draft.id).first)
        var external = try await repository.load(); external.snippets[0].body = "External saved edit"
        try await repository.save(external)
        draft.body = "Local unsaved edit"; store.drafts[draft.id] = draft
        #expect(await store.flushDrafts())
        #expect(try await repository.recoveredDrafts().first?.baseRevisionID == first.id)
    }
    @Test @MainActor func favoriteCommandPreservesAnUnsavedBody() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let repository = LibraryRepository(url: folder.appending(path: "library.sqlite")), store = LibraryStore(repository: LibraryRepository(url: folder.appending(path: "library.sqlite")))
        await store.load(); var draft = try #require(store.selected)
        let saved = draft; draft.body = "Unsaved authored content"; store.drafts[draft.id] = draft
        await store.toggleFavorite()
        #expect(store.drafts[draft.id]?.body == draft.body)
        #expect(store.drafts[draft.id]?.isFavorite == !saved.isFavorite)
        #expect(try await repository.load().snippets.first { $0.id == draft.id } == saved)
        #expect(try await repository.itemHistory(draft.id).count == 1)
    }
    @Test func alteredHistoryPayloadFailsIntegrityReview() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let repository = LibraryRepository(url: folder.appending(path: "library.sqlite"))
        let library = try await repository.load(), item = library.snippets[0]
        let db = try LibraryDatabase(url: repository.url)
        try db.execute("UPDATE item_revisions SET hash='altered' WHERE item_id=?", [.text(item.id.uuidString)])
        await #expect(throws: LibraryError.self) { try await repository.itemHistory(item.id) }
        #expect(try await repository.load() == library)
    }
    @Test func diffsPreserveAddedRemovedAndUnchangedLines() {
        let lines = TemplateDiff.lines(from: "one\ntwo\nthree", to: "one\nchanged\nthree")
        #expect(lines.map(\.text) == ["one", "two", "changed", "three"])
        #expect(lines.map(\.kind) == [.unchanged, .removed, .added, .unchanged])
    }
}
