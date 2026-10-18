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
//  The meter (R9): a centre bar from -50 to +50 cents, green when the
//  display model's in-tune flag is set and orange otherwise, grey when
//  stale, with the cents underneath. The bar is set per hop from the
//  model's smoothed cents with no SwiftUI animation (KTD9).

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

        Canvas
        {
            context, size in
            var context = context
            MeterView.draw(&context, size, live: live, cents: cents,
                           stale: stale)
        }
    }

    nonisolated private static func draw(_ context: inout GraphicsContext,
                                         _ size: CGSize, live: Bool,
                                         cents: Double, stale: Bool)
    {
        let tickSize = size.height / 8
        let barSize = size.height / 5
        let textSize = size.height / 5
        let font = Font.system(size: textSize).monospacedDigit()

        // The scale leaves room for the end labels
        let margin = textSize * 1.5 + 4
        let left = margin
        let right = size.width - margin
        let centre = (left + right) / 2
        let perCent = (right - left) / 100

        // Labels
        let labelY = textSize / 2 + 2
        for (value, text) in [(-50, "-50"), (-25, "-25"), (0, "0"),
                              (25, "+25"), (50, "+50")]
        {
            context.draw(Text(text).font(font),
                         at: CGPoint(x: centre + Double(value) * perCent,
                                     y: labelY))
        }

        // Ticks every 5 cents, long ones under the labels
        let tickTop = labelY + textSize / 2 + 1
        var ticks = Path()
        for value in stride(from: -50, through: 50, by: 5)
        {
            let x = centre + Double(value) * perCent
            let length = (value % 25 == 0) ? tickSize : tickSize / 2
            ticks.move(to: CGPoint(x: x, y: tickTop))
            ticks.addLine(to: CGPoint(x: x, y: tickTop + length))
        }
        context.stroke(ticks, with: .color(.primary), lineWidth: 1)

        // The track
        let barY = tickTop + tickSize + 4
        context.fill(Path(CGRect(x: left, y: barY, width: right - left,
                                 height: barSize)),
                     with: .color(.secondary.opacity(0.25)))

        // Nothing more without a note
        if !live
        {
            return
        }

        // The bar from the centre to the cents, at least 3 points wide
        let x = centre + max(-50, min(50, cents)) * perCent
        let barWidth = max(abs(x - centre), 3)
        let barX = (cents < 0) ? centre - barWidth : centre
        let colour: Color = stale ? .gray
                                  : DisplayModel.inTune(cents) ? .green
                                                               : .orange
        context.fill(Path(CGRect(x: barX, y: barY, width: barWidth,
                                 height: barSize)),
                     with: .color(colour))

        // The centre line over the bar
        context.fill(Path(CGRect(x: centre - 0.5, y: barY, width: 1,
                                 height: barSize)),
                     with: .color(.secondary))

        // The cents under the bar
        context.draw(Text(String(format: "%+.1f\u{00A2}", cents))
                       .font(font)
                       .foregroundStyle(stale ? Color.gray : Color.primary),
                     at: CGPoint(x: centre,
                                 y: barY + barSize + textSize / 2 + 2))
    }
}
