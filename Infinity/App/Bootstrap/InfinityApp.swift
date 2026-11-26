import SwiftUI

@main
struct InfinityApp: App {
    @StateObject private var petStore = DesktopPetStore.shared

    var body: some Scene {
        WindowGroup {
            RootView(store: petStore)
        }
    }
}
