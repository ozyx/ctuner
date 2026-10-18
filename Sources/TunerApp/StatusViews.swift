//
//  StatusViews.swift
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
//  The status views (U19): what happened and what fixes it, shown in
//  place of the main area when capture cannot supply a reading. The
//  toolbar and inspector stay.

import AppKit
import SwiftUI
import TunerState

// One status view: a symbol, what happened, and an optional fix
struct StatusView: View
{
    let symbol: String
    let title: String
    let detail: String
    var button: (title: String, url: String)?

    var body: some View
    {
        VStack(spacing: 12)
        {
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(detail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let button
            {
                Button(button.title)
                {
                    if let url = URL(string: button.url)
                    {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(maxWidth: 420, maxHeight: .infinity)
        .frame(maxWidth: .infinity)
    }
}

// The view for a status area
struct StatusContent: View
{
    let area: MainArea

    var body: some View
    {
        switch area
        {
        case .denied:
            StatusView(symbol: "mic.slash",
                       title: "Microphone Access Is Off",
                       detail: "Tuner needs the microphone to hear a note. " +
                               "Allow Tuner under Microphone in Privacy & " +
                               "Security, then return to Tuner.",
                       button: ("Open Microphone Settings",
                                "x-apple.systempreferences:" +
                                "com.apple.preference.security" +
                                "?Privacy_Microphone"))

        case .noDevice:
            StatusView(symbol: "mic.badge.xmark",
                       title: "No Input Device",
                       detail: "Connect a microphone or choose an input " +
                               "in Sound settings. Tuner starts listening " +
                               "when an input appears.",
                       button: ("Open Sound Settings",
                                "x-apple.systempreferences:" +
                                "com.apple.Sound-Settings.extension"))

        case .failed(let message):
            StatusView(symbol: "exclamationmark.triangle",
                       title: "Tuner Could Not Listen",
                       detail: message + "\n\nTuner tries again when it " +
                               "becomes active or the input changes.")

        case .tuner:
            EmptyView()
        }
    }
}
