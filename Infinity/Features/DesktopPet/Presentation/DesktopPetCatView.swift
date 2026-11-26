import Foundation
import SwiftUI

/// Shared by the app and the StockMarketWidget extension. The cat is the pixel
/// sprite from `DesktopPetPixelSprite.swift`, drawn into a `Canvas` laid out in
/// a 160×160 space and scaled to the view. The tail follows pixelpets'
/// segmented tail (src/body.js, MIT, see the notice in the sprite file).
struct DesktopPetCatView: View {
    let pose: DesktopPetPose
    let motion: DesktopPetMotion

    init(pose: DesktopPetPose, motion: DesktopPetMotion? = nil) {
        self.pose = pose
        self.motion = motion ?? .resting(pose)
    }

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let scale = side / DesktopPetScene.side
            context.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
            context.scaleBy(x: scale, y: scale)
            DesktopPetScene(pose: pose, motion: motion).draw(in: &context)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct DesktopPetMotion: Equatable, Sendable {
    /// -1...1, drives the chest rising and falling.
    var breath: Double
    /// Milliseconds on a looping clock for the tail, whiskers and floating
    /// marks; nil draws them at rest.
    var clock: Double?
    var isBlinking: Bool
    /// Cells the head is lowered while eating.
    var headDrop: Int
    /// 0..<1 while hearts float up after petting.
    var heartProgress: Double?

    static let heartDuration: TimeInterval = 1.6

    /// The frame used where nothing animates, such as the widget.
    static func resting(_ pose: DesktopPetPose) -> Self {
        DesktopPetMotion(
            breath: 0,
            clock: nil,
            isBlinking: false,
            headDrop: pose == .eating ? 2 : 0,
            heartProgress: nil
        )
    }

    static func at(_ date: Date, pose: DesktopPetPose, lastPettedAt: Date?) -> Self {
        let seconds = date.timeIntervalSinceReferenceDate
        // Wrapped so the sine inputs stay small; the jump once a day is invisible.
        let clock = seconds.truncatingRemainder(dividingBy: 86_400) * 1000

        var heartProgress: Double?
        if let lastPettedAt {
            let elapsed = date.timeIntervalSince(lastPettedAt)
            if elapsed >= 0, elapsed < heartDuration {
                heartProgress = elapsed / heartDuration
            }
        }

        return DesktopPetMotion(
            breath: sin(clock / (pose == .sleeping ? 3200 : 2200)),
            clock: clock,
            isBlinking: pose != .sleeping && seconds.truncatingRemainder(dividingBy: 4.2) < 0.14,
            headDrop: pose == .eating ? (sin(clock / 300) > 0 ? 2 : 1) : 0,
            heartProgress: heartProgress
        )
    }
}

private func rgb(_ hex: UInt32, shade: Double = 1) -> Color {
    func channel(_ shift: UInt32) -> Double {
        min(255, Double((hex >> shift) & 0xFF) * shade) / 255
    }
    return Color(red: channel(16), green: channel(8), blue: channel(0))
}

/// Coat colors sampled from the reference photos: an orange-and-white bicolor
/// with faint darker stripes, pink nose and amber eyes.
private enum Palette {
    static func hex(_ role: DesktopPetSprite.Role) -> UInt32? {
        switch role {
        case .empty: nil
        case .fur: 0xF7F1E6
        case .orange: 0xE8943C
        case .stripe: 0xC97430
        case .innerEar: 0xF2A9A6
        case .nose: 0xE0888F
        case .eye: 0xD9B53E
        case .outline: 0x5A3514
        case .halo: 0xFBFDFF
        }
    }

