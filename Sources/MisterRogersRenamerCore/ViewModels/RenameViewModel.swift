import AppKit
import Combine
import Foundation

@MainActor
final class RenameViewModel: NSObject, ObservableObject {
    enum CatalogMode: String, CaseIterable, Identifiable {
        case misterRogersBundled = "Mister Rogers (bundled)"
        case theTvdbAnySeries = "Any series (TheTVDB)"

        var id: String { rawValue }
    }

    enum Phase: Equatable {
        case welcome
        case preview
        case results
    }

    @Published var selectedFileURLs: [URL] = []
    @Published var scanSubfoldersRecursively: Bool = false
    @Published var renameOperations: [FileRenameOperation] = []
    @Published var phase: Phase = .welcome
    @Published var isProcessing: Bool = false
    @Published var isDryRunMode: Bool = true

    /// Last successful renames for one-level undo: `(finalURL, originalURL)`.
    @Published private(set) var lastUndoPairs: [(movedTo: URL, original: URL)] = []

    @Published var catalogMode: CatalogMode = .misterRogersBundled {
        didSet {
            guard oldValue != catalogMode else { return }
            renameOperations = []
            phase = .welcome
            lastUndoPairs = []
        }
    }

    @Published var tvdbSeriesInput: String = ""
    @Published var tvdbApiKeyDraft: String = ""
    /// Non-secret hint: whether a key is stored or env is set (for UI).
    @Published private(set) var hasResolvedTvdbApiKey: Bool = false

    @Published var tvdbLoadError: String?
    @Published var isLoadingTvdb: Bool = false
    @Published private(set) var activeTvdbCatalog: TvdbEpisodeCatalog?
    @Published private(set) var loadedTvdbSeriesId: Int?

    private let database = EpisodeDatabase.shared

    override init() {
        super.init()
        refreshTvdbKeyHint()
    }

    func refreshTvdbKeyHint() {
        hasResolvedTvdbApiKey = TVDBAPIKeyStore.resolvedAPIKey() != nil
    }

    func saveTvdbApiKeyToKeychain() {
        tvdbLoadError = nil
        do {
            try TVDBAPIKeyStore.saveToKeychain(tvdbApiKeyDraft)
            tvdbApiKeyDraft = ""
            refreshTvdbKeyHint()
        } catch {
            tvdbLoadError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadTheTvdbSeries() {
        tvdbLoadError = nil
        guard let seriesId = TvdbSeriesIDParser.parseSeriesID(from: tvdbSeriesInput) else {
            tvdbLoadError = "Enter a numeric series id or paste a TheTVDB series URL (path must contain /series/<id>)."
            return
        }
        guard let apiKey = TVDBAPIKeyStore.resolvedAPIKey(), !apiKey.isEmpty else {
            tvdbLoadError =
                "Add your TheTVDB v4 API key: paste it below and click Save, or set the TVDB_API_KEY environment variable."
            return
        }
        isLoadingTvdb = true
        Task {
            do {
                let catalog = try await TheTvdbClient.loadCatalog(apiKey: apiKey, seriesId: seriesId)
                await MainActor.run {
                    self.activeTvdbCatalog = catalog
                    self.loadedTvdbSeriesId = seriesId
                    self.isLoadingTvdb = false
                }
            } catch {
                await MainActor.run {
                    self.tvdbLoadError = error.localizedDescription
                    self.isLoadingTvdb = false
                }
            }
        }
    }

    private func makeRenameService() -> RenameService? {
        switch catalogMode {
        case .misterRogersBundled:
            return RenameService(catalog: MRNEpisodeCatalog.shared, matchStrategy: .productionNumber)
        case .theTvdbAnySeries:
            guard let catalog = activeTvdbCatalog else { return nil }
            return RenameService(catalog: catalog, matchStrategy: .seasonEpisode)
        }
    }

    var totalEpisodesInDatabase: Int {
        switch catalogMode {
        case .misterRogersBundled:
            return database.count()
        case .theTvdbAnySeries:
            return activeTvdbCatalog?.episodeCount ?? 0
        }
    }

    var readyToRenameCount: Int {
        renameOperations.filter(\.isReadyToRename).count
    }

    var successfulRenamesCount: Int {
        renameOperations.filter {
            if case .renamed = $0.status { return true }
            return false
        }.count
    }

    var skippedCount: Int {
        renameOperations.filter {
            if case .skipped = $0.status { return true }
            return false
        }.count
    }

    var errorCount: Int {
        renameOperations.filter {
            if case .error = $0.status { return true }
            return false
        }.count
    }

    func selectFiles() {
        let panel = NSOpenPanel()
        panel.title = "Select Video Files"
        panel.prompt = "Select"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.resolvesAliases = true

        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        guard !urls.isEmpty else { return }
        mergeSelection(urls)
        phase = .welcome
    }

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Folder"
        panel.prompt = "Choose"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.resolvesAliases = true

        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        guard !urls.isEmpty else { return }
        mergeSelection(urls)
        phase = .welcome
    }

    func addDroppedFileURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        mergeSelection(urls)
        phase = .welcome
    }

