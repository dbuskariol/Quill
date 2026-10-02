import Darwin
import Foundation

struct LibraryRevision: Identifiable, Sendable {
    var id: String { url.lastPathComponent }
    let url: URL
    let date: Date
}

actor LibraryRepository {
    let url: URL
    private var observedData: Data?
    init(url: URL) { self.url = url }

    static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "Quill/library.json")
    }
    var historyURL: URL { url.deletingLastPathComponent().appending(path: "Quill History", directoryHint: .isDirectory) }

    func load() throws -> Library {
        try withFileLock {
            guard FileManager.default.fileExists(atPath: url.path) else {
                let starter = Library.starter
                try saveLocked(starter)
                return starter
            }
            let data = try Data(contentsOf: url)
            let library = try Self.decode(data)
            observedData = data
            return library
        }
    }

    static func decode(_ data: Data) throws -> Library {
        guard data.count <= 50_000_000 else { throw LibraryError.invalid("Library exceeds the 50 MB import limit.") }
        let library = try JSONDecoder().decode(Library.self, from: data)
        try library.validate()
        return library
    }

    func saveNew(_ library: Library) throws {
        try withFileLock {
            guard !FileManager.default.fileExists(atPath: url.path) else {
                throw LibraryError.invalid("The selected folder already contains library.json. Import it explicitly or choose an empty folder.")
            }
            try saveLocked(library)
        }
    }

    func save(_ library: Library) throws { try withFileLock { try saveLocked(library) } }

    private func saveLocked(_ library: Library) throws {
        try library.validate()
        let data = try Self.encode(library)
        let current = try currentData()
        if let observedData, current != observedData {
            throw LibraryError.invalid("The library changed outside Quill. Reopen it before saving; your draft is preserved.")
        }
        if let current {
            _ = try Self.decode(current) // Normal saves must never overwrite corrupt data.
            try archive(current)
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        observedData = data
    }

    static func encode(_ library: Library) throws -> Data {
        try library.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(library)
    }

    func backup() throws -> URL {
        try withFileLock {
            guard let data = try currentData() else { throw LibraryError.invalid("No library file exists yet.") }
            return try archive(data)
        }
    }

    func revisions() throws -> [LibraryRevision] {
        guard FileManager.default.fileExists(atPath: historyURL.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: historyURL, includingPropertiesForKeys: [.creationDateKey])
            .filter { $0.pathExtension == "json" }
            .map { LibraryRevision(url: $0, date: try $0.resourceValues(forKeys: [.creationDateKey]).creationDate ?? .distantPast) }
            .sorted { $0.date > $1.date }
    }

    func read(_ source: URL) throws -> Library {
        let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 50_000_000 else { throw LibraryError.invalid("Library exceeds the 50 MB import limit.") }
        return try Self.decode(Data(contentsOf: source))
    }
    func export(_ library: Library, to destination: URL) throws {
        try exportData(Self.encode(library), to: destination)
    }
    func exportData(_ data: Data, to destination: URL) throws {
        guard destination.resolvingSymlinksInPath().standardizedFileURL != url.resolvingSymlinksInPath().standardizedFileURL else {
            throw LibraryError.invalid("Choose an export file outside the active library.")
        }
        try data.write(to: destination, options: .atomic)
    }

    // Explicit recovery archives the damaged bytes before replacing them with a validated revision.
    func recover(from source: URL) throws -> Library {
        let library = try read(source)
        return try withFileLock {
            if let current = try currentData() { try archive(current) }
            let data = try Self.encode(library)
            try data.write(to: url, options: .atomic)
            observedData = data
            return library
        }
    }

    // Advisory coordination across Quill processes, with a nonblocking failure path.
    // External editors do not participate; observedData still detects their stale replacements.
    private func withFileLock<T>(_ operation: () throws -> T) throws -> T {
        let directory = url.resolvingSymlinksInPath().deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let lockURL = directory.appending(path: ".quill-library.lock")
        let descriptor = Darwin.open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw LibraryError.invalid("Could not open the library coordination lock.") }
        defer { _ = Darwin.close(descriptor) }
        let lockOperation: @convention(c) (Int32, Int32) -> Int32 = flock
        guard lockOperation(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            throw LibraryError.invalid("Another Quill operation is using this library. Retry shortly; your changes are preserved.")
        }
        defer { _ = lockOperation(descriptor, LOCK_UN) }
        return try operation()
    }

    private func currentData() throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    @discardableResult private func archive(_ data: Data) throws -> URL {
        try FileManager.default.createDirectory(at: historyURL, withIntermediateDirectories: true)
        let destination = historyURL.appending(path: "\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString).json")
        try data.write(to: destination, options: .atomic)
        return destination
    }
}
