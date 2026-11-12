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
//  64 : 50 : 36 : 14 and share one scale factor: the largest at which the
//  three rows fit the pane's height and each row's widest strings fit
//  its width.
//
//  The sizes come from a measuring function the caller supplies, because
//  the font's width is not proportional to its size: San Francisco tracks
//  wider below 20 points, where the third row sits. The layout therefore
//  measures at each candidate size rather than scaling one measurement.

import Foundation

public struct ReadoutLayout: Equatable, Sendable
{
    public enum Weight: Sendable
    {
        case regular
        case bold
    }

    // The caller measures with monospaced digits, since the readout draws
    // them that way
    public struct Measure: Sendable
    {
        public var lineHeight: @Sendable (_ size: Double,
                                          _ weight: Weight) -> Double

        public var width: @Sendable (_ text: String, _ size: Double,
                                     _ weight: Weight) -> Double

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

    public static let noteProportion = 64.0
    public static let frequencyProportion = 50.0
    public static let deviationProportion = 36.0
    public static let detailProportion = 14.0

    public static let rowSpacing = 4.0
    public static let minimumGap = 8.0

    // The widest strings each row is fitted to. Digits are monospaced, so
    // 8 stands for any digit. The highest note, B8, is about 7902 Hz, the
    // engine drops a reading beyond 60 cents, and 60 cents of B8 is about
    // 279 Hz. The reference field takes 300 to 500 Hz. The figures that can
    // be signed carry a plus, which is wider than a minus in the font.
    public static let noteLetters = Set(Notes.names).sorted()
    public static let octaveDigit = "8"
    public static let accidentals = Set(Notes.symbols).subtracting([""])
      .sorted()
    public static let frequencyText = "8888.88 Hz"
    public static let centsText = "+60.0\u{00A2}"
    public static let differenceText = "+888.88 Hz"
    public static let targetText = "target 8888.88 Hz"
    public static let lockText = "L"
    public static let referenceText = "A4 = 888.88 Hz"

    public let note: Double
    public let frequency: Double
    public let deviation: Double
    public let detail: Double

    // The octave and the accidental
    public var mark: Double { note / 2 }

    public init(width: Double, height: Double, measure: Measure)
    {
        self.init(scale: ReadoutLayout.largestFittingScale(
                    width: width, height: height, measure: measure))
    }

    private init(scale: Double)
    {
        note = ReadoutLayout.noteProportion * scale
        frequency = ReadoutLayout.frequencyProportion * scale
        deviation = ReadoutLayout.deviationProportion * scale
        detail = ReadoutLayout.detailProportion * scale
    }

    private static func largestFittingScale(width: Double, height: Double,
                                            measure: Measure) -> Double
    {
        var fits = 0.0
        var exceeds = 1.0

        var doublings = 0
        while doublings < 40 &&
                ReadoutLayout(scale: exceeds).fits(width: width,
                                                   height: height,
                                                   measure: measure)
        {
            fits = exceeds
            exceeds *= 2
            doublings += 1
        }

        // A factor of one ten-thousandth moves the note by under a
        // hundredth of a point
        while exceeds - fits > 1e-4
        {
            let middle = (fits + exceeds) / 2
            if ReadoutLayout(scale: middle).fits(width: width, height: height,
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

    private func fits(width: Double, height: Double, measure: Measure) -> Bool
    {
        let tall = measure.lineHeight(note, .bold)
          + measure.lineHeight(deviation, .bold)
          + measure.lineHeight(detail, .regular)
          + 2 * ReadoutLayout.rowSpacing
        if tall > height
        {
            return false
        }

        let letter = ReadoutLayout.noteLetters
          .map { measure.width($0, note, .bold) }.max()!
        let accidental = ReadoutLayout.accidentals
          .map { measure.width($0, mark, .bold) }.max()!
        let first = letter + accidental
          + measure.width(ReadoutLayout.octaveDigit, mark, .bold)
          + measure.width(ReadoutLayout.frequencyText, frequency, .bold)
          + ReadoutLayout.minimumGap
        if first > width
        {
            return false
        }

        let second = measure.width(ReadoutLayout.centsText, deviation, .bold)
          + measure.width(ReadoutLayout.differenceText, deviation, .bold)
          + ReadoutLayout.minimumGap
        if second > width
        {
            return false
        }

        let third = measure.width(ReadoutLayout.targetText, detail, .regular)
          + measure.width(ReadoutLayout.lockText, detail, .bold)
          + measure.width(ReadoutLayout.referenceText, detail, .regular)
          + 2 * ReadoutLayout.minimumGap
        return third <= width
    }
}
