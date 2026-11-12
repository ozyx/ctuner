//
//  ReadoutLayout.swift
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
//  The single-note readout's four type sizes, from the pane's size. The
//  note, the frequency, the second row (cents and Hz difference) and the
//  third row (target, lock badge and A4 reference) keep the proportions
//  of the layout sketch the owner chose, 64 : 50 : 36 : 14, and share one
//  scale factor: the largest at which the three rows fit the pane's
//  height and each row's widest strings fit its width.
//
//  The sizes come from a measuring function the caller supplies, because
//  the font's width is not proportional to its size: San Francisco tracks
//  wider below 20 points, where the third row sits. The layout therefore
//  measures at each candidate size rather than scaling one measurement.
//  Only the pane and the font set the sizes. No reading enters them, so
//  the type does not change size from note to note.

import Foundation

public struct ReadoutLayout: Equatable, Sendable
{
    public enum Weight: Sendable
    {
        case regular
        case bold
    }

    // The font as the layout needs it. The caller measures with monospaced
    // digits, since the readout draws them that way.
    public struct Measure: Sendable
    {
        // The height of a line of text at a point size
        public var lineHeight: @Sendable (_ size: Double,
                                          _ weight: Weight) -> Double

        // The width of a string at a point size
        public var width: @Sendable (_ text: String, _ size: Double,
                                     _ weight: Weight) -> Double

        // init
        public init(lineHeight: @escaping @Sendable (_ size: Double,
                                                     _ weight: Weight)
                                  -> Double,
                    width: @escaping @Sendable (_ text: String,
                                                _ size: Double,
                                                _ weight: Weight) -> Double)
        {
            self.lineHeight = lineHeight
            self.width = width
        }
    }

    // The sizes at a scale of one, from the sketch the owner chose. The
    // octave and the accidental are half the note's size.
    public static let noteProportion = 64.0
    public static let frequencyProportion = 50.0
    public static let deviationProportion = 36.0
    public static let detailProportion = 14.0

    // The gap between rows, and the least gap between the strings on one
    public static let rowSpacing = 4.0
    public static let minimumGap = 8.0

    // The widest strings each row is fitted to. Digits are monospaced, so
    // 8 stands for any digit. The highest note, B8, is about 7902 Hz, the
    // engine drops a reading beyond 60 cents, and 60 cents of B8 is about
    // 279 Hz. The reference field takes 300 to 500 Hz.
    public static let noteLetters = ["A", "B", "C", "D", "E", "F", "G"]
    public static let octaveDigit = "8"
    public static let accidentals = ["\u{266F}", "\u{266D}"]
    public static let frequencyText = "8888.88 Hz"
    public static let centsText = "-60.0\u{00A2}"
    public static let differenceText = "-888.88 Hz"
    public static let targetText = "target 8888.88 Hz"
    public static let lockText = "L"
    public static let referenceText = "A4 = 888.88 Hz"

    // The sizes in points
    public let note: Double
    public let frequency: Double
    public let deviation: Double
    public let detail: Double

    // init: the sizes for a pane of this width and height in points
    public init(width: Double, height: Double, measure: Measure)
    {
        let scale = ReadoutLayout.scale(width: width, height: height,
                                        measure: measure)

        note = ReadoutLayout.noteProportion * scale
        frequency = ReadoutLayout.frequencyProportion * scale
        deviation = ReadoutLayout.deviationProportion * scale
        detail = ReadoutLayout.detailProportion * scale
    }

    // scale: the largest factor at which the rows fit. Whether they fit
    // grows with the factor, so double it until they do not, then halve
    // the gap between a factor that fits and one that does not. The result
    // is always one that fits.
    private static func scale(width: Double, height: Double,
                              measure: Measure) -> Double
    {
        var fits = 0.0
        var exceeds = 1.0

        for _ in 0 ..< 40 where rows(at: exceeds, width: width,
                                     height: height, measure: measure)
        {
            fits = exceeds
            exceeds *= 2
        }

        for _ in 0 ..< 50
        {
            let middle = (fits + exceeds) / 2
            if rows(at: middle, width: width, height: height,
                    measure: measure)
            {
                fits = middle
            }

            else
            {
                exceeds = middle
            }
        }

        return fits
    }

    // rows: whether the three rows fit the pane at a scale factor
    private static func rows(at scale: Double, width: Double,
                             height: Double, measure: Measure) -> Bool
    {
        let note = noteProportion * scale
        let frequency = frequencyProportion * scale
        let deviation = deviationProportion * scale
        let detail = detailProportion * scale
        let half = note / 2

        let tall = measure.lineHeight(note, .bold)
          + measure.lineHeight(deviation, .bold)
          + measure.lineHeight(detail, .regular)
          + 2 * rowSpacing
        if tall > height
        {
            return false
        }

        // The note is its widest letter, an octave digit and an
        // accidental; the last two sit at half size
        let letter = noteLetters.map { measure.width($0, note, .bold) }.max()!
        let mark = accidentals.map { measure.width($0, half, .bold) }.max()!

        let first = letter + mark
          + measure.width(octaveDigit, half, .bold)
          + measure.width(frequencyText, frequency, .bold)
          + minimumGap
        let second = measure.width(centsText, deviation, .bold)
          + measure.width(differenceText, deviation, .bold)
          + minimumGap

        // The lock badge's room is kept whether or not it shows
        let third = measure.width(targetText, detail, .regular)
          + measure.width(lockText, detail, .bold)
          + measure.width(referenceText, detail, .regular)
          + 2 * minimumGap

        return max(first, second, third) <= width
    }
}
