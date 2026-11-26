// The cell grid, its primitives and the sitting and loaf composers are adapted
// from pixelpets (https://github.com/JOhnsonKC201/pixelpets, src/cat-sprite.js
// and src/poses.js). The orange-and-white coat is drawn for this cat.
//
// MIT License
//
// Copyright (c) 2026 JOhnsonKC201
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

/// The cat as a grid of cells, each `cell` pixels square. Every cell holds a
/// role; the renderer picks the color. Built once per variant and reused.
struct DesktopPetSprite: Sendable {
    enum Role: UInt8, Sendable {
        case empty, fur, orange, stripe, innerEar, nose, eye, outline, halo

        /// Fur cells get the top-to-bottom shading.
        var isFur: Bool { self == .fur || self == .orange || self == .stripe || self == .innerEar }
    }

    enum Body: Hashable, Sendable {
        /// Sitting upright; `headDrop` lowers the head by whole cells.
        case sitting(headDrop: Int)
        /// Lying as a loaf with the tail wrapped round, used for sleeping.
        case loaf
    }

    struct Key: Hashable, Sendable {
        var body: Body
        var eyesOpen: Bool
    }

    /// An eye's bounds in sprite pixels.
    struct EyeBox: Sendable {
        var centerX: Double
        var centerY: Double
        var width: Double
        var height: Double
    }

    static let cell = 4
    static let columns = 24
    /// pixelpets' 30 rows plus two above for the raised ear tips and two below
    /// for the outline and halo under the paws.
    static let rows = 34
    /// Sprite pixel where the outline under the paws meets the ground.
    static let groundY = 128.0
    /// Sprite pixel of the vertical center line (the middle of column 12).
    static let axisX = 50.0

    let cells: [[Role]]
    let eyes: [EyeBox]
    /// Center of the nose in sprite pixels.
    let muzzle: (x: Double, y: Double)

    static func variant(_ body: Body, eyesOpen: Bool) -> DesktopPetSprite {
        variants[Key(body: body, eyesOpen: eyesOpen)] ?? variants[Key(body: .sitting(headDrop: 0), eyesOpen: true)]!
    }

    /// Every variant the renderer asks for. Closed-eye variants keep the eye
    /// positions of the open ones so lids land where the eyes were.
    private static let variants: [Key: DesktopPetSprite] = {
        var result: [Key: DesktopPetSprite] = [:]
        for body in [Body.sitting(headDrop: 0), .sitting(headDrop: 1), .sitting(headDrop: 2), .loaf] {
            let open = build(body, eyesOpen: true, eyes: nil)
            result[Key(body: body, eyesOpen: true)] = open
            result[Key(body: body, eyesOpen: false)] = build(body, eyesOpen: false, eyes: open.eyes)
        }
        return result
    }()

    private static func build(_ body: Body, eyesOpen: Bool, eyes: [EyeBox]?) -> DesktopPetSprite {
        var grid = Grid()
        switch body {
        case .sitting(let headDrop): grid.composeSitting(headDrop: headDrop, eyesOpen: eyesOpen)
        case .loaf: grid.composeLoaf(eyesOpen: eyesOpen)
        }
        grid.outlineHalo()
        return DesktopPetSprite(
            cells: grid.cells,
            eyes: eyes ?? [grid.eyeBox(left: true), grid.eyeBox(left: false)],
            muzzle: grid.muzzle()
        )
    }
}

/// Writes roles into the cells. Coordinates are pixelpets' 30-row space and are
/// shifted down two rows here, so the raised ear tips keep their outline.
private struct Grid {
    typealias Role = DesktopPetSprite.Role

    private static let rowOffset = 2
    // pixelpets' "stocky" build: this cat is round with a big face.
    private static let cx = 12.0
    private static let bodyWidth = 1.16
    private static let headRx = 6.8, headRy = 6.0
    // Ears stand higher than pixelpets' so they clear the orange cap.
    private static let earApexY = -0.8, earBaseY = 5.8, earWidth = 2.8, earOut = 4.1
    private static let eyeRx = 2.0, eyeRy = 2.2

    var cells = Array(
        repeating: Array(repeating: Role.empty, count: DesktopPetSprite.columns),
        count: DesktopPetSprite.rows
    )

    private func contains(_ c: Int, _ row: Int) -> Bool {
        c >= 0 && c < DesktopPetSprite.columns && row >= 0 && row < DesktopPetSprite.rows
    }

    private mutating func set(_ c: Int, _ r: Int, _ role: Role, onlyOn: Set<Role>? = nil) {
        let row = r + Self.rowOffset
        guard contains(c, row) else { return }
        if let onlyOn, !onlyOn.contains(cells[row][c]) { return }
        cells[row][c] = role
    }

