import Foundation

private struct TvdbLoginBody: Encodable {
    let apikey: String
}

private struct TvdbAuthResponse: Decodable {
    let status: String
    let data: TokenData

    struct TokenData: Decodable {
        let token: String
    }
}

private struct TvdbSeriesResponse: Decodable {
    let status: String
    let data: SeriesData

    struct SeriesData: Decodable {
        let name: String?
    }
}

private struct TvdbEpisodesPageResponse: Decodable {
    let status: String
    let data: EpisodesBlock
    let links: PageLinks?

    struct EpisodesBlock: Decodable {
        let episodes: [TvdbEpisodeDTO]
    }

    struct PageLinks: Decodable {
        let next: Int?
    }
}

private struct TvdbEpisodeDTO: Decodable {
    let id: Int
    let seasonNumber: Int?
    let number: Int?
    let name: String?
    let aired: String?
}

enum TheTvdbError: Error, LocalizedError {
    case invalidURL
    case httpStatus(Int, String)
    case tvdbStatus(String)
    case decodeFailed
    case missingSeriesName

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid TheTVDB URL."
        case let .httpStatus(code, body):
            return "TheTVDB HTTP \(code): \(body.prefix(200))"
        case let .tvdbStatus(status):
            return "TheTVDB error: \(status)"
        case .decodeFailed:
            return "Could not parse TheTVDB response."
        case .missingSeriesName:
            return "Series title missing from TheTVDB response."
        }
    }
}

final class TheTvdbClient {
    private let session: URLSession
    private let baseURL = URL(string: "https://api4.thetvdb.com/v4")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func login(apiKey: String) async throws -> String {
        let url = baseURL.appendingPathComponent("login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(TvdbLoginBody(apikey: apiKey))

        let (data, response) = try await session.data(for: request)
        try throwIfHTTPError(data: data, response: response)
        let decoded = try JSONDecoder().decode(TvdbAuthResponse.self, from: data)
        guard decoded.status == "success" else {
            throw TheTvdbError.tvdbStatus(decoded.status)
        }
        return decoded.data.token
    }

    func fetchSeriesTitle(token: String, seriesId: Int) async throws -> String {
        let url = baseURL
            .appendingPathComponent("series")
            .appendingPathComponent("\(seriesId)")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try throwIfHTTPError(data: data, response: response)
        let decoded = try JSONDecoder().decode(TvdbSeriesResponse.self, from: data)
        guard decoded.status == "success" else {
            throw TheTvdbError.tvdbStatus(decoded.status)
        }
        let name = decoded.data.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else { throw TheTvdbError.missingSeriesName }
        return name
    }

    func fetchEpisodesAiredEnglish(token: String, seriesId: Int) async throws -> [Episode] {
        try await fetchEpisodes(token: token, seriesId: seriesId, language: "eng", order: "default")
    }

    private func fetchEpisodes(token: String, seriesId: Int, language: String, order: String) async throws -> [Episode] {
        var all: [Episode] = []
        var page = 0
        while true {
            let episodesURL = baseURL
                .appendingPathComponent("series")
                .appendingPathComponent("\(seriesId)")
                .appendingPathComponent("episodes")
                .appendingPathComponent(order)
                .appendingPathComponent(language)
            guard var components = URLComponents(url: episodesURL, resolvingAgainstBaseURL: false) else {
                throw TheTvdbError.invalidURL
            }
            components.queryItems = [URLQueryItem(name: "page", value: "\(page)")]
            guard let url = components.url else { throw TheTvdbError.invalidURL }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await session.data(for: request)
            try throwIfHTTPError(data: data, response: response)

            let decoded = try JSONDecoder().decode(TvdbEpisodesPageResponse.self, from: data)
            guard decoded.status == "success" else {
                throw TheTvdbError.tvdbStatus(decoded.status)
            }
            for dto in decoded.data.episodes {
                if let ep = Self.mapEpisode(dto) {
                    all.append(ep)
                }
            }
            if decoded.links?.next == nil {
                break
            }
            page += 1
        }
        return all
    }

    private static func mapEpisode(_ dto: TvdbEpisodeDTO) -> Episode? {
        let season = dto.seasonNumber ?? 0
        let epNum = dto.number ?? 0
        let titleRaw = dto.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = titleRaw.isEmpty ? "Untitled" : titleRaw
        let air = dto.aired?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Episode(
            id: dto.id,
            season: season,
            episode: epNum,
            title: title,
            airDate: air,
            source: "TheTVDB"
        )
    }

    private func throwIfHTTPError(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw TheTvdbError.httpStatus(http.statusCode, text)
        }
    }
}

extension TheTvdbClient {
    /// Login, fetch title + aired/default episodes, optionally read/write disk cache.
    static func loadCatalog(
        apiKey: String,
        seriesId: Int,
        language: String = "eng",
        client: TheTvdbClient = TheTvdbClient(),
        useCache: Bool = true
    ) async throws -> TvdbEpisodeCatalog {
        if useCache, let cached = TvdbCatalogCache.load(seriesId: seriesId, language: language) {
            return TvdbEpisodeCatalog.build(seriesTitle: cached.seriesTitle, episodes: cached.episodes)
        }

        let token = try await client.login(apiKey: apiKey)
        async let titleTask = client.fetchSeriesTitle(token: token, seriesId: seriesId)
        async let episodesTask = client.fetchEpisodesAiredEnglish(token: token, seriesId: seriesId)
        let (title, episodes) = try await (titleTask, episodesTask)

        if useCache {
            let payload = TvdbCachedPayload(
                seriesId: seriesId,
                seriesTitle: title,
                language: language,
                episodes: episodes,
                savedAt: Date()
            )
            try? TvdbCatalogCache.save(payload)
        }

        return TvdbEpisodeCatalog.build(seriesTitle: title, episodes: episodes)
    }
}
