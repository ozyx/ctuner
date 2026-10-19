//
//  InputSourceTests.swift
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
@testable import TunerSource
import TunerState

@MainActor
@Suite("input source")
struct InputSourceTests
{
    @Test func noArgumentIsNoSource() throws
    {
        #expect(try InputSource.source(arguments: [:]) == nil)
        #expect(try InputSource.source(arguments: ["Other": "x"]) == nil)
    }

    @Test func fileAndToneDescriptions() throws
    {
        #expect(try InputSource.source(arguments: ["InputSource": "file:/tmp/x.wav"])
                == .file("/tmp/x.wav"))

        let spec = try InputSource.source(arguments: ["InputSource": "tone:E4+5"])
        #expect(spec == (try SourceSpec.parse("tone:E4+5")))
    }

    @Test(arguments: ["", "mic:", "tone:", "file:", "wav"])
    func badValuesAreErrors(_ value: String)
    {
        #expect(throws: SourceError.self)
        {
            try InputSource.source(arguments: ["InputSource": value])
        }
    }

    // The error names the value, except the empty one, which has none
    @Test(arguments: ["mic:", "wav"])
    func theErrorNamesTheValue(_ value: String)
    {
        do
        {
            _ = try InputSource.source(arguments: ["InputSource": value])
            Issue.record("expected an error")
        }

        catch
        {
            #expect(error.message.contains(value))
        }
    }

    @Test func aValueThatIsNotTextIsAnError()
    {
        #expect(throws: SourceError.self)
        {
            try InputSource.source(arguments: ["InputSource": 5])
        }
    }

    // Covers AE4: the flag never reaches the saved settings
    @Test func settingsNeverSaveTheFlag()
    {
        let name = "TunerSourceTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        // The launch argument sits in the argument domain, which Settings
        // does not read; a full change cycle then saves its own keys
        let settings = Settings(defaults: defaults)
        settings.reference = 442
        settings.strobe.toggle()
        settings.cycleColour()
        settings.expandSpectrum()

        let saved = defaults.persistentDomain(forName: name) ?? [:]
        #expect(!saved.isEmpty)
        #expect(saved[InputSource.key] == nil)
    }

    @Test func runSettingsFollowTheAppSettings()
    {
        let name = "TunerSourceTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        let settings = Settings(defaults: defaults)
        settings.reference = 442
        settings.temperament = 3
        settings.key = 7

        let run = RunSettings(settings)
        #expect(run.reference == 442)
        #expect(run.temperament == 3)
        #expect(run.key == 7)
    }
}
