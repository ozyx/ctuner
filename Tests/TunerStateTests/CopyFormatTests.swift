//
//  CopyFormatTests.swift
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

// Today's line for A4 at +3.00 cents, 440.00 Hz target and 440.76 Hz
// measured, written out by hand from the format string in
// swift/TunerView.swift: note, accidental, octave, a space, the cents
// with a sign and the cent sign, then target, measured and difference,
// each with Hz, and a newline
private let kA4Line = "A4 +3.00\u{00A2} 440.00Hz 440.76Hz 0.76Hz\n"

// No transpose: the middle of today's transpose table
private let kNoTranspose = 6

private let kA4 = Hop(sequence: 1, found: true, note: 57, cents: 3,
                      frequency: 440.76, reference: 440, lower: 425,
                      upper: 455,
                      reeds: [Reed(note: 57, cents: 3, frequency: 440.76,
                                   reference: 440),
                              Reed(note: 69, cents: -8,
                                   frequency: 878.0, reference: 880)])

@MainActor
@Suite("copy format")
struct CopyFormatTests
{
    @Test func todaysLine()
    {
        let reading = Reading(note: 57, cents: 3, frequency: 440.76,
                              reference: 440, reeds: [])
        #expect(reading.copyLine(transpose: kNoTranspose) == kA4Line)
    }

    @Test func flatNoteBelowTarget()
    {
        // E flat 3 at -12.50 cents, 154.65 Hz against 155.56 Hz
        let reading = Reading(note: 39, cents: -12.5, frequency: 154.65,
                              reference: 155.56, reeds: [])
        #expect(reading.copyLine(transpose: kNoTranspose) ==
                  "E\u{266D}3 -12.50\u{00A2} 155.56Hz 154.65Hz -0.91Hz\n")
    }

    @Test func copiesInLiveStaleAndLockedButNotBlank()
    {
        let model = DisplayModel()
        #expect(model.copyLine(transpose: kNoTranspose) == nil)

        model.update(kA4, now: 0)
        #expect(model.copyLine(transpose: kNoTranspose) == kA4Line)

        // Stale
        var silence = Hop(sequence: 2, found: false)
        model.update(silence, now: 2)
        #expect(model.isStale)
        #expect(model.copyLine(transpose: kNoTranspose) == kA4Line)

        // Locked, while another note plays
        model.isLocked = true
        var c5 = kA4
        c5.sequence = 3
        c5.note = 60
        model.update(c5, now: 3)
        #expect(model.copyLine(transpose: kNoTranspose) == kA4Line)

        silence.sequence = 4
        model.update(silence, now: 4)
        #expect(model.copyLine(transpose: kNoTranspose) == kA4Line)
    }

    @Test func multipleReedsCopyThePrimaryLine()
    {
        // The model has no reed mode of its own; the copy is always the
        // primary note, whatever rows the reading carries
        let model = DisplayModel()
        model.update(kA4, now: 0)
        #expect(model.reading?.reeds.count == 2)
        #expect(model.copyLine(transpose: kNoTranspose) == kA4Line)
    }

    @Test func transposedNameAndStaffOctaveAgree()
    {
        // Today's table, written out: index 0 shows six semitones
        // down, index 12 six up
        let shift = [-6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6]
        let letters = ["C", "C", "D", "E", "E", "F",
                       "F", "G", "A", "A", "B", "B"]
        let marks = ["", "\u{266F}", "", "\u{266D}", "", "",
                     "\u{266F}", "", "\u{266D}", "", "\u{266D}", ""]

        for transpose in 0 ... 12
        {
            for note in 0 ..< 108
            {
                let shifted = note + shift[transpose]
                let octave = Int((Double(shifted) / 12).rounded(.down))
                let index = shifted - octave * 12

                let shown = DisplayNote(note: note, transpose: transpose)
                #expect(shown.index == index)
                #expect(shown.octave == octave)
                #expect(shown.text == letters[index] + marks[index] +
                          String(octave))

                // The copy line names the same note
                let reading = Reading(note: note, cents: 0, frequency: 1,
                                      reference: 1, reeds: [])
                let line = reading.copyLine(transpose: transpose)
                #expect(line.hasPrefix(shown.text + " "))
            }
        }

        // B3 shown a semitone up is C4 in the readout and on the staff
        #expect(DisplayNote(note: 47, transpose: 7).text == "C4")
        #expect(DisplayNote(note: 47, transpose: 7).octave == 4)
    }

    @Test func accidentalTags()
    {
        #expect(DisplayNote(note: 57, transpose: kNoTranspose).accidental ==
                  .natural)
        #expect(DisplayNote(note: 58, transpose: kNoTranspose).accidental ==
                  .flat)
        #expect(DisplayNote(note: 54, transpose: kNoTranspose).accidental ==
                  .sharp)
        #expect(Notes.reference == 440)
    }
}
