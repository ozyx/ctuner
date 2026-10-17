//
//  EngineLifecycleTests.swift
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
//  Start, stop and destroy, and where the analysis runs (covers AE2).

import Foundation
import Testing
import TunerCore

@Suite("core lifecycle")
struct EngineLifecycleTests
{
    static let block = Int(kTunerBlock)

    // Create, start, feed, stop and destroy, a hundred times
    @Test func repeatedLifecycle() throws
    {
        let samples = [Float](repeating: 0.25, count: 4 * EngineLifecycleTests.block)

        for _ in 0 ..< 100
        {
            let running = try RunningEngine()
            try running.start()
            running.push(samples, samples.indices)
            #expect(running.wait(hops: 4))
            TunerEngineStop(running.engine)
        }
    }

    // Destroy with the thread waiting on its semaphore returns
    @Test func destroyWhileWaiting() throws
    {
        let engine = try createEngine(rate: 44100)
        #expect(TunerEngineStart(engine, nil, nil) == kTunerStatusOK)
        TunerEngineDestroy(engine)
    }

    // A second start is refused, and so is a caller's block while the
    // thread owns the analysis; after a stop both work again
    @Test func oneOwnerAtATime() throws
    {
        let engine = try createEngine(rate: 44100)
        defer { TunerEngineDestroy(engine) }

        let slot = try #require(TunerSlotCreate())
        defer { TunerSlotDestroy(slot) }

        let block = [Float](repeating: 0, count: EngineLifecycleTests.block)

        #expect(TunerEngineStart(engine, nil, nil) == kTunerStatusOK)
        #expect(TunerEngineStart(engine, nil, nil) == kTunerStatusBadArgument)
        #expect(TunerEngineProcessBlock(engine, block, slot) == kTunerStatusBadArgument)

        TunerEngineStop(engine)
        #expect(TunerEngineProcessBlock(engine, block, slot) == kTunerStatusOK)
        #expect(TunerEngineStart(engine, nil, nil) == kTunerStatusOK)
    }

    // Covers AE2: on a 440 Hz feed snapshots arrive with A4 found, and
    // every hop ran on the engine's thread, never on this one
    @Test func analysisOffTheCallerThread() throws
    {
        let fixture = try #require(Fixture.named("tone-00440.0"))
        let samples = try fixture.samples()
        let running = try RunningEngine(recording: true)
        try running.start()

        running.push(samples, 0 ..< 32 * EngineLifecycleTests.block)
        #expect(running.wait(hops: 32))

        let threads = running.threads
        #expect(threads.count == 1)
        #expect(!threads.contains(currentThread()))

        let last = try #require(running.records.last)
        #expect(last.found)
        #expect(last.note == 57)
    }
}
