import Foundation

// MARK: - File utilities

enum FileUtils {
    static let supportedExtensions: Set<String> = [
        "mp4", "mkv", "avi", "mov", "m4v", "webm", "flv", "ts", "mpg", "mpeg"
    ]

    static func isSupportedVideoFile(_ url: URL) -> Bool {
        fileExtension(url).map { supportedExtensions.contains($0) } ?? false
    }

    static func baseFileName(_ url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }

    static func fileExtension(_ url: URL) -> String? {
        let e = url.pathExtension
        guard !e.isEmpty else { return nil }
        return e.lowercased()
    }

    /// Collects supported video files under `directoryURL`. When `recursive` is false, only the immediate directory is scanned.
    static func getVideoFiles(in directoryURL: URL, recursive: Bool) -> [URL] {
        let fm = FileManager.default
        guard let isDir = try? directoryURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir else {
            return []
        }

        if !recursive {
            guard let contents = try? fm.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }
            return contents.filter { isSupportedVideoFile($0) }.sorted { $0.path < $1.path }
        }

        guard let enumerator = fm.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var result: [URL] = []
        for case let fileURL as URL in enumerator {
            guard let isRegular = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isRegular else {
                continue
            }
            if isSupportedVideoFile(fileURL) {
                result.append(fileURL)
            }
        }
        return result.sorted { $0.path < $1.path }
    }

    static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    static func parentDirectoryIsWritable(_ fileURL: URL) -> Bool {
        let parent = fileURL.deletingLastPathComponent()
        return FileManager.default.isWritableFile(atPath: parent.path)
    }
}

// MARK: - Production number extraction

enum ProductionNumberExtractor {
    /// PBS-style production numbers on the Archive run from 1 through 1765 (often written with leading zeros).
    private static let productionRange: ClosedRange<Int> = 1...1800
    /// Four-digit values in this band are usually calendar years in filenames, not production numbers.
    private static let yearAmbiguityRange: ClosedRange<Int> = 1968...2001

    /// Extracts a production number from the filename stem: first 4-digit run in `productionRange`
    /// that is not in `yearAmbiguityRange`, scanned left to right.
    static func extract(from filename: String) -> Int? {
        let stem = (filename as NSString).deletingPathExtension
        let ns = stem as NSString
        guard let regex = try? NSRegularExpression(pattern: "\\d{4}", options: []) else {
            return nil
        }
        let full = NSRange(location: 0, length: ns.length)
        var found: Int?
        regex.enumerateMatches(in: stem, options: [], range: full) { result, _, stop in
            guard found == nil, let result, result.range.location != NSNotFound else { return }
            let substr = ns.substring(with: result.range)
            guard let value = Int(substr),
                  productionRange.contains(value),
                  !yearAmbiguityRange.contains(value) else { return }
            found = value
            stop.pointee = true
        }
        return found
    }
}

// MARK: - Target filename formatting

enum FilenameFormatter {
    private static let invalidFilenameCharacters = CharacterSet(charactersIn: "<>:\"/\\|?*")
        .union(.controlCharacters)

    static func format(season: Int, episode: Int, title: String, showTitle: String, extension ext: String) -> String {
        let safeTitle = sanitizeTitle(title)
        let safeShow = sanitizeTitle(showTitle)
        let extPart = ext.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let dotExt = extPart.isEmpty ? "" : ".\(extPart)"
        return "S\(season)E\(episode) - \(safeShow) - \"\(safeTitle)\"\(dotExt)"
    }

    static func sanitizeTitle(_ title: String) -> String {
        let cleaned = title.unicodeScalars.map { scalar -> String in
            if invalidFilenameCharacters.contains(scalar) {
                return ""
            }
            return String(scalar)
        }.joined()
        let collapsed = cleaned
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.isEmpty ? "Untitled" : collapsed
    }

    /// Display name without extension for comparison (already-renamed detection).
    static func formattedBaseName(season: Int, episode: Int, title: String, showTitle: String) -> String {
        let safeTitle = sanitizeTitle(title)
        let safeShow = sanitizeTitle(showTitle)
        return "S\(season)E\(episode) - \(safeShow) - \"\(safeTitle)\""
    }
}

// MARK: - Rename operation & service

struct FileRenameOperation: Identifiable {
    let id: UUID
    let sourceURL: URL
    let targetURL: URL
    let episode: Episode?
    var status: RenameStatus

    enum RenameStatus: Equatable {
        case willRename(targetName: String)
        case skipped(reason: String)
        case error(reason: String)
        case renamed(targetName: String)
    }

    init(
        id: UUID = UUID(),
        sourceURL: URL,
        targetURL: URL,
        episode: Episode?,
        status: RenameStatus
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.targetURL = targetURL
        self.episode = episode
        self.status = status
    }

    var isReadyToRename: Bool {
        if case .willRename = status { return true }
        return false
    }

    var targetFileName: String {
        targetURL.lastPathComponent
    }
}

// MARK: - Rename matching

enum RenameMatchStrategy: Sendable {
    case productionNumber
    case seasonEpisode
}

final class RenameService: @unchecked Sendable {
    private let catalog: EpisodeCatalog
    private let matchStrategy: RenameMatchStrategy
    private let fileManager: FileManager

    init(catalog: EpisodeCatalog, matchStrategy: RenameMatchStrategy, fileManager: FileManager = .default) {
        self.catalog = catalog
        self.matchStrategy = matchStrategy
        self.fileManager = fileManager
    }

