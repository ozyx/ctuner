//
//  NoteFilterView.swift
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
//  The note filter (R11): 12 note toggles and 9 octave toggles bound
//  to the settings model, with the enable control mirroring the
//  toolbar toggle.

import SwiftUI
import TunerState

struct NoteFilterView: View
{
    @Environment(AppModel.self) private var model

    private static let labels = ["C", "C#", "D", "Eb", "E", "F",
                                 "F#", "G", "Ab", "A", "Bb", "B"]

    var body: some View
    {
        @Bindable var settings = model.settings

        VStack(alignment: .leading, spacing: 6)
        {
            Toggle("Note Filter", isOn: $settings.noteFilter)
                .font(.headline)

            HStack(alignment: .top, spacing: 16)
            {
                column(Array(0 ..< 6), $settings.notes)
                {
                    NoteFilterView.labels[$0]
                }
                column(Array(6 ..< 12), $settings.notes)
                {
                    NoteFilterView.labels[$0]
                }
            }

            Divider()

            HStack(alignment: .top, spacing: 16)
            {
                column(Array(0 ..< 5), $settings.octaves)
                {
                    "Octave \($0)"
                }
                column(Array(5 ..< 9), $settings.octaves)
                {
                    "Octave \($0)"
                }
            }
        }
        .toggleStyle(.checkbox)
        .padding(8)
    }

    // column: one toggle per index
    private func column(_ indices: [Int], _ flags: Binding<[Bool]>,
                        _ label: @escaping (Int) -> String) -> some View
    {
        VStack(alignment: .leading, spacing: 4)
        {
            ForEach(indices, id: \.self)
            {
                index in
                Toggle(label(index), isOn: flags[index])
            }
        }
    }
}
