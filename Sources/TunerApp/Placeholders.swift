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
//  Placeholder panes that carry their clicks (R17), so every mirror of
//  a toggle can be checked before the real panes arrive: U11 replaces
//  the readout, meter and staff, U16 the strobe and U17 the scope and
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

struct MainArea: View
{
    @Environment(AppModel.self) private var model

    var body: some View
    {
        VStack(spacing: 8)
        {
            // Today's tooltips: the readout and the meter lock the
            // display, the strobe and the staff replace each other
            PlaceholderPane(help: "Display - click to lock",
                            action: model.toggleLock)
            {
                ReadoutPlaceholder()
            }
            .frame(minHeight: 8 * 24)

            PlaceholderPane(help: model.settings.strobe
                              ? "Strobe - click for staff"
                              : "Staff - click for strobe",
                            action: model.toggleStrobe)
            {
                Text(model.settings.strobe ? "Strobe" : "Staff")
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 80)

            PlaceholderPane(help: "Meter - click to lock",
                            action: model.toggleLock)
            {
                Text("Meter")
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 36, maxHeight: 48)
        }
        .padding(8)
    }
}

struct ReadoutPlaceholder: View
{
    @Environment(AppModel.self) private var model

    var body: some View
    {
        VStack(spacing: 4)
        {
            if model.display.isLocked
            {
                Label("Locked", systemImage: "lock.fill")
                    .foregroundStyle(.secondary)
            }

            Text(model.display.copyLine(transpose: model.settings.transpose)
                   ?? "Readout")
                .foregroundStyle(.secondary)
        }
    }
}
