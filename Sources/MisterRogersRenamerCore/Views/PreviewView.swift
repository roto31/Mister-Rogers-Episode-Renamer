import SwiftUI

struct PreviewRowView: View {
    let operation: FileRenameOperation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            indicator
            VStack(alignment: .leading, spacing: 4) {
                Text(operation.sourceURL.lastPathComponent)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Text(arrowLabel)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(detailLine)
                    .font(.caption)
                    .foregroundColor(detailColor)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private var indicator: some View {
        switch operation.status {
        case .willRename:
            return StatusIndicator(kind: .neutral)
        case .skipped:
            return StatusIndicator(kind: .warning)
        case .error:
            return StatusIndicator(kind: .error)
        case .renamed:
            return StatusIndicator(kind: .success)
        }
    }

    private var arrowLabel: String {
        switch operation.status {
        case .willRename(let name), .renamed(let name):
            return "→ \(name)"
        case .skipped(let reason), .error(let reason):
            return reason
        }
    }

    private var detailLine: String {
        switch operation.status {
        case .willRename:
            return "Will rename (preview / dry run)"
        case .skipped(let reason):
            return reason
        case .error(let reason):
            return reason
        case .renamed(let name):
            return "Renamed to \(name)"
        }
    }

    private var detailColor: Color {
        switch operation.status {
        case .willRename:
            return MRColor.primary
        case .skipped:
            return MRColor.warning
        case .error:
            return MRColor.error
        case .renamed:
            return MRColor.success
        }
    }
}

struct PreviewView: View {
    @ObservedObject var viewModel: RenameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rename preview")
                    .font(.title3.weight(.semibold))
                Button("Change files") {
                    viewModel.phase = .welcome
                }
                .keyboardShortcut("[", modifiers: [.command])
                Spacer()
                Label("Dry run", systemImage: "eye")
                    .font(.footnote.weight(.semibold))
                    .padding(8)
                    .background(MRColor.primary.opacity(0.12))
                    .cornerRadius(8)
            }

            Text("\(viewModel.renameOperations.count) file(s) · \(viewModel.readyToRenameCount) ready · Catalog: \(viewModel.totalEpisodesInDatabase) episodes")
                .font(.footnote)
                .foregroundColor(.secondary)

            Divider()

            if viewModel.renameOperations.isEmpty {
                Text("Run Preview after selecting files.")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.renameOperations) { op in
                            PreviewRowView(operation: op)
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
