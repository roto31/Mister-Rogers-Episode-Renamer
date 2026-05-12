import SwiftUI

struct StatusIndicator: View {
    enum Kind {
        case success
        case warning
        case error
        case neutral
    }

    let kind: Kind

    var body: some View {
        Circle()
            .fill(fillColor)
            .frame(width: 10, height: 10)
            .accessibilityLabel(Text(accessibilityLabel))
    }

    private var fillColor: Color {
        switch kind {
        case .success: return MRColor.success
        case .warning: return MRColor.warning
        case .error: return MRColor.error
        case .neutral: return MRColor.neutral
        }
    }

    private var accessibilityLabel: String {
        switch kind {
        case .success: return "Success"
        case .warning: return "Skipped"
        case .error: return "Error"
        case .neutral: return "Pending"
        }
    }
}
