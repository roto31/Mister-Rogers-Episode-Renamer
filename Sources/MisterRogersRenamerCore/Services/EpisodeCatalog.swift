import Foundation

enum SeasonEpisodeMatch: Equatable {
    case found(Episode)
    case notFound
    case ambiguous
}

/// Lookup source for rename planning (bundled MRN vs fetched TheTVDB series).
protocol EpisodeCatalog: AnyObject {
    var seriesTitle: String { get }

    func lookupProduction(_ productionNumber: Int) -> Episode?
    func lookupSeasonEpisode(season: Int, episode: Int) -> SeasonEpisodeMatch
}

final class MRNEpisodeCatalog: EpisodeCatalog {
    static let shared = MRNEpisodeCatalog()

    private let database: EpisodeDatabase

    init(database: EpisodeDatabase = .shared) {
        self.database = database
    }

    var seriesTitle: String { "Mister Rogers' Neighborhood" }

    func lookupProduction(_ productionNumber: Int) -> Episode? {
        database.getEpisode(productionNumber: productionNumber)
    }

    func lookupSeasonEpisode(season: Int, episode: Int) -> SeasonEpisodeMatch {
        .notFound
    }
}

/// In-memory index keyed by aired order season and episode number from TheTVDB.
final class TvdbEpisodeCatalog: EpisodeCatalog {
    let seriesTitle: String
    private let map: [String: Episode]
    private let ambiguousKeys: Set<String>

    let episodeCount: Int

    private init(seriesTitle: String, map: [String: Episode], ambiguousKeys: Set<String>, episodeCount: Int) {
        self.seriesTitle = seriesTitle
        self.map = map
        self.ambiguousKeys = ambiguousKeys
        self.episodeCount = episodeCount
    }

    static func build(seriesTitle: String, episodes: [Episode]) -> TvdbEpisodeCatalog {
        var building: [String: Episode] = [:]
        var collisions: Set<String> = []
        for ep in episodes {
            let k = mapKey(season: ep.season, episode: ep.episode)
            if collisions.contains(k) { continue }
            if let existing = building[k] {
                if existing.id != ep.id {
                    building.removeValue(forKey: k)
                    collisions.insert(k)
                }
            } else {
                building[k] = ep
            }
        }
        for k in collisions {
            building.removeValue(forKey: k)
        }
        return TvdbEpisodeCatalog(seriesTitle: seriesTitle, map: building, ambiguousKeys: collisions, episodeCount: building.count)
    }

    private static func mapKey(season: Int, episode: Int) -> String {
        "\(season):\(episode)"
    }

    func lookupProduction(_ productionNumber: Int) -> Episode? { nil }

    func lookupSeasonEpisode(season: Int, episode: Int) -> SeasonEpisodeMatch {
        let k = Self.mapKey(season: season, episode: episode)
        if ambiguousKeys.contains(k) { return .ambiguous }
        if let ep = map[k] { return .found(ep) }
        return .notFound
    }
}
