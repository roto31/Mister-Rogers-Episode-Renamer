import Foundation

struct TvdbCachedPayload: Codable {
    let seriesId: Int
    let seriesTitle: String
    let language: String
    let episodes: [Episode]
    let savedAt: Date
}

enum TvdbCatalogCache {
    private static let folderComponent = "MisterRogersRenamer"

    static func load(seriesId: Int, language: String) -> TvdbCachedPayload? {
        guard let url = try? cacheFileURL(seriesId: seriesId, language: language),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try? JSONDecoder().decode(TvdbCachedPayload.self, from: Data(contentsOf: url))
    }

    static func save(_ payload: TvdbCachedPayload) throws {
        let url = try cacheFileURL(seriesId: payload.seriesId, language: payload.language)
        let data = try JSONEncoder().encode(payload)
        let tmp = url.appendingPathExtension("tmp")
        try data.write(to: tmp, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmp, to: url)
    }

    static func cacheFileURL(seriesId: Int, language: String) throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent(folderComponent, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let safeLang = language.replacingOccurrences(of: "/", with: "_")
        return dir.appendingPathComponent("tvdb-\(seriesId)-\(safeLang).json")
    }
}
