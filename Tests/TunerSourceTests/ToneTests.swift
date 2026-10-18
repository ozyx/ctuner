//
//  ToneTests.swift
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
//  Tone sources: the Hz a description resolves to under each setting,
//  and samples that stay true however far into the tone they are.

import Foundation
import Testing
@testable import TunerSource
import TunerState

// resolve: a tone from a description and the settings that matter
private func resolve(_ description: String, reference: Double = 440,
                     temperament: Int = Temperaments.equal,
                     key: Int = 0) throws -> Tone
{
    guard case .tone(let spec) = try SourceSpec.parse(description) else
    {
        throw SourceError("not a tone")
    }
    return try Tone(spec, reference: reference, temperament: temperament,
                    key: key)
}

@Suite("tone")
struct ToneTests
{
    @Test func hertz() throws
    {
        let tone = try resolve("tone:440")
        #expect(tone.frequency == 440)
        #expect(tone.rate == 44100)
        #expect(tone.amplitude == 0.5)
    }

    @Test func a4FollowsTheReference() throws
    {
        #expect(try resolve("tone:A4").frequency == 440)
        #expect(abs(try resolve("tone:A4", reference: 415).frequency - 415)
                < 1e-9)
    }

    @Test func centsOverEqualTemperament() throws
    {
        // E flat 4 is six semitones below A4
        let flat = 440 * pow(2.0, -6.0 / 12)
        let expected = flat * pow(2.0, 7.0 / 1200)

        let a = try resolve("tone:Eb4+7").frequency
        let b = try resolve("tone:D#4+7").frequency
        #expect(a == b)
        #expect(abs(a - expected) < 1e-9)
    }

    @Test func kirnbergerIII() throws
    {
        let row = Temperaments.values[1]
        let equal = Temperaments.values[Temperaments.equal]
        let adjust = (row[4] / row[9]) / (equal[4] / equal[9])
        let expected = 440 * pow(2.0, -5.0 / 12) * adjust

        let tone = try resolve("tone:E4", temperament: 1, key: 0)
        #expect(abs(tone.frequency - expected) < 1e-9)

        // Not the equal-tempered E4
        let equalE4 = try resolve("tone:E4").frequency
        #expect(abs(1200 * log2(tone.frequency / equalE4)) > 1)
    }

    @Test(arguments: 0 ..< 32, [0, 3, 9])
    func a4IsTheReferenceInEveryTemperament(temperament: Int, key: Int)
      throws
    {
        let tone = try resolve("tone:A4", temperament: temperament, key: key)
        #expect(abs(tone.frequency - 440) < 1e-9)
    }

    @Test func options() throws
    {
        let tone = try resolve("tone:E4,rate=96000,amp=0.25,secs=2")
        #expect(tone.rate == 96000)
        #expect(tone.amplitude == 0.25)
        #expect(tone.count == 192000)
    }

    @Test func endlessWithoutSeconds() throws
    {
        #expect(try resolve("tone:440").count == nil)
    }

    @Test func noteAboveNyquistIsAnError() throws
    {
        #expect(throws: SourceError.self)
        {
            try resolve("tone:B8,rate=8000")
        }
    }

    // A length no run could play is an error, not a trap
    @Test(arguments: ["tone:A4,secs=1e30", "tone:A4,rate=1e300,secs=10"])
    func absurdLengthIsAnError(_ description: String) throws
    {
        #expect(throws: SourceError.self)
        {
            try resolve(description)
        }
    }

    @Test func unknownTemperamentIsAnError() throws
    {
        #expect(throws: SourceError.self)
        {
            try resolve("tone:A4", temperament: 32)
        }
    }

    // Long tones do not drift
    @Test func sampleAtALargeIndex() throws
    {
        let tone = try resolve("tone:440")
        let start = 10_000_000

        var block = [Float](repeating: 0, count: 4)
        block.withUnsafeMutableBufferPointer { tone.fill($0, from: start) }

        for (i, sample) in block.enumerated()
        {
            let direct = 0.5 * sin(2 * Double.pi * 440 * Double(start + i)
                                   / 44100)
            #expect(abs(Double(sample) - direct) < 1e-6)
        }
    }

    @Test func blocksJoinSeamlessly() throws
    {
        let tone = try resolve("tone:1234.5")

        var whole = [Float](repeating: 0, count: 2048)
        whole.withUnsafeMutableBufferPointer { tone.fill($0, from: 0) }

        var second = [Float](repeating: 0, count: 1024)
        second.withUnsafeMutableBufferPointer { tone.fill($0, from: 1024) }

        #expect(Array(whole[1024...]) == second)
    }
}
