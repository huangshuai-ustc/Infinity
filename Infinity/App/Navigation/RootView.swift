import SwiftUI

struct RootView: View {
    @ObservedObject var reminderStore: ReminderStore
#if os(iOS)
    @ObservedObject private var overlay = DesktopPetOverlayController.shared
#endif

    var body: some View {
        NavigationStack {
            ReminderListView()
        }
#if os(iOS)
        .onAppear { overlay.setShown(true) }
#endif
    }
}
