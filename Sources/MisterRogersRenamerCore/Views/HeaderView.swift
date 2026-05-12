import SwiftUI

struct HeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mister Rogers' Neighborhood")
                .font(.largeTitle.weight(.semibold))
            Text("Episode Renamer")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Rename video files using PBS production numbers (from the Neighborhood Archive index) and the bundled episode database.")
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
