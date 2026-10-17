//
//  Meter.swift
//  Tuner
//
//  Created by Bill Farmer on 08/10/2017.
//  Copyright © 2017 Bill Farmer. All rights reserved.
//
//  Created by Bill Farmer on 18/02/2018.
//  Copyright © 2018 Bill Farmer. All rights reserved.
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

import Cocoa
import TunerState

// TunerView
class MeterView: TunerView
{
    // The font and its metrics, made again only when the text size
    // changes, as looking up the font every redraw was most of the cost
    var textSize: CGFloat = 0
    var attribs: [NSAttributedString.Key: Any] = [:]
    var textHeight: CGFloat = 0
    var labelWidths: [String: CGFloat] = [:]

    // What the last draw showed, so the timer can leave an unchanged
    // meter alone
    var shown: (Bool, Double, Bool)?

    // What the meter would show now; the cents don't matter without a note
    var showing: (Bool, Double, Bool)
    {
        let live = model.reading != nil
        return (live, live ? model.meterCents: 0, model.isStale)
    }

    // changed
    var changed: Bool
    {
        guard let shown = shown else {return true}
        return shown != showing
    }

    // mouseDown
    override func mouseDown(with event: NSEvent)
    {
        if (event.type == .leftMouseDown)
        {
            model.isLocked = !model.isLocked
            if (lockBox != nil)
            {
                lockBox.state = model.isLocked ? .on: .off
            }
            displayView.needsDisplay = true
        }
    }

    // draw
    override func draw(_ dirtyRect: NSRect)
    {
        super.draw(dirtyRect)

        // The display model smooths the cents every hop, as this view
        // used to every redraw
        let cents = model.meterCents
        shown = showing

        // Context
        let context = NSGraphicsContext.current!

        // Tick and bar sizes
        let tickSize = height / 8
        let barSize = height / 5

        // Font, with fixed width digits so the numbers don't jitter
        if (textSize != height / 5)
        {
            textSize = height / 5
            let font = NSFont.monospacedDigitSystemFont(ofSize: textSize,
                                                        weight: .regular)
            attribs = [.font: font]
            textHeight = "0".size(withAttributes: attribs).height
            labelWidths = [:]
            for s in ["-50", "-25", "0", "+25", "+50"]
            {
                labelWidths[s] = s.size(withAttributes: attribs).width
            }
        }

        // Drawing code here.
        NSEraseRect(rect)

        // Scale runs from -50 to +50 cents, leaving room for the end labels
        let margin = labelWidths["-50"]! / 2 + 4
        let left = rect.minX + margin
        let right = rect.maxX - margin
        let centre = (left + right) / 2
        let perCent = (right - left) / 100

        // Draw the labels
        let labelY = rect.maxY - textHeight - 2
        for (v, s) in [(-50, "-50"), (-25, "-25"), (0, "0"),
                       (25, "+25"), (50, "+50")]
        {
            let x = centre + CGFloat(v) * perCent
            let offset = labelWidths[s]! / 2
            s.draw(at: NSMakePoint(x - offset, labelY),
                   withAttributes: attribs)
        }

        // Draw the ticks, every 5 cents, long ones under the labels
        let tickTop = labelY
        NSColor.black.set()
        context.shouldAntialias = false
        for v in stride(from: -50, through: 50, by: 5)
        {
            let x = centre + CGFloat(v) * perCent
            let length = (v % 25 == 0) ? tickSize: tickSize / 2
            NSBezierPath.strokeLine(from: NSMakePoint(x, tickTop),
                                    to: NSMakePoint(x, tickTop - length))
        }
        context.shouldAntialias = true

        // Draw the track
        let barY = tickTop - tickSize - 4 - barSize
        NSColor(white: 0.9, alpha: 1).set()
        NSBezierPath.fill(NSMakeRect(left, barY, right - left, barSize))

        // Nothing more to show without a note
        if (model.reading == nil)
        {
            return
        }

        // Draw the bar from the centre to the measured cents, green
        // when within 5 cents, grey once the reading is no longer live,
        // at least 3 points wide so it shows
        let x = centre + CGFloat(max(-50, min(50, cents))) * perCent
        let barWidth = max(abs(x - centre), 3)
        let barX = (cents < 0) ? centre - barWidth: centre
        let inTune = DisplayModel.inTune(cents)
        let stale = model.isStale
        (stale ? NSColor.lightGray:
           inTune ? NSColor.systemGreen: NSColor.systemOrange).set()
        NSBezierPath.fill(NSMakeRect(barX, barY, barWidth, barSize))

        // Draw the centre line over the bar
        NSColor.darkGray.set()
        NSBezierPath.fill(NSMakeRect(centre - 0.5, barY, 1, barSize))

        // Draw the cents under the bar
        let s = String(format: "%+.1f\u{00A2}", cents)
        let offset = s.size(withAttributes: attribs).width / 2
        var centsAttribs = attribs
        if (stale)
        {
            centsAttribs[.foregroundColor] = NSColor.gray
        }
        s.draw(at: NSMakePoint(centre - offset, barY - textHeight - 2),
               withAttributes: centsAttribs)
    }
}