    private mutating func set(_ c: Double, _ r: Double, _ role: Role, onlyOn: Set<Role>? = nil) {
        set(Int(c), Int(r), role, onlyOn: onlyOn)
    }

    private mutating func ellipse(
        _ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ role: Role, onlyOn: Set<Role>? = nil
    ) {
        for r in Int((cy - ry).rounded(.down))...Int((cy + ry).rounded(.up)) {
            for c in Int((cx - rx).rounded(.down))...Int((cx + rx).rounded(.up)) {
                let dx = (Double(c) - cx) / rx, dy = (Double(r) - cy) / ry
                if dx * dx + dy * dy <= 1 { set(c, r, role, onlyOn: onlyOn) }
            }
        }
    }

    private mutating func triangle(
        _ a: (Double, Double), _ b: (Double, Double), _ c: (Double, Double), _ role: Role,
        onlyOn: Set<Role>? = nil
    ) {
        func sign(_ p: (Double, Double), _ q: (Double, Double), _ r: (Double, Double)) -> Double {
            (p.0 - r.0) * (q.1 - r.1) - (q.0 - r.0) * (p.1 - r.1)
        }
        let minC = Int(min(a.0, b.0, c.0).rounded(.down)), maxC = Int(max(a.0, b.0, c.0).rounded(.up))
        let minR = Int(min(a.1, b.1, c.1).rounded(.down)), maxR = Int(max(a.1, b.1, c.1).rounded(.up))
        for r in minR...maxR {
            for col in minC...maxC {
                let p = (Double(col), Double(r))
                let d1 = sign(p, a, b), d2 = sign(p, b, c), d3 = sign(p, c, a)
                let hasNegative = d1 < 0 || d2 < 0 || d3 < 0
                let hasPositive = d1 > 0 || d2 > 0 || d3 > 0
                if !(hasNegative && hasPositive) { set(col, r, role, onlyOn: onlyOn) }
            }
        }
    }

    /// Head, ears and face, `dy` rows below their sitting position. The face is
    /// white under an orange cap, split by a white blaze between the eyes.
    private mutating func head(dy: Double, eyesOpen: Bool) {
        let cx = Self.cx, rx = Self.headRx
        ellipse(cx, 8 + dy, rx, Self.headRy, .fur)
        ellipse(cx - rx * 0.7, 9.6 + dy, 1.7, 2.2, .fur)
        ellipse(cx + rx * 0.7, 9.6 + dy, 1.7, 2.2, .fur)
        ellipse(cx, 3.6 + dy, 8, 4.2, .orange, onlyOn: [.fur])
        triangle((cx, 4.6 + dy), (cx - 2.2, 9 + dy), (cx + 2.2, 9 + dy), .fur, onlyOn: [.orange])

        let earY = Self.earApexY + dy, baseY = Self.earBaseY + dy
        let ew = Self.earWidth, eo = Self.earOut, iw = ew * 0.55
        triangle((cx - eo - 0.5, earY), (cx - eo - ew, baseY + 1.2), (cx - eo + ew, baseY), .orange)
        triangle((cx + eo + 0.5, earY), (cx + eo + ew, baseY + 1.2), (cx + eo - ew, baseY), .orange)
        triangle((cx - eo - 0.3, earY + 1.6), (cx - eo - iw, baseY), (cx - eo + iw, baseY - 0.6), .innerEar)
        triangle((cx + eo + 0.3, earY + 1.6), (cx + eo + iw, baseY), (cx + eo - iw, baseY - 0.6), .innerEar)

        // Faint forehead stripes on the cap.
        for (c, r) in [(9.0, 4.0), (10.0, 5.0), (15.0, 4.0), (14.0, 5.0)] {
            set(c, r + dy, .stripe, onlyOn: [.orange])
        }
        if eyesOpen {
            ellipse(9, 8.2 + dy, Self.eyeRx, Self.eyeRy, .eye)
            ellipse(15, 8.2 + dy, Self.eyeRx, Self.eyeRy, .eye)
        }
        set(11.0, 11 + dy, .nose)
        set(12.0, 11 + dy, .nose)
        // The orange spot on the upper lip.
        set(9.0, 12 + dy, .orange)
        set(10.0, 12 + dy, .orange)
    }

    /// Darker rows across the orange flanks, away from the white chest.
    private mutating func flankStripes(rows: ClosedRange<Int>) {
        for r in rows where r % 3 == 0 {
            for c in 0..<DesktopPetSprite.columns where c < 8 || c > 16 {
                set(c, r, .stripe, onlyOn: [.orange])
            }
        }
    }

