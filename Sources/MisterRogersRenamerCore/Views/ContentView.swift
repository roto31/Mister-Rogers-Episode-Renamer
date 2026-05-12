import SwiftUI

public struct ContentView: View {
    @StateObject private var viewModel = RenameViewModel()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HeaderView()

            Group {
                switch viewModel.phase {
                case .welcome:
                    SelectFileView(viewModel: viewModel)
                case .preview:
                    PreviewView(viewModel: viewModel)
                case .results:
                    ResultsView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            FooterView(viewModel: viewModel)
        }
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