    private func mergeSelection(_ urls: [URL]) {
        var seen = Set(selectedFileURLs.map { $0.standardizedFileURL.path })
        var combined = selectedFileURLs
        for url in urls {
            let path = url.standardizedFileURL.path
            if seen.insert(path).inserted {
                combined.append(url)
            }
        }
        selectedFileURLs = combined
    }

    func previewRenames() {
        guard !selectedFileURLs.isEmpty else { return }
        if catalogMode == .theTvdbAnySeries, activeTvdbCatalog == nil {
            tvdbLoadError = "Load a TheTVDB series first (series URL or id, then Load)."
            return
        }
        guard let service = makeRenameService() else {
            tvdbLoadError = "Load a TheTVDB series first."
            return
        }
        isProcessing = true
        isDryRunMode = true
        let selections = selectedFileURLs
        let recursive = scanSubfoldersRecursively

        DispatchQueue.global(qos: .userInitiated).async {
            let operations = service.planRenames(for: selections, recursive: recursive)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.renameOperations = operations
                self.phase = .preview
                self.isProcessing = false
            }
        }
    }

    func commitRenames() {
        let pending = renameOperations.filter(\.isReadyToRename)
        guard !pending.isEmpty else { return }
        isProcessing = true
        isDryRunMode = false
        let snapshot = renameOperations

        DispatchQueue.global(qos: .userInitiated).async {
            let executed = RenameService.executePendingRenames(pending)
            let updatesByID = Dictionary(uniqueKeysWithValues: executed.map { ($0.id, $0) })
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.renameOperations = snapshot.map { updatesByID[$0.id] ?? $0 }

                var pairs: [(URL, URL)] = []
                for op in executed {
                    if case .renamed = op.status {
                        pairs.append((op.targetURL, op.sourceURL))
                    }
                }
                self.lastUndoPairs = pairs.map { (movedTo: $0.0, original: $0.1) }

                self.phase = .results
                self.isProcessing = false
            }
        }
    }

    func undoLastRenames() {
        guard !lastUndoPairs.isEmpty else { return }
        let pairs = lastUndoPairs
        lastUndoPairs = []
        isProcessing = true

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            for pair in pairs.reversed() {
                if fm.fileExists(atPath: pair.movedTo.path) {
                    try? fm.moveItem(at: pair.movedTo, to: pair.original)
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isProcessing = false
                self.previewRenames()
            }
        }
    }

    func reset() {
        selectedFileURLs = []
        renameOperations = []
        phase = .welcome
        isProcessing = false
        isDryRunMode = true
        lastUndoPairs = []
    }

    func clearSelection() {
        selectedFileURLs = []
        renameOperations = []
        phase = .welcome
        lastUndoPairs = []
    }

    func openCommonParentInFinder() {
        guard let folder = renameOperations.first?.sourceURL.deletingLastPathComponent() else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path)
    }
}
