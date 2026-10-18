//
//  Commands.swift
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
//  The menu commands (R16, KTD11). The bare letters are the shortcuts,
//  so one binding serves the menu item and the key; a focused text
//  field takes the key instead. The Print, Find, Spelling and Help
//  items that did nothing are not carried over, and the app-settings
//  group is left alone.

import AppKit
import SwiftUI
import TunerState

struct TunerCommands: Commands
{
    let model: AppModel
    @Bindable private var settings: TunerState.Settings
    @Bindable private var display: DisplayModel

    init(model: AppModel)
    {
        self.model = model
        _settings = Bindable(model.settings)
        _display = Bindable(model.display)
    }

    var body: some Commands
    {
        CommandGroup(replacing: .printItem) {}
        CommandGroup(replacing: .textEditing) {}
        CommandGroup(replacing: .help) {}

        // Edit > Copy copies the readout, unless a text field is
        // being edited, which keeps its own copy (R18)
        CommandGroup(replacing: .pasteboard)
        {
            Button("Cut") { send(#selector(NSText.cut(_:))) }
                .keyboardShortcut("x")
            Button("Copy") { copy() }
                .keyboardShortcut("c")
            Button("Paste") { send(#selector(NSText.paste(_:))) }
                .keyboardShortcut("v")
            Button("Select All") { send(#selector(NSText.selectAll(_:))) }
                .keyboardShortcut("a")
        }

        CommandGroup(after: .toolbar)
        {
            Divider()

            Toggle("Multiple Reeds", isOn: $settings.multiple)
                .keyboardShortcut("m", modifiers: [])
            Toggle("Strobe", isOn: $settings.strobe)
                .keyboardShortcut("s", modifiers: [])
            Toggle("Filter Audio", isOn: $settings.filter)
                .keyboardShortcut("f", modifiers: [])
            Toggle("Downsample", isOn: $settings.downsample)
                .keyboardShortcut("d", modifiers: [])
            Toggle("Fundamental Filter", isOn: $settings.fundamental)
            Toggle("Note Filter", isOn: $settings.noteFilter)

            Divider()

            Toggle("Inspector", isOn: $settings.inspector)
                .keyboardShortcut("i", modifiers: [.command, .option])
        }

        CommandMenu("Tuner")
        {
            Button("Copy Readout") { model.copyReadout() }
                .keyboardShortcut("c", modifiers: [])
            Toggle("Lock Display", isOn: $display.isLocked)
                .keyboardShortcut("l", modifiers: [])
            Button("Change Strobe Colours") { settings.cycleColour() }
                .keyboardShortcut("k", modifiers: [])

            Divider()

            Toggle("Zoom Spectrum", isOn: $settings.zoom)
                .keyboardShortcut("z", modifiers: [])
            Button("Expand Spectrum") { settings.expandSpectrum() }
                .keyboardShortcut("+", modifiers: [])
            Button("Contract Spectrum") { settings.contractSpectrum() }
                .keyboardShortcut("-", modifiers: [])
        }
    }

    // copy: the readout, or the selection of a text field being edited
    private func copy()
    {
        if NSApp.keyWindow?.firstResponder is NSText
        {
            send(#selector(NSText.copy(_:)))
        }

        else
        {
            model.copyReadout()
        }
    }

    // send: an editing action to whatever has focus
    private func send(_ action: Selector)
    {
        NSApp.sendAction(action, to: nil, from: nil)
    }
}
