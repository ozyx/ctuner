//
//  Settings.swift
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
//  Every setting the owner can change (R19), written to the defaults
//  as it changes and forwarded to the engine when it is one the engine
//  reads. Lock is not here: it starts off on every launch.
//
//  Each setting is read from its own key, then from the key today's app
//  wrote under the same bundle identifier, then from its first-launch
//  default. The new keys are lower camel case, so they never collide
//  with today's capitalised ones, which are read but never written.

import Foundation
import Observation

@MainActor
@Observable
public final class Settings
{
    // The reference frequencies the field accepts (R33)
    public nonisolated static let referenceRange = 300.0 ... 500.0

    // Index ranges
    public nonisolated static let temperamentRange =
      0 ... Temperaments.values.count - 1
    public nonisolated static let keyRange = 0 ... Notes.octave - 1
    public nonisolated static let transposeRange =
      0 ... Notes.translate.count - 1
    public nonisolated static let colourRange = 0 ... 2

    // The note filter's two independent sets
    public nonisolated static let noteCount = 12
    public nonisolated static let octaveCount = 9

    // The keys this model writes
    private enum Key
    {
        static let reference = "reference"
        static let temperament = "temperament"
        static let key = "key"
        static let transpose = "transpose"
        static let colour = "colour"
        static let zoom = "zoom"
        static let filter = "filter"
        static let strobe = "strobe"
        static let downsample = "downsample"
        static let multiple = "multiple"
        static let fundamental = "fundamental"
        static let noteFilter = "noteFilter"
        static let notes = "notes"
        static let octaves = "octaves"
        static let expand = "expand"
        static let inspector = "inspector"
    }

    // The nine keys today's app writes
    private enum Legacy
    {
        static let reference = "Ref"
        static let temperament = "Temper"
        static let key = "Key"
        static let transpose = "Trans"
        static let colour = "Colours"
        static let zoom = "Zoom"
        static let filter = "Filter"
        static let strobe = "Strobe"
        static let downsample = "Down"
    }

    // A4 reference in Hz; a value outside the range is ignored
    public var reference: Double
    {
        didSet
        {
            if !Settings.referenceRange.contains(reference)
            {
                reference = oldValue
                return
            }
            defaults.set(reference, forKey: Key.reference)
            engine?.setReference(reference)
        }
    }

    // Temperament row index; the table order is frozen
    public var temperament: Int
    {
        didSet
        {
            let clamped = Settings.clamp(temperament,
                                         Settings.temperamentRange)
            if clamped != temperament
            {
                temperament = clamped
                return
            }
            defaults.set(temperament, forKey: Key.temperament)
            engine?.setTemperament(temperament)
        }
    }

    // Key, 0 is C
    public var key: Int
    {
        didSet
        {
            let clamped = Settings.clamp(key, Settings.keyRange)
            if clamped != key
            {
                key = clamped
                return
            }
            defaults.set(key, forKey: Key.key)
            engine?.setKey(key)
        }
    }

    // Transpose index into Notes.translate; display only
    public var transpose: Int
    {
        didSet
        {
            let clamped = Settings.clamp(transpose, Settings.transposeRange)
            if clamped != transpose
            {
                transpose = clamped
                return
            }
            defaults.set(transpose, forKey: Key.transpose)
        }
    }

    // Strobe colours
    public var colour: Int
    {
        didSet
        {
            let clamped = Settings.clamp(colour, Settings.colourRange)
            if clamped != colour
            {
                colour = clamped
                return
            }
            defaults.set(colour, forKey: Key.colour)
        }
    }

    public var zoom: Bool
    {
        didSet { defaults.set(zoom, forKey: Key.zoom) }
    }

    public var filter: Bool
    {
        didSet
        {
            defaults.set(filter, forKey: Key.filter)
            engine?.setFilter(filter)
        }
    }

    // Strobe shown rather than the staff
    public var strobe: Bool
    {
        didSet { defaults.set(strobe, forKey: Key.strobe) }
    }

    public var downsample: Bool
    {
        didSet
        {
            defaults.set(downsample, forKey: Key.downsample)
            engine?.setDownsample(downsample)
        }
    }

    // Multiple reeds
    public var multiple: Bool
    {
        didSet { defaults.set(multiple, forKey: Key.multiple) }
    }

    public var fundamental: Bool
    {
        didSet
        {
            defaults.set(fundamental, forKey: Key.fundamental)
            engine?.setFundamental(fundamental)
        }
    }

    public var noteFilter: Bool
    {
        didSet
        {
            defaults.set(noteFilter, forKey: Key.noteFilter)
            engine?.setNoteFilter(noteFilter)
        }
    }

    // The note filter's 12 notes from C
    public var notes: [Bool]
    {
        didSet
        {
            defaults.set(Int(Settings.mask(notes)), forKey: Key.notes)
            engine?.setNoteMask(noteMask)
        }
    }

