import SwiftUI

struct RootView: View {
    @ObservedObject var store: DesktopPetStore

    var body: some View {
        NavigationStack {
            DesktopPetView(store: store)
        }
    }
}
