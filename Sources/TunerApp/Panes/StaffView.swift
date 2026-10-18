//
//  StaffView.swift
//  Tuner
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//  The staff (R14): the glyph tables and the octave wrap rules ported
//  from swift/StaffView.swift. Coordinates are y-up as in the old
//  view, so the canvas flips once and draws the tables unchanged. No
//  note head before the first note; greyed when stale.

import SwiftUI
import TunerState

struct StaffView: View
{
    @Environment(AppModel.self) private var model

    var body: some View
    {
        // Read what the canvas draws here, so the observation tracks it
        let note = model.display.staffNote(transpose: model.settings.transpose)
        let stale = model.display.isStale

        Canvas
        {
            context, size in
            var context = context
            StaffView.draw(&context, size, note: note)
        }
        .opacity(stale ? 0.4 : 1)
    }

    // Treble clef
    nonisolated private static let treble: [[Double]] =
    [
      [-6, 16], [-8, 13],
      [-14, 19], [-10, 35], [2, 35],
      [8, 37], [21, 30], [21, 17],
      [21, 5], [10, -1], [0, -1],
      [-12, -1], [-23, 5], [-23, 22],
      [-23, 29], [-22, 37], [-7, 49],
      [10, 61], [10, 68], [10, 73],
      [10, 78], [9, 82], [7, 82],
      [2, 78], [-2, 68], [-2, 62],
      [-2, 25], [10, 18], [11, -8],
      [11, -18], [5, -23], [-4, -23],
      [-10, -23], [-15, -18], [-15, -13],
      [-15, -8], [-12, -4], [-7, -4],
      [3, -4], [3, -20], [-6, -17],
      [-5, -23], [9, -20], [9, -9],
      [7, 24], [-5, 30], [-5, 67],
      [-5, 78], [-2, 87], [7, 91],
      [13, 87], [18, 80], [17, 73],
      [17, 62], [10, 54], [1, 45],
      [-5, 38], [-15, 33], [-15, 19],
      [-15, 7], [-8, 1], [0, 1],
      [8, 1], [15, 6], [15, 14],
      [15, 23], [7, 26], [2, 26],
      [-5, 26], [-9, 21], [-6, 16]
    ]

    // Bass clef
    nonisolated private static let bass: [[Double]] =
    [
      [-2.3, 3],
      [6, 7], [10.5, 12], [10.5, 16],
      [10.5, 20.5], [8.5, 23.5], [6.2, 23.3],
      [5.2, 23.5], [2, 23.5], [0.5, 19.5],
      [2, 20], [4, 19.5], [4, 18],
      [4, 17], [3.5, 16], [2, 16],
      [1, 16], [0, 16.9], [0, 18.5],
      [0, 21], [2.1, 24], [6, 24],
      [10, 24], [13.5, 21.5], [13.5, 16.5],
      [13.5, 11], [7, 5.5], [-2.0, 2.8],
      [14.9, 21],
      [14.9, 22.5], [16.9, 22.5], [16.9, 21],
      [16.9, 19.5], [14.9, 19.5], [14.9, 21],
      [14.9, 15],
      [14.9, 16.5], [16.9, 16.5], [16.9, 15],
      [16.9, 13.5], [14.9, 13.5], [14.9, 15]
    ]

    // Note head
    nonisolated private static let head: [[Double]] =
    [
      [8.0, 0.0],
      [8.0, 8.0], [-8.0, 8.0], [-8.0, 0.0],
      [-8.0, -8.0], [8.0, -8.0], [8.0, 0.0]
    ]

    // Sharp symbol
    nonisolated private static let sharp: [[Double]] =
    [
      [35, 35], [8, 22], [8, 46], [35, 59], [35, 101], [8, 88],
      [8, 111], [35, 125], [35, 160], [44, 160], [44, 129], [80, 147],
      [80, 183], [89, 183], [89, 151], [116, 165], [116, 141], [89, 127],
      [89, 86], [116, 100], [116, 75], [89, 62], [89, 19], [80, 19],
      [80, 57], [44, 39], [44, -1], [35, -1], [35, 35],
      [44, 64], [80, 81], [80, 123], [44, 105], [44, 64]
    ]

