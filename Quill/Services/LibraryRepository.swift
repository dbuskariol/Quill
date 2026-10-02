import CryptoKit
import Darwin
import Foundation

struct LibraryRevision: Identifiable, Sendable {
    var id: String { url.lastPathComponent }
    let url: URL
    let date: Date
    var isRecoverable: Bool { ["json", "quillbackup"].contains(url.pathExtension) }
}

actor LibraryRepository {
    nonisolated let url: URL
    private var observedData: Data?
    init(url: URL) { self.url = url }
    static var defaultURL: URL { URL.applicationSupportDirectory.appending(path: "Quill/library.sqlite") }
    var historyURL: URL { url.deletingLastPathComponent().appending(path: "Quill History", directoryHint: .isDirectory) }

    func load() throws -> Library {
        try withFileLock {
            guard url.pathExtension == "sqlite" else { throw LibraryError.invalid("Active libraries must use SQLite storage. Choose a library folder in Settings.") }
            let existed = FileManager.default.fileExists(atPath: url.path)
            let db = try LibraryDatabase(url: url)
            guard try db.query("PRAGMA quick_check").first?.first?.string == "ok" else { throw LibraryError.invalid("Library integrity check failed. Restore a backup; the database was preserved.") }
            if let data = try currentData(db) { let library = try Self.decode(data); observedData = data; return library }
            guard !existed else { throw LibraryError.invalid("The library database has no saved content. It was preserved; open a complete backup or choose a new library folder.") }
            let library = Library.starter
            try write(library, database: db, reason: "Created")
            return library
        }
    }
    static func decode(_ data: Data) throws -> Library {
        guard data.count <= 50_000_000 else { throw LibraryError.invalid("Library exceeds the 50 MB import limit.") }
        let library: Library
        do { library = try JSONDecoder().decode(Library.self, from: data) }
        catch DecodingError.keyNotFound(let key, let context) {
            let path = (context.codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue } + [key.stringValue]).joined(separator: ".")
            throw LibraryError.invalid("The library is missing required field ‘\(path)’. Re-export it using the current Quill format.")
        } catch DecodingError.typeMismatch(_, let context), DecodingError.valueNotFound(_, let context), DecodingError.dataCorrupted(let context) {
            let path = context.codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: ".")
            throw LibraryError.invalid("Invalid library data\(path.isEmpty ? "" : " at ‘\(path)’").")
        }
        try library.validate(); return library
    }
    static func encode(_ library: Library) throws -> Data {
        try library.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(library)
    }
    private static func encodeSnapshot(_ snapshot: TemplateSnapshot) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(snapshot)
    }
    func save(_ library: Library, reason: String = "Saved") throws {
        try library.validate()
        guard url.pathExtension == "sqlite" else { throw LibraryError.invalid("Active libraries must use SQLite storage.") }
        try withFileLock {
            if observedData != nil && !FileManager.default.fileExists(atPath: url.path) { throw LibraryError.invalid("The active database was removed. Reopen your library; your draft is preserved.") }
            try write(library, database: LibraryDatabase(url: url), reason: reason)
        }
    }
    private func write(_ library: Library, database db: LibraryDatabase, reason: String, importedHistory: [[LibraryDatabase.Value]] = [], importedDrafts: [[LibraryDatabase.Value]] = []) throws {
        let data = try Self.encode(library)
        try databaseTransaction(db) {
            let current = try currentData(db)
            if let observedData, current != observedData { throw LibraryError.invalid("The library changed outside this window. Reopen it before saving; your draft is preserved.") }
            for row in importedHistory {
                try db.execute("INSERT OR IGNORE INTO item_revisions (id,item_id,parent_id,transaction_id,created,reason,deleted,protected,hash,payload) VALUES (?,?,?,?,?,?,?,?,?,?)", row)
            }
            for row in importedDrafts { try db.execute("INSERT OR IGNORE INTO drafts VALUES (?,?)", row) }
            guard current != data else { return }
            let previous = try current.map(Self.decode)
            let old = previous?.snapshots ?? [:], new = library.snapshots
            let transaction = UUID().uuidString
            for id in Set(old.keys).union(new.keys).sorted(by: { $0.uuidString < $1.uuidString }) {
                guard old[id] != new[id], let snapshot = new[id] ?? old[id] else { continue }
                let parent = try latestRevisionID(id, db: db)
                let payload = try Self.encodeSnapshot(snapshot)
                let hash = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
                try db.execute("INSERT INTO item_revisions (id,item_id,parent_id,transaction_id,created,reason,deleted,hash,payload) VALUES (?,?,?,?,?,?,?,?,?)", [
                    .text(UUID().uuidString), .text(id.uuidString), parent.map { .text($0.uuidString) } ?? .null, .text(transaction), .real(Date().timeIntervalSince1970), .text(new[id] == nil ? "Deleted" : reason), .integer(new[id] == nil ? 1 : 0), .text(hash), .blob(payload)
                ])
                // Remove a checkpoint only when this exact draft was committed, or the item was deleted.
                if let row = try db.query("SELECT payload FROM drafts WHERE item_id=?", [.text(id.uuidString)]).first,
                   let bytes = row.first?.data, let draft = try? JSONDecoder().decode(DraftCheckpoint.self, from: bytes),
                   new[id] == nil || draft.snapshot == new[id] {
                    try db.execute("DELETE FROM drafts WHERE item_id=?", [.text(id.uuidString)])
                }
                try prune(id, db: db)
            }
            try db.execute("INSERT INTO library_state VALUES (1,1,?) ON CONFLICT(id) DO UPDATE SET generation=generation+1,payload=excluded.payload", [.blob(data)])
        }
        observedData = data
    }
    private func databaseTransaction<T>(_ db: LibraryDatabase, _ operation: () throws -> T) throws -> T {
        try db.execute("BEGIN IMMEDIATE")
        do { let result = try operation(); try db.execute("COMMIT"); return result }
        catch { try? db.execute("ROLLBACK"); throw error }
    }
    private func currentData(_ db: LibraryDatabase) throws -> Data? { try db.query("SELECT payload FROM library_state WHERE id=1").first?.first?.data }
    private func latestRevisionID(_ id: UUID, db: LibraryDatabase) throws -> UUID? {
        guard let row = try db.query("SELECT id FROM item_revisions WHERE item_id=? ORDER BY created DESC,rowid DESC LIMIT 1", [.text(id.uuidString)]).first else { return nil }
        guard let revision = row.first?.string.flatMap(UUID.init(uuidString:)) else { throw LibraryError.invalid("Invalid history identifier.") }
        return revision
    }
    func itemHistory(_ id: UUID) throws -> [ItemRevision] {
        try historyRows("WHERE item_id=?", [.text(id.uuidString)])
    }
    func deletedItems() throws -> [ItemRevision] {
        try historyRows("WHERE deleted=1 AND id IN (SELECT id FROM item_revisions r WHERE NOT EXISTS (SELECT 1 FROM item_revisions n WHERE n.item_id=r.item_id AND (n.created>r.created OR (n.created=r.created AND n.rowid>r.rowid))))", [])
    }
    private func historyRows(_ condition: String, _ values: [LibraryDatabase.Value]) throws -> [ItemRevision] {
        let db = try LibraryDatabase(url: url)
        return try db.query("SELECT id,parent_id,transaction_id,created,reason,deleted,protected,payload,hash,item_id FROM item_revisions \(condition) ORDER BY created DESC,rowid DESC", values).map { row in
            guard let id = row[0].string.flatMap(UUID.init(uuidString:)), let transaction = row[2].string.flatMap(UUID.init(uuidString:)), let date = row[3].double, let bytes = row[7].data else { throw LibraryError.invalid("Invalid item history record.") }
            let snapshot = try JSONDecoder().decode(TemplateSnapshot.self, from: bytes)
            let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            guard snapshot.id.uuidString == row[9].string, digest == row[8].string, let reason = row[4].string else { throw LibraryError.invalid("Item history integrity check failed.") }
            return ItemRevision(id: id, parentID: row[1].string.flatMap(UUID.init(uuidString:)), transactionID: transaction, date: Date(timeIntervalSince1970: date), reason: reason, isDeleted: row[5].int == 1, isProtected: row[6].int == 1, snapshot: snapshot)
        }
    }
    func revisionHeads() throws -> [UUID: UUID] {
        let db = try LibraryDatabase(url: url)
        var result: [UUID: UUID] = [:]
        for row in try db.query("SELECT item_id,id FROM item_revisions r WHERE NOT EXISTS (SELECT 1 FROM item_revisions n WHERE n.item_id=r.item_id AND (n.created>r.created OR (n.created=r.created AND n.rowid>r.rowid)))") {
            guard let item = row[0].string.flatMap(UUID.init(uuidString:)), let revision = row[1].string.flatMap(UUID.init(uuidString:)) else { throw LibraryError.invalid("Invalid history identifiers.") }
            result[item] = revision
        }
        return result
    }
    func protectRevision(_ id: UUID, protected: Bool) throws {
        let db = try LibraryDatabase(url: url)
        try db.execute("UPDATE item_revisions SET protected=? WHERE id=?", [.integer(protected ? 1 : 0), .text(id.uuidString)])
    }
    func historyLimit() throws -> Int { try historyLimit(db: LibraryDatabase(url: url)) }
    private func historyLimit(db: LibraryDatabase) throws -> Int {
        guard let limit = try db.query("SELECT value FROM preferences WHERE key='history_limit'").first?.first?.int, [30, 100, 500].contains(limit) else { throw LibraryError.invalid("Invalid history retention setting.") }
        return Int(limit)
    }
    func setHistoryLimit(_ limit: Int) throws {
        guard [30, 100, 500].contains(limit) else { throw LibraryError.invalid("Unsupported history limit.") }
        let db = try LibraryDatabase(url: url)
        try db.execute("BEGIN IMMEDIATE")
        defer { try? db.execute("ROLLBACK") }
        try db.execute("UPDATE preferences SET value=? WHERE key='history_limit'", [.integer(Int64(limit))])
        for row in try db.query("SELECT DISTINCT item_id FROM item_revisions") {
            if let id = row.first?.string.flatMap(UUID.init(uuidString:)) { try prune(id, db: db) }
        }
        try db.execute("COMMIT")
    }
    private func prune(_ id: UUID, db: LibraryDatabase) throws {
        let limit = try historyLimit(db: db)
        try db.execute("DELETE FROM item_revisions WHERE item_id=? AND protected=0 AND id NOT IN (SELECT id FROM item_revisions WHERE item_id=? ORDER BY created DESC,rowid DESC LIMIT ?)", [.text(id.uuidString), .text(id.uuidString), .integer(Int64(limit))])
    }
    func checkpoint(_ snapshots: [TemplateSnapshot], preserving recoveredIDs: Set<UUID> = [], bases: [UUID: UUID]? = nil) throws {
        let db = try LibraryDatabase(url: url)
        try db.execute("BEGIN IMMEDIATE")
        defer { try? db.execute("ROLLBACK") }
        let keep = Set(snapshots.map(\.id)).union(recoveredIDs)
        for row in try db.query("SELECT item_id FROM drafts") {
            if let id = row.first?.string.flatMap(UUID.init(uuidString:)), !keep.contains(id) { try db.execute("DELETE FROM drafts WHERE item_id=?", [.text(id.uuidString)]) }
        }
        for snapshot in snapshots {
            // Preserve the original base across successive checkpoints for conflict review.
            let existing = try db.query("SELECT payload FROM drafts WHERE item_id=?", [.text(snapshot.id.uuidString)]).first?.first?.data
            let previous = try existing.map { try JSONDecoder().decode(DraftCheckpoint.self, from: $0) }
            let base: UUID?
            if let previous { base = previous.baseRevisionID } else if let bases { base = bases[snapshot.id] } else { base = try latestRevisionID(snapshot.id, db: db) }
            let draft = DraftCheckpoint(snapshot: snapshot, baseRevisionID: base, date: .now)
            let data = try JSONEncoder().encode(draft)
            try db.execute("INSERT INTO drafts VALUES (?,?) ON CONFLICT(item_id) DO UPDATE SET payload=excluded.payload", [.text(snapshot.id.uuidString), .blob(data)])
        }
        try db.execute("COMMIT")
    }
    func recoveredDrafts() throws -> [DraftCheckpoint] {
        try LibraryDatabase(url: url).query("SELECT payload FROM drafts").map { row in
            guard let data = row.first?.data else { throw LibraryError.invalid("Invalid recovery checkpoint.") }
            return try JSONDecoder().decode(DraftCheckpoint.self, from: data)
        }.sorted { $0.date > $1.date }
    }
    func discardCheckpoint(_ id: UUID) throws { try LibraryDatabase(url: url).execute("DELETE FROM drafts WHERE item_id=?", [.text(id.uuidString)]) }

    func backup() throws -> URL {
        let db = try LibraryDatabase(url: url)
        guard let data = try currentData(db) else { throw LibraryError.invalid("No saved library exists yet.") }
        _ = try Self.decode(data)
        try FileManager.default.createDirectory(at: historyURL, withIntermediateDirectories: true)
        let destination = historyURL.appending(path: "backup-\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID()).quillbackup")
        do { try db.backup(to: destination); return destination }
        catch { try? FileManager.default.removeItem(at: destination); throw error }
    }
    func exportBackup(to destination: URL) throws {
        let temporary = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).quillbackup")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try LibraryDatabase(url: url).backup(to: temporary)
        try exportData(Data(contentsOf: temporary), to: destination)
    }
    /// Install a complete database without replacing anything at the destination.
    func copyStorage(to destination: URL) throws {
        let temporary = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).sqlite")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try LibraryDatabase(url: url).backup(to: temporary)
        try FileManager.default.copyItem(at: temporary, to: destination)
    }
    func revisions() throws -> [LibraryRevision] {
        guard FileManager.default.fileExists(atPath: historyURL.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: historyURL, includingPropertiesForKeys: [.creationDateKey])
            .filter { ["quillbackup", "damaged-sqlite"].contains($0.pathExtension) }
            .map { LibraryRevision(url: $0, date: try $0.resourceValues(forKeys: [.creationDateKey]).creationDate ?? .distantPast) }.sorted { $0.date > $1.date }
    }
    func read(_ source: URL) throws -> Library {
        if source.pathExtension == "quillbackup" {
            let db = try LibraryDatabase(url: source, readOnly: true)
            guard try db.query("PRAGMA quick_check").first?.first?.string == "ok", let data = try currentData(db) else { throw LibraryError.invalid("Backup integrity check failed.") }
            return try Self.decode(data)
        }
        guard (try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 50_000_000 else { throw LibraryError.invalid("Library exceeds the 50 MB import limit.") }
        return try Self.decode(Data(contentsOf: source))
    }
    func export(_ library: Library, to destination: URL) throws { try exportData(Self.encode(library), to: destination) }
    func exportData(_ data: Data, to destination: URL) throws {
        let target = destination.resolvingSymlinksInPath().standardizedFileURL
        let active = url.resolvingSymlinksInPath().standardizedFileURL
        guard target != active, !target.path.hasPrefix(active.path + "-") else { throw LibraryError.invalid("Choose an export file outside active storage.") }
        try data.write(to: destination, options: .atomic)
    }
    func recover(from source: URL) throws -> Library {
        let library = try read(source)
        return try withFileLock {
            let healthy: Bool
            do { let db = try LibraryDatabase(url: url); healthy = try db.query("PRAGMA quick_check").first?.first?.string == "ok" && currentData(db) != nil }
            catch { healthy = false }
            if healthy {
                _ = try backup()
                let db = try LibraryDatabase(url: url)
                observedData = try currentData(db)
                let imported: [[LibraryDatabase.Value]], drafts: [[LibraryDatabase.Value]]
                if source.pathExtension == "quillbackup" {
                    let backup = try LibraryDatabase(url: source, readOnly: true)
                    imported = try backup.query("SELECT id,item_id,parent_id,transaction_id,created,reason,deleted,protected,hash,payload FROM item_revisions ORDER BY created,rowid")
                    drafts = try backup.query("SELECT item_id,payload FROM drafts")
                } else { imported = []; drafts = [] }
                try write(library, database: db, reason: "Restored library", importedHistory: imported, importedDrafts: drafts)
            } else {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.createDirectory(at: historyURL, withIntermediateDirectories: true)
                    try Data(contentsOf: url).write(to: historyURL.appending(path: "\(UUID()).damaged-sqlite"), options: .atomic)
                }
                let temporary = url.deletingLastPathComponent().appending(path: "\(UUID()).sqlite")
                defer { try? FileManager.default.removeItem(at: temporary) }
                observedData = nil
                if source.pathExtension == "quillbackup" { try FileManager.default.copyItem(at: source, to: temporary) }
                else { do { let db = try LibraryDatabase(url: temporary); try write(library, database: db, reason: "Recovered library") } }
                // Preserve any recovery sidecars before replacing a damaged database.
                for suffix in ["-journal", "-wal", "-shm"] {
                    let sidecar = URL(fileURLWithPath: url.path + suffix)
                    if FileManager.default.fileExists(atPath: sidecar.path) {
                        try FileManager.default.moveItem(at: sidecar, to: historyURL.appending(path: "\(UUID())\(suffix).damaged-sqlite"))
                    }
                }
                try Data(contentsOf: temporary).write(to: url, options: .atomic)
                observedData = try Self.encode(library)
            }
            return library
        }
    }
    private func withFileLock<T>(_ operation: () throws -> T) throws -> T {
        let directory = url.resolvingSymlinksInPath().deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = Darwin.open(directory.appending(path: ".quill-library.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw LibraryError.invalid("Could not open the library coordination lock.") }
        defer { _ = Darwin.close(descriptor) }
        let lock: @convention(c) (Int32, Int32) -> Int32 = flock
        guard lock(descriptor, LOCK_EX | LOCK_NB) == 0 else { throw LibraryError.invalid("Another Quill operation is using this library. Retry shortly; your changes are preserved.") }
        defer { _ = lock(descriptor, LOCK_UN) }
        return try operation()
    }
}
