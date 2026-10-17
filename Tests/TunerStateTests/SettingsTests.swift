//
//  SettingsTests.swift
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
//  Every test runs on its own defaults suite, never the app's domain,
//  and removes it afterwards.

import Foundation
import Testing
import TunerState

// A defaults suite of its own for one test
private final class Suite
{
    let name = "TunerStateTests." + UUID().uuidString
    let defaults: UserDefaults

    // init
    init()
    {
        defaults = UserDefaults(suiteName: name)!
    }

    deinit
    {
        defaults.removePersistentDomain(forName: name)
    }

    // legacy: write today's nine keys
    func legacy(ref: Double = 442, temper: Int = 19, key: Int = 7,
                trans: Int = 6, colours: Int = 2)
    {
        defaults.set(ref, forKey: "Ref")
        defaults.set(temper, forKey: "Temper")
        defaults.set(key, forKey: "Key")
        defaults.set(trans, forKey: "Trans")
        defaults.set(colours, forKey: "Colours")
        defaults.set(false, forKey: "Zoom")
        defaults.set(true, forKey: "Filter")
        defaults.set(true, forKey: "Strobe")
        defaults.set(true, forKey: "Down")
    }
}

@MainActor
@Suite("settings")
struct SettingsTests
{
    @Test func firstLaunchDefaults()
    {
        let suite = Suite()
        let settings = Settings(defaults: suite.defaults)

        #expect(settings.reference == 440)
        #expect(settings.temperament == 8)
        #expect(settings.key == 0)
        #expect(settings.transpose == 6)
        #expect(settings.colour == 1)
        #expect(settings.zoom)
        #expect(!settings.filter)
        #expect(!settings.downsample)
        #expect(!settings.multiple)
        #expect(!settings.fundamental)
        #expect(!settings.noteFilter)
        #expect(settings.expand == 1)

        // Strobe first, inspector hidden (R32)
        #expect(settings.strobe)
        #expect(!settings.inspector)
    }

    // Covers AE5
    @Test func writtenOnChangeAndReadAfterRelaunch()
    {
        let suite = Suite()
        let settings = Settings(defaults: suite.defaults)
        settings.multiple = true
        settings.fundamental = true
        settings.noteFilter = true
        settings.notes = (0 ..< 12).map { $0 == 9 }
        settings.octaves = (0 ..< 9).map { $0 == 4 }
        settings.expand = 4
        settings.reference = 415
        settings.temperament = 19
        settings.key = 7
        settings.transpose = 3
        settings.colour = 2
        settings.zoom = false
        settings.filter = true
        settings.strobe = false
        settings.downsample = true
        settings.inspector = true

        // Lock lives in the display model, which starts unlocked
        let display = DisplayModel()
        display.isLocked = true

        // Relaunch: nothing is saved at quit, so a new model on the same
        // defaults sees only what was written on change
        let relaunched = Settings(defaults: suite.defaults)
        #expect(relaunched.multiple)
        #expect(relaunched.fundamental)
        #expect(relaunched.noteFilter)
        #expect(relaunched.notes == (0 ..< 12).map { $0 == 9 })
        #expect(relaunched.octaves == (0 ..< 9).map { $0 == 4 })
        #expect(relaunched.expand == 4)
        #expect(relaunched.reference == 415)
        #expect(relaunched.temperament == 19)
        #expect(relaunched.key == 7)
        #expect(relaunched.transpose == 3)
        #expect(relaunched.colour == 2)
        #expect(!relaunched.zoom)
        #expect(relaunched.filter)
        #expect(!relaunched.strobe)
        #expect(relaunched.downsample)
        #expect(relaunched.inspector)
        #expect(!DisplayModel().isLocked)
    }

