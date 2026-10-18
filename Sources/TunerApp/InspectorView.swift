//
//  InspectorView.swift
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
//  The inspector (R10): the scope, the spectrum and the note filter,
//  each a placeholder until U17 and U11 fill it. The scope and the
//  spectrum carry their clicks.

import SwiftUI

struct InspectorView: View
{
    @Environment(AppModel.self) private var model

    var body: some View
    {
        VStack(spacing: 8)
        {
            PlaceholderPane(help: "Scope - click to filter audio",
                            action: { model.settings.filter.toggle() })
            {
                Text("Scope")
                    .foregroundStyle(.secondary)
            }

            PlaceholderPane(help: "Spectrum - click to zoom",
                            action: { model.settings.zoom.toggle() })
            {
                Text("Spectrum")
                    .foregroundStyle(.secondary)
            }

            PlaceholderPane(help: "Note filter", action: {})
            {
                Text("Note Filter")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
    }
}
