import SwiftUI

extension View {
    func appFont(_ font: Font) -> some View {
        self.font(font)
    }

    func appNavigationTitle(_ title: String) -> some View {
        self.navigationTitle(title)
    }

    func diagnosticScreen(_ name: String) -> some View {
        self
    }
}
