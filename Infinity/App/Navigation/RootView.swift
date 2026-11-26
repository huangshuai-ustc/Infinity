import SwiftUI

struct RootView: View {
    @ObservedObject var reminderStore: ReminderStore
#if os(iOS)
    @ObservedObject private var overlay = DesktopPetOverlayController.shared
    @Environment(\.scenePhase) private var scenePhase
#endif

    var body: some View {
        NavigationStack {
            ReminderListView()
        }
#if os(iOS)
        .onAppear {
            overlay.setShown(true)
            overlay.restoreIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                overlay.setShown(true)
                overlay.restoreIfNeeded()
            }
        }
#endif
    }
}
