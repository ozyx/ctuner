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
}