    /// Expands folders and files into a flat list of supported video URLs, preserving stable ordering.
    func expandedVideoURLs(from selections: [URL], recursive: Bool) -> [URL] {
        var collected: [URL] = []
        var seen = Set<String>()
        for url in selections {
            if FileUtils.isDirectory(url) {
                for video in FileUtils.getVideoFiles(in: url, recursive: recursive) {
                    if seen.insert(video.standardizedFileURL.path).inserted {
                        collected.append(video)
                    }
                }
            } else if FileUtils.isSupportedVideoFile(url), seen.insert(url.standardizedFileURL.path).inserted {
                collected.append(url)
            }
        }
        return collected
    }

    func planRenames(for selections: [URL], recursive: Bool) -> [FileRenameOperation] {
        let videos = expandedVideoURLs(from: selections, recursive: recursive)
        var claimedTargets = Set<String>()
        return videos.map { planOne(sourceURL: $0, claimedTargets: &claimedTargets) }
    }

    private func planOne(sourceURL: URL, claimedTargets: inout Set<String>) -> FileRenameOperation {
        let base = FileUtils.baseFileName(sourceURL)

        if !FileUtils.parentDirectoryIsWritable(sourceURL) {
            return FileRenameOperation(
                sourceURL: sourceURL,
                targetURL: sourceURL,
                episode: nil,
                status: .skipped(reason: "Folder is not writable (check permissions).")
            )
        }

        let episode: Episode
        switch matchStrategy {
        case .productionNumber:
            guard let production = ProductionNumberExtractor.extract(from: base) else {
                return FileRenameOperation(
                    sourceURL: sourceURL,
                    targetURL: sourceURL,
                    episode: nil,
                    status: .skipped(reason: "No production number (see docs for valid ranges) found in filename.")
                )
            }
            guard let ep = catalog.lookupProduction(production) else {
                return FileRenameOperation(
                    sourceURL: sourceURL,
                    targetURL: sourceURL,
                    episode: nil,
                    status: .skipped(reason: "Production \(production) is not in the database yet.")
                )
            }
            episode = ep

        case .seasonEpisode:
            guard let pair = SeasonEpisodeExtractor.extract(from: base) else {
                return FileRenameOperation(
                    sourceURL: sourceURL,
                    targetURL: sourceURL,
                    episode: nil,
                    status: .skipped(reason: "No season/episode pattern (e.g. S01E02 or 1x02) found in filename.")
                )
            }
            switch catalog.lookupSeasonEpisode(season: pair.season, episode: pair.episode) {
            case .found(let ep):
                episode = ep
            case .notFound:
                return FileRenameOperation(
                    sourceURL: sourceURL,
                    targetURL: sourceURL,
                    episode: nil,
                    status: .skipped(
                        reason: "S\(pair.season)E\(pair.episode) is not in the loaded series."
                    )
                )
            case .ambiguous:
                return FileRenameOperation(
                    sourceURL: sourceURL,
                    targetURL: sourceURL,
                    episode: nil,
                    status: .skipped(
                        reason: "Multiple TheTVDB episodes share S\(pair.season)E\(pair.episode); cannot pick one automatically."
                    )
                )
            }
        }

        let showTitle = catalog.seriesTitle

        guard let ext = FileUtils.fileExtension(sourceURL) else {
            return FileRenameOperation(
                sourceURL: sourceURL,
                targetURL: sourceURL,
                episode: episode,
                status: .skipped(reason: "Missing or unsupported file extension.")
            )
        }

        let expectedBase = FilenameFormatter.formattedBaseName(
            season: episode.season,
            episode: episode.episode,
            title: episode.title,
            showTitle: showTitle
        )
        if base.caseInsensitiveCompare(expectedBase) == .orderedSame {
            return FileRenameOperation(
                sourceURL: sourceURL,
                targetURL: sourceURL,
                episode: episode,
                status: .skipped(reason: "File already matches the standard episode title.")
            )
        }

        let formatted = FilenameFormatter.format(
            season: episode.season,
            episode: episode.episode,
            title: episode.title,
            showTitle: showTitle,
            extension: ext
        )
        let target = sourceURL.deletingLastPathComponent().appendingPathComponent(formatted)
        let targetPath = target.standardizedFileURL.path

        if claimedTargets.contains(targetPath) {
            return FileRenameOperation(
                sourceURL: sourceURL,
                targetURL: target,
                episode: episode,
                status: .skipped(reason: "Another selected file already uses this target name.")
            )
        }

        if fileManager.fileExists(atPath: target.path) {
            let sameFile = sourceURL.standardizedFileURL == target.standardizedFileURL
            if !sameFile {
                return FileRenameOperation(
                    sourceURL: sourceURL,
                    targetURL: target,
                    episode: episode,
                    status: .skipped(reason: "Target already exists: \(target.lastPathComponent)")
                )
            }
        }

        claimedTargets.insert(targetPath)
        return FileRenameOperation(
            sourceURL: sourceURL,
            targetURL: target,
            episode: episode,
            status: .willRename(targetName: target.lastPathComponent)
        )
    }

    @discardableResult
    static func executePendingRenames(_ operations: [FileRenameOperation], fileManager: FileManager = .default) -> [FileRenameOperation] {
        var updated: [FileRenameOperation] = []
        for var op in operations {
            switch op.status {
            case .willRename:
                do {
                    try fileManager.moveItem(at: op.sourceURL, to: op.targetURL)
                    op.status = .renamed(targetName: op.targetURL.lastPathComponent)
                } catch {
                    op.status = .error(reason: error.localizedDescription)
                }
            default:
                break
            }
            updated.append(op)
        }
        return updated
    }

    @discardableResult
    func executeRenames(_ operations: [FileRenameOperation]) -> [FileRenameOperation] {
        Self.executePendingRenames(operations, fileManager: fileManager)
    }
}