    static let pupil: UInt32 = 0x22242B
    static let blush: UInt32 = 0xFFAAB8
    static let heart: UInt32 = 0xFF5A6E
    static let sleepMark: UInt32 = 0x8AB4CC
    static let tangerine: UInt32 = 0xF59A23
    static let leaf: UInt32 = 0x6DAA4C
    static let bowl: UInt32 = 0x7FA7D9
    static let bowlRim: UInt32 = 0xB5CFEF
    static let kibble: UInt32 = 0xA8683A
}

/// A few cells of pixel art for the props, outlined like the cat.
private struct PixelArt {
    struct Cell: Hashable {
        var x: Int
        var y: Int
    }

    var cells: [Cell: UInt32] = [:]

    subscript(x: Int, y: Int) -> UInt32? {
        get { cells[Cell(x: x, y: y)] }
        set { cells[Cell(x: x, y: y)] = newValue }
    }

    func outlined(_ hex: UInt32) -> PixelArt {
        var result = self
        for cell in cells.keys {
            for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] where self[cell.x + dx, cell.y + dy] == nil {
                result[cell.x + dx, cell.y + dy] = hex
            }
        }
        return result
    }

    func draw(in context: inout GraphicsContext, origin: CGPoint, cell: CGFloat, opacity: Double = 1) {
        for (position, hex) in cells {
            let rect = CGRect(
                x: origin.x + CGFloat(position.x) * cell,
                y: origin.y + CGFloat(position.y) * cell,
                width: cell + 0.3,
                height: cell + 0.3
            )
            context.fill(Path(rect), with: .color(rgb(hex).opacity(opacity)))
        }
    }
}

/// One frame of the cat and its props in the 160×160 space.
private struct DesktopPetScene {
    typealias Sprite = DesktopPetSprite

    static let side: CGFloat = 160
    /// Where the cat's paws meet the ground.
    private static let footX = 72.0, footY = 150.0

    let pose: DesktopPetPose
    let motion: DesktopPetMotion

    private var sprite: Sprite {
        let body: Sprite.Body
        switch pose {
        case .sleeping: body = .loaf
        case .eating: body = .sitting(headDrop: motion.headDrop)
        case .idle, .happy, .hungry: body = .sitting(headDrop: 0)
        }
        return Sprite.variant(body, eyesOpen: !eyesClosedCalmly && !motion.isBlinking)
    }

    private var eyesClosedCalmly: Bool { pose == .sleeping || pose == .happy }

    func draw(in context: inout GraphicsContext) {
        let sprite = sprite
        shadow(in: &context)
        tangerine(in: &context)
        if pose != .sleeping { tail(in: &context) }

        // Breathing stretches the cat from its paws, so they stay on the ground.
        var cat = context
        cat.translateBy(x: Self.footX, y: Self.footY)
        cat.scaleBy(x: 1 - motion.breath * 0.012, y: 1 + motion.breath * 0.020)
        cat.translateBy(x: -Sprite.axisX, y: -Sprite.groundY)
        cells(sprite, in: &cat)
        face(sprite, in: &cat)
        whiskers(sprite, in: &cat)

        if pose == .eating || pose == .hungry { bowl(in: &context) }
        if pose == .sleeping { sleepMarks(in: &context) }
        if let progress = motion.heartProgress { hearts(progress, in: &context) }
    }
}

// MARK: The cat

