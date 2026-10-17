//
//  Display.swift
//  Tuner
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

class DisplayView: TunerView
{
    let kTextSize: CGFloat = 12

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
            needsDisplay = true
        }
    }

    // draw
    override func draw(_ dirtyRect: NSRect)
    {
        super.draw(dirtyRect)

        // Text sizes
        let textSizeLarger = height / 2
        let textSizeLarge = height / 3
        let textSizeMedium = height / 5
        let textSizeSmall = height / 9

        // Drawing code here.
        NSEraseRect(rect)

        // The held or live reading, none until the first note
        let reading = model.reading
        let stale = model.isStale

        if (settings.multiple), let reading
        {
	    // Select font
            let font = NSFont.systemFont(ofSize: textSizeSmall)
            let attribs: [NSAttributedString.Key: Any] = [.font: font]

            var s = ""
            var x = rect.minX + 2
            var y = rect.maxY - textSizeSmall - 2

            // The rows clear when the reading goes stale
            let reeds = stale ? [] : reading.reeds

            // No data, probably
	    if (reeds.count == 0)
	    {
                let c = reading.cents / 100
                let f = reading.frequency
                let fr = reading.reference

	        // Display note
                s = reading.displayNote(transpose: settings.transpose).text
                s.draw(at: NSMakePoint(x, y), withAttributes: attribs)
                x += s.size(withAttributes: attribs).width +
                  "  ".size(withAttributes: attribs).width

	        // Display cents
                s = String(format: "%+4.2lf\u{00A2}", c * 100.0)
                s.draw(at: NSMakePoint(x, y), withAttributes: attribs)
                x += s.size(withAttributes: attribs).width +
                  "  ".size(withAttributes: attribs).width

	        // Display reference
	        s = String(format: "%4.2lfHz", fr);
                s.draw(at: NSMakePoint(x, y), withAttributes: attribs)
                x += s.size(withAttributes: attribs).width +
                  "  ".size(withAttributes: attribs).width

	        // Display frequency
	        s = String(format: "%4.2lfHz", f);
                s.draw(at: NSMakePoint(x, y), withAttributes: attribs)
                x += s.size(withAttributes: attribs).width +
                  "  ".size(withAttributes: attribs).width

	        // Display difference
	        s = String(format: "%+4.2lfHz", f - fr);
                s.draw(at: NSMakePoint(x, y), withAttributes: attribs)
            }

            // The reeds skip a maximum with no note or silly cents
            for reed in reeds
            {
                // Actual freq
	        let f = reed.frequency

	        // Reference freq
	        let fr = reed.reference

                // Cents
	        let c = reed.cents / 100

	        // Display note
	        s = DisplayNote(note: reed.note,
                                transpose: settings.transpose).text
                s.draw(at: NSMakePoint(x, y), withAttributes: attribs)
                x += s.size(withAttributes: attribs).width +
                  "  ".size(withAttributes: attribs).width
	        // Display cents

	        s = String(format: "%+4.2lf\u{00A2}", c * 100.0)
                s.draw(at: NSMakePoint(x, y), withAttributes: attribs)
                x += s.size(withAttributes: attribs).width +
                  "  ".size(withAttributes: attribs).width
	        // Display reference

	        s = String(format: "%4.2lfHz", fr)
                s.draw(at: NSMakePoint(x, y), withAttributes: attribs)
                x += s.size(withAttributes: attribs).width +
                  "  ".size(withAttributes: attribs).width
	        // Display frequency

	        s = String(format: "%4.2lfHz", f)
                s.draw(at: NSMakePoint(x, y), withAttributes: attribs)
                x += s.size(withAttributes: attribs).width +
                  "  ".size(withAttributes: attribs).width
	        // Display difference

	        s = String(format: "%+4.2lfHz", f - fr)
                s.draw(at: NSMakePoint(x, y), withAttributes: attribs)
                y += textSizeSmall
            }
        }

        // Leave the display blank until the first note
        else if let reading
        {
            let shown = reading.displayNote(transpose: settings.transpose)
            let f = reading.frequency
            let fr = reading.reference

            var s = ""
            var x = rect.minX + 2
            var y = rect.maxY - textSizeLarger - 2

	    // Select font
            var font = NSFont.boldSystemFont(ofSize: textSizeLarger)
            var attribs: [NSAttributedString.Key: Any] = [.font: font]

	    s = shown.name
            s.draw(at: NSMakePoint(x, y), withAttributes: attribs)
            x += s.size(withAttributes: attribs).width

	    // Select font
            font = NSFont.boldSystemFont(ofSize: textSizeLarger / 2)
            attribs = [.font: font]

	    s = String(format: "%d", shown.octave)
            s.draw(at: NSMakePoint(x, y), withAttributes: attribs)
            var noteRight = x + s.size(withAttributes: attribs).width

	    // Select font
            font = NSFont.boldSystemFont(ofSize: textSizeLarger / 2)
            attribs = [.font: font]

	    s = shown.symbol
            s.draw(at: NSMakePoint(x, y + textSizeLarger / 2),
                   withAttributes: attribs)
            noteRight = max(noteRight, x + s.size(withAttributes: attribs).width)

	    // Select font, as large as fits beside the note, sized for the
            // widest frequency so it doesn't jump about between notes
            let room = rect.maxX - noteRight - 8
            var size = textSizeLarge
            font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .bold)
            attribs = [.font: font]
            var dx = "0000.00 Hz".size(withAttributes: attribs).width
            if (dx > room)
            {
                size *= room / dx
                font = NSFont.monospacedDigitSystemFont(ofSize: size,
                                                        weight: .bold)
                attribs = [.font: font]
            }

            // Right justify the measured frequency
	    s = String(format: "%.2f Hz", f)
            x = rect.maxX - s.size(withAttributes: attribs).width - 2
            s.draw(at: NSMakePoint(x, y), withAttributes: attribs)

	    // Select font, shrinking it if the row won't fit
            size = textSizeMedium
            font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .bold)
            attribs = [.font: font]
            dx = "target 0000.00 Hz".size(withAttributes: attribs).width +
              "+000.00 Hz".size(withAttributes: attribs).width
            if (dx > width - 16)
            {
                size *= (width - 16) / dx
                font = NSFont.monospacedDigitSystemFont(ofSize: size,
                                                        weight: .bold)
                attribs = [.font: font]
            }

	    y -= textSizeMedium + 4
            x = rect.minX + 2

	    s = String(format: "target %.2f Hz", fr)
            s.draw(at: NSMakePoint(x, y), withAttributes: attribs)

            // Right justify
	    s = String(format: "%+.2f Hz", f - fr)
            x = rect.maxX - s.size(withAttributes: attribs).width - 2
            s.draw(at: NSMakePoint(x, y), withAttributes: attribs)

	    y -= textSizeMedium
            x = rect.minX + 2

	    s = String(format: "A4 = %.2f Hz", settings.reference)
            s.draw(at: NSMakePoint(x, y), withAttributes: attribs)
        }

        // Grey out a reading that is no longer live
        if (stale)
        {
            NSColor(white: 1, alpha: 0.6).set()
            NSBezierPath.fill(rect)
        }

        // Display L if locked
        if (model.isLocked)
        {
            let font = NSFont.boldSystemFont(ofSize: kTextSize)
            let attribs: [NSAttributedString.Key: Any] = [.font: font]

            "L".draw(at: NSMakePoint(rect.minX + 2, rect.minY),
                     withAttributes: attribs)
        }
    }
}
