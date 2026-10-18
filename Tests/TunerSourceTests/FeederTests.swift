//
//  FeederTests.swift
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
//  The feeder on a fast clock, with blocks that carry their own count
//  in the first sample so order is easy to see.

import Foundation
import Testing
@testable import TunerSource
import TunerState

// A sound of numbered blocks, and what was pushed
private final class Counter: @unchecked Sendable
{
    private let lock = NSLock()
    private var made = 0
    private(set) var pushed: [Float] = []

    // limit is the number of blocks before the sound ends; nil never ends
    let limit: Int?

    // init
    init(limit: Int?)
    {
        self.limit = limit
    }

    // fill
    func fill(_ block: UnsafeMutableBufferPointer<Float>) -> Bool
    {
        lock.lock()
        defer { lock.unlock() }

        if let limit, made >= limit
        {
            return false
        }

        block[0] = Float(made)
        made += 1
        return true
    }

    // push
    func push(_ block: UnsafeBufferPointer<Float>)
    {
        lock.lock()
        defer { lock.unlock() }
        pushed.append(block[0])
    }

    // count
    var count: Int
    {
        lock.lock()
        defer { lock.unlock() }
        return pushed.count
    }
}

// One block a millisecond
private let kFastRate = 1_024_000.0

@Suite("feeder")
struct FeederTests
{
    @Test func deliversEveryBlockInOrderAndEndsAtTheEnd()
    {
        let counter = Counter(limit: 25)
        let feeder = Feeder(rate: kFastRate, fill: counter.fill,
                            push: counter.push)

        feeder.start()
        feeder.wait()
        feeder.stop()

        #expect(counter.pushed == (0 ..< 25).map { Float($0) })
        #expect(feeder.finished)
    }

    @Test func stopReturnsOnlyAfterThePushesEnd() async throws
    {
        let counter = Counter(limit: nil)
        let feeder = Feeder(rate: kFastRate, fill: counter.fill,
                            push: counter.push)

        feeder.start()
        while counter.count < 5
        {
            try await Task.sleep(for: .milliseconds(1))
        }
        feeder.stop()

        let stopped = counter.count
        try await Task.sleep(for: .milliseconds(30))
        #expect(counter.count == stopped)
        #expect(!feeder.finished)
    }

    @Test func resumesAtThePlayhead() async throws
    {
        let counter = Counter(limit: nil)
        let feeder = Feeder(rate: kFastRate, fill: counter.fill,
                            push: counter.push)

        feeder.start()
        while counter.count < 5
        {
            try await Task.sleep(for: .milliseconds(1))
        }
        feeder.stop()
        let first = counter.count

        feeder.start()
        while counter.count < first + 5
        {
            try await Task.sleep(for: .milliseconds(1))
        }
        feeder.stop()

        // No block repeated and none skipped across the pause
        let blocks = counter.pushed
        #expect(blocks == (0 ..< blocks.count).map { Float($0) })
    }

    @Test func stopTwiceAndStopBeforeStartAreHarmless()
    {
        let counter = Counter(limit: nil)
        let feeder = Feeder(rate: kFastRate, fill: counter.fill,
                            push: counter.push)

        feeder.stop()
        feeder.start()
        feeder.stop()
        feeder.stop()
    }

    @Test(.timeLimit(.minutes(1)))
    func aDroppedFeederStopsItsThread() async throws
    {
        let counter = Counter(limit: nil)
        do
        {
            let feeder = Feeder(rate: kFastRate, fill: counter.fill,
                                push: counter.push)
            feeder.start()
            while counter.count < 5
            {
                try await Task.sleep(for: .milliseconds(1))
            }

            // A use after the loop keeps the feeder from being released
            // early
            #expect(!feeder.finished)
        }

        // The deinit joined the thread, so nothing more arrives
        let stopped = counter.count
        try await Task.sleep(for: .milliseconds(30))
        #expect(counter.count == stopped)
    }

    @Test func keepsTimeAgainstTheClock() async throws
    {
        // 50 blocks at 2 ms each take about 100 ms, not 100 ms plus the
        // sum of every late wake-up
        let counter = Counter(limit: 50)
        let feeder = Feeder(rate: 512_000, fill: counter.fill,
                            push: counter.push)

        let begun = ProcessInfo.processInfo.systemUptime
        feeder.start()
        feeder.wait()
        feeder.stop()
        let took = ProcessInfo.processInfo.systemUptime - begun

        #expect(counter.count == 50)
        #expect(took > 0.09)
        #expect(took < 0.25)
    }
}