    mutating func composeSitting(headDrop: Int, eyesOpen: Bool) {
        let cx = Self.cx, bw = Self.bodyWidth
        ellipse(cx, 24, 7.6 * bw, 5, .fur)
        ellipse(cx, 16, 5.2 * bw, 7.5, .fur)
        // Orange back showing down both flanks; the chest stays white.
        ellipse(4.6, 21, 3.4, 6.5, .orange, onlyOn: [.fur])
        ellipse(19.4, 21, 3.4, 6.5, .orange, onlyOn: [.fur])
        flankStripes(rows: 14...27)
        head(dy: Double(headDrop), eyesOpen: eyesOpen)
        // Two white front legs and planted paws.
        ellipse(10, 23, 1.6, 5.2, .fur)
        ellipse(14, 23, 1.6, 5.2, .fur)
        ellipse(10, 27.4, 2, 1.7, .fur)
        ellipse(14, 27.4, 2, 1.7, .fur)
        // Carved last so the outline separates the legs and toes on white fur.
        for r in 19...29 { set(12, r, .empty) }
        for r in 22...29 {
            set(8, r, .empty)
            set(16, r, .empty)
        }
        set(10, 29, .empty)
        set(14, 29, .empty)
    }

    mutating func composeLoaf(eyesOpen: Bool) {
        let cx = Self.cx, bw = Self.bodyWidth
        // The tail wraps round the front-right base, drawn first so the body covers it.
        for (c, r) in [(20.4, 26.6), (18.6, 28.2), (16.2, 29.2)] {
            ellipse(c, r, 1.7, 1.6, .orange)
        }
        set(19.0, 28, .stripe)
        set(19.0, 29, .stripe)
        ellipse(16.2, 29.2, 0.9, 0.9, .fur, onlyOn: [.orange])
        // A low mound seen from the front: orange back, white bib and paws.
        ellipse(cx, 25, 8.9 * bw, 4.7, .orange)
        ellipse(cx, 21, 8.0 * bw, 4.0, .orange)
        flankStripes(rows: 18...28)
        head(dy: 6, eyesOpen: eyesOpen)
        ellipse(cx, 22, 2.6, 3.4, .fur, onlyOn: [.orange, .stripe])
        ellipse(9.6, 28.4, 2.0, 1.4, .fur, onlyOn: [.orange, .stripe])
        ellipse(14.4, 28.4, 2.0, 1.4, .fur, onlyOn: [.orange, .stripe])
        set(12, 28, .empty)
        set(12, 29, .empty)
    }

    /// Empty cells next to the cat become outline, and empty cells next to the
    /// outline become a pale halo, so the cat reads on any background.
    mutating func outlineHalo() {
        let columns = DesktopPetSprite.columns, rows = DesktopPetSprite.rows
        func neighbors(_ c: Int, _ r: Int, _ test: (Role) -> Bool) -> Bool {
            [(c - 1, r), (c + 1, r), (c, r - 1), (c, r + 1)].contains { c, r in
                contains(c, r) && test(cells[r][c])
            }
        }
        for r in 0..<rows {
            for c in 0..<columns where cells[r][c] == .empty {
                if neighbors(c, r, { $0 != .empty && $0 != .outline && $0 != .halo }) { cells[r][c] = .outline }
            }
        }
        for r in 0..<rows {
            for c in 0..<columns where cells[r][c] == .empty {
                if neighbors(c, r, { $0 == .outline }) { cells[r][c] = .halo }
            }
        }
    }

    func eyeBox(left: Bool) -> DesktopPetSprite.EyeBox {
        var minC = Int.max, maxC = Int.min, minR = Int.max, maxR = Int.min
        for r in cells.indices {
            for c in cells[r].indices where cells[r][c] == .eye && (c < DesktopPetSprite.columns / 2) == left {
                minC = min(minC, c); maxC = max(maxC, c)
                minR = min(minR, r); maxR = max(maxR, r)
            }
        }
        guard minC <= maxC else { return DesktopPetSprite.EyeBox(centerX: 0, centerY: 0, width: 0, height: 0) }
        let cell = Double(DesktopPetSprite.cell)
        return DesktopPetSprite.EyeBox(
            centerX: Double(minC + maxC + 1) / 2 * cell,
            centerY: Double(minR + maxR + 1) / 2 * cell,
            width: Double(maxC - minC + 1) * cell,
            height: Double(maxR - minR + 1) * cell
        )
    }

    func muzzle() -> (x: Double, y: Double) {
        var sumX = 0.0, sumY = 0.0, count = 0.0
        for r in cells.indices {
            for c in cells[r].indices where cells[r][c] == .nose {
                sumX += Double(c); sumY += Double(r); count += 1
            }
        }
        let cell = Double(DesktopPetSprite.cell)
        count = max(count, 1)
        return ((sumX / count + 0.5) * cell, (sumY / count + 0.5) * cell)
    }
}
