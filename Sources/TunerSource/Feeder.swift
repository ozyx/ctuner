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

import Foundation
import TunerState

public final class Feeder: @unchecked Sendable
{
    // One run of the thread
    private final class Run: @unchecked Sendable
    {
        var cancelled = false
        let exited = DispatchSemaphore(value: 0)
    }

    private let interval: Double
    private let fill: (UnsafeMutableBufferPointer<Float>) -> Bool
    private let push: (UnsafeBufferPointer<Float>) -> Void

    // The one buffer every block goes through
    private let buffer: UnsafeMutableBufferPointer<Float>

    private let lock = NSLock()
    private var run: Run?
    private var ended = false

    // init: fill writes the next block and returns false at the end of
    // the sound; push takes each block
    public init(rate: Double,
                fill: @escaping (UnsafeMutableBufferPointer<Float>) -> Bool,
                push: @escaping (UnsafeBufferPointer<Float>) -> Void)
    {
        interval = Double(Engine.blockSize) / rate
        self.fill = fill
        self.push = push
        buffer = .allocate(capacity: Engine.blockSize)
        buffer.initialize(repeating: 0)
    }

    deinit
    {
        stop()
        buffer.deallocate()
    }

    // finished: the sound ended; a stop alone does not set it
    public var finished: Bool
    {
        lock.lock()
        defer { lock.unlock() }
        return ended
    }

    // start: no effect while running or after the end
    public func start()
    {
        lock.lock()
        defer { lock.unlock() }
        guard run == nil, !ended else
        {
            return
        }

        let run = Run()
        self.run = run

        let thread = Thread { [self] in feed(run) }
        thread.name = "Feeder"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    // stop: returns once the thread has exited
    public func stop()
    {
        lock.lock()
        let run = self.run
        run?.cancelled = true
        lock.unlock()

        // Signalled again so that a second stop does not wait forever
        run?.exited.wait()
        run?.exited.signal()

        lock.lock()
        if self.run === run
        {
            self.run = nil
        }
        lock.unlock()
    }

    // wait: until the sound ends or the feeder is stopped
    public func wait()
    {
        while true
        {
            lock.lock()
            let running = run != nil && !(run!.cancelled) && !ended
            lock.unlock()

            if !running
            {
                return
            }
            Thread.sleep(forTimeInterval: interval)
        }
    }

    // cancelled
    private func cancelled(_ run: Run) -> Bool
    {
        lock.lock()
        defer { lock.unlock() }
        return run.cancelled
    }

    // feed: the thread body
    private func feed(_ run: Run)
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
