//
//  RateTests.swift
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
//  What the core derives from its sample rate: the bin width, and the
//  input filter's unit gain at DC and half power at its 480 Hz corner.
//  At 44100 the filter goldens already pin today's literal
//  coefficients; these check the other rates follow the same formulas.

import Foundation
import Testing
import TunerCore

@Suite("core rate")
struct RateTests
{
    // Corner frequency of the input filter
    static let corner = 480.0

    @Test(arguments: [44100.0, 48000.0, 96000.0])
    func binWidth(rate: Double) throws
    {
        let run = try filteredScope(rate: rate, frequency: 0)
        #expect(run.binWidth == rate / Double(kTunerSamples))
        #expect(run.sampleRate == rate)
    }

    @Test(arguments: [44100.0, 48000.0, 96000.0])
    func filterUnitGainAtDC(rate: Double) throws
    {
        let scope = try filteredScope(rate: rate, frequency: 0).scope
        let worst = scope.map { abs($0 - 0.5) }.max() ?? .infinity

        #expect(worst < 1e-9)
    }

    @Test(arguments: [44100.0, 48000.0, 96000.0])
    func filterHalfPowerAtCorner(rate: Double) throws
    {
        let scope = try filteredScope(rate: rate, frequency: RateTests.corner).scope

        // The RMS over a whole number of periods, as an amplitude
        let periods = Int(Double(scope.count) * RateTests.corner / rate)
        let length = Int((Double(periods) * rate / RateTests.corner).rounded())
        let tail = scope.suffix(length)
        let power = tail.reduce(0.0) { $0 + $1 * $1 } / Double(length)
        let amplitude = (2.0 * power).squareRoot()

        // A 0.5 sine comes out at 0.5 / sqrt(2)
        #expect(abs(amplitude - 0.5 / 2.0.squareRoot()) < 1e-3)
    }

    // filteredScope: the rate fields and the scope, copied out of the
    // slot, after 32 blocks of a 0.5 amplitude sine (or DC when the
    // frequency is 0) with the filter on
    func filteredScope(rate: Double, frequency: Double) throws
        -> (sampleRate: Double, binWidth: Double, scope: [Double])
    {
        let engine = try createEngine(rate: rate)
        defer { TunerEngineDestroy(engine) }

        let slot = try #require(TunerSlotCreate())
        defer { TunerSlotDestroy(slot) }

        TunerEngineSetFilter(engine, true)

        let block = Int(kTunerBlock)
        let samples = (0 ..< 32 * block).map
        {
            frequency == 0 ? Float(0.5) :
                Float(0.5 * sin(2.0 * Double.pi * frequency * Double($0) / rate))
        }

        for hop in 0 ..< 32
        {
            samples.withUnsafeBufferPointer
            {
                _ = TunerEngineProcessBlock(engine, $0.baseAddress! + hop * block,
                                            slot)
            }
        }

        var snapshot = TunerSnapshot()
        TunerSlotView(slot, &snapshot)
        let scope = Array(UnsafeBufferPointer(start: snapshot.scope,
                                              count: Int(kTunerScopeLength)))
        return (snapshot.sampleRate, snapshot.binWidth, scope)
    }
}
