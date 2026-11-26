#if os(macOS)
import AppKit
import Combine
import SwiftUI

/// A borderless panel that keeps the cat above other windows on every Space.
/// Shown or hidden by the user; the choice and position survive relaunches.
@MainActor
final class DesktopPetDesktopWindowController: ObservableObject {
    static let shared = DesktopPetDesktopWindowController()

    static let shownKey = "desktop-pet-window-shown"
    static let originKey = "desktop-pet-window-origin"
    static let windowSize = NSSize(width: 170, height: 170)

    @Published private(set) var isShown = false

    private let defaults: UserDefaults
    private var panel: DesktopPetPanel?
    private var dragStartOrigin: NSPoint?
    private var dragStartMouse: NSPoint?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Called once the main window appears.
    func restoreIfNeeded() {
        guard defaults.bool(forKey: Self.shownKey) else { return }
        show()
    }

    func setShown(_ shown: Bool) {
        defaults.set(shown, forKey: Self.shownKey)
        DiagnosticLogger.shared.log(.lifecycle, "桌面宠物窗口\(shown ? "显示" : "收起")")
        shown ? show() : hide()
    }

    private func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.orderFrontRegardless()
        isShown = true
    }

    private func hide() {
        panel?.orderOut(nil)
        isShown = false
    }

    private func makePanel() -> DesktopPetPanel {
        let panel = DesktopPetPanel(
            contentRect: NSRect(origin: initialOrigin(), size: Self.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = DesktopPetHostingView(rootView: DesktopPetDesktopContent(controller: self))
        return panel
    }

    private func initialOrigin() -> NSPoint {
        if let stored = defaults.array(forKey: Self.originKey) as? [Double], stored.count == 2 {
            let origin = NSPoint(x: stored[0], y: stored[1])
            let frame = NSRect(origin: origin, size: Self.windowSize)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
                return origin
            }
        }
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        return NSPoint(x: visible.maxX - Self.windowSize.width - 24, y: visible.minY + 24)
    }

    // MARK: Interactions from the SwiftUI content

    fileprivate func drag(ended: Bool) {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        if dragStartOrigin == nil {
            dragStartOrigin = panel.frame.origin
            dragStartMouse = mouse
        }
        if let startOrigin = dragStartOrigin, let startMouse = dragStartMouse {
            panel.setFrameOrigin(NSPoint(
                x: startOrigin.x + mouse.x - startMouse.x,
                y: startOrigin.y + mouse.y - startMouse.y
            ))
        }
        if ended {
            dragStartOrigin = nil
            dragStartMouse = nil
            let origin = panel.frame.origin
            defaults.set([Double(origin.x), Double(origin.y)], forKey: Self.originKey)
        }
    }

    fileprivate func openMainWindow() {
        NSApp.activate()
        let window = NSApp.windows.first { !($0 is NSPanel) && $0.canBecomeMain }
        window?.makeKeyAndOrderFront(nil)
    }
}

private final class DesktopPetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private final class DesktopPetHostingView<Content: View>: NSHostingView<Content> {
    /// The first click on an inactive app should pet or drag, not just focus.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private struct DesktopPetDesktopContent: View {
    let controller: DesktopPetDesktopWindowController
    @ObservedObject private var store = DesktopPetStore.shared

    var body: some View {
        DesktopPetAnimatedCat(state: store.state, frameInterval: 1.0 / 20)
            .padding(6)
            .frame(
                width: DesktopPetDesktopWindowController.windowSize.width,
                height: DesktopPetDesktopWindowController.windowSize.height
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .global)
                    .onChanged { _ in controller.drag(ended: false) }
                    .onEnded { _ in controller.drag(ended: true) }
            )
            .onTapGesture { store.pet() }
            .help(store.state.statusText(at: Date()))
            .contextMenu {
                Button("喂食") { store.feed() }
                Button("摸摸") { store.pet() }
                Divider()
                Button("打开∞") { controller.openMainWindow() }
                Button("收起") { controller.setShown(false) }
            }
            .diagnosticScreen("桌面宠物窗口")
    }
}
#endif
