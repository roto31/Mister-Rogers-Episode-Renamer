import Foundation

/// A single Mister Rogers' Neighborhood episode keyed by PBS-style production number.
struct Episode: Codable, Identifiable, Hashable {
    /// Production number (primary key).
    let id: Int
    let season: Int
    let episode: Int
    let title: String
    let airDate: String
    let source: String

    var productionNumber: Int { id }

    init(
        id: Int,
        season: Int,
        episode: Int,
        title: String,
        airDate: String,
        source: String
    ) {
        self.id = id
        self.season = season
        self.episode = episode
        self.title = title
        self.airDate = airDate
        self.source = source
    }

    init(
        productionNumber: Int,
        season: Int,
        episode: Int,
        title: String,
        airDate: String,
        source: String
    ) {
        self.id = productionNumber
        self.season = season
        self.episode = episode
        self.title = title
        self.airDate = airDate
        self.source = source
    }
}

/// In-memory episode lookup with optional bundled JSON merge for future expansion.
final class EpisodeDatabase: @unchecked Sendable {
    static let shared = EpisodeDatabase()

    private let lock = NSLock()
    private var episodes: [Int: Episode] = [:]

    private init() {
        if let url = Bundle.module.url(forResource: "episodes", withExtension: "json") {
            loadEpisodesFromBundledJSONIfPresent(at: url)
        }
        if count() == 0 {
            seedVerifiedEpisodes()
        }
    }

    /// Loads episodes from JSON if present at `url` and merges into the database (later wins on key collision).
    func loadEpisodesFromBundledJSONIfPresent(at url: URL?) {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Episode].self, from: data)
            lock.lock()
            for ep in decoded {
                episodes[ep.id] = ep
            }
            lock.unlock()
        } catch {
            // Stub: no bundled JSON in v1 by default.
        }
    }

    func getEpisode(productionNumber: Int) -> Episode? {
        lock.lock()
        defer { lock.unlock() }
        return episodes[productionNumber]
    }

    func addEpisode(_ episode: Episode) {
        lock.lock()
        episodes[episode.id] = episode
        lock.unlock()
    }

    func getAllEpisodes() -> [Episode] {
        lock.lock()
        let all = Array(episodes.values).sorted { $0.id < $1.id }
        lock.unlock()
        return all
    }

    func count() -> Int {
        lock.lock()
        let c = episodes.count
        lock.unlock()
        return c
    }

    private func seedVerifiedEpisodes() {
        addEpisode(
            Episode(
                id: 1066,
                season: 3,
                episode: 1,
                title: "Models of the Homes in the Neighborhood of Make-Believe",
                airDate: "1970-02-02",
                source: "Neighborhood Archive"
            )
        )
        addEpisode(
            Episode(
                id: 1067,
                season: 3,
                episode: 2,
                title: "Trees",
                airDate: "1970-02-03",
                source: "Neighborhood Archive"
            )
        )
    }
}