    // Flat symbol
    nonisolated private static let flat: [[Double]] =
    [
      [20, 86],
      [28, 102.667], [41.6667, 111], [61, 111],
      [71.6667, 111], [80.3333, 107.5], [87, 100.5],
      [93.6667, 93.5], [97, 83.6667], [97, 71],
      [97, 53], [89, 36.6667], [73, 22],
      [57, 7.33333], [35.3333, -1.33333], [8, -4],
      [8, 195],
      [20, 195],
      [20, 86],
      [20, 7],
      [35.3333, 9], [47.8333, 15.6667], [57.5, 27],
      [67.1667, 38.3333], [72, 51.6667], [72, 67],
      [72, 75.6667], [70.1667, 82.3333], [66.5, 87],
      [62.8333, 91.6667], [57.3333, 94], [50, 94],
      [41.3333, 94], [34.1667, 90.3333], [28.5, 83],
      [22.8333, 75.6667], [20, 64.6667], [20, 50],
      [20, 7]
    ]

    // Scale offsets in staff steps from C
    nonisolated private static let offset: [Double] =
    [0, 0, 1, 2, 2, 3, 3, 4, 5, 5, 6, 6]

    // point
    nonisolated private static func point(_ table: [[Double]],
                                          _ i: Int) -> CGPoint
    {
        return CGPoint(x: table[i][0], y: table[i][1])
    }

    // curves: cubic segments from the current point, three table
    // entries each, over indices i, i + 3, ... below end
    nonisolated private static func curves(_ path: inout Path,
                                           _ table: [[Double]],
                                           from start: Int, to end: Int)
    {
        for i in stride(from: start, to: end, by: 3)
        {
            path.addCurve(to: point(table, i + 2),
                          control1: point(table, i),
                          control2: point(table, i + 1))
        }
    }

    // The clefs and accidentals as paths in table units
    nonisolated private static func trebleClef() -> Path
    {
        var path = Path()
        path.move(to: point(treble, 0))
        path.addLine(to: point(treble, 1))
        curves(&path, treble, from: 2, to: treble.count)
        return path
    }

    nonisolated private static func bassClef() -> Path
    {
        var path = Path()
        path.move(to: point(bass, 0))
        curves(&path, bass, from: 1, to: 27)

        // Two dots
        path.move(to: point(bass, 28))
        curves(&path, bass, from: 29, to: 34)
        path.move(to: point(bass, 35))
        curves(&path, bass, from: 36, to: bass.count)
        return path
    }

    nonisolated private static func noteHead() -> Path
    {
        var path = Path()
        path.move(to: point(head, 0))
        curves(&path, head, from: 1, to: head.count)
        return path
    }

    nonisolated private static func sharpSign() -> Path
    {
        var path = Path()
        path.move(to: point(sharp, 0))
        for i in 1 ... 28
        {
            path.addLine(to: point(sharp, i))
        }

        path.move(to: point(sharp, 0))
        for i in 29 ... 33
        {
            path.addLine(to: point(sharp, i))
        }
        return path
    }

    nonisolated private static func flatSign() -> Path
    {
        var path = Path()
        path.move(to: point(flat, 0))
        curves(&path, flat, from: 1, to: 15)
        for i in 15 ... 18
        {
            path.addLine(to: point(flat, i))
        }

        path.move(to: point(flat, 19))
        curves(&path, flat, from: 19, to: 36)
        path.addLine(to: point(flat, 38))
        return path
    }

