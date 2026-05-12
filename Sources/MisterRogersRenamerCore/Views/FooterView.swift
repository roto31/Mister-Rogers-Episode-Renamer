import SwiftUI

struct FooterView: View {
    @ObservedObject var viewModel: RenameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack(spacing: 12) {
                Button("Clear") { viewModel.clearSelection() }
                    .keyboardShortcut(.delete, modifiers: [])
                Spacer()
                if viewModel.isProcessing {
                    ProgressView()
                        .scaleEffect(0.85)
                }
                Button("Preview") { viewModel.previewRenames() }
                    .disabled(
                        viewModel.selectedFileURLs.isEmpty
                            || viewModel.isProcessing
                            || (viewModel.catalogMode == .theTvdbAnySeries && viewModel.activeTvdbCatalog == nil)
                    )
                    .keyboardShortcut(.return, modifiers: [.command])
                Button("Rename Files") {
                    viewModel.commitRenames()
                }
                .disabled(viewModel.readyToRenameCount == 0 || viewModel.isProcessing)
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
            if let manifest = BundledEpisodeDataManifest.shared {
                Text(
                    "Bundled catalog \(manifest.dataRevision) · \(manifest.digestPrefix)"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.top, 8)
    }
}
