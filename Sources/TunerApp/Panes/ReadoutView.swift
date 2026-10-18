//
//  ReadoutView.swift
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
//  The readout (R7, R8): single mode with the note dominant, the
//  measured Hz sized for the widest value, target and difference
//  below and the A4 reference last; multiple-reed mode with one row
//  per maximum. Blank before the first reading, greyed when stale,
//  an "L" badge when locked. Semantic colours only (KTD9).

import SwiftUI
import TunerState

struct ReadoutView: View
{
    @Environment(AppModel.self) private var model

    var body: some View
    {
        GeometryReader
        {
            geometry in
            Group
            {
                if let reading = model.display.reading
                {
                    if model.settings.multiple
                    {
                        ReedRows(reading: reading,
                                 stale: model.display.isStale,
                                 transpose: model.settings.transpose,
                                 height: geometry.size.height)
                    }

                    else
                    {
                        SingleReadout(reading: reading,
                                      transpose: model.settings.transpose,
                                      reference: model.settings.reference,
                                      size: geometry.size)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: .topLeading)
            .opacity(model.display.isStale ? 0.4 : 1)
            .overlay(alignment: .bottomLeading)
            {
                if model.display.isLocked
                {
                    Text("L")
                        .font(.system(size: 12, weight: .bold))
                        .padding(2)
                }
            }
        }
        .onChange(of: model.display.readoutTick)
        {
            _, tick in
            Signposts.readout(tick)
        }
    }
}

// The single-note layout
private struct SingleReadout: View
{
    let reading: Reading
    let transpose: Int
    let reference: Double
    let size: CGSize

    var body: some View
    {
        let shown = reading.displayNote(transpose: transpose)
        let large = size.height / 2
        let medium = size.height / 3
        let small = size.height / 5

        // The Hz number takes the room beside the note, sized for the
        // widest value so it does not change size between notes
        let room = max(size.width - large * 1.6 - 16, 40)
        let hzSize = min(medium, room / 6.2)

        // The rows below shrink to fit the width
        let rowSize = min(small, (size.width - 16) / 17)

        VStack(alignment: .leading, spacing: 4)
        {
            HStack(alignment: .firstTextBaseline)
            {
                HStack(alignment: .firstTextBaseline, spacing: 0)
                {
                    Text(shown.name)
                        .font(.system(size: large, weight: .bold))

                    // The octave sits on the note's baseline, the
                    // accidental raised above it, as the old view drew
                    Text(String(shown.octave))
                        .font(.system(size: large / 2, weight: .bold))
                        .overlay(alignment: .topLeading)
                        {
                            Text(shown.symbol)
                                .font(.system(size: large / 2, weight: .bold))
                                .fixedSize()
                                .offset(y: -large / 2)
                        }
                }

                Spacer(minLength: 8)

                Text(String(format: "%.2f Hz", reading.frequency))
                    .font(.system(size: hzSize, weight: .bold)
                            .monospacedDigit())
            }
            .lineLimit(1)

            HStack
            {
                Text(String(format: "target %.2f Hz", reading.reference))
                Spacer(minLength: 8)
                Text(String(format: "%+.2f Hz", reading.difference))
            }
            .font(.system(size: rowSize, weight: .bold).monospacedDigit())
            .lineLimit(1)

            Text(String(format: "A4 = %.2f Hz", reference))
                .font(.system(size: rowSize, weight: .bold).monospacedDigit())
                .lineLimit(1)
        }
        .padding(.horizontal, 2)
    }
}

// The multiple-reed layout: the primary line when no maximum is
// found, then one row per reed; the rows clear when stale
private struct ReedRows: View
{
    let reading: Reading
    let stale: Bool
    let transpose: Int
    let height: CGFloat

    var body: some View
    {
        let rowHeight = height / 9
        let reeds = stale ? [] : reading.reeds

        VStack(alignment: .leading, spacing: 0)
        {
            if reeds.isEmpty
            {
                row(reading.displayNote(transpose: transpose).text,
                    reading.cents, reading.reference, reading.frequency)
            }

            ForEach(reeds.indices, id: \.self)
            {
                let reed = reeds[$0]
                row(DisplayNote(note: reed.note, transpose: transpose).text,
                    reed.cents, reed.reference, reed.frequency)
            }
        }
        .font(.system(size: rowHeight * 0.8).monospacedDigit())
        .padding(.horizontal, 2)
    }

    // row: note, cents, target, measured and difference
    private func row(_ note: String, _ cents: Double, _ reference: Double,
                     _ frequency: Double) -> some View
    {
        let line = note + "  " +
                   String(format: "%+4.2f\u{00A2}  %4.2fHz  %4.2fHz  %+4.2fHz",
                          cents, reference, frequency, frequency - reference)
        return Text(line)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}
