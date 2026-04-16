import Foundation

actor AppCacheStore {
    static let shared = AppCacheStore()

    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let directoryURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        directoryURL = baseDirectory
            .appendingPathComponent("CoListCache", isDirectory: true)

        try? fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    func load<Value: Decodable>(_ type: Value.Type, for key: String) -> Value? {
        let fileURL = fileURL(for: key)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func save<Value: Encodable>(_ value: Value, for key: String) {
        let fileURL = fileURL(for: key)
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    func removeValue(for key: String) {
        try? fileManager.removeItem(at: fileURL(for: key))
    }

    private func fileURL(for key: String) -> URL {
        directoryURL.appendingPathComponent("\(key).json", isDirectory: false)
    }
}