    // scaled: the path scaled to a height, measured on the control
    // points as NSBezierPath.bounds did, then moved
    nonisolated private static func scaled(_ path: Path, height: Double,
                                           centred: Bool = false) -> Path
    {
        let bounds = path.cgPath.boundingBox
        var transform = CGAffineTransform.identity
        if centred
        {
            transform = transform.translatedBy(x: -bounds.midX,
                                               y: -bounds.midY)
        }

        let scale = height / bounds.height
        return path.applying(transform.concatenating(
                               CGAffineTransform(scaleX: scale, y: scale)))
    }

    // moved
    nonisolated private static func moved(_ path: Path, _ x: Double,
                                          _ y: Double) -> Path
    {
        return path.applying(CGAffineTransform(translationX: x, y: y))
    }

    // draw
    nonisolated private static func draw(_ context: inout GraphicsContext,
                                         _ size: CGSize, note: DisplayNote?)
    {
        // Y-up from the vertical middle, as the old view drew
        context.translateBy(x: 0, y: size.height / 2)
        context.scaleBy(x: 1, y: -1)

        let width = size.width
        let height = size.height
        let lineHeight = height / 14
        let lineWidth = width / 16
        let margin = width / 32

        // The staff
        var lines = Path()
        for i in 1 ... 5
        {
            let y = Double(i) * lineHeight
            lines.move(to: CGPoint(x: margin, y: y))
            lines.addLine(to: CGPoint(x: width - margin, y: y))
            lines.move(to: CGPoint(x: margin, y: -y))
            lines.addLine(to: CGPoint(x: width - margin, y: -y))
        }

        // Leger lines
        lines.move(to: CGPoint(x: width / 2 - lineWidth / 2, y: 0))
        lines.addLine(to: CGPoint(x: width / 2 + lineWidth / 2, y: 0))
        lines.move(to: CGPoint(x: width / 2 + lineWidth * 5.5,
                               y: lineHeight * 6))
        lines.addLine(to: CGPoint(x: width / 2 + lineWidth * 6.5,
                                  y: lineHeight * 6))
        lines.move(to: CGPoint(x: width / 2 - lineWidth * 5.5,
                               y: -lineHeight * 6))
        lines.addLine(to: CGPoint(x: width / 2 - lineWidth * 6.5,
                                  y: -lineHeight * 6))
        context.stroke(lines, with: .color(.primary), lineWidth: 1)

        // Clefs
        context.fill(moved(scaled(trebleClef(), height: height / 2),
                           margin + lineWidth / 2, lineHeight),
                     with: .color(.primary))
        context.fill(moved(scaled(bassClef(), height: lineHeight * 4),
                           margin + lineWidth / 4, -lineHeight * 5.4),
                     with: .color(.primary))

        // No note head until the first note
        guard let note else
        {
            return
        }

        // A note transposed below C0 draws as octave 0, as it always has
        var octave = max(note.octave, 0)
        let index = note.index

        // Wrap the top two octaves
        if octave >= 6
        {
            octave -= 2
        }

        // Wrap C0
        else if octave == 0 && index <= 1
        {
            octave += 4
        }

        // Wrap the bottom two octaves
        else if octave <= 1 || octave == 2 && index <= 1
        {
            octave += 2
        }

        let xBase = lineWidth * 14
        let yBase = lineHeight * 14
        let dx = Double(octave) * lineWidth * 3.5 +
                 offset[index] * (lineWidth / 2)
        let dy = Double(octave) * lineHeight * 3.5 +
                 offset[index] * (lineHeight / 2)
        let x = width / 2 - xBase + dx
        let y = -yBase + dy

        context.fill(moved(scaled(noteHead(), height: lineHeight * 1.5),
                           x, y),
                     with: .color(.primary))

        switch note.accidental
        {
        case .natural:
            break

        case .sharp:
            context.fill(moved(scaled(sharpSign(), height: lineHeight * 3,
                                      centred: true),
                               x - lineWidth / 2, y),
                         with: .color(.primary))

        case .flat:
            context.fill(moved(scaled(flatSign(), height: lineHeight * 3,
                                      centred: true),
                               x - lineWidth / 2, y + lineHeight / 2),
                         with: .color(.primary))
        }
    }
}
