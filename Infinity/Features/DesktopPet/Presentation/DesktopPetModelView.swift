import RealityKit
import SwiftUI

/// The 3D cat on the pet page and in the floating overlay, from
/// `DesktopPetCat.usdz` (Rodin source, optimized mesh and extended rig). Shows the pixel cat while the
/// model loads or if it cannot load.
struct DesktopPetModelView: View {
    enum Framing {
        /// The pet page: a large view the user can turn by dragging.
        case page
        /// The floating overlay: drags move the overlay, so the cat stays turned.
        case overlay
    }

    let state: DesktopPetState
    var framing: Framing = .page

    @State private var cat: Entity?
    @State private var failed = false

    var body: some View {
        if let cat {
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                // `Date()` rather than the timeline date, so feeding and petting
                // show at once instead of at the next tick.
                DesktopPetModelScene(cat: cat, pose: state.pose(at: Date()), pettedAt: state.lastPettedAt, framing: framing)
            }
        } else {
            DesktopPetAnimatedCat(state: state, frameInterval: 1.0 / 30)
                .frame(maxWidth: framing == .page ? 260 : nil)
                .overlay(alignment: .bottom) {
                    if !failed && framing == .page { ProgressView() }
                }
                .task {
                    do {
                        cat = try await DesktopPetModel.makeCat()
                    } catch {
                        failed = true
                    }
                }
        }
    }
}

private struct DesktopPetModelScene: View {
    let cat: Entity
    let pose: DesktopPetPose
    let pettedAt: Date?
    let framing: DesktopPetModelView.Framing

    /// Turned a little so the cat shows its side as well as its face.
    @State private var yaw: Float = -0.6
    @State private var dragStartYaw: Float?
    /// Turned by the drag. The cat keeps its own rotation, which stands the
    /// Z-up USD file upright.
    @State private var turntable = Entity()

    private struct Performance: Hashable {
        var pose: DesktopPetPose
        var pettedAt: Date?
    }

    var body: some View {
        RealityView { content in
            let camera = PerspectiveCamera()
            switch framing {
            case .page: camera.look(at: [0, 0.6, 0], from: [0, 0.95, 3.1], relativeTo: nil)
            case .overlay: camera.look(at: [0, 0.55, 0], from: [0, 0.85, 3.1], relativeTo: nil)
            }
            content.add(camera)
            turntable.addChild(cat)
            content.add(turntable)
        } update: { _ in
            turntable.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        }
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    let start = dragStartYaw ?? yaw
                    dragStartYaw = start
                    yaw = start + Float(value.translation.width) / 120
                }
                .onEnded { _ in dragStartYaw = nil },
            isEnabled: framing == .page
        )
        .task(id: Performance(pose: pose, pettedAt: pettedAt)) {
            let justPetted = pettedAt.map { abs($0.timeIntervalSinceNow) < 10 } ?? false
            await DesktopPetModel.perform(pose, on: cat, celebrating: pose == .happy && justPetted)
        }
    }
}

@MainActor
private enum DesktopPetModel {
    /// Loaded once per launch; every view gets a clone that shares the mesh.
    private static var template: Task<Entity, Error>?

    static func makeCat() async throws -> Entity {
        let task = template ?? Task {
            let start = Date()
            let entity = try await Entity(named: "DesktopPetCat", in: .main)
            let seconds = String(format: "%.1f", Date().timeIntervalSince(start))
            DiagnosticLogger.shared.log(.lifecycle, "3D 小猫加载完成，用时 \(seconds) 秒")
            return entity
        }
        template = task
        do {
            return try await task.value.clone(recursive: true)
        } catch {
            template = nil
            DiagnosticLogger.shared.log(.lifecycle, "3D 小猫加载失败：\(error)", level: .error)
            throw error
        }
    }

    /// Frames of Rodin's ten clips, merged on one 30 fps timeline in export order.
    struct Clip {
        var frames: ClosedRange<Double>
        var speed: Float = 1

        var duration: TimeInterval { (frames.upperBound - frames.lowerBound) / 30 / Double(speed) }

        /// Lying with the head up, small movements; ends where it starts.
        static let resting = Clip(frames: 1168...1363)
        /// Lying, turning the head to look round; ends on `resting`'s first frame.
        static let lookingRound = Clip(frames: 960...1168)
        /// The stillest stretch of the lying clip, slowed down.
        static let dozing = Clip(frames: 860...920, speed: 0.5)
        /// Sitting and looking up, as if waiting for food.
        static let begging = Clip(frames: 24...373)
        /// Looks round, then head down to the bowl.
        static let eating = Clip(frames: 603...789)
        /// Standing on the hind legs.
        static let standingUp = Clip(frames: 374...454)
    }

    /// A quiet loop most of the time, and now and then a short extra move.
    private static func acting(for pose: DesktopPetPose) -> (loop: Clip, extra: Clip?) {
        switch pose {
        case .idle, .happy: (.resting, .lookingRound)
        case .sleeping: (.dozing, nil)
        case .hungry: (.begging, nil)
        case .eating: (.eating, nil)
        }
    }

    static let extraChance = 0.3
    static let extraWait: ClosedRange<Double> = 40...90
    private static let transition: TimeInterval = 0.6

    /// Runs until the task is cancelled. Right after petting the cat stands up
    /// on its hind legs twice before settling.
    static func perform(_ pose: DesktopPetPose, on cat: Entity, celebrating: Bool) async {
        guard let source = cat.availableAnimations.first?.definition else {
            DiagnosticLogger.shared.log(.lifecycle, "3D 小猫没有可播放的动作", level: .error)
            return
        }
        let (loop, extra) = acting(for: pose)
        do {
            if celebrating {
                try await playOnce(.standingUp, count: 2, from: source, on: cat)
            }
            play(loop, from: source, on: cat)
            while true {
                try await Task.sleep(for: .seconds(Double.random(in: extraWait)))
                guard let extra, Double.random(in: 0..<1) < extraChance else { continue }
                try await playOnce(extra, count: 1, from: source, on: cat)
                play(loop, from: source, on: cat)
            }
        } catch {
            // Cancelled: the pose changed or the view went away.
        }
    }

    private static func play(_ clip: Clip, from source: AnimationDefinition, on cat: Entity) {
        guard let resource = resource(clip, from: source) else { return }
        cat.playAnimation(resource.repeat(), transitionDuration: transition)
    }

    /// Returns a little before the clip ends, so the next one blends in.
    private static func playOnce(_ clip: Clip, count: Int, from source: AnimationDefinition, on cat: Entity) async throws {
        guard let resource = resource(clip, from: source) else { return }
        cat.playAnimation(resource.repeat(count: count), transitionDuration: transition)
        try await Task.sleep(for: .seconds(clip.duration * Double(count) - transition))
    }

    private static func resource(_ clip: Clip, from source: AnimationDefinition) -> AnimationResource? {
        let view = AnimationView(
            source: source,
            trimStart: clip.frames.lowerBound / 30,
            trimEnd: clip.frames.upperBound / 30,
            speed: clip.speed
        )
        do {
            return try AnimationResource.generate(with: view)
        } catch {
            DiagnosticLogger.shared.log(.lifecycle, "3D 小猫动作生成失败：\(error)", level: .error)
            return nil
        }
    }
}
