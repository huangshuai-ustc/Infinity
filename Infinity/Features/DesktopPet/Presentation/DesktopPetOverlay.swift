#if os(iOS)
import Combine
import SwiftUI
import UIKit

/// Keeps the cat above every page, tab and sheet of the app in its own window,
/// like the copy toast. Only the cat and its action bar take touches; the rest
/// of the window passes them through. The choice and position survive relaunches.
@MainActor
final class DesktopPetOverlayController: ObservableObject {
    static let shared = DesktopPetOverlayController()

    static let shownKey = "desktop-pet-overlay-shown"
    static let positionKey = "desktop-pet-overlay-position"
    /// Wider than tall, so the 3D cat fits both lying down and standing up.
    static let petSize = CGSize(width: 192, height: 168)
    static let actionBarSize = CGSize(width: 234, height: 66)
    private static let margin: CGFloat = 6

    /// The user's choice; the cat also needs the module to be visible.
    @Published private(set) var isEnabled: Bool
    /// Center of the cat as a fraction of the window, so it survives rotation.
    @Published private(set) var position: CGPoint
    @Published var showsActions = false

    private let defaults: UserDefaults
    private var window: DesktopPetOverlayWindow?
    private var activationObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Self.shownKey)
        if let stored = defaults.array(forKey: Self.positionKey) as? [Double], stored.count == 2 {
            position = CGPoint(x: stored[0], y: stored[1])
        } else {
            position = CGPoint(x: 0.82, y: 0.74)
        }
    }

    /// Called once the main window appears.
    func restoreIfNeeded() {
        if activationObserver == nil {
            // A scene that becomes active (launch, iPad window switch) gets the cat.
            activationObserver = NotificationCenter.default.addObserver(
                forName: UIScene.didActivateNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.attachIfNeeded() }
            }
        }
        attachIfNeeded()
    }

    func setShown(_ shown: Bool) {
        defaults.set(shown, forKey: Self.shownKey)
        isEnabled = shown
        DiagnosticLogger.shared.log(.lifecycle, "App 内悬浮宠物\(shown ? "显示" : "收起")")
        attachIfNeeded()
    }

    private func attachIfNeeded() {
        guard isEnabled else {
            detach()
            return
        }
        guard let scene = activeWindowScene else { return }
        // Pick up feeding done from the widget while the app was away.
        DesktopPetStore.shared.reload()
        if let window, window.windowScene === scene { return }
        detach()
        let window = DesktopPetOverlayWindow(windowScene: scene)
        window.controller = self
        // Same level as the copy toast: above sheets and alerts in this scene.
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
        let host = UIHostingController(rootView: DesktopPetOverlayContent(controller: self))
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.isHidden = false
        self.window = window
    }

    private func detach() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        showsActions = false
    }

    private var activeWindowScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        return scenes.first(where: { scene in
            scene.windows.contains(where: { $0.isKeyWindow })
        }) ?? scenes.first
    }

    // MARK: Layout shared by the window's hit test and the SwiftUI content

    /// The cat's center in points, kept fully inside the window.
    func center(in size: CGSize, offset: CGSize = .zero) -> CGPoint {
        let halfWidth = Self.petSize.width / 2 + Self.margin
        let halfHeight = Self.petSize.height / 2 + Self.margin
        let x = position.x * size.width + offset.width
        let y = position.y * size.height + offset.height
        return CGPoint(
            x: min(max(x, halfWidth), max(halfWidth, size.width - halfWidth)),
            y: min(max(y, halfHeight), max(halfHeight, size.height - halfHeight))
        )
    }

    func petRect(_ size: CGSize) -> CGRect {
        let center = center(in: size), pet = Self.petSize
        return CGRect(x: center.x - pet.width / 2, y: center.y - pet.height / 2, width: pet.width, height: pet.height)
    }

    /// The bar sits above the cat, or below it when the cat is near the top.
    func actionBarCenter(in size: CGSize) -> CGPoint {
        let pet = petRect(size), bar = Self.actionBarSize
        let above = pet.minY - bar.height / 2 - 4
        let y = above - bar.height / 2 < Self.margin ? pet.maxY + bar.height / 2 + 4 : above
        let halfWidth = bar.width / 2 + Self.margin
        let x = min(max(pet.midX, halfWidth), max(halfWidth, size.width - halfWidth))
        return CGPoint(x: x, y: y)
    }

    fileprivate func acceptsTouch(at point: CGPoint, in size: CGSize) -> Bool {
        if petRect(size).contains(point) { return true }
        guard showsActions else { return false }
        let center = actionBarCenter(in: size), bar = Self.actionBarSize
        return CGRect(x: center.x - bar.width / 2, y: center.y - bar.height / 2, width: bar.width, height: bar.height)
            .contains(point)
    }

    fileprivate func endDrag(translation: CGSize, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let center = center(in: size, offset: translation)
        position = CGPoint(x: center.x / size.width, y: center.y / size.height)
        defaults.set([Double(position.x), Double(position.y)], forKey: Self.positionKey)
    }
}

private final class DesktopPetOverlayWindow: UIWindow {
    weak var controller: DesktopPetOverlayController?

    /// Touches outside the cat fall through to the app underneath.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        controller?.acceptsTouch(at: point, in: bounds.size) ?? false
    }
}

private struct DesktopPetOverlayContent: View {
    @ObservedObject var controller: DesktopPetOverlayController
    @ObservedObject private var store = DesktopPetStore.shared
    @GestureState private var dragOffset = CGSize.zero
    @AppStorage(DesktopPetView.showsModelKey) private var showsModel = true

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                cat
                    .frame(width: DesktopPetOverlayController.petSize.width, height: DesktopPetOverlayController.petSize.height)
                    .contentShape(Rectangle())
                    .position(controller.center(in: size, offset: dragOffset))
                    .gesture(
                        DragGesture(minimumDistance: 4)
                            .updating($dragOffset) { value, state, _ in state = value.translation }
                            .onEnded { controller.endDrag(translation: $0.translation, in: size) }
                    )
                    .onTapGesture {
                        if controller.showsActions {
                            controller.showsActions = false
                        } else {
                            store.pet()
                        }
                    }
                    .onLongPressGesture(minimumDuration: 0.4) {
                        controller.showsActions.toggle()
                    }
                    .accessibilityElement()
                    .accessibilityLabel(store.state.statusText(at: Date()))
                    .accessibilityHint("轻点摸摸它，长按显示喂食和收起")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { store.pet() }
                    .accessibilityAction(named: "喂食") { store.feed() }
                    .accessibilityAction(named: "收起") { controller.setShown(false) }

                if controller.showsActions && dragOffset == .zero {
                    actionBar
                        .position(controller.actionBarCenter(in: size))
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: controller.showsActions)
        }
        .ignoresSafeArea()
        .diagnosticScreen("App 内悬浮宠物")
    }

    @ViewBuilder
    private var cat: some View {
        if showsModel {
            DesktopPetModelView(state: store.state, framing: .overlay)
        } else {
            DesktopPetAnimatedCat(state: store.state, frameInterval: 1.0 / 20)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 0) {
            barButton("喂食", systemImage: "fork.knife") {
                store.feed()
                controller.showsActions = false
            }
            barButton("摸摸", systemImage: "hand.wave") {
                store.pet()
                controller.showsActions = false
            }
            barButton("收起", systemImage: "eye.slash") {
                controller.setShown(false)
            }
        }
        .frame(
            width: DesktopPetOverlayController.actionBarSize.width,
            height: DesktopPetOverlayController.actionBarSize.height
        )
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
    }

    private func barButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
#endif
