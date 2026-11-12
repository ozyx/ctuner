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
//  The readout, as docs/plans/2026-11-11-1526-feat-readout-cents-meter-scale-plan.md
//  amends it. Single mode has three rows sized together by ReadoutLayout
//  from the pane: the note and the measured Hz, then the signed cents
//  under the note and the signed Hz difference under the Hz, then the
//  target, the lock badge and the A4 reference in small secondary text.
//  Multiple-reed mode has one row per maximum. Blank before the first
//  reading, greyed when stale, an "L" badge when locked: in the third row
//  in single mode, in the corner in multiple-reed mode and before a first
//  reading, when there is no third row. Semantic colours only (KTD9).

import AppKit
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
                                      locked: model.display.isLocked,
                                      size: geometry.size)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: .topLeading)
            .opacity(model.display.isStale ? 0.4 : 1)
            .overlay(alignment: .bottomLeading)
            {
                // The single-note rows carry the badge themselves
                if model.display.isLocked
                    && (model.settings.multiple
                        || model.display.reading == nil)
                {
                    LockBadge(size: 12)
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

// The lock badge
private struct LockBadge: View
{
    let size: CGFloat

    var body: some View
    {
        Text(ReadoutLayout.lockText)
            .font(.system(size: size, weight: .bold))
    }
}

// The system font with monospaced digits, which the rows draw, measured
// for ReadoutLayout
private enum ReadoutFont
{
    nonisolated static let measure = ReadoutLayout.Measure(
        lineHeight:
        {
            size, weight in
            let font = ReadoutFont.font(size, weight)
            return Double(font.ascender - font.descender + font.leading)
        },
        width:
        {
            text, size, weight in
            let font = ReadoutFont.font(size, weight)
            let measured = NSAttributedString(string: text,
                                              attributes: [.font: font])
            return Double(measured.size().width)
        })

    nonisolated private static func font(_ size: Double,
                                         _ weight: ReadoutLayout.Weight)
      -> NSFont
    {
        return NSFont.monospacedDigitSystemFont(
          ofSize: size, weight: (weight == .bold) ? .bold : .regular)
    }
}

// The layout for a pane, worked out once per pane size rather than on
// every reading
private enum ReadoutSizing
{
    private static var last: (width: Double, height: Double,
                              layout: ReadoutLayout)?

    static func layout(width: Double, height: Double) -> ReadoutLayout
    {
        if let last, last.width == width, last.height == height
        {
            return last.layout
        }

        let layout = ReadoutLayout(width: width, height: height,
                                   measure: ReadoutFont.measure)
        last = (width, height, layout)
        return layout
    }
}

// The single-note layout
private struct SingleReadout: View
{
    // The padding either side of the rows
    private static let inset = 2.0

    let reading: Reading
    let transpose: Int
    let reference: Double
    let locked: Bool
    let size: CGSize

    var body: some View
    {
        let shown = reading.displayNote(transpose: transpose)
        let layout = ReadoutSizing.layout(
          width: size.width - 2 * SingleReadout.inset, height: size.height)
        let gap = ReadoutLayout.minimumGap

        VStack(alignment: .leading, spacing: ReadoutLayout.rowSpacing)
        {
            HStack(alignment: .firstTextBaseline)
            {
                HStack(alignment: .firstTextBaseline, spacing: 0)
                {
                    Text(shown.name)
                        .font(.system(size: layout.note, weight: .bold))

                    // The octave sits on the note's baseline, the
                    // accidental raised above it, as the old view drew
                    Text(String(shown.octave))
                        .font(.system(size: layout.note / 2, weight: .bold))
                        .overlay(alignment: .topLeading)
                        {
                            Text(shown.symbol)
                                .font(.system(size: layout.note / 2,
                                              weight: .bold))
                                .fixedSize()
                                .offset(y: -layout.note / 2)
                        }
                }

                Spacer(minLength: gap)

                Text(String(format: "%.2f Hz", reading.frequency))
                    .font(.system(size: layout.frequency, weight: .bold)
                            .monospacedDigit())
            }
            .lineLimit(1)

            // The deviation: the cents under the note, the difference
            // under the Hz
            HStack
            {
                Text(reading.centsText)
                Spacer(minLength: gap)
                Text(reading.differenceText)
            }
            .font(.system(size: layout.deviation, weight: .bold)
                    .monospacedDigit())
            .lineLimit(1)

            // The target and the A4 reference, with the lock badge
            // between them while locked
            HStack
            {
                Text(String(format: "target %.2f Hz", reading.reference))
                Spacer(minLength: gap)

                if locked
                {
                    LockBadge(size: layout.detail)
                    Spacer(minLength: gap)
                }

                Text(String(format: "A4 = %.2f Hz", reference))
            }
            .font(.system(size: layout.detail).monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.horizontal, SingleReadout.inset)
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
