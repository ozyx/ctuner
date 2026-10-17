//
//  CoreRunner.swift
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
//  Runs the new core over a fixture input on the test's own thread,
//  configured from the fixture's header.

import Foundation
import Testing
import TunerCore
import TunerState

// Engine configuration from a fixture header, with the README defaults
struct CoreConfig
{
    var rate = 44100.0
    var reference = 440.0
    var temperament: Int32 = 8
    var key: Int32 = 0
    var filter = false
    var downsample = false
    var fundamental = false
    var noteFilter = false
    var notes: UInt32 = 0xfff
    var octaves: UInt32 = 0x1ff
    var toggleHop = -1

    // init(header:)
    init(header: [String: String])
    {
        func value<T>(_ key: String, _ parse: (String) -> T?) -> T?
        {
            return header[key].flatMap(parse)
        }

        rate = value("rate", Double.init) ?? rate
        reference = value("reference", Double.init) ?? reference
        temperament = value("temper", Int32.init) ?? temperament
        key = value("key", Int32.init) ?? key
        filter = (value("filt", Int.init) ?? 0) != 0
        downsample = (value("down", Int.init) ?? 0) != 0
        fundamental = (value("fund", Int.init) ?? 0) != 0
        noteFilter = (value("note", Int.init) ?? 0) != 0
        notes = value("notes") { UInt32($0, radix: 16) } ?? notes
        octaves = value("octaves") { UInt32($0, radix: 16) } ?? octaves
        toggleHop = value("filt_toggle_hop", Int.init) ?? toggleHop
    }

    // init()
    init()
    {
    }
}

// createEngine: an engine at a rate with today's temperament table
func createEngine(rate: Double) throws -> OpaquePointer
{
    var engine: OpaquePointer?
    let status = Temperaments.flattened.withUnsafeBufferPointer
    {
        TunerEngineCreate(rate, $0.baseAddress, &engine)
    }
    try #require(status == kTunerStatusOK)
    return try #require(engine)
}

// runCore: one ActualHop per 1024-sample block of the input
func runCore(samples: [Float], config: CoreConfig) throws -> [ActualHop]
{
    let engine = try createEngine(rate: config.rate)
    defer { TunerEngineDestroy(engine) }

    let slot = try #require(TunerSlotCreate())
    defer { TunerSlotDestroy(slot) }

    TunerEngineSetReference(engine, config.reference)
    TunerEngineSetTemperament(engine, config.temperament)
    TunerEngineSetKey(engine, config.key)
    TunerEngineSetDownsample(engine, config.downsample)
    TunerEngineSetFundamental(engine, config.fundamental)
    TunerEngineSetNoteFilter(engine, config.noteFilter)
    TunerEngineSetNoteMask(engine, config.notes)
    TunerEngineSetOctaveMask(engine, config.octaves)

    var filter = config.filter
    let block = Int(kTunerBlock)
    var hops: [ActualHop] = []

    for hop in 0 ..< samples.count / block
    {
        if hop == config.toggleHop
        {
            filter.toggle()
        }
        TunerEngineSetFilter(engine, filter)

        let result = samples.withUnsafeBufferPointer
        {
            TunerEngineProcessBlock(engine, $0.baseAddress! + hop * block, slot)
        }
        try #require(result == kTunerStatusOK)

        var snapshot = TunerSnapshot()
        TunerSlotView(slot, &snapshot)
        hops.append(ActualHop(snapshot: snapshot))
    }

    return hops
}
