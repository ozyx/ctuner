//
//  Placeholders.swift
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
//  The tuner's pane layout and the placeholder panes that carry their
//  clicks (R17) until the real ones arrive: U17 replaces the scope and
//  spectrum.

import SwiftUI
import TunerState

// A rounded pane holding a caption, clickable like the real pane
struct PlaceholderPane<Content: View>: View
{
    let help: String
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View
    {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary, in: .rect(cornerRadius: 8))
            .contentShape(.rect(cornerRadius: 8))
            .onTapGesture(perform: action)
            .help(help)
    }
}

struct TunerPanes: View
{
    @Environment(AppModel.self) private var model

    var body: some View
    {
        VStack(spacing: 8)
        {
            // Today's tooltips: the readout and the meter lock the
            // display, the strobe and the staff replace each other
            ReadoutView()
                .clickable(help: "Display - click to lock",
                           action: model.toggleLock)
                .frame(minHeight: 8 * 24)

            if model.settings.strobe
            {
                StrobeLayerView()
                    .clickable(help: "Strobe - click for staff",
                               action: model.toggleStrobe)
                    .frame(minHeight: 80)
            }

            else
            {
                StaffView()
                    .clickable(help: "Staff - click for strobe",
                               action: model.toggleStrobe)
                    .frame(minHeight: 80)
            }

            MeterView()
                .clickable(help: "Meter - click to lock",
                           action: model.toggleLock)
                .frame(minHeight: 48, maxHeight: 72)
        }
        .padding(8)
    }
}

extension View
{
    // clickable: a pane that carries its click and tooltip (R17)
    func clickable(help: String, action: @escaping () -> Void) -> some View
    {
        return contentShape(.rect)
            .onTapGesture(perform: action)
            .help(help)
    }
}
