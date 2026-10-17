//
//  RingTests.swift
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
//  The sample ring, seen through the hops the analysis thread runs:
//  with the filter off, the newest 1024 scope samples of each hop are
//  the 1024 samples the thread read from the ring for it.

import Foundation
import Testing
import TunerCore

@Suite("core ring")
struct RingTests
{
    static let block = Int(kTunerBlock)
    static let ringLength = 32 * block

    // Every sample distinct and exact in a float
    static func ramp(_ count: Int) -> [Float]
    {
        return (0 ..< count).map { Float($0 % 65536) / 65536 }
    }

    // 10,000 random-sized pushes, wrapping the ring many times, reach
    // the thread exactly and in order
    @Test func randomPushesArriveInOrder() throws
    {
        var random = SplitMix(seed: 0x5eed)
        let sizes = (0 ..< 10_000).map { _ in Int(random.next() % 256) + 1 }
        let samples = RingTests.ramp(sizes.reduce(0, +))

        let running = try RunningEngine(recording: true)
        try running.start()

        var pushed = 0
        for size in sizes
        {
            // Stay well inside the ring, so nothing is dropped
            while pushed + size - running.hops * RingTests.block >
                RingTests.ringLength / 2
            {
                running.wait(hops: running.hops + 1)
            }

            running.push(samples, pushed ..< pushed + size)
            pushed += size
        }

        let hops = pushed / RingTests.block
        #expect(running.wait(hops: hops))
        #expect(TunerEngineOverruns(running.engine) == 0)

        let received = running.blocks.joined()
        let sent = samples.prefix(hops * RingTests.block).map(Double.init)
        #expect(Array(received) == sent)
    }

    // A push that does not fit is dropped whole and counted, and the
    // thread then reads only what was kept
    @Test func fullRingDropsAndCounts() throws
    {
        let samples = RingTests.ramp(34 * RingTests.block)
        let running = try RunningEngine(recording: true)

        // Fill the ring before the thread starts
        for hop in 0 ..< 32
        {
            running.push(samples, hop * RingTests.block ..< (hop + 1) * RingTests.block)
        }
        #expect(TunerEngineOverruns(running.engine) == 0)

        running.push(samples, 32 * RingTests.block ..< 33 * RingTests.block)
        #expect(TunerEngineOverruns(running.engine) == 1)

        running.push(samples, 33 * RingTests.block ..< 33 * RingTests.block + 1)
        #expect(TunerEngineOverruns(running.engine) == 2)

        try running.start()
        #expect(running.wait(hops: 32))

        let received = running.blocks.joined()
        let kept = samples.prefix(32 * RingTests.block).map(Double.init)
        #expect(Array(received) == kept)
    }

    // After an overrun the thread resets its phase history, and once
    // the gap has left the window the readings match the fixture again
    @Test func recoversAfterOverrun() throws
    {
        let fixture = try #require(Fixture.named("tone-00440.0"))
        let samples = try fixture.samples()
        let expected = try fixture.expected()
        let running = try RunningEngine(recording: true)

        // Blocks 0 to 31 fill the ring; 32 to 35 are dropped
        for hop in 0 ..< 36
        {
            running.push(samples, hop * RingTests.block ..< (hop + 1) * RingTests.block)
        }
        #expect(TunerEngineOverruns(running.engine) == 4)

        try running.start()
        #expect(running.wait(hops: 32))

        for hop in 36 ..< expected.count
        {
            running.push(samples, hop * RingTests.block ..< (hop + 1) * RingTests.block)
            #expect(running.wait(hops: hop - 3))
        }

        // Record k holds input block k for k under 32, and k + 4 after
        let records = running.records
        try #require(records.count == expected.count - 4)

        for block in 36 + Fixture.warmUpHops ..< expected.count
        {
            let problems = mismatches(records[block - 4], expected[block])
            #expect(problems.isEmpty, "block \(block): \(problems)")
        }
    }

    // A gap reached with hops still queued before it resets the phase
    // history at the first hop after the gap, as one reached with the
    // ring empty does, so the two runs read the same hop for hop
    @Test func resetsAtTheGap() throws
    {
        let fixture = try #require(Fixture.named("tone-00440.0"))
        let samples = try fixture.samples()
        let hops = try fixture.expected().count
        let block = RingTests.block

        // Stalled: the thread holds after block 0 while blocks 1 to 32
        // fill the ring and 33 and 34 are dropped behind them
        let stalled = try RunningEngine(recording: true)
        stalled.hold(after: 1)
        try stalled.start()

        stalled.push(samples, 0 ..< block)
        #expect(stalled.wait(hops: 1))
        for hop in 1 ..< 35
        {
            stalled.push(samples, hop * block ..< (hop + 1) * block)
        }
        #expect(TunerEngineOverruns(stalled.engine) == 2)
        stalled.release()

        // Caught up: the thread has read every block before the gap,
        // and a push too big for the ring leaves the gap in one place
        let caughtUp = try RunningEngine(recording: true)
        try caughtUp.start()

        for hop in 0 ..< 33
        {
            caughtUp.push(samples, hop * block ..< (hop + 1) * block)
            #expect(caughtUp.wait(hops: hop + 1))
        }
        caughtUp.push(samples, 0 ..< RingTests.ringLength + 1)
        #expect(TunerEngineOverruns(caughtUp.engine) == 1)

        for running in [stalled, caughtUp]
        {
            #expect(running.wait(hops: 33))
            for hop in 35 ..< hops
            {
                running.push(samples, hop * block ..< (hop + 1) * block)
                #expect(running.wait(hops: hop - 1))
            }
        }

        let expected = caughtUp.records
        let actual = stalled.records
        try #require(actual.count == hops - 2 && expected.count == hops - 2)

        for (k, (a, e)) in zip(actual, expected).enumerated()
        {
            #expect(identical(a, e), "record \(k): \(a) against \(e)")
        }
    }

    // identical: two hops of the same input read the same, bit for bit
    func identical(_ a: ActualHop, _ b: ActualHop) -> Bool
    {
        return a.found == b.found && a.note == b.note && a.count == b.count &&
            a.imax == b.imax &&
            [a.f, a.fr, a.c, a.max, a.sumsq].elementsEqual(
                [b.f, b.fr, b.c, b.max, b.sumsq]) { close($0, $1, relative: 0) }
    }
}

// SplitMix: a small seeded generator, so the sizes are the same on
// every run
struct SplitMix
{
    var state: UInt64

    // init(seed:)
    init(seed: UInt64)
    {
        state = seed
    }

    // next
    mutating func next() -> UInt64
    {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
