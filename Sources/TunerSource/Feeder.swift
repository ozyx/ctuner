//
//  Feeder.swift
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
//  The real-time feeder: one thread that hands a block to its push
//  closure each block-time, against an absolute deadline so pacing
//  errors do not accumulate. stop returns only once the thread has
//  exited, so nothing pushes after it. The source behind fill keeps its
//  own playhead, so a stop and a start resume where the sound left off.
//  The thread holds the work, not the feeder, so a feeder that is
//  dropped without a stop still stops in its deinit.

import Foundation
import TunerState

public final class Feeder: @unchecked Sendable
{
    // What the thread holds: the blocks' source and sink and the state
    // they share with the feeder
    private final class Work: @unchecked Sendable
    {
        let interval: Double
        let fill: (UnsafeMutableBufferPointer<Float>) -> Bool
        let push: (UnsafeBufferPointer<Float>) -> Void

        // The one buffer every block goes through
        let buffer: UnsafeMutableBufferPointer<Float>

        let lock = NSLock()
        var run: Run?
        var ended = false

        // init
        init(interval: Double,
             fill: @escaping (UnsafeMutableBufferPointer<Float>) -> Bool,
             push: @escaping (UnsafeBufferPointer<Float>) -> Void)
        {
            self.interval = interval
            self.fill = fill
            self.push = push
            buffer = .allocate(capacity: Engine.blockSize)
            buffer.initialize(repeating: 0)
        }

        deinit
        {
            buffer.deallocate()
        }

        // cancelled
        func cancelled(_ run: Run) -> Bool
        {
            lock.lock()
            defer { lock.unlock() }
            return run.cancelled
        }

        // feed: the thread body
        func feed(_ run: Run)
        {
            defer { run.exited.signal() }

            let start = ProcessInfo.processInfo.systemUptime
            var count = 0

            while !cancelled(run)
            {
                let deadline = start + Double(count) * interval
                let wait = deadline - ProcessInfo.processInfo.systemUptime
                if wait > 0
                {
                    Thread.sleep(forTimeInterval: wait)
                    if cancelled(run)
                    {
                        break
                    }
                }

                guard fill(buffer) else
                {
                    lock.lock()
                    ended = true
                    lock.unlock()
                    break
                }

                push(UnsafeBufferPointer(buffer))
                count += 1
            }
        }
    }

    // One run of the thread
    private final class Run: @unchecked Sendable
    {
        var cancelled = false
        let exited = DispatchSemaphore(value: 0)
    }

    private let work: Work

    // init: fill writes the next block and returns false at the end of
    // the sound; push takes each block
    public init(rate: Double,
                fill: @escaping (UnsafeMutableBufferPointer<Float>) -> Bool,
                push: @escaping (UnsafeBufferPointer<Float>) -> Void)
    {
        work = Work(interval: Double(Engine.blockSize) / rate,
                    fill: fill, push: push)
    }

    deinit
    {
        stop()
    }

    // finished: the sound ended; a stop alone does not set it
    public var finished: Bool
    {
        work.lock.lock()
        defer { work.lock.unlock() }
        return work.ended
    }

    // start: no effect while running or after the end
    public func start()
    {
        work.lock.lock()
        defer { work.lock.unlock() }
        guard work.run == nil, !work.ended else
        {
            return
        }

        let run = Run()
        work.run = run

        let work = self.work
        let thread = Thread { work.feed(run) }
        thread.name = "Feeder"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    // stop: returns once the thread has exited
    public func stop()
    {
        work.lock.lock()
        let run = work.run
        run?.cancelled = true
        work.lock.unlock()

        // Signalled again so that a second stop does not wait forever
        run?.exited.wait()
        run?.exited.signal()

        work.lock.lock()
        if work.run === run
        {
            work.run = nil
        }
        work.lock.unlock()
    }

    // wait: until the sound ends or the feeder is stopped
    public func wait()
    {
        while true
        {
            work.lock.lock()
            let running = (work.run.map { !$0.cancelled } ?? false)
              && !work.ended
            work.lock.unlock()

            if !running
            {
                return
            }
            Thread.sleep(forTimeInterval: work.interval)
        }
    }
}
