//
//  RunOptionsTests.swift
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
//  The tuner-run command line: what each flag sets and which
//  arguments are usage errors.

import Testing
import TunerSource
import TunerState

@Suite("run options")
struct RunOptionsTests
{
    @Test func fullArgumentListParses() throws
    {
        let options = try RunOptions.parse(
          ["tone:Eb4+7,secs=2", "--reference", "415", "--temperament", "1",
           "--key", "3", "--filter", "--downsample", "--fundamental",
           "--note-filter", "--notes", "0x200", "--octaves", "1F",
           "--target", "Eb4+7", "--tolerance", "0.25", "--paced",
           "--quiet"])

        #expect(options.source == "tone:Eb4+7,secs=2")
        #expect(options.settings.reference == 415)
        #expect(options.settings.temperament == 1)
        #expect(options.settings.key == 3)
        #expect(options.settings.filter)
        #expect(options.settings.downsample)
        #expect(options.settings.fundamental)
        #expect(options.settings.noteFilter)
        #expect(options.settings.notes == 0x200)
        #expect(options.settings.octaves == 0x1F)
        #expect(options.target == Target(note: 51, cents: 7, tolerance: 0.25))
        #expect(options.paced)
        #expect(options.quiet)
    }

    @Test func defaultsAreTheApps() throws
    {
        let options = try RunOptions.parse(["tone:A4"])

        #expect(options.settings == RunSettings())
        #expect(options.settings.reference == 440)
        #expect(options.settings.temperament == Temperaments.equal)
        #expect(options.target == nil)
        #expect(!options.paced)
        #expect(!options.quiet)
    }

    @Test func targetWithNoOffsetMeansZeroCents() throws
    {
        let options = try RunOptions.parse(["tone:E4", "--target", "E4"])
        #expect(options.target == Target(note: 52, cents: 0))
    }

    @Test func targetTakesBothParts() throws
    {
        let options = try RunOptions.parse(["tone:E4", "--target", "Eb4-3.5"])
        #expect(options.target == Target(note: 51, cents: -3.5))
    }

    @Test func targetUsesHalfACentByDefault() throws
    {
        let options = try RunOptions.parse(["tone:E4", "--target", "E4"])
        #expect(options.target?.tolerance == 0.5)
    }

    @Test func toleranceMayComeBeforeTheTarget() throws
    {
        let options = try RunOptions.parse(["tone:E4", "--tolerance", "2",
                                            "--target", "E4"])
        #expect(options.target?.tolerance == 2)
    }

    // The note filter is a switch of its own: masks alone leave it off
    @Test func masksAloneLeaveTheNoteFilterOff() throws
    {
        let alone = try RunOptions.parse(["tone:E4", "--notes", "0x200"])
        #expect(alone.settings.notes == 0x200)
        #expect(!alone.settings.noteFilter)

        let with = try RunOptions.parse(["tone:E4", "--notes", "0x200",
                                         "--note-filter"])
        #expect(with.settings.noteFilter)
        #expect(with.settings.notes == 0x200)
    }

    @Test(arguments: [
        [],
        ["--paced"],
        ["tone:A4", "--bogus"],
        ["tone:A4", "--reference"],
        ["tone:A4", "--temperament"],
        ["tone:A4", "--temperament", "32"],
        ["tone:A4", "--temperament", "-1"],
        ["tone:A4", "--key", "12"],
        ["tone:A4", "--reference", "9000"],
        ["tone:A4", "--notes", "0x1000"],
        ["tone:A4", "--octaves", "zz"],
        ["tone:A4", "--target"],
        ["tone:A4", "--target", "440"],
        ["tone:A4", "--target", "E4+51"],
        ["tone:A4", "--tolerance", "0.5"],
        ["tone:A4", "--target", "A4", "--tolerance", "0"],
    ])
    func usageErrors(arguments: [String])
    {
        #expect(throws: SourceError.self)
        {
            try RunOptions.parse(arguments)
        }
    }
}
