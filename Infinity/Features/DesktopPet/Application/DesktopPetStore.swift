import Combine
import Foundation
#if canImport(WidgetKit) && os(iOS)
import WidgetKit
#endif

@MainActor
final class DesktopPetStore: ObservableObject {
    static let shared: DesktopPetStore = {
        let defaults = DesktopPetDefaults.resolved()
        if defaults !== UserDefaults.standard {
            _ = DesktopPetStateRepository.moveLegacyState(from: .standard, to: defaults)
        }
        return DesktopPetStore(defaults: defaults)
    }()

    @Published private(set) var state: DesktopPetState
    @Published private(set) var hasUnreadableStoredState = false

    private let defaults: UserDefaults
    private let now: () -> Date

    init(defaults: UserDefaults, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        state = .initial(at: now())
        reload()
    }

    func reload() {
        switch DesktopPetStateRepository.load(from: defaults) {
        case .missing:
            hasUnreadableStoredState = false
            state = .initial(at: now())
        case .loaded(let stored):
            hasUnreadableStoredState = false
            if stored != state { state = stored }
        case .unreadable:
            if !hasUnreadableStoredState { AppLogger.warning("桌面宠物本地状态无法读取；原数据已保留") }
            hasUnreadableStoredState = true
            state = .initial(at: now())
        }
    }

    func feed() {
        apply { $0.feed(at: $1) }
    }

    func pet() {
        apply { $0.pet(at: $1) }
    }

    func removeLocalData() {
        DesktopPetStateRepository.remove(from: defaults)
        hasUnreadableStoredState = false
        state = .initial(at: now())
        reloadWidgets()
    }

    private func apply(_ change: (inout DesktopPetState, Date) -> Void) {
        let date = now()
        var next = state
        change(&next, date)
        do {
            try DesktopPetStateRepository.save(next, to: defaults)
            hasUnreadableStoredState = false
        } catch {
            AppLogger.error("桌面宠物状态保存失败：\(error.localizedDescription)")
        }
        state = next
        reloadWidgets()
    }

    private func reloadWidgets() {
#if canImport(WidgetKit) && os(iOS)
        WidgetCenter.shared.reloadTimelines(ofKind: DesktopPetWidgetKind.kind)
#endif
    }
}
