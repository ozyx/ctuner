//
//  MeterView.swift
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
//  The meter, as docs/plans/2026-11-11-1526-feat-readout-cents-meter-scale-plan.md
//  amends it: a centre bar on MeterScale, whose middle half is the 5
//  cents either side of zero and whose outer quarters run to 50 cents,
//  with a labelled tick for each value and the in-tune zone drawn behind
//  the bar. The bar is green inside the zone, orange outside it and grey
//  when stale. The bar is set per hop from the model's smoothed cents
//  with no SwiftUI animation (KTD9).

import SwiftUI
import TunerState

struct MeterView: View
{
    @Environment(AppModel.self) private var model

    var body: some View
    {
        // Read everything the canvas draws here, so the observation
        // tracks it and the drawing closure holds plain values
        let live = model.display.reading != nil
        let cents = model.display.meterCents
        let stale = model.display.isStale
        let tolerance = model.settings.inTuneTolerance

        Canvas
        {
            context, size in
            var context = context
            MeterView.draw(&context, size, live: live, cents: cents,
                           stale: stale, tolerance: tolerance)
        }
    }

    nonisolated private static func draw(_ context: inout GraphicsContext,
                                         _ size: CGSize, live: Bool,
                                         cents: Double, stale: Bool,
                                         tolerance: Int)
    {
        let tickSize = size.height / 8
        let textSize = size.height / 5
        let font = Font.system(size: textSize).monospacedDigit()

        // The scale leaves room for the end labels
        let margin = textSize * 1.5 + 4
        let left = margin
        let right = size.width - margin
        let centre = (left + right) / 2
        let halfWidth = (right - left) / 2

        let labelY = textSize / 2 + 2
        let tickTop = labelY + textSize / 2 + 1
        var ticks = Path()
        for tick in MeterScale.ticks
        {
            let x = centre + tick.position * halfWidth
            context.draw(Text(tick.label).font(font),
                         at: CGPoint(x: x, y: labelY))
            ticks.move(to: CGPoint(x: x, y: tickTop))
            ticks.addLine(to: CGPoint(x: x, y: tickTop + tickSize))
        }
        context.stroke(ticks, with: .color(.primary), lineWidth: 1)

        let barY = tickTop + tickSize + 4
        let barSize = max(size.height - barY - 2, 4)
        context.fill(Path(CGRect(x: left, y: barY, width: right - left,
                                 height: barSize)),
                     with: .color(.secondary.opacity(0.25)))

        let zoneHalfWidth = MeterScale.position(cents: Double(tolerance))
          * halfWidth
        context.fill(Path(CGRect(x: centre - zoneHalfWidth, y: barY,
                                 width: 2 * zoneHalfWidth,
                                 height: barSize)),
                     with: .color(.green.opacity(0.3)))

        // Nothing more without a note
        if !live
        {
            return
        }

        // The bar from the centre to the cents, at least 3 points wide
        let x = centre + MeterScale.position(cents: cents) * halfWidth
        let barWidth = max(abs(x - centre), 3)
        let barX = (cents < 0) ? centre - barWidth : centre
        let colour: Color = stale ? .gray
          : DisplayModel.inTune(cents, tolerance: tolerance) ? .green
                                                             : .orange
        context.fill(Path(CGRect(x: barX, y: barY, width: barWidth,
                                 height: barSize)),
                     with: .color(colour))

        // The centre line over the bar
        context.fill(Path(CGRect(x: centre - 0.5, y: barY, width: 1,
                                 height: barSize)),
                     with: .color(.secondary))
    }
}
