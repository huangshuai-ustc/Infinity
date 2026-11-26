import AppIntents
import SwiftUI
import WidgetKit

struct DesktopPetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: DesktopPetWidgetKind.kind, provider: DesktopPetTimelineProvider()) { entry in
            DesktopPetWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(red: 1, green: 0.96, blue: 0.9), Color(red: 0.91, green: 0.86, blue: 1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("∞ 桌面宠物")
        .description("看看脏脏橘在做什么，直接喂食和摸摸。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DesktopPetEntry: TimelineEntry {
    let date: Date
    let state: DesktopPetState?
}

struct DesktopPetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DesktopPetEntry {
        DesktopPetEntry(date: Date(), state: .initial(at: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (DesktopPetEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : Self.entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<DesktopPetEntry>) -> Void) {
        let now = Date()
        let first = Self.entry(at: now)
        let later = first.state?.poseChangeDates(after: now).map { DesktopPetEntry(date: $0, state: first.state) } ?? []
        completion(Timeline(entries: [first] + later, policy: .atEnd))
    }

    private static func entry(at date: Date) -> DesktopPetEntry {
        switch DesktopPetStateRepository.load(from: DesktopPetDefaults.resolved()) {
        case .missing: DesktopPetEntry(date: date, state: .initial(at: date))
        case .loaded(let state): DesktopPetEntry(date: date, state: state)
        case .unreadable: DesktopPetEntry(date: date, state: nil)
        }
    }
}

struct DesktopPetFeedIntent: AppIntent {
    static let title: LocalizedStringResource = "喂食"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        DesktopPetStateRepository.update(in: DesktopPetDefaults.resolved(), at: Date()) { $0.feed(at: $1) }
        return .result()
    }
}

struct DesktopPetPetIntent: AppIntent {
    static let title: LocalizedStringResource = "摸摸"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        DesktopPetStateRepository.update(in: DesktopPetDefaults.resolved(), at: Date()) { $0.pet(at: $1) }
        return .result()
    }
}

private struct DesktopPetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DesktopPetEntry

    var body: some View {
        if let state = entry.state {
            let pose = state.pose(at: entry.date)
            switch family {
            case .systemMedium: medium(state, pose: pose)
            default: small(state, pose: pose)
            }
        } else {
            VStack(spacing: 6) {
                DesktopPetCatView(pose: .idle)
                Text("打开 ∞ 查看")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func small(_ state: DesktopPetState, pose: DesktopPetPose) -> some View {
        VStack(spacing: 4) {
            DesktopPetCatView(pose: pose)
                .accessibilityLabel(state.statusText(at: entry.date))
            HStack(spacing: 10) {
                Button(intent: DesktopPetFeedIntent()) { Image(systemName: "fork.knife") }
                    .accessibilityLabel("喂食")
                Button(intent: DesktopPetPetIntent()) { Image(systemName: "hand.wave") }
                    .accessibilityLabel("摸摸")
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(.orange)
        }
    }

    private func medium(_ state: DesktopPetState, pose: DesktopPetPose) -> some View {
        let current = state.settled(at: entry.date)
        return HStack(spacing: 12) {
            DesktopPetCatView(pose: pose)
            VStack(alignment: .leading, spacing: 6) {
                Text(DesktopPetState.name).font(.headline)
                Text(state.statusText(at: entry.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                level("饱腹", value: current.fullness)
                level("心情", value: current.mood)
                HStack(spacing: 8) {
                    Button(intent: DesktopPetFeedIntent()) { Label("喂食", systemImage: "fork.knife") }
                    Button(intent: DesktopPetPetIntent()) { Label("摸摸", systemImage: "hand.wave") }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
    }

    private func level(_ title: String, value: Double) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            ProgressView(value: value, total: DesktopPetState.levelRange.upperBound)
                .tint(value < DesktopPetState.hungryThreshold ? .red : .orange)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(Int(value.rounded()))")
    }
}
