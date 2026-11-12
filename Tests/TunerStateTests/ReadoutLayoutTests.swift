//
//  ReadoutLayoutTests.swift
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
//  The tests measure with a fake font shaped like SF Pro: a line about
//  1.19 times the size, and a string as wide as its characters times the
//  size, bold a little wider. Below 20 points the real font tracks wider,
//  so the fake can widen the characters there by a factor of its own.

import Foundation
import Testing
import TunerState

struct ReadoutLayoutTests
{
    // The fake font. tracking widens every character below 20 points.
    private func fake(tracking: Double = 1.08) -> ReadoutLayout.Measure
    {
        return ReadoutLayout.Measure(
            lineHeight: { size, _ in size * 1.19 },
            width:
            {
                text, size, weight in
                let bold = (weight == .bold) ? 1.04 : 1.0
                let narrow = (size < 20) ? tracking : 1.0
                return Double(text.count) * 0.58 * size * bold * narrow
            })
    }

    private let gap = ReadoutLayout.minimumGap

    // The height the three rows take with the gaps between them
    private func height(_ layout: ReadoutLayout,
                        _ measure: ReadoutLayout.Measure) -> Double
    {
        return measure.lineHeight(layout.note, .bold)
          + measure.lineHeight(layout.deviation, .bold)
          + measure.lineHeight(layout.detail, .regular)
          + 2 * ReadoutLayout.rowSpacing
    }

    // The widest each row gets, laid out as the view lays it out: the
    // note and the frequency on the first row, the cents and the Hz
    // difference on the second, the target, the lock badge and the A4
    // reference on the third. The note is its widest letter, an octave
    // digit and an accidental, the last two at half size.
    private func widths(_ layout: ReadoutLayout,
                        _ measure: ReadoutLayout.Measure) -> [Double]
    {
        let half = layout.note / 2
        let letter = ReadoutLayout.noteLetters
          .map { measure.width($0, layout.note, .bold) }.max()!
        let mark = ReadoutLayout.accidentals
          .map { measure.width($0, half, .bold) }.max()!

        let first = letter + mark
          + measure.width(ReadoutLayout.octaveDigit, half, .bold)
          + measure.width(ReadoutLayout.frequencyText, layout.frequency,
                          .bold)
          + gap
        let second = measure.width(ReadoutLayout.centsText, layout.deviation,
                                   .bold)
          + measure.width(ReadoutLayout.differenceText, layout.deviation,
                          .bold)
          + gap
        let third = measure.width(ReadoutLayout.targetText, layout.detail,
                                  .regular)
          + measure.width(ReadoutLayout.lockText, layout.detail, .bold)
          + measure.width(ReadoutLayout.referenceText, layout.detail,
                          .regular)
          + 2 * gap

        return [first, second, third]
    }

    // The default window's pane: its 192 point minimum height, and a
    // width that is not the limit
    @Test func theMinimumPaneUsesItsHeight()
    {
        let measure = fake()
        let layout = ReadoutLayout(width: 540, height: 192, measure: measure)
        let used = height(layout, measure)

        #expect(used <= 192)
        #expect(used > 190)
    }

    @Test func theMinimumPaneGivesAboutTheSizesTheSketchScaledUp()
    {
        let layout = ReadoutLayout(width: 540, height: 192, measure: fake())

        // 87, 68, 49 and 19 points at a line of 1.19 times the size
        #expect(abs(layout.note - 87) < 2)
        #expect(abs(layout.frequency - 68) < 2)
        #expect(abs(layout.deviation - 49) < 2)
        #expect(abs(layout.detail - 19) < 1)
    }

    @Test func everyPaneFitsItsRowsAndKeepsTheProportions()
    {
        let measure = fake()

        for width in stride(from: 540.0, through: 2400, by: 140)
        {
            for height in stride(from: 192.0, through: 1400, by: 151)
            {
                let layout = ReadoutLayout(width: width, height: height,
                                           measure: measure)

                #expect(self.height(layout, measure) <= height + 1e-6)
                for row in widths(layout, measure)
                {
                    #expect(row <= width + 1e-6)
                }

                // 64 : 50 : 36 : 14
                #expect(abs(layout.frequency / layout.note - 50.0 / 64)
                        < 1e-9)
                #expect(abs(layout.deviation / layout.note - 36.0 / 64)
                        < 1e-9)
                #expect(abs(layout.detail / layout.note - 14.0 / 64) < 1e-9)

                // The second row is below the frequency and more than
                // twice the third
                #expect(layout.deviation < layout.frequency)
                #expect(layout.deviation > 2 * layout.detail)
            }
        }
    }

    @Test func aNarrowTallPaneIsLimitedByItsWidth()
    {
        let measure = fake()
        let layout = ReadoutLayout(width: 540, height: 600, measure: measure)

        // The widest row takes the whole width, and the height is not used
        let widest = widths(layout, measure).max()!
        #expect(widest <= 540)
        #expect(widest > 539)
        #expect(height(layout, measure) < 560)
    }

    // The real font tracks wider below 20 points, where the third row
    // sits. Sizing it from one measurement scaled up or down would let it
    // spill; measuring at each candidate size does not.
    @Test func theThirdRowStillFitsWhenSmallTypeTracksWider()
    {
        let measure = fake(tracking: 2.0)
        let layout = ReadoutLayout(width: 540, height: 192, measure: measure)

        #expect(layout.detail < 20)
        for row in widths(layout, measure)
        {
            #expect(row <= 540)
        }

        // The third row set the size, so the rows leave height unused
        #expect(height(layout, measure) < 160)
    }

    @Test func sizesDoNotDependOnAnyReading()
    {
        // The same pane and font give the same sizes every time
        let first = ReadoutLayout(width: 700, height: 300, measure: fake())
        let second = ReadoutLayout(width: 700, height: 300, measure: fake())

        #expect(first == second)
    }
}
