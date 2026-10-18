//
//  Tone.swift
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
//  A tone source: resolves a pitch to Hz once, using the engine's own
//  reference formula for a note name, then synthesises samples from
//  the absolute sample index so a long tone does not drift.

import Foundation
import TunerState

public struct Tone: Sendable
{
    // A note's Hz in the engine's reference formula: the reference times
    // 2^((note - 57) / 12), times the ratio of the temperament row to
    // equal temperament between the note and A, rooted at the key. Cents
    // are then added on top. Re-implemented from Temperaments.values, so
    // a check that uses it cannot vouch for the tables themselves.
    public static func frequency(note: Int, cents: Double = 0,
                                 reference: Double, temperament: Int,
                                 key: Int) throws(SourceError) -> Double
    {
        guard Temperaments.values.indices.contains(temperament) else
        {
            throw SourceError("temperament \(temperament) is not a row of "
                              + "the table")
        }

        let octave = Notes.octave
        let n = (note - key + octave) % octave
        let a = (9 - key + octave) % octave

        let row = Temperaments.values[temperament]
        let equal = Temperaments.values[Temperaments.equal]
        let adjust = (row[n] / row[a]) / (equal[n] / equal[a])

        return reference * pow(2.0, Double(note - Notes.a4) / 12.0) * adjust
            * pow(2.0, cents / 1200.0)
    }

    public let frequency: Double
    public let rate: Double
    public let amplitude: Double

    // nil is endless
    public let count: Int?

    // init(_:reference:temperament:key:): resolve a parsed tone; the
    // settings matter only to a note name
    public init(_ spec: ToneSpec, reference: Double = Notes.reference,
                temperament: Int = Temperaments.equal, key: Int = 0)
      throws(SourceError)
    {
        switch spec.pitch
        {
        case .hertz(let hertz):
            frequency = hertz

        case .note(let number, let cents):
            frequency = try Tone.frequency(note: number, cents: cents,
                                           reference: reference,
                                           temperament: temperament,
                                           key: key)
        }

        guard frequency < spec.rate / 2 else
        {
            throw SourceError("\(frequency) Hz is at or above half the "
                              + "rate, \(spec.rate / 2) Hz")
        }

        rate = spec.rate
        amplitude = spec.amplitude
        count = spec.seconds.map { Int(($0 * spec.rate).rounded()) }
    }

    // fill: samples from the absolute index start, in double precision
    // and rounded to float; the fraction of a cycle keeps the phase exact
    // however far in the tone is
    public func fill(_ block: UnsafeMutableBufferPointer<Float>,
                     from start: Int)
    {
        for i in 0 ..< block.count
        {
            let cycles = frequency * Double(start + i) / rate
            let phase = cycles - cycles.rounded(.down)
            block[i] = Float(amplitude * sin(2 * Double.pi * phase))
        }
    }
}
