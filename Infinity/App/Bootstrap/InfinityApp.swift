import SwiftUI

@main
struct InfinityApp: App {
    @StateObject private var reminderStore = ReminderStore.shared

    var body: some Scene {
        WindowGroup {
            RootView(reminderStore: reminderStore)
        }
    }
}
