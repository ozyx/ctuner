//
//  SourceSpecTests.swift
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
//  Source descriptions: what parses, what each option sets and which
//  descriptions are errors that name themselves.

import Testing
@testable import TunerSource
import TunerState

// tone: the parsed tone of a description
private func tone(_ description: String) throws -> ToneSpec
{
    guard case .tone(let spec) = try SourceSpec.parse(description) else
    {
        throw SourceError("not a tone")
    }
    return spec
}

@Suite("source spec")
struct SourceSpecTests
{
    @Test func hertzDefaults() throws
    {
        let spec = try tone("tone:440")
        #expect(spec.pitch == .hertz(440))
        #expect(spec.rate == 44100)
        #expect(spec.amplitude == 0.5)
        #expect(spec.seconds == nil)
    }

    @Test func fractionalHertz() throws
    {
        #expect(try tone("tone:329.6").pitch == .hertz(329.6))
    }

    @Test func noteName() throws
    {
        #expect(try tone("tone:A4").pitch == .note(number: 57, cents: 0))
        #expect(try tone("tone:C0").pitch == .note(number: 0, cents: 0))
    }

    // Both spellings of each accidental name the same note
    @Test(arguments: ["Eb4+7", "D#4+7", "E\u{266D}4+7", "D\u{266F}4+7"])
    func accidentalSpellings(_ name: String) throws
    {
        #expect(try tone("tone:" + name).pitch
                == .note(number: 51, cents: 7))
    }

    @Test func centsOffsets() throws
    {
        #expect(try tone("tone:F#3-12.5").pitch
                == .note(number: 42, cents: -12.5))
        #expect(try tone("tone:E4+50").pitch == .note(number: 52, cents: 50))
    }

    @Test func allOptions() throws
    {
        let spec = try tone("tone:E4,rate=96000,amp=0.25,secs=2")
        #expect(spec.rate == 96000)
        #expect(spec.amplitude == 0.25)
        #expect(spec.seconds == 2)
    }

    @Test func filePath() throws
    {
        #expect(try SourceSpec.parse("file:/tmp/a b.wav")
                == .file("/tmp/a b.wav"))
    }

    // Covers AE5
    @Test(arguments: ["tone:E4+51", "tone:H4", "tone:30000,rate=44100",
                      "tone:", "wave:x", "file:", "tone:E4,amp=2",
                      "tone:E4,rate=0", "tone:E4,volume=1", "tone:E4,rate",
                      "tone:0", "tone:nan", "tone:E", "tone:E4x"])
    func errorsNameTheDescription(_ description: String)
    {
        do
        {
            _ = try SourceSpec.parse(description)
            Issue.record("\(description) parsed")
        }
        catch
        {
            #expect(error.message.contains("\"\(description)\""))
        }
    }
}
