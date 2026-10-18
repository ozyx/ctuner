//
//  RunOptions.swift
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
//  The tuner-run command line, parsed here so that it can be tested.
//  The source comes first; every flag after it is --name, or --name and
//  a value.

import Foundation
import TunerState

public struct RunOptions: Equatable, Sendable
{
    public static let usage = """
    usage: tuner-run SOURCE [--reference HZ] [--temperament N] [--key N]
                     [--filter] [--downsample] [--fundamental]
                     [--note-filter] [--notes HEX] [--octaves HEX]
                     [--target NOTE[+-CENTS]] [--tolerance CENTS]
                     [--paced] [--quiet]
      SOURCE is file:PATH or tone:PITCH[,rate=HZ][,amp=0..1][,secs=S]
      A pitch is Hz or a note name such as E4, Eb4+7 or F#3-12.5
      exit: 0 pass or no target, 1 fail, 2 usage or source error
    """

    public var source: String
    public var settings = RunSettings()
    public var target: Target?
    public var paced = false
    public var quiet = false

    // init
    public init(source: String)
    {
        self.source = source
    }

    // parse: arguments after the program name
    public static func parse(_ arguments: [String]) throws(SourceError)
      -> RunOptions
    {
        guard let first = arguments.first, !first.hasPrefix("--") else
        {
            throw SourceError("a source such as tone:A4 comes first")
        }

        var options = RunOptions(source: first)
        var target: (note: Int, cents: Double)?
        var tolerance: Double?

        var rest = arguments.dropFirst()[...]
        while let flag = rest.popFirst()
        {
            // value: the argument after a flag that takes one
            func value() throws(SourceError) -> String
            {
                guard let value = rest.popFirst() else
                {
                    throw SourceError("\(flag) needs a value")
                }
                return value
            }

            // number: the value as a finite number in a range
            func number(_ range: ClosedRange<Double>) throws(SourceError)
              -> Double
            {
                let text = try value()
                guard let number = Double(text), range.contains(number) else
                {
                    throw SourceError("\(flag) takes a number from "
                                      + "\(range.lowerBound) to "
                                      + "\(range.upperBound), not \"\(text)\"")
                }
                return number
            }

            // mask: hex, with or without 0x
            func mask(_ bits: Int) throws(SourceError) -> UInt32
            {
                let text = try value()
                let digits = text.hasPrefix("0x") ? String(text.dropFirst(2))
                                                  : text
                guard let mask = UInt32(digits, radix: 16),
                      mask < (1 << bits) else
                {
                    throw SourceError("\(flag) takes up to \(bits) bits in "
                                      + "hex, not \"\(text)\"")
                }
                return mask
            }

            switch flag
            {
            case "--reference":
                options.settings.reference =
                  try number(Settings.referenceRange)

            case "--temperament":
                let range = Settings.temperamentRange
                options.settings.temperament =
                  Int(try number(Double(range.lowerBound)
                                 ... Double(range.upperBound)))

            case "--key":
                let range = Settings.keyRange
                options.settings.key =
                  Int(try number(Double(range.lowerBound)
                                 ... Double(range.upperBound)))

            case "--filter": options.settings.filter = true
            case "--downsample": options.settings.downsample = true
            case "--fundamental": options.settings.fundamental = true
            case "--note-filter": options.settings.noteFilter = true
            case "--notes": options.settings.notes = try mask(Settings.noteCount)
            case "--octaves": options.settings.octaves = try mask(Settings.octaveCount)

            case "--target":
                let text = try value()
                guard case .note(let note, let cents) =
                        try SourceSpec.parsePitch(text, description: text)
                else
                {
                    throw SourceError("--target takes a note name such as "
                                      + "E4 or Eb4+7, not \"\(text)\"")
                }
                target = (note, cents)

            case "--tolerance":
                tolerance = try number(0.000001 ... 50)

            case "--paced": options.paced = true
            case "--quiet": options.quiet = true

            default:
                throw SourceError("unknown flag \(flag)")
            }
        }

        if let target
        {
            options.target = Target(note: target.note, cents: target.cents,
                                    tolerance: tolerance
                                      ?? Target.defaultTolerance)
        }
        else if tolerance != nil
        {
            throw SourceError("--tolerance needs a --target")
        }

        return options
    }
}
