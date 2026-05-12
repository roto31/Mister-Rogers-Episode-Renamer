import Foundation

/// Metadata for the bundled MRN `episodes.json` resource (see `episodes.manifest.json`).
struct BundledEpisodeDataManifest: Decodable, Sendable {
    let dataset: String
    let tvdbSeriesId: Int
    let dataRevision: String
    let contentSha256: String
    let generatedAt: String

    static let shared: BundledEpisodeDataManifest? = {
        guard let url = Bundle.module.url(forResource: "episodes.manifest", withExtension: "json")
        else { return nil }
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(BundledEpisodeDataManifest.self, from: data)
    }()

    /// Short fingerprint for footer / support prompts.
    var digestPrefix: String {
        let hex = contentSha256
        if hex.count <= 16 { return hex }
        let end = hex.index(hex.startIndex, offsetBy: 8)
        return "\(hex[..<end])…"
    }
}
