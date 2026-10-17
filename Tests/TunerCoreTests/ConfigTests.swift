//
//  ConfigTests.swift
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
//  Configuration set while the analysis thread runs: a change applies
//  on the next hop, and a hop never sees half of one.

import Foundation
import Testing
import TunerCore

@Suite("core config")
struct ConfigTests
{
    static let block = Int(kTunerBlock)

    // feed: push one block and wait for its hop
    func feed(_ running: RunningEngine, _ samples: [Float], block k: Int) -> Bool
    {
        let hops = running.hops
        running.push(samples, k * ConfigTests.block ..< (k + 1) * ConfigTests.block)
        return running.wait(hops: hops + 1)
    }

    // A reference change shows in the hop after it
    @Test func referenceAppliesNextHop() throws
    {
        let samples = try #require(Fixture.named("tone-00440.0")).samples()
        let running = try RunningEngine(recording: true)
        try running.start()

        for k in 0 ..< 24
        {
            #expect(feed(running, samples, block: k))
        }
        #expect(running.records.last?.fr == 440)

        TunerEngineSetReference(running.engine, 442)
        #expect(feed(running, samples, block: 24))

        let last = try #require(running.records.last)
        #expect(last.found)
        #expect(last.fr == 442)
    }

    // A note mask change shows in the hop after it
    @Test func noteMaskAppliesNextHop() throws
    {
        let samples = try #require(Fixture.named("tone-00440.0")).samples()
        let running = try RunningEngine(recording: true)
        TunerEngineSetNoteFilter(running.engine, true)
        try running.start()

        for k in 0 ..< 24
        {
            #expect(feed(running, samples, block: k))
        }
        #expect(running.records.last?.found == true)

        // Every note but A
        TunerEngineSetNoteMask(running.engine, 0xfff & ~(1 << 9))
        #expect(feed(running, samples, block: 24))

        let last = try #require(running.records.last)
        #expect(!last.found)
        #expect(last.count == 0)
    }

    // A writer flipping the reference as fast as it can never gives a
    // hop a value that is neither setting
    @Test func referenceNeverTears() throws
    {
        let samples = try #require(Fixture.named("tone-00440.0")).samples()
        let running = try RunningEngine(recording: true)
        try running.start()

        let done = DispatchSemaphore(value: 0)
        let flag = Flag()
        let writer = Thread
        {
            var high = false
            while !flag.isSet
            {
                high.toggle()
                TunerEngineSetReference(running.engine, high ? 442 : 440)
            }
            done.signal()
        }
        writer.start()

        for k in 0 ..< samples.count / ConfigTests.block
        {
            #expect(feed(running, samples, block: k))
        }

        flag.set()
        done.wait()

        for record in running.records.dropFirst(Fixture.warmUpHops) where record.found
        {
            #expect(record.fr == 440 || record.fr == 442)
        }
    }
}

// Flag: a stop flag shared between threads
final class Flag: @unchecked Sendable
{
    private let lock = NSLock()
    private var value = false

    var isSet: Bool
    {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    // set
    func set()
    {
        lock.lock()
        value = true
        lock.unlock()
    }
}
