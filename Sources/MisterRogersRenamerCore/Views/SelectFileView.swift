import SwiftUI
import UniformTypeIdentifiers

struct SelectFileView: View {
    @ObservedObject var viewModel: RenameViewModel

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            catalogSection

            HStack(spacing: 12) {
                Button("Select Files") { viewModel.selectFiles() }
                    .keyboardShortcut("o", modifiers: [.command])
                Button("Select Folder") { viewModel.selectFolder() }
                Toggle("Scan subfolders", isOn: $viewModel.scanSubfoldersRecursively)
                    .help("When a folder is selected, include supported videos in nested folders.")
            }

            Text("Supported formats")
                .font(.subheadline.weight(.semibold))

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(Array(FileUtils.supportedExtensions).sorted(), id: \.self) { ext in
                    Text(ext.uppercased())
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                }
            }

            dropZone

            if !viewModel.selectedFileURLs.isEmpty {
                Text("\(viewModel.selectedFileURLs.count) item(s) selected")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Catalog source", selection: $viewModel.catalogMode) {
                ForEach(RenameViewModel.CatalogMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(catalogHelpText)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.catalogMode == .theTvdbAnySeries {
                TextField("TheTVDB series URL or numeric id", text: $viewModel.tvdbSeriesInput)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 8) {
                    SecureField("TheTVDB v4 API key", text: $viewModel.tvdbApiKeyDraft)
                        .textFieldStyle(.roundedBorder)
                    Button("Save key") {
                        viewModel.saveTvdbApiKeyToKeychain()
                    }
                    .disabled(viewModel.tvdbApiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Load series") {
                        viewModel.loadTheTvdbSeries()
                    }
                    .disabled(viewModel.isLoadingTvdb)
                }

                HStack(spacing: 8) {
                    if viewModel.isLoadingTvdb {
                        ProgressView()
                            .scaleEffect(0.75)
                        Text("Fetching…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if viewModel.hasResolvedTvdbApiKey {
                        Label("API key configured", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let err = viewModel.tvdbLoadError {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let cat = viewModel.activeTvdbCatalog, let sid = viewModel.loadedTvdbSeriesId {
                    Text("Loaded: \(cat.seriesTitle) (id \(sid), \(cat.episodeCount) episodes indexed)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var catalogHelpText: String {
        switch viewModel.catalogMode {
        case .misterRogersBundled:
            return "Match filenames using PBS-style 4-digit production numbers and the bundled episode list."
        case .theTvdbAnySeries:
            return "Paste your API key once, enter a series id or TheTVDB URL, load the series, then match files using S01E02 or 1x02 patterns in the filename."
        }
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
            .foregroundColor(MRColor.neutral.opacity(0.6))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.35))
            )
            .frame(height: 120)
            .overlay(
                Text("Drag and drop files or folders here")
                    .font(.callout)
                    .foregroundColor(.secondary)
            )
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers)
            }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var collected: [URL] = []
        let lock = NSLock()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    lock.lock()
                    collected.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            guard !collected.isEmpty else { return }
            viewModel.addDroppedFileURLs(collected)
        }
        return true
    }
}
