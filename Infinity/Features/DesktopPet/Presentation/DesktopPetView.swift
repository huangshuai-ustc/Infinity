import SwiftUI

/// The pet's own page: a stage with the cat, its two levels, the two actions
/// and where else the cat can be shown.
struct DesktopPetView: View {
    @ObservedObject private var store: DesktopPetStore
#if os(macOS)
    @ObservedObject private var desktopWindow = DesktopPetDesktopWindowController.shared
#else
    @ObservedObject private var overlay = DesktopPetOverlayController.shared
#endif
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(DesktopPetView.showsModelKey) private var showsModel = true

    static let showsModelKey = "desktop-pet-page-shows-3d"

    init(store: DesktopPetStore = .shared) {
        self.store = store
    }

    var body: some View {
        ScrollView {
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                // `Date()` rather than the timeline date, so feeding and petting
                // show at once instead of at the next tick.
                content(at: Date())
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
            .padding(16)
        }
        .appNavigationTitle("桌面宠物")
        .diagnosticScreen("桌面宠物")
        .onAppear {
            store.reload()
#if os(macOS)
            desktopWindow.restoreIfNeeded()
#else
            overlay.restoreIfNeeded()
#endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.reload() }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: store.state.lastPettedAt)
        .sensoryFeedback(.success, trigger: store.state.lastFedAt)
    }

    private func content(at date: Date) -> some View {
        let current = store.state.settled(at: date)
        return VStack(spacing: 16) {
            if store.hasUnreadableStoredState {
                Label("之前保存的宠物状态无法读取，已保留原数据，这里先从新的小猫开始。", systemImage: "exclamationmark.triangle.fill")
                    .appFont(.footnote)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            DesktopPetStage(
                state: store.state,
                date: date,
                showsModel: $showsModel,
                onPet: { store.pet() }
            )

            HStack(spacing: 12) {
                DesktopPetLevelCard(
                    title: "饱腹",
                    value: current.fullness,
                    tint: current.fullness < DesktopPetState.hungryThreshold ? .red : .orange,
                    caption: Self.fullnessCaption(current.fullness)
                )
                DesktopPetLevelCard(
                    title: "心情",
                    value: current.mood,
                    tint: .pink,
                    caption: Self.moodCaption(current.mood)
                )
            }

            HStack(spacing: 12) {
                DesktopPetActionTile(
                    title: "喂食",
                    systemImage: "fork.knife",
                    tint: .orange,
                    detail: Self.lastTime(store.state.lastFedAt, at: date, never: "还没喂过")
                ) { store.feed() }
                DesktopPetActionTile(
                    title: "摸摸",
                    systemImage: "hand.wave.fill",
                    tint: .pink,
                    detail: Self.lastTime(store.state.lastPettedAt, at: date, never: "还没摸过")
                ) { store.pet() }
            }

            companionCard
            tipsCard
        }
    }

    private var companionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
#if os(macOS)
            Toggle(isOn: Binding(
                get: { desktopWindow.isShown },
                set: { desktopWindow.setShown($0) }
            )) {
                Label("放在桌面上", systemImage: "macwindow")
                    .appFont(.headline)
            }
            Text("小猫会浮在所有窗口上方，可以拖动；单击摸摸，右键可以喂食或收起。")
                .appFont(.footnote)
                .foregroundStyle(.secondary)
#else
            Toggle(isOn: Binding(
                get: { overlay.isEnabled },
                set: { overlay.setShown($0) }
            )) {
                Label("在 App 里悬浮显示", systemImage: "pip")
                    .appFont(.headline)
            }
            Text("小猫会浮在所有页面上方，可以拖动；轻点摸摸，长按喂食或收起。")
                .appFont(.footnote)
                .foregroundStyle(.secondary)
#endif
        }
        .tint(.orange)
        .padding(16)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsModel {
#if os(iOS)
                tip("cube", "3D 小猫平时安静趴着，偶尔四处张望。悬浮小猫也用这里选的样式，小组件仍是像素小猫。")
#else
                tip("cube", "3D 小猫平时安静趴着，偶尔四处张望。桌面浮窗仍是像素小猫。")
#endif
            }
#if os(iOS)
            tip("apps.iphone", "长按主屏幕空白处，添加 Infinity 的「桌面宠物」小组件，在桌面上直接喂食和摸摸。")
#endif
            tip("lock", "宠物状态只保存在这台设备上，不参与备份和 iCloud 同步。")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func tip(_ systemImage: String, _ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage)
                .frame(width: 18)
        }
        .appFont(.caption)
        .foregroundStyle(.secondary)
    }

    private static func fullnessCaption(_ fullness: Double) -> String {
        guard fullness >= DesktopPetState.hungryThreshold else { return "饿了，快喂喂它" }
        let hours = (fullness - DesktopPetState.hungryThreshold) / DesktopPetState.fullnessDecayPerHour
        return hours < 1 ? "快要饿了" : "约 \(Int(hours)) 小时后会饿"
    }

    private static func moodCaption(_ mood: Double) -> String {
        mood >= DesktopPetState.happyThreshold ? "心情很好" : "摸摸能让它开心"
    }

    private static func lastTime(_ moment: Date?, at date: Date, never: String) -> String {
        guard let moment else { return never }
        let minutes = Int(max(0, date.timeIntervalSince(moment)) / 60)
        switch minutes {
        case ..<1: return "刚刚"
        case ..<60: return "\(minutes) 分钟前"
        case ..<(24 * 60): return "\(minutes / 60) 小时前"
        default: return "\(minutes / (24 * 60)) 天前"
        }
    }
}

