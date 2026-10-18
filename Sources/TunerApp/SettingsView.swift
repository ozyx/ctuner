//
//  SettingsView.swift
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
//  The Settings window (R15): the reference frequency, transpose,
//  temperament and key on General, the strobe colours on Strobe. The
//  toggles live in the toolbar and the View menu, not here.

import SwiftUI
import TunerState

// The labels today's preferences window shows
private let colourNames = ["Blue/Cyan", "Olive/Aquamarine", "Magenta/Yellow"]

private let transposeNames =
  ["+6[Key:F\u{266F}]", "+5[Key:F]", "+4[Key:E]", "+3[Key:E\u{266D}]",
   "+2[Key:D]", "+1[Key:C\u{266F}]", "+0[Key:C]", "-1[Key:B]",
   "-2[Key:B\u{266D}]", "-3[Key:A]", "-4[Key:A\u{266D}]", "-5[Key:G]",
   "-6[Key:F\u{266F}]"]

private let keyNames = zip(Notes.names, Notes.symbols).map { $0 + $1 }

struct SettingsView: View
{
    var body: some View
    {
        TabView
        {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }

            StrobeSettings()
                .tabItem { Label("Strobe", systemImage: "circle.dotted") }
        }
        .frame(width: 440)
        .scenePadding()
    }
}

struct GeneralSettings: View
{
    @Environment(AppModel.self) private var model
    @LocalState private var text = ""
    @FocusState private var focused: Bool

    var body: some View
    {
        @Bindable var settings = model.settings

        Form
        {
            LabeledContent("Reference frequency")
            {
                HStack
                {
                    TextField("Reference frequency", text: $text)
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                        .focused($focused)
                        .onSubmit(commit)
                    Text("Hz")
                    Stepper("Reference frequency",
                            value: $settings.reference,
                            in: Settings.referenceRange,
                            step: 1)
                        .labelsHidden()
                }
            }

            Picker("Transpose display", selection: $settings.transpose)
            {
                ForEach(transposeNames.indices, id: \.self)
                {
                    Text(transposeNames[$0]).tag($0)
                }
            }

            Picker("Temperament", selection: $settings.temperament)
            {
                ForEach(Temperaments.names.indices, id: \.self)
                {
                    Text(Temperaments.names[$0]).tag($0)
                }
            }

            Picker("Temperament key", selection: $settings.key)
            {
                ForEach(keyNames.indices, id: \.self)
                {
                    Text(keyNames[$0]).tag($0)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { show() }
        .onChange(of: settings.reference) { show() }
        .onChange(of: focused)
        {
            if !focused
            {
                commit()
            }
        }
    }

    // show: the current reference in the field
    private func show()
    {
        text = model.settings.reference.formatted(.number.precision(
          .fractionLength(0 ... 2)).grouping(.never))
    }

    // commit: take the field if it holds a reference in range, and show
    // the stored one either way (R33)
    private func commit()
    {
        if let value = Double(text.trimmingCharacters(in: .whitespaces)),
           Settings.referenceRange.contains(value)
        {
            model.settings.reference = value
        }

        show()
    }
}

struct StrobeSettings: View
{
    @Environment(AppModel.self) private var model

    var body: some View
    {
        @Bindable var settings = model.settings

        Form
        {
            Picker("Strobe colours", selection: $settings.colour)
            {
                ForEach(colourNames.indices, id: \.self)
                {
                    Text(colourNames[$0]).tag($0)
                }
            }
        }
        .formStyle(.grouped)
    }
}
