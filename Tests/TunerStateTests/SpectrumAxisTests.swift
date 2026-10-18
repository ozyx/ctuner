//
//  SpectrumAxisTests.swift
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

import Foundation
import Testing
import TunerState

struct SpectrumAxisTests
{
    let count = 7168

    // A spectrum with one peak at a bin
    private func spectrum(peak: Int) -> [Double]
    {
        var values = [Double](repeating: 0, count: count)
        values[peak] = 10
        return values
    }

    // The column the decimated trace puts a bin's value in
    private func column(of peak: Int, _ axis: SpectrumAxis) -> Int?
    {
        let values = spectrum(peak: peak)
        return values.withUnsafeBufferPointer
        {
            axis.decimate($0).first { $0.maximum == 10 }?.x
        }
    }

    @Test(arguments: [1, 2, 4, 8, 16])
    func unzoomedMarkerLandsOnThePeaksColumn(expand: Int)
    {
        let axis = SpectrumAxis(width: 400, count: count, expand: expand)!

        for bin in [3, 17, 100, 250, count / expand - 1]
        {
            let marker = axis.x(bin: Double(bin))
            #expect(Int(marker) == column(of: bin, axis))
        }
    }

    @Test func zoomedMarkerLandsOnThePeaksColumn()
    {
        // 440 Hz at 48000 / 16384 Hz a bin, -60 to +60 cents
        let reference = 440 / (48000.0 / 16384)
        let lower = reference * pow(2, -60 / 1200)
        let upper = reference * pow(2, 60 / 1200)
        let axis = SpectrumAxis(zoomedFrom: lower, reference: reference,
                                upper: upper, width: 400, count: count)!

        for bin in Int(ceil(lower)) ... Int(floor(upper))
        {
            #expect(Int(axis.x(bin: Double(bin))) == column(of: bin, axis))
        }

        // The reference is the middle
        #expect(abs(axis.x(bin: reference) - 200) < 1e-9)
    }

    @Test func zoomedWindowSpansTheSixtyCentLimits()
    {
        let reference = 150.0
        let lower = reference * pow(2, -60 / 1200)
        let upper = reference * pow(2, 60 / 1200)
        let axis = SpectrumAxis(zoomedFrom: lower, reference: reference,
                                upper: upper, width: 400, count: count)!

        #expect(axis.contains(bin: lower))
        #expect(axis.contains(bin: upper))
        #expect(abs(axis.x(bin: reference) - 200) < 1e-9)
        #expect(axis.bins == Int(floor(lower)) ... Int(ceil(upper)))
    }

    @Test func expandSixteenShowsBinsOneToFourHundredFortyEight()
    {
        let axis = SpectrumAxis(width: 400, count: count, expand: 16)!
        #expect(axis.bins == 1 ... 448)
        #expect(abs(axis.x(bin: 448) - 400) < 1e-9)

        let plain = SpectrumAxis(width: 400, count: count, expand: 1)!
        #expect(plain.bins == 1 ... 7168)
    }

    @Test func decimationKeepsEachColumnsMinimumAndMaximum()
    {
        let axis = SpectrumAxis(width: 400, count: count, expand: 1)!

        // A trace that alternates, so every column with several bins
        // has both a low and a high value
        var values = [Double](repeating: 0, count: count)
        for i in 0 ..< count
        {
            values[i] = (i % 2 == 0) ? 1 : 5
        }

        let columns = values.withUnsafeBufferPointer { axis.decimate($0) }
        #expect(columns.count <= 401)
        #expect(columns.count > 200)

        // The upper columns each hold many bins
        for column in columns where column.x > 250
        {
            #expect(column.minimum == 1)
            #expect(column.maximum == 5)
        }

        // x increases and never repeats
        for (a, b) in zip(columns, columns.dropFirst())
        {
            #expect(a.x < b.x)
        }
    }

    @Test func nothingToDrawBeforeAReading()
    {
        #expect(SpectrumAxis(zoomedFrom: 0, reference: 0, upper: 0, width: 400,
                             count: count) == nil)
        #expect(SpectrumAxis(width: 0, count: count, expand: 1) == nil)
    }
}
