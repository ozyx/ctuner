//
//  Toolbar.swift
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
//  The toolbar (R17): each toggle is a symbol with a text label and a
//  tinted on-state. The analysis toggles do not move into overflow.

import SwiftUI
import TunerState

// One toggle button
struct ToolbarToggle: View
{
    let title: String
    let symbol: String
    let help: String
    @Binding var isOn: Bool

    var body: some View
    {
        Toggle(isOn: $isOn)
        {
            Label(title, systemImage: symbol)
        }
        .toggleStyle(.button)
        .symbolVariant(isOn ? .fill : .none)
        .tint(.accentColor)
        .help(help)
    }
}

struct TunerToolbar: CustomizableToolbarContent
{
    @Bindable var settings: TunerState.Settings
    @Bindable var display: DisplayModel

    var body: some CustomizableToolbarContent
    {
        ToolbarItem(id: "filter")
        {
            ToolbarToggle(title: "Filter",
                          symbol: "waveform",
                          help: "Filter audio",
                          isOn: $settings.filter)
        }
        .customizationBehavior(.disabled)

        ToolbarItem(id: "downsample")
        {
            ToolbarToggle(title: "Downsample",
                          symbol: "arrow.down.to.line",
                          help: "Downsample, for bass reeds",
                          isOn: $settings.downsample)
        }
        .customizationBehavior(.disabled)

        ToolbarItem(id: "fundamental")
        {
            ToolbarToggle(title: "Fundamental",
                          symbol: "f.cursive",
                          help: "Fundamental filter",
                          isOn: $settings.fundamental)
        }
        .customizationBehavior(.disabled)

        ToolbarItem(id: "noteFilter")
        {
            ToolbarToggle(title: "Note Filter",
                          symbol: "line.3.horizontal.decrease",
                          help: "Show selected notes and octaves only",
                          isOn: $settings.noteFilter)
        }
        .customizationBehavior(.disabled)

        ToolbarItem(id: "lock")
        {
            ToolbarToggle(title: "Lock",
                          symbol: "lock",
                          help: "Lock display",
                          isOn: $display.isLocked)
        }

        ToolbarItem(id: "multiple")
        {
            ToolbarToggle(title: "Multiple",
                          symbol: "list.number",
                          help: "Multiple reeds",
                          isOn: $settings.multiple)
        }

        ToolbarItem(id: "strobe")
        {
            ToolbarToggle(title: "Strobe",
                          symbol: "circle.dotted",
                          help: "Strobe, or staff when off",
                          isOn: $settings.strobe)
        }

        ToolbarItem(id: "inspector", placement: .primaryAction)
        {
            ToolbarToggle(title: "Inspector",
                          symbol: "sidebar.trailing",
                          help: "Show the scope, spectrum and note filter",
                          isOn: $settings.inspector)
        }
    }
}