    // The note filter's 9 octaves from 0
    public var octaves: [Bool]
    {
        didSet
        {
            defaults.set(Int(Settings.mask(octaves)), forKey: Key.octaves)
            engine?.setOctaveMask(octaveMask)
        }
    }

    // Spectrum expand, 1 to 16
    public var expand: Int
    {
        didSet { defaults.set(expand, forKey: Key.expand) }
    }

    // The inspector's visibility
    public var inspector: Bool
    {
        didSet { defaults.set(inspector, forKey: Key.inspector) }
    }

    // The engine these settings drive; every engine setting is applied
    // when one is attached
    @ObservationIgnored public var engine: Engine?
    {
        didSet { apply() }
    }

    // The masks the engine filters with: an empty set is no filter
    // (R29), so turning the filter on never blanks the readout
    public var noteMask: UInt32
    {
        let mask = Settings.mask(notes)
        return (mask == 0) ? (1 << Settings.noteCount) - 1 : mask
    }

    public var octaveMask: UInt32
    {
        let mask = Settings.mask(octaves)
        return (mask == 0) ? (1 << Settings.octaveCount) - 1 : mask
    }

    @ObservationIgnored private let defaults: UserDefaults

    // init: read every setting
    public init(defaults: UserDefaults = .standard)
    {
        self.defaults = defaults

        // Today's reference, unless it is out of range, which includes
        // the 0 it never wrote but read as first launch
        var reference = Notes.reference
        if let saved = defaults.object(forKey: Key.reference) as? Double,
           Settings.referenceRange.contains(saved)
        {
            reference = saved
        }
        else if defaults.object(forKey: Key.reference) == nil,
                let saved = defaults.object(forKey: Legacy.reference)
                  as? Double,
                Settings.referenceRange.contains(saved)
        {
            reference = saved
        }

        self.reference = reference
        temperament = Settings.clamp(Settings.read(defaults, Key.temperament,
                                                   Legacy.temperament,
                                                   Temperaments.equal),
                                     Settings.temperamentRange)
        key = Settings.clamp(Settings.read(defaults, Key.key, Legacy.key, 0),
                             Settings.keyRange)
        transpose = Settings.clamp(Settings.read(defaults, Key.transpose,
                                                 Legacy.transpose,
                                                 Notes.noTranspose),
                                   Settings.transposeRange)
        colour = Settings.clamp(Settings.read(defaults, Key.colour,
                                              Legacy.colour, 1),
                                Settings.colourRange)
        zoom = Settings.read(defaults, Key.zoom, Legacy.zoom, true)
        filter = Settings.read(defaults, Key.filter, Legacy.filter, false)
        strobe = Settings.read(defaults, Key.strobe, Legacy.strobe, true)
        downsample = Settings.read(defaults, Key.downsample,
                                   Legacy.downsample, false)
        multiple = Settings.read(defaults, Key.multiple, nil, false)
        fundamental = Settings.read(defaults, Key.fundamental, nil, false)
        noteFilter = Settings.read(defaults, Key.noteFilter, nil, false)
        notes = Settings.flags(Settings.read(defaults, Key.notes, nil,
                                             (1 << Settings.noteCount) - 1),
                               Settings.noteCount)
        octaves = Settings.flags(Settings.read(defaults, Key.octaves, nil,
                                               (1 << Settings.octaveCount) - 1),
                                 Settings.octaveCount)
        expand = Settings.read(defaults, Key.expand, nil, 1)
        inspector = Settings.read(defaults, Key.inspector, nil, false)
    }

    // apply: every engine setting to the attached engine
    private func apply()
    {
        guard let engine else
        {
            return
        }

        engine.setReference(reference)
        engine.setTemperament(temperament)
        engine.setKey(key)
        engine.setFilter(filter)
        engine.setDownsample(downsample)
        engine.setFundamental(fundamental)
        engine.setNoteFilter(noteFilter)
        engine.setNoteMask(noteMask)
        engine.setOctaveMask(octaveMask)
    }

    // read: the new key, then the legacy key, then the default
    private static func read<T>(_ defaults: UserDefaults, _ key: String,
                                _ legacy: String?, _ value: T) -> T
    {
        if let saved = defaults.object(forKey: key) as? T
        {
            return saved
        }

        if let legacy, let saved = defaults.object(forKey: legacy) as? T
        {
            return saved
        }

        return value
    }

    // clamp
    private static func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int
    {
        return min(max(value, range.lowerBound), range.upperBound)
    }

    // mask: flags to bits, the first flag in bit 0
    private static func mask(_ flags: [Bool]) -> UInt32
    {
        var mask: UInt32 = 0
        for (index, flag) in flags.enumerated() where flag
        {
            mask |= 1 << index
        }
        return mask
    }

    // flags: bits to a count of flags
    private static func flags(_ mask: Int, _ count: Int) -> [Bool]
    {
        return (0 ..< count).map { (mask >> $0) & 1 != 0 }
    }
}
