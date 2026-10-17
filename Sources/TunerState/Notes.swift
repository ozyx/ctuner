//
//  Notes.swift
//  Tuner
//
//  Created by Bill Farmer on 08/10/2017.
//  Copyright © 2017 Bill Farmer. All rights reserved.
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
//  Note names, accidentals and the transpose table from
//  swift/TunerView.swift, the reference constants from
//  Reference/Audio.h, and the copy-readout line. Transpose is display
//  state only: it shifts the name and the staff position and never
//  reaches the engine.

import Foundation

// An accidental, as the readout and the staff draw it
public enum Accidental: Sendable
{
    case natural
    case sharp
    case flat
}

public enum Notes
{
    // The default A4 reference in Hz
    public static let reference = 440.0

    // Semitones in an octave
    public static let octave = 12

    // The note number of A4
    public static let a4 = 57

    // The transpose index that shifts nothing
    public static let noTranspose = 6

    // Semitones subtracted from the note for each transpose index;
    // index 0 is the menu's +6, index 12 its -6
    public static let translate =
      [6, 5, 4, 3, 2, 1, 0, -1, -2, -3, -4, -5, -6]

    // Letter names from C
    public static let names =
      ["C", "C", "D", "E", "E", "F",
       "F", "G", "A", "A", "B", "B"]

    // Accidentals from C
    public static let accidentals: [Accidental] =
      [.natural, .sharp, .natural, .flat, .natural, .natural,
       .sharp, .natural, .flat, .natural, .flat, .natural]

    // Accidental symbols from C
    public static let symbols =
      ["", "\u{266F}", "", "\u{266D}", "", "",
       "\u{266F}", "", "\u{266D}", "", "\u{266D}", ""]
}

// A note as shown after transpose. The readout, the copy line and the
// staff all take the octave from here, so they agree.
public struct DisplayNote: Equatable, Sendable
{
    // Pitch class from C, 0 to 11
    public let index: Int

    // Octave, rounded down, so a note shifted below C0 is in octave -1
    public let octave: Int

    // init(note:transpose:)
    public init(note: Int, transpose: Int)
    {
        let shifted = note - Notes.translate[transpose]
        let octave = Int((Double(shifted) / Double(Notes.octave))
                           .rounded(.down))
        self.octave = octave
        index = shifted - octave * Notes.octave
    }

    public var name: String { Notes.names[index] }
    public var accidental: Accidental { Notes.accidentals[index] }
    public var symbol: String { Notes.symbols[index] }

    // Name, accidental and octave, such as E♭4
    public var text: String { name + symbol + String(octave) }
}

// One spectrum maximum as a multiple-reed row
public struct Reed: Equatable, Sendable
{
    public var note: Int
    public var cents: Double
    public var frequency: Double
    public var reference: Double

    // init
    public init(note: Int, cents: Double, frequency: Double,
                reference: Double)
    {
        self.note = note
        self.cents = cents
        self.frequency = frequency
        self.reference = reference
    }

    // The frequency deviation in Hz
    public var difference: Double { frequency - reference }
}

// The readout: the primary note and the multiple-reed rows
public struct Reading: Equatable, Sendable
{
    // Note number, 57 is A4
    public var note: Int
    public var cents: Double
    public var frequency: Double
    public var reference: Double
    public var reeds: [Reed]

    // init
    public init(note: Int, cents: Double, frequency: Double,
                reference: Double, reeds: [Reed])
    {
        self.note = note
        self.cents = cents
        self.frequency = frequency
        self.reference = reference
        self.reeds = reeds
    }

    // The frequency deviation in Hz
    public var difference: Double { frequency - reference }

    // displayNote
    public func displayNote(transpose: Int) -> DisplayNote
    {
        return DisplayNote(note: note, transpose: transpose)
    }

    // copyLine: today's c key line for the primary note
    public func copyLine(transpose: Int) -> String
    {
        let shown = displayNote(transpose: transpose)
        return String(format: "%@%@%d %+4.2lf\u{00A2} %4.2lfHz %4.2lfHz " +
                        "%4.2lfHz\n",
                      shown.name, shown.symbol, shown.octave, cents,
                      reference, frequency, difference)
    }
}
