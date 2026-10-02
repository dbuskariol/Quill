import Foundation
import SQLite3

/// Synchronous, actor-confined connection. No pointer or statement leaves the repository operation.
final class LibraryDatabase {
    enum Value: Sendable {
        case text(String), blob(Data), integer(Int64), real(Double), null
        var string: String? { if case .text(let s) = self { s } else { nil } }
        var data: Data? { if case .blob(let d) = self { d } else { nil } }
        var int: Int64? { if case .integer(let n) = self { n } else { nil } }
        var double: Double? { if case .real(let n) = self { n } else { nil } }
    }
    private var handle: OpaquePointer?
    init(url: URL, readOnly: Bool = false) throws {
        guard sqlite3_open_v2(url.path, &handle, (readOnly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE) | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else { let error = failure(); sqlite3_close(handle); handle = nil; throw error }
        sqlite3_busy_timeout(handle, 500)
        do {
            let version = try query("PRAGMA user_version").first?.first?.int ?? 0
            guard version == 1 || (version == 0 && !readOnly) else { throw LibraryError.invalid("Unsupported database version: \(version).") }
            if version == 0 {
                guard try query("SELECT name FROM sqlite_master WHERE type='table'").isEmpty else { throw LibraryError.invalid("This is not a Quill library database.") }
            }
            try execute("PRAGMA foreign_keys=ON")
            if !readOnly {
                _ = try query("PRAGMA journal_mode=DELETE")
                try execute("PRAGMA synchronous=FULL")
            }
            if version == 0 {
                try transaction {
                    try execute("CREATE TABLE library_state (id INTEGER PRIMARY KEY CHECK(id=1), generation INTEGER NOT NULL, payload BLOB NOT NULL)")
                    try execute("CREATE TABLE item_revisions (id TEXT PRIMARY KEY, item_id TEXT NOT NULL, parent_id TEXT REFERENCES item_revisions(id) ON DELETE SET NULL, transaction_id TEXT NOT NULL, created REAL NOT NULL, reason TEXT NOT NULL, deleted INTEGER NOT NULL, protected INTEGER NOT NULL DEFAULT 0, hash TEXT NOT NULL, payload BLOB NOT NULL)")
                    try execute("CREATE INDEX revision_items ON item_revisions(item_id, created DESC)")
                    try execute("CREATE TABLE drafts (item_id TEXT PRIMARY KEY, payload BLOB NOT NULL)")
                    try execute("CREATE TABLE preferences (key TEXT PRIMARY KEY, value INTEGER NOT NULL)")
                    try execute("INSERT INTO preferences VALUES ('history_limit', 100)")
                    try execute("PRAGMA user_version=1")
                }
            }
        } catch { sqlite3_close(handle); handle = nil; throw error }
    }
    deinit { sqlite3_close(handle) }
    private func failure() -> LibraryError {
        // SQLite messages contain diagnostics, never SQL-bound template content.
        .invalid("Library database: \(handle.map { String(cString: sqlite3_errmsg($0)) } ?? "could not open storage").")
    }
    func execute(_ sql: String, _ values: [Value] = []) throws { _ = try query(sql, values) }
    func query(_ sql: String, _ values: [Value] = []) throws -> [[Value]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else { throw failure() }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch value {
            case .text(let string): result = string.withCString { sqlite3_bind_text(statement, index, $0, Int32(string.utf8.count), transient) }
            case .blob(let data): result = data.withUnsafeBytes { sqlite3_bind_blob(statement, index, $0.baseAddress, Int32(data.count), transient) }
            case .integer(let n): result = sqlite3_bind_int64(statement, index, n)
            case .real(let n): result = sqlite3_bind_double(statement, index, n)
            case .null: result = sqlite3_bind_null(statement, index)
            }
            guard result == SQLITE_OK else { throw failure() }
        }
        var rows: [[Value]] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { return rows }
            guard result == SQLITE_ROW else { throw failure() }
            rows.append((0..<sqlite3_column_count(statement)).map { index in
                switch sqlite3_column_type(statement, index) {
                case SQLITE_INTEGER: .integer(sqlite3_column_int64(statement, index))
                case SQLITE_FLOAT: .real(sqlite3_column_double(statement, index))
                case SQLITE_TEXT: .text(String(cString: sqlite3_column_text(statement, index)))
                case SQLITE_BLOB: .blob(Data(bytes: sqlite3_column_blob(statement, index), count: Int(sqlite3_column_bytes(statement, index))))
                default: .null
                }
            })
        }
    }
    func backup(to destination: URL) throws {
        var output: OpaquePointer?
        guard sqlite3_open_v2(destination.path, &output, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            sqlite3_close(output); throw LibraryError.invalid("Could not create the library backup.")
        }
        defer { sqlite3_close(output) }
        guard let backup = sqlite3_backup_init(output, "main", handle, "main") else { throw LibraryError.invalid("Could not start the library backup.") }
        let step = sqlite3_backup_step(backup, -1)
        let finish = sqlite3_backup_finish(backup)
        guard step == SQLITE_DONE, finish == SQLITE_OK else { throw LibraryError.invalid("Could not finish a consistent library backup. Retry after other operations finish.") }
    }
    func transaction<T>(isolation: isolated (any Actor)? = #isolation, _ operation: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE")
        do { let result = try operation(); try execute("COMMIT"); return result }
        catch { try? execute("ROLLBACK"); throw error }
    }
}
