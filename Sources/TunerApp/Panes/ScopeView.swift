//
//  ScopeView.swift
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
//  The scope (R10): the newest input samples on a dark graticule, in
//  green, triggered on the steepest rising slope, with a yellow F
//  while the filter is on and FF for the fundamental filter. It
//  redraws when the trace store takes a new snapshot, which is the
//  display model's trace refresh, and when the pane or a setting
//  changes; between those nothing runs.

import SwiftUI
import TunerState

struct ScopeView: View
{
    @Environment(AppModel.self) private var model

    var body: some View
    {
        // Read everything the canvas draws here, so the observation
        // tracks it and the drawing closure holds plain values
        let samples = model.traces.scope
        let filter = model.settings.filter
        let fundamental = model.settings.fundamental

        Canvas
        {
            context, size in
            var context = context
            ScopeView.draw(&context, size, samples: samples, filter: filter,
                           fundamental: fundamental)
        }
    }

    // The graticule is shared with the spectrum
    nonisolated static let graticule = Color(red: 0, green: 0.25, blue: 0)
    nonisolated static let textSize = 10.0

    nonisolated static func drawGraticule(_ context: inout GraphicsContext,
                                          _ size: CGSize)
    {
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(.black))

        var lines = Path()
        for x in stride(from: 0.0, to: size.width, by: 6)
        {
            lines.move(to: CGPoint(x: x, y: 0))
            lines.addLine(to: CGPoint(x: x, y: size.height))
        }

        for y in stride(from: 0.0, to: size.height, by: 6)
        {
            lines.move(to: CGPoint(x: 0, y: y))
            lines.addLine(to: CGPoint(x: size.width, y: y))
        }

        context.stroke(lines, with: .color(graticule), lineWidth: 1)
    }

    nonisolated static func badge(_ text: String, font: Font = .system(size: textSize))
        -> Text
    {
        return Text(text).font(font).foregroundStyle(.yellow)
    }

    nonisolated private static func draw(_ context: inout GraphicsContext,
                                         _ size: CGSize, samples: [Double],
                                         filter: Bool, fundamental: Bool)
    {
        drawGraticule(&context, size)

        if filter
        {
            context.draw(badge("F"), at: CGPoint(x: 2, y: 2),
                         anchor: .topLeading)
        }

        if fundamental
        {
            context.draw(badge("FF"), at: CGPoint(x: 2, y: size.height - 2),
                         anchor: .bottomLeading)
        }

        let width = Int(size.width)
        guard width > 1, !samples.isEmpty else
        {
            return
        }

        samples.withUnsafeBufferPointer
        {
            let first = ScopeTrace.trigger($0, width: width)
            let count = ScopeTrace.points(count: $0.count, trigger: first,
                                          width: width)

            // The scale follows the trace's own peak, at least 0.125
            var peak = 0.125
            for i in 0 ..< count
            {
                peak = max(peak, abs($0[first + i * ScopeTrace.step]))
            }

            let middle = size.height / 2
            let yscale = middle / peak

            var trace = Path()
            for i in 0 ..< count
            {
                let y = middle - $0[first + i * ScopeTrace.step] * yscale
                let point = CGPoint(x: Double(i), y: y)
                if i == 0
                {
                    trace.move(to: point)
                }

                else
                {
                    trace.addLine(to: point)
                }
            }

            context.stroke(trace, with: .color(.green), lineWidth: 1)
        }
    }
}
