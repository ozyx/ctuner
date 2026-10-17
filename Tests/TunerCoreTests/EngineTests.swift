//
//  EngineTests.swift
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
//  The block entry's window and isolation: the scope holds the newest
//  input in order, and two engines in one process share no state.

import Foundation
import Testing
import TunerCore

@Suite("core engine")
struct EngineTests
{
    // After 16 blocks the scope is the newest 8192 inputs, in order
    @Test func scopeIsNewestInput() throws
    {
        let engine = try createEngine(rate: 44100)
        defer { TunerEngineDestroy(engine) }

        let slot = try #require(TunerSlotCreate())
        defer { TunerSlotDestroy(slot) }

        // Every sample distinct and exact in a float
        let block = Int(kTunerBlock)
        let samples = (0 ..< 16 * block).map { Float($0) / 32768 }

        for hop in 0 ..< 16
        {
            samples.withUnsafeBufferPointer
            {
                _ = TunerEngineProcessBlock(engine, $0.baseAddress! + hop * block,
                                            slot)
            }
        }

        var snapshot = TunerSnapshot()
        TunerSlotView(slot, &snapshot)
        let scope = Array(UnsafeBufferPointer(start: snapshot.scope,
                                              count: Int(kTunerScopeLength)))
        let newest = samples.suffix(Int(kTunerScopeLength)).map(Double.init)

        #expect(scope == newest)
    }

    // Two engines fed block by block in turn give exactly what each
    // gives alone
    @Test func enginesShareNoState() throws
    {
        let first = try #require(Fixture.named("tone-00440.0"))
        let second = try #require(Fixture.named("temper-kirnberger3-g"))
        let configs = [CoreConfig(header: try first.header()),
                       CoreConfig(header: try second.header())]
        let inputs = [try first.samples(), try second.samples()]

        let alone = try zip(inputs, configs).map { try runCore(samples: $0, config: $1) }
        let together = try runInterleaved(inputs: inputs, configs: configs)

        for engine in 0 ..< 2
        {
            try #require(alone[engine].count == together[engine].count)

            for (a, b) in zip(alone[engine], together[engine])
            {
                #expect(a.found == b.found && a.note == b.note && a.count == b.count)
                #expect(a.f.bitPattern == b.f.bitPattern)
                #expect(a.c.bitPattern == b.c.bitPattern)
                #expect(a.sumsq.bitPattern == b.sumsq.bitPattern)
                #expect(a.maxima == b.maxima)
            }
        }
    }

    // runInterleaved: one engine per input, each block of the first
    // followed by the same block of the second
    func runInterleaved(inputs: [[Float]], configs: [CoreConfig]) throws -> [[ActualHop]]
    {
        let engines = try configs.map { try createEngine(rate: $0.rate) }
        defer { engines.forEach { TunerEngineDestroy($0) } }

        let slots = try configs.map { _ in try #require(TunerSlotCreate()) }
        defer { slots.forEach { TunerSlotDestroy($0) } }

        for (engine, config) in zip(engines, configs)
        {
            TunerEngineSetReference(engine, config.reference)
            TunerEngineSetTemperament(engine, config.temperament)
            TunerEngineSetKey(engine, config.key)
            TunerEngineSetFilter(engine, config.filter)
            TunerEngineSetDownsample(engine, config.downsample)
            TunerEngineSetFundamental(engine, config.fundamental)
            TunerEngineSetNoteFilter(engine, config.noteFilter)
            TunerEngineSetNoteMask(engine, config.notes)
            TunerEngineSetOctaveMask(engine, config.octaves)
        }

        let block = Int(kTunerBlock)
        let hops = inputs.map { $0.count / block }.min() ?? 0
        var results: [[ActualHop]] = [[], []]

        for hop in 0 ..< hops
        {
            for k in 0 ..< 2
            {
                let status = inputs[k].withUnsafeBufferPointer
                {
                    TunerEngineProcessBlock(engines[k], $0.baseAddress! + hop * block,
                                            slots[k])
                }
                try #require(status == kTunerStatusOK)

                var snapshot = TunerSnapshot()
                TunerSlotView(slots[k], &snapshot)
                results[k].append(ActualHop(snapshot: snapshot))
            }
        }

        return results
    }
}
