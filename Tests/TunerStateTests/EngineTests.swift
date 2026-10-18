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
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//  The engine wrapper on its own analysis thread, fed a synthetic A4.
//  No capture: the test pushes samples itself.

import Foundation
import Testing
import TunerState

private let kRate = 44100.0

// sine: one second of A4
private func sine(_ frequency: Double = 440, seconds: Double = 1) -> [Float]
{
    let count = Int(kRate * seconds)
    return (0 ..< count).map
    {
        Float(0.5 * sin(2 * Double.pi * frequency * Double($0) / kRate))
    }
}

// play: push the samples a block at a time and wait for every hop;
// returns the newest snapshot's hop
private func play(_ engine: Engine, _ samples: [Float]) throws -> Hop?
{
    let hops = DispatchSemaphore(value: 0)
    try engine.start { hops.signal() }
    defer { engine.stop() }

    let block = 1024
    for start in stride(from: 0, to: samples.count - block + 1, by: block)
    {
        samples[start ..< start + block].withUnsafeBufferPointer
        {
            engine.push($0)
        }
        #expect(hops.wait(timeout: .now() + 10) == .success)
    }

    return engine.acquire()?.hop
}

@MainActor
@Suite("engine")
struct EngineTests
{
    @Test func findsA4()
    {
        let engine = try! Engine(sampleRate: kRate)
        let suite = "TunerStateTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = Settings(defaults: defaults)
        settings.engine = engine

        let hop = try! play(engine, sine())
        #expect(hop?.found == true)
        #expect(hop?.note == 57)
        #expect(abs(hop?.cents ?? 100) < 1)
        #expect(engine.acquire() == nil)
    }

    // Covers AE11
    @Test func emptyNoteFilterStillShowsA4()
    {
        let engine = try! Engine(sampleRate: kRate)
        let suite = "TunerStateTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = Settings(defaults: defaults)
        settings.engine = engine
        settings.notes = Array(repeating: false, count: 12)
        settings.octaves = Array(repeating: false, count: 9)
        settings.noteFilter = true

        let hop = try! play(engine, sine())
        #expect(hop?.found == true)
        #expect(hop?.note == 57)
    }

    @Test func noteFilterForwards()
    {
        // A filter set to C only hides A4
        let engine = try! Engine(sampleRate: kRate)
        let suite = "TunerStateTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = Settings(defaults: defaults)
        settings.notes = (0 ..< 12).map { $0 == 0 }
        settings.noteFilter = true
        settings.engine = engine

        let hop = try! play(engine, sine())
        #expect(hop?.found == false)
    }

    // The per-block call and the threaded path give the same hops
    @Test func processBlockMatchesThreadedPath() throws
    {
        let samples = sine(seconds: 64 * 1024 / kRate)
        let block = 1024

        let direct = try Engine(sampleRate: kRate)
        var expected: [Hop] = []
        for start in stride(from: 0, to: samples.count - block + 1,
                            by: block)
        {
            let hop = try samples[start ..< start + block]
              .withUnsafeBufferPointer { try direct.processBlock($0) }
            expected.append(hop)
        }
        #expect(expected.count == 64)

        let threaded = try Engine(sampleRate: kRate)
        let hops = DispatchSemaphore(value: 0)
        let seen = HopLog()
        try threaded.start
        {
            if let hop = threaded.acquire()?.hop
            {
                seen.append(hop)
            }
            hops.signal()
        }
        defer { threaded.stop() }

        for start in stride(from: 0, to: samples.count - block + 1,
                            by: block)
        {
            samples[start ..< start + block].withUnsafeBufferPointer
            {
                threaded.push($0)
            }
            #expect(hops.wait(timeout: .now() + 10) == .success)
        }

        #expect(seen.hops == expected)
    }

    @Test func processBlockThrowsWhileRunning() throws
    {
        let engine = try Engine(sampleRate: kRate)
        try engine.start {}
        defer { engine.stop() }

        let block = [Float](repeating: 0, count: 1024)
        #expect(throws: EngineError.self)
        {
            try block.withUnsafeBufferPointer { try engine.processBlock($0) }
        }

        // The thread is still running: a second start is refused
        #expect(throws: EngineError.self) { try engine.start {} }
    }

    @Test func processBlockRefusesShortBlock() throws
    {
        let engine = try Engine(sampleRate: kRate)
        let block = [Float](repeating: 0, count: 100)
        #expect(throws: EngineError.self)
        {
            try block.withUnsafeBufferPointer { try engine.processBlock($0) }
        }
    }

    @Test func countsOverruns() throws
    {
        let engine = try Engine(sampleRate: kRate)
        #expect(engine.overruns == 0)

        // Nothing drains the ring, so an oversized push is dropped
        let huge = [Float](repeating: 0, count: 1 << 22)
        huge.withUnsafeBufferPointer { engine.push($0) }
        #expect(engine.overruns == 1)
    }
}

// The hops the callback saw, in order
private final class HopLog: @unchecked Sendable
{
    private let lock = NSLock()
    private var store: [Hop] = []

    // append
    func append(_ hop: Hop)
    {
        lock.lock()
        defer { lock.unlock() }
        store.append(hop)
    }

    // hops
    var hops: [Hop]
    {
        lock.lock()
        defer { lock.unlock() }
        return store
    }
}
