import SwiftUI

struct ResultRowView: View {
    let operation: FileRenameOperation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            indicator
            VStack(alignment: .leading, spacing: 4) {
                Text(operation.sourceURL.lastPathComponent)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Text(message)
                    .font(.caption)
                    .foregroundColor(messageColor)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private var indicator: some View {
        switch operation.status {
        case .renamed:
            return StatusIndicator(kind: .success)
        case .skipped:
            return StatusIndicator(kind: .warning)
        case .error:
            return StatusIndicator(kind: .error)
        case .willRename:
            return StatusIndicator(kind: .neutral)
        }
    }

    private var message: String {
        switch operation.status {
        case .renamed(let name):
            return "Renamed to \(name)"
        case .skipped(let reason):
            return reason
        case .error(let reason):
            return reason
        case .willRename(let name):
            return "Pending rename to \(name)"
        }
    }

    private var messageColor: Color {
        switch operation.status {
        case .renamed:
            return MRColor.success
        case .skipped:
            return MRColor.warning
        case .error:
            return MRColor.error
        case .willRename:
            return MRColor.neutral
        }
    }
}

struct ResultsView: View {
    @ObservedObject var viewModel: RenameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Results")
                .font(.title3.weight(.semibold))

            HStack(spacing: 12) {
                badge(title: "Renamed", value: viewModel.successfulRenamesCount, color: MRColor.success)
                badge(title: "Skipped", value: viewModel.skippedCount, color: MRColor.warning)
                badge(title: "Errors", value: viewModel.errorCount, color: MRColor.error)
            }

            HStack(spacing: 12) {
                Button("Open in Finder") { viewModel.openCommonParentInFinder() }
                Button("Start Over") { viewModel.reset() }
                if !viewModel.lastUndoPairs.isEmpty {
                    Button("Undo Last Batch") { viewModel.undoLastRenames() }
                        .keyboardShortcut("z", modifiers: [.command])
                }
            }

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.renameOperations) { op in
                        ResultRowView(operation: op)
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func badge(title: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.title2.weight(.bold))
                .foregroundColor(color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.1)))
    }
}
