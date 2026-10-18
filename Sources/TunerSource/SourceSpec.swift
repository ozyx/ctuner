//
//  SourceSpec.swift
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
//  Source descriptions: the one text form, file:<path> or
//  tone:<pitch>[,rate=<Hz>][,amp=<0..1>][,secs=<s>], that both the
//  tuner-run command and the app's launch argument take. A pitch is Hz
//  or a note name with an optional cents offset; a note name resolves
//  against a reference, temperament and key the caller passes in.

import Foundation
import TunerState

// A description that could not be used, naming it and the reason
public struct SourceError: Error, Equatable, CustomStringConvertible,
                           Sendable
{
    public let message: String

    // init
    public init(_ message: String)
    {
        self.message = message
    }

    // init(description:reason:)
    init(description: String, reason: String)
    {
        message = "\"\(description)\": \(reason)"
    }

    public var description: String { message }
}

// A tone's pitch before it is resolved to Hz
public enum TonePitch: Equatable, Sendable
{
    case hertz(Double)

    // number is the engine's note number, where 57 is A4
    case note(number: Int, cents: Double)
}

// A tone and its options
public struct ToneSpec: Equatable, Sendable
{
    public static let defaultRate = 44100.0
    public static let defaultAmplitude = 0.5

    // A cents offset beyond this would name a different note
    public static let maxCents = 50.0

    public var pitch: TonePitch
    public var rate: Double
    public var amplitude: Double

    // nil is endless
    public var seconds: Double?

    // init
    public init(pitch: TonePitch, rate: Double = defaultRate,
                amplitude: Double = defaultAmplitude, seconds: Double? = nil)
    {
        self.pitch = pitch
        self.rate = rate
        self.amplitude = amplitude
        self.seconds = seconds
    }
}

public enum SourceSpec: Equatable, Sendable
{
    case file(String)
    case tone(ToneSpec)

    // parse
    public static func parse(_ description: String) throws(SourceError)
      -> SourceSpec
    {
        func fail(_ reason: String) -> SourceError
        {
            SourceError(description: description, reason: reason)
        }

        if description.hasPrefix("file:")
        {
            let path = String(description.dropFirst("file:".count))
            if path.isEmpty
            {
                throw fail("no path after file:")
            }
            return .file(path)
        }

        guard description.hasPrefix("tone:") else
        {
            throw fail("a source starts with file: or tone:")
        }

        let parts = description.dropFirst("tone:".count)
          .split(separator: ",", omittingEmptySubsequences: false)
        guard let first = parts.first, !first.isEmpty else
        {
            throw fail("no pitch after tone:")
        }

        let pitch = try parsePitch(String(first), description: description)
        var tone = ToneSpec(pitch: pitch)

        for option in parts.dropFirst()
        {
            let pair = option.split(separator: "=", maxSplits: 1,
                                    omittingEmptySubsequences: false)
            guard pair.count == 2, let value = Double(pair[1]),
                  value.isFinite else
            {
                throw fail("option \"\(option)\" is not name=number")
            }

            switch pair[0]
            {
            case "rate":
                guard value > 0 else { throw fail("rate must be above 0") }
                tone.rate = value

            case "amp":
                guard value >= 0, value <= 1 else
                {
                    throw fail("amp must be from 0 to 1")
                }
                tone.amplitude = value

            case "secs":
                guard value > 0 else { throw fail("secs must be above 0") }
                tone.seconds = value

            default:
                throw fail("unknown option \"\(pair[0])\"")
            }
        }

        if case .hertz(let hertz) = pitch, hertz >= tone.rate / 2
        {
            throw fail("\(hertz) Hz is at or above half the rate, "
                       + "\(tone.rate / 2) Hz")
        }

        return .tone(tone)
    }

    // parsePitch: Hz, or a note name with an optional cents offset
    static func parsePitch(_ text: String, description: String)
      throws(SourceError) -> TonePitch
    {
        func fail(_ reason: String) -> SourceError
        {
            SourceError(description: description, reason: reason)
        }

        if let hertz = Double(text)
        {
            guard hertz.isFinite, hertz > 0 else
            {
                throw fail("pitch must be above 0 Hz")
            }
            return .hertz(hertz)
        }

        let letters: [Character: Int] =
          ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]

        var rest = Substring(text)
        guard let letter = rest.popFirst(), let base = letters[letter] else
        {
            throw fail("\"\(text)\" is not Hz or a note name such as E4")
        }

        // Both spellings of each accidental
        var semitones = base
        while let accidental = rest.first
        {
            if accidental == "#" || accidental == "\u{266F}"
            {
                semitones += 1
            }
            else if accidental == "b" || accidental == "\u{266D}"
            {
                semitones -= 1
            }
            else
            {
                break
            }
            rest.removeFirst()
        }

        let digits = rest.prefix { $0.isASCII && $0.isNumber }
        guard let octave = Int(digits) else
        {
            throw fail("\"\(text)\" has no octave")
        }
        rest.removeFirst(digits.count)

        var cents = 0.0
        if !rest.isEmpty
        {
            guard rest.first == "+" || rest.first == "-",
                  let offset = Double(rest), offset.isFinite else
            {
                throw fail("\"\(rest)\" is not a cents offset such as +7")
            }
            cents = offset
        }

        guard abs(cents) <= ToneSpec.maxCents else
        {
            throw fail("a cents offset beyond \u{00B1}50 names another note")
        }

        let number = octave * Notes.octave + semitones
        guard number >= 0 else
        {
            throw fail("\"\(text)\" is below the lowest note")
        }

        return .note(number: number, cents: cents)
    }
}