/// The large card with the cat, its name and what it is doing.
private struct DesktopPetStage: View {
    let state: DesktopPetState
    let date: Date
    @Binding var showsModel: Bool
    let onPet: () -> Void

    private var pose: DesktopPetPose { state.pose(at: date) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(DesktopPetState.name)
                        .appFont(.title2.bold())
                    Label(state.statusText(at: date), systemImage: Self.symbol(for: pose))
                        .appFont(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
                Spacer(minLength: 12)
                Picker("样式", selection: $showsModel) {
                    Text("像素").tag(false)
                    Text("3D").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 112)
            }
            .padding([.horizontal, .top], 18)

            cat
                .frame(height: 280)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(perform: onPet)
                .accessibilityElement()
                .accessibilityLabel(state.statusText(at: date))
                .accessibilityHint("轻点摸摸它")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onPet() }

            Text(showsModel ? "轻点摸摸 · 左右拖动转个方向" : "轻点摸摸")
                .appFont(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 14)
        }
        .background(backdrop, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .environment(\.colorScheme, pose == .sleeping ? .dark : colorScheme)
        .animation(.easeInOut(duration: 0.6), value: pose)
    }

    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    private var cat: some View {
        if showsModel {
            DesktopPetModelView(state: state)
                .overlay(alignment: .top) { DesktopPetHeartBurst(trigger: state.lastPettedAt) }
        } else {
            DesktopPetAnimatedCat(state: state, frameInterval: 1.0 / 30)
                .frame(maxWidth: 260)
        }
    }

    private var backdrop: LinearGradient {
        let colors: [Color] = switch pose {
        case .sleeping: [Color(red: 0.16, green: 0.18, blue: 0.36), Color(red: 0.28, green: 0.24, blue: 0.45)]
        case .hungry: [Color.orange.opacity(0.22), Color.red.opacity(0.10)]
        case .happy: [Color.pink.opacity(0.20), Color.orange.opacity(0.14)]
        case .idle, .eating: [Color.orange.opacity(0.20), Color.yellow.opacity(0.10)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    private static func symbol(for pose: DesktopPetPose) -> String {
        switch pose {
        case .idle: "cloud"
        case .happy: "heart.fill"
        case .eating: "fork.knife"
        case .hungry: "exclamationmark.bubble"
        case .sleeping: "moon.zzz.fill"
        }
    }
}

/// Hearts that float up once after petting; the pixel cat draws its own.
private struct DesktopPetHeartBurst: View {
    let trigger: Date?

    var body: some View {
        // Starts at 1 so nothing shows until the first petting.
        Color.clear
            .keyframeAnimator(initialValue: 1.0, trigger: trigger) { _, progress in
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundStyle(.pink)
                            .offset(x: CGFloat(index - 1) * 34, y: 70 - 60 * progress - CGFloat(index % 2) * 12)
                            .opacity(progress < 1 ? 1 - progress : 0)
                            .scaleEffect(0.6 + 0.4 * progress)
                    }
                }
            } keyframes: { _ in
                MoveKeyframe(0.0)
                LinearKeyframe(1.0, duration: DesktopPetMotion.heartDuration)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct DesktopPetLevelCard: View {
    let title: String
    let value: Double
    let tint: Color
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .appFont(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(Int(value.rounded()))")
                .appFont(.title.bold().monospacedDigit())
                .foregroundStyle(tint)
                .contentTransition(.numericText(value: value))
            Gauge(value: value, in: DesktopPetState.levelRange) { EmptyView() }
                .gaugeStyle(.linearCapacity)
                .tint(tint)
            Text(caption)
                .appFont(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(.snappy, value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(Int(value.rounded()))，\(caption)")
    }
}

private struct DesktopPetActionTile: View {
    let title: String
    let systemImage: String
    let tint: Color
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .appFont(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(tint.gradient, in: Circle())
                Text(title)
                    .appFont(.headline)
                Text(detail)
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(DesktopPetPressStyle())
        .accessibilityLabel(title)
        .accessibilityValue(detail)
    }
}

private struct DesktopPetPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Animates the cat from the clock instead of SwiftUI animations, so the pose
/// follows the state and nothing keeps running when the view is off screen.
struct DesktopPetAnimatedCat: View {
    let state: DesktopPetState
    let frameInterval: TimeInterval

    var body: some View {
        TimelineView(.animation(minimumInterval: frameInterval)) { context in
            let pose = state.pose(at: context.date)
            DesktopPetCatView(
                pose: pose,
                motion: .at(context.date, pose: pose, lastPettedAt: state.lastPettedAt)
            )
        }
    }
}
