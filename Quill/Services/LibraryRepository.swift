import Foundation

actor LibraryRepository {
    let url: URL
    init(url: URL) { self.url = url }

    static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "Quill/library.json")
    }

    func load() throws -> Library {
        guard FileManager.default.fileExists(atPath: url.path) else {
            let starter = Library.starter
            try save(starter)
            return starter
        }
        let library = try JSONDecoder().decode(Library.self, from: Data(contentsOf: url))
        try library.validate()
        return library
    }

    func save(_ library: Library) throws {
        try library.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(library)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Foundation stages beside the destination and replaces it atomically.
        try data.write(to: url, options: .atomic)
    }
}
