//
//  AppModel.swift
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
//  The app-level model, injected through the environment. It owns the
//  settings and the display model and holds the actions the toolbar,
//  the menus, the bare keys and the pane clicks share, so each mirror
//  of a toggle reads the same state.

import AppKit
import Observation
import TunerState

@Observable
final class AppModel
{
    let settings = Settings()
    let display = DisplayModel()

    // toggleLock
    func toggleLock()
    {
        display.isLocked.toggle()
    }

    // toggleStrobe: the strobe and the staff replace each other
    func toggleStrobe()
    {
        settings.strobe.toggle()
    }

    // copyReadout: the readout line to the pasteboard; nothing in blank
    func copyReadout()
    {
        guard let line = display.copyLine(transpose: settings.transpose)
        else
        {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(line, forType: .string)
    }
}
