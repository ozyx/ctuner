//
//  TunerView.swift
//  Tuner
//
//  Created by Bill Farmer on 08/10/2017.
//  Copyright © 2017 Bill Farmer. All rights reserved.
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

class TunerView: NSView
{
    var rect: NSRect = .zero
    var width: CGFloat = 0
    var height: CGFloat = 0

    // draw
    override func draw(_ dirtyRect: NSRect)
    {
        super.draw(dirtyRect)

        // Drawing code here.
        rect = DrawEdge(bounds)
        width = rect.width
        height = rect.height
    }

    // DrawEdge
    func DrawEdge(_ rect: NSRect) -> NSRect
    {
        // Save context
        NSGraphicsContext.saveGraphicsState()

        // Set colour
        NSColor.lightGray.set()

        // Draw edge
        var path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        path.fill()

        // Restore context before clip
        NSGraphicsContext.restoreGraphicsState()

        // Create inset
        let inset = NSInsetRect(rect, 2, 2)
        path = NSBezierPath(roundedRect: inset, xRadius: 8, yRadius: 8)
        path.setClip()

        return inset
    }

    // This, IMHO is a kludge because you ought to be able to do this
    // in AppDelegate rather than one of the views
    // keyDown
    override func keyDown(with event: NSEvent)
    {
        let key = event.characters!

        switch key.lowercased()
        {
        case "c":
            // Copy the readout
            copyReadout()

        case "k":
            // Change colour
            if (settings.colour + 1 >= strobeView.kMaxColours)
            {
                settings.colour = 0
            }

            else
            {
                settings.colour += 1
            }

            // Update popup
            if (colourPopUp != nil)
            {
                colourPopUp.selectItem(at: settings.colour)
            }

            // Update strobe view
            strobeView.changed = true
            strobeView.needsDisplay = true

        case "d":
            // Update downsampling
            settings.downsample = !settings.downsample
            if (downBox != nil)
            {
                downBox.state = settings.downsample ? .on: .off
            }
            // Update spectrum view
            spectrumView.needsDisplay = true

        case "f":
            // Update filter
            settings.filter = !settings.filter
            if (filtBox != nil)
            {
                filtBox.state = settings.filter ? .on: .off
            }
            // Update scope view
            scopeView.needsDisplay = true

        case "l":
            // Update display lock
            model.isLocked = !model.isLocked
            if (lockBox != nil)
            {
                lockBox.state = model.isLocked ? .on: .off
            }
            // Update display
            displayView.needsDisplay = true

        case "m":
            // Update multiple notes
            settings.multiple = !settings.multiple
            if (multBox != nil)
            {
                multBox.state = settings.multiple ? .on: .off
            }
            // Update display
            displayView.needsDisplay = true

        case "s":
            // Switch views
            strobeView.enable = !strobeView.enable
            staffView.enable = !strobeView.enable
            // Hide views, animation here
            if (strbBox != nil)
            {
                strbBox.state = strobeView.enable ? .on: .off
            }

        case "z":
            // Update zoom
            settings.zoom = !settings.zoom
            if (zoomBox != nil)
            {
                zoomBox.state = settings.zoom ? .on: .off
            }

        case "+":
            // Expand spectrum
            if (settings.expand * 2 > kMaxExpand)
            {
                settings.expand = kMinExpand
            }

            else
            {
                settings.expand *= 2
            }
            if (expandPopUp != nil)
            {
                expandPopUp
                  .selectItem(at: Int(log2(Float(settings.expand))))
            }

        case "-":
            // Contract spectrum
            if (settings.expand / 2 < kMinExpand)
            {
                settings.expand = kMaxExpand
            }

            else
            {
                settings.expand /= 2
            }
            if (expandPopUp != nil)
            {
                expandPopUp
                  .selectItem(at: Int(log2(Float(settings.expand))))
            }

        default:
            NSLog("Key %@", key)
            break
        }
    }
}
