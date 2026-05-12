import MisterRogersRenamerCore
import SwiftUI

@main
struct MisterRogersRenamerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
