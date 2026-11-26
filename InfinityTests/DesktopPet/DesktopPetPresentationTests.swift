import SwiftUI
import RealityKit
import Testing
@testable import Infinity

@MainActor
struct DesktopPetPresentationTests {
    @Test func rootViewCanBeComposedWithAnInjectedStore() {
        let defaults = UserDefaults(suiteName: "InfinityTests.Presentation.\(UUID().uuidString)")!
        let store = DesktopPetStore(defaults: defaults, now: { Date(timeIntervalSinceReferenceDate: 800_000_000) })
        _ = RootView(store: store)
    }

    @Test func bundledModelContainsTheMergedAnimationTimeline() async throws {
        let cat = try await Entity(named: "DesktopPetCat", in: .main)
        let duration = try #require(cat.availableAnimations.first).definition.duration
        #expect(abs(duration - 1366.0 / 30) < 0.1)
    }

#if os(macOS)
    @Test func desktopWindowVisibilityChoicePersistsAndRepeatedHideIsSafe() {
        let name = "InfinityTests.DesktopWindow.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let controller = DesktopPetDesktopWindowController(defaults: defaults)

        controller.setShown(false)
        controller.setShown(false)

        #expect(!controller.isShown)
        #expect(!defaults.bool(forKey: DesktopPetDesktopWindowController.shownKey))
    }
#endif
}
