import Foundation

/// Tiny JSON-file persistence. Deliberately not SwiftData/Core Data: our data is
/// small (hundreds of workouts), Codable, and this has zero migration surprises.
/// Supabase sync can sit on top of these same Codable types later.
enum LocalStore {
    private static var directory: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GPSGym", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func load<T: Decodable>(_ type: T.Type, from file: String) -> T? {
        let url = directory.appendingPathComponent(file)
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            print("LocalStore: failed to decode \(file): \(error)")
            return nil
        }
    }

    static func save<T: Encodable>(_ value: T?, to file: String) {
        let url = directory.appendingPathComponent(file)
        guard let value else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        do {
            try encoder.encode(value).write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            print("LocalStore: failed to save \(file): \(error)")
        }
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
    }
}