private extension DesktopPetScene {
    func shadow(in context: inout GraphicsContext) {
        let radius = pose == .sleeping ? 42.0 : 34.0
        let rect = CGRect(x: Self.footX - radius, y: Self.footY - 3, width: radius * 2, height: 10)
        context.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.16)))
    }

    /// pixelpets' shading: fur is lit from the top, the outline carries a rim
    /// light, and the halo fades along the bottom.
    func cells(_ sprite: Sprite, in context: inout GraphicsContext) {
        let cell = CGFloat(Sprite.cell), rows = Double(Sprite.rows)
        for (r, row) in sprite.cells.enumerated() {
            let depth = Double(r) / rows
            var paths: [Sprite.Role: Path] = [:]
            for (c, role) in row.enumerated() where role != .empty {
                // Opaque cells overlap a hair so no seams show once scaled.
                let bleed: CGFloat = role == .halo ? 0 : 0.3
                paths[role, default: Path()].addRect(CGRect(
                    x: CGFloat(c) * cell, y: CGFloat(r) * cell, width: cell + bleed, height: cell + bleed
                ))
            }
            for (role, path) in paths {
                guard let hex = Palette.hex(role) else { continue }
                switch role {
                case .halo:
                    let alpha = 0.55 * min(max(1.3 - depth * 0.7, 0.5), 1.4)
                    context.fill(path, with: .color(rgb(hex).opacity(alpha)))
                case .outline:
                    context.fill(path, with: .color(rgb(hex, shade: 1.16 - depth * 0.30)))
                default:
                    let shade = role.isFur ? max(0.82, 1.12 - depth * 0.34) : 1
                    context.fill(path, with: .color(rgb(hex, shade: shade)))
                }
            }
        }
    }

    func face(_ sprite: Sprite, in context: inout GraphicsContext) {
        let ink = GraphicsContext.Shading.color(rgb(Palette.hex(.outline)!))
        for eye in sprite.eyes where eye.width > 0 {
            if eyesClosedCalmly {
                // Contented closed eyes with a lash tick at the outer corner.
                let cy = eye.centerY - 1, radius = eye.width * 0.54
                var lid = Path()
                for k in 0...10 {
                    let angle = Double.pi * (0.12 + 0.76 * Double(k) / 10)
                    let p = CGPoint(x: eye.centerX + radius * cos(angle), y: cy + radius * sin(angle))
                    k == 0 ? lid.move(to: p) : lid.addLine(to: p)
                }
                let dir = eye.centerX < sprite.muzzle.x ? -1.0 : 1.0
                var lash = Path()
                lash.move(to: CGPoint(x: eye.centerX + dir * radius * 0.92, y: cy + radius * 0.30))
                lash.addLine(to: CGPoint(x: eye.centerX + dir * radius * 1.35, y: cy + radius * 0.02))
                context.stroke(lid, with: ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                context.stroke(lash, with: ink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            } else if motion.isBlinking {
                context.fill(
                    Path(CGRect(x: eye.centerX - eye.width / 2, y: eye.centerY - 1, width: eye.width, height: 2)),
                    with: ink
                )
            } else {
                pupil(in: eye, dilate: pose == .hungry ? 1.3 : 1, context: &context)
            }
        }
        if pose == .happy {
            for eye in sprite.eyes where eye.width > 0 {
                let x = (eye.centerX - 2).rounded(), y = (eye.centerY + eye.height * 0.55).rounded()
                var blush = Path(CGRect(x: x, y: y, width: 5, height: 2))
                blush.addRect(CGRect(x: x + 1, y: y + 2, width: 3, height: 1))
                context.fill(blush, with: .color(rgb(Palette.blush).opacity(0.52)))
            }
        }
    }

    private func pupil(in eye: Sprite.EyeBox, dilate: Double, context: inout GraphicsContext) {
        let width = max(4, (eye.width * 0.46 * dilate).rounded())
        let height = max(5, (eye.height * 0.7 * min(dilate, 1.12)).rounded())
        let x = (eye.centerX - width / 2).rounded(), y = (eye.centerY - height / 2).rounded()
        var body = Path(CGRect(x: x, y: y + 1, width: width, height: height - 2))
        body.addRect(CGRect(x: x + 1, y: y, width: width - 2, height: height))
        context.fill(body, with: .color(rgb(Palette.pupil)))
        context.fill(Path(CGRect(x: x + width - 3, y: y + 1, width: 2, height: 2)), with: .color(.white.opacity(0.95)))
        context.fill(Path(CGRect(x: x + 1, y: y + height - 3, width: 2, height: 2)), with: .color(.white.opacity(0.4)))
    }

    /// Three whiskers a side in whole pixels. They are dark here because the
    /// face is white, where pixelpets' pale whiskers would vanish.
    func whiskers(_ sprite: Sprite, in context: inout GraphicsContext) {
        let t = motion.clock
        let waft = t.map { sin($0 / 1400) * 0.6 } ?? 0
        let twitch = t.map { $0.truncatingRemainder(dividingBy: 5200) < 200 ? sin($0 / 26) * 1.5 : 0 } ?? 0
        let my = sprite.muzzle.y
        var path = Path()
        for (startX, dir) in [(sprite.muzzle.x - 18, -1.0), (sprite.muzzle.x + 18, 1.0)] {
            for i in 0..<3 {
                let wobble = t.map { sin($0 / 900 + Double(i)) * 0.5 } ?? 0
                let tipY = my + Double(i) * 5 - 1 + waft + twitch + wobble
                addPixelLine(&path, from: (startX, my + Double(i) * 3 - 2), to: (startX + dir * 13, tipY))
            }
        }
        context.fill(path, with: .color(rgb(Palette.hex(.outline)!).opacity(0.45)))
    }

    /// A line of whole pixels (Bresenham), so it stays crisp when scaled.
    private func addPixelLine(_ path: inout Path, from start: (Double, Double), to end: (Double, Double)) {
        var x = Int(start.0.rounded()), y = Int(start.1.rounded())
        let endX = Int(end.0.rounded()), endY = Int(end.1.rounded())
        let dx = abs(endX - x), dy = -abs(endY - y)
        let stepX = x < endX ? 1 : -1, stepY = y < endY ? 1 : -1
        var error = dx + dy
        while true {
            path.addRect(CGRect(x: x, y: y, width: 1, height: 1))
            if x == endX && y == endY { return }
            let doubled = 2 * error
            if doubled >= dy { error += dy; x += stepX }
            if doubled <= dx { error += dx; y += stepY }
        }
    }
}

// MARK: Tail and props

private extension DesktopPetScene {
    /// pixelpets' tail: ten segments that dive behind the haunch, run along the
    /// ground and curl up, swaying most at the tip. Ringed, with a pale tip.
    func tail(in context: inout GraphicsContext) {
        let spriteWidth = Double(Sprite.columns * Sprite.cell), spriteHeight = 120.0
        let baseX = Self.footX + spriteWidth * 0.20, baseY = Self.footY - spriteHeight * 0.22
        let segment = spriteHeight * 0.052
        let rest = [1.30, 1.10, 0.85, 0.55, 0.28, 0.08, -0.05, -0.45, -0.85, -1.20]
        let t = motion.clock
        let speed = pose == .happy ? 1.8 : 1
        let wag = t.map { sin($0 * speed / 540) * 0.12 } ?? 0

        var points = [CGPoint(x: baseX, y: baseY)]
        var x = baseX, y = baseY, deviation = 0.0
        for (i, angle) in rest.enumerated() {
            let weight = Double(i + 1) / Double(rest.count)
            deviation += wag * weight * weight + (t.map { sin($0 / 430 + Double(i) * 0.6) * 0.03 * weight } ?? 0)
            let heading = angle - deviation
            x += cos(heading) * segment
            y = min(y + sin(heading) * segment, Self.footY - 2.5)
            points.append(CGPoint(x: x, y: y))
        }

        // Quadratics through the midpoints so the tapered pieces show no corners.
        var smooth = [points[0]]
        var previous = points[0]
        for i in 1..<(points.count - 1) {
            let mid = CGPoint(x: (points[i].x + points[i + 1].x) / 2, y: (points[i].y + points[i + 1].y) / 2)
            for k in 1...4 {
                let u = Double(k) / 4, v = 1 - u
                smooth.append(CGPoint(
                    x: v * v * previous.x + 2 * v * u * points[i].x + u * u * mid.x,
                    y: v * v * previous.y + 2 * v * u * points[i].y + u * u * mid.y
                ))
            }
            previous = mid
        }
        smooth.append(points[points.count - 1])

        let pieces = smooth.count - 1
        for outlinePass in [true, false] {
            for j in 0..<pieces {
                let s = (Double(j) + 0.5) / Double(pieces)
                let role: Sprite.Role
                if outlinePass {
                    role = .outline
                } else if s > 0.82 {
                    role = .fur
                } else {
                    role = j % 6 < 2 && s > 0.15 ? .stripe : .orange
                }
                var piece = Path()
                piece.move(to: smooth[j])
                piece.addLine(to: smooth[j + 1])
                context.stroke(
                    piece,
                    with: .color(rgb(Palette.hex(role)!)),
                    style: StrokeStyle(lineWidth: 7 - 4 * s + (outlinePass ? 3 : 0), lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    /// The smiling tangerine plush from the photos, beside the cat.
    func tangerine(in context: inout GraphicsContext) {
        var art = PixelArt()
        for y in 0..<5 {
            for x in 0..<5 where !((x == 0 || x == 4) && (y == 0 || y == 4)) {
                art[x, y + 1] = Palette.tangerine
            }
        }
        art[2, 0] = Palette.leaf
        art[3, 0] = Palette.leaf
        art[1, 3] = Palette.hex(.outline)
        art[3, 3] = Palette.hex(.outline)
        art.outlined(Palette.hex(.outline)!)
            .draw(in: &context, origin: CGPoint(x: 6, y: Self.footY - 24), cell: 3.5)
    }

    func bowl(in context: inout GraphicsContext) {
        var art = PixelArt()
        for x in 0..<11 { art[x, 1] = Palette.bowlRim }
        for y in 2..<4 {
            for x in (y - 1)..<(12 - y) { art[x, y] = Palette.bowl }
        }
        if pose == .eating {
            for x in [2, 4, 5, 7, 8] { art[x, 0] = Palette.kibble }
        }
        art.outlined(Palette.hex(.outline)!)
            .draw(in: &context, origin: CGPoint(x: Self.footX - 20, y: Self.footY - 9), cell: 3.6)
    }

    /// pixelpets' floating "Z"s, drifting up and fading.
    func sleepMarks(in context: inout GraphicsContext) {
        let t = motion.clock ?? 400
        for (index, size) in [2.0, 1.5].enumerated() {
            let phase = ((t + Double(index) * 900) / 1800).truncatingRemainder(dividingBy: 1)
            let fade = phase < 0.15 ? phase / 0.15 : phase > 0.75 ? (1 - phase) / 0.25 : 1
            let x = (100 + Double(index) * 14).rounded(), y = (60 - Double(index) * 12 - phase * 14).rounded()
            var z = Path()
            z.addRect(CGRect(x: x, y: y, width: size * 4, height: size))
            z.addRect(CGRect(x: x + size * 2, y: y + size, width: size * 2, height: size))
            z.addRect(CGRect(x: x + size, y: y + size * 2, width: size * 2, height: size))
            z.addRect(CGRect(x: x, y: y + size * 3, width: size * 4, height: size))
            context.fill(z, with: .color(rgb(Palette.sleepMark).opacity(fade * 0.8)))
        }
    }

    func hearts(_ progress: Double, in context: inout GraphicsContext) {
        let rows = ["0110110", "1111111", "1111111", "0111110", "0011100", "0001000"]
        var art = PixelArt()
        for (y, row) in rows.enumerated() {
            for (x, bit) in row.enumerated() where bit == "1" { art[x, y] = Palette.heart }
        }
        let rise = progress * 26
        art.draw(in: &context, origin: CGPoint(x: 46, y: 22 - rise), cell: 2.4, opacity: 1 - progress)
        art.draw(in: &context, origin: CGPoint(x: 92, y: 16 - rise * 0.8), cell: 2, opacity: 1 - progress)
    }
}