    // Covers AE11
    @Test func noteFilterDefaultsAndEmptySelection()
    {
        let suite = Suite()
        let settings = Settings(defaults: suite.defaults)

        #expect(settings.notes == Array(repeating: true, count: 12))
        #expect(settings.octaves == Array(repeating: true, count: 9))
        #expect(settings.noteMask == 0xfff)
        #expect(settings.octaveMask == 0x1ff)

        // A partial pick filters
        settings.notes = (0 ..< 12).map { $0 == 9 }
        settings.octaves = (0 ..< 9).map { $0 == 4 }
        #expect(settings.noteMask == 1 << 9)
        #expect(settings.octaveMask == 1 << 4)

        // An empty set is no filter
        settings.notes = Array(repeating: false, count: 12)
        settings.octaves = Array(repeating: false, count: 9)
        #expect(settings.noteMask == 0xfff)
        #expect(settings.octaveMask == 0x1ff)
    }

    @Test func legacyKeysMigrate()
    {
        let suite = Suite()
        suite.legacy()

        let settings = Settings(defaults: suite.defaults)
        #expect(settings.reference == 442)
        #expect(settings.temperament == 19)
        #expect(settings.key == 7)
        #expect(settings.transpose == 6)
        #expect(settings.colour == 2)
        #expect(!settings.zoom)
        #expect(settings.filter)
        #expect(settings.strobe)
        #expect(settings.downsample)

        // Once the new keys are written, the legacy ones are ignored
        settings.reference = 430
        settings.temperament = 3
        settings.key = 2
        settings.transpose = 9
        settings.colour = 0
        settings.zoom = true
        settings.filter = false
        settings.strobe = false
        settings.downsample = false

        let relaunched = Settings(defaults: suite.defaults)
        #expect(relaunched.reference == 430)
        #expect(relaunched.temperament == 3)
        #expect(relaunched.key == 2)
        #expect(relaunched.transpose == 9)
        #expect(relaunched.colour == 0)
        #expect(relaunched.zoom)
        #expect(!relaunched.filter)
        #expect(!relaunched.strobe)
        #expect(!relaunched.downsample)

        // The legacy keys themselves are left as they were
        #expect(suite.defaults.double(forKey: "Ref") == 442)
    }

    @Test func legacyZeroReferenceIsNotStored()
    {
        // Today's first-launch sentinel
        let suite = Suite()
        suite.legacy(ref: 0)

        let settings = Settings(defaults: suite.defaults)
        #expect(settings.reference == 440)
    }

    @Test func indicesClamp()
    {
        let suite = Suite()
        suite.legacy(temper: 40, key: 12, trans: 13, colours: 3)

        let migrated = Settings(defaults: suite.defaults)
        #expect(migrated.temperament == 31)
        #expect(migrated.key == 11)
        #expect(migrated.transpose == 12)
        #expect(migrated.colour == 2)

        let other = Suite()
        let settings = Settings(defaults: other.defaults)
        settings.temperament = 40
        settings.key = 12
        settings.transpose = 13
        settings.colour = 3
        #expect(settings.temperament == 31)
        #expect(settings.key == 11)
        #expect(settings.transpose == 12)
        #expect(settings.colour == 2)

        settings.temperament = -1
        settings.key = -1
        settings.transpose = -1
        settings.colour = -1
        #expect(settings.temperament == 0)
        #expect(settings.key == 0)
        #expect(settings.transpose == 0)
        #expect(settings.colour == 0)
    }

    @Test func referenceRange()
    {
        let suite = Suite()
        let settings = Settings(defaults: suite.defaults)

        settings.reference = 0
        #expect(settings.reference == 440)
        settings.reference = 1000
        #expect(settings.reference == 440)
        settings.reference = 415
        #expect(settings.reference == 415)
        settings.reference = 0
        #expect(settings.reference == 415)

        // A rejected value is never stored
        #expect(Settings(defaults: suite.defaults).reference == 415)

        // Nor read from the legacy key
        let legacy = Suite()
        legacy.legacy(ref: 1000)
        #expect(Settings(defaults: legacy.defaults).reference == 440)
    }
}
