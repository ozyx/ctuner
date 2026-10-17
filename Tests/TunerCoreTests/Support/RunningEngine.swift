//
//  RunningEngine.swift
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
//  An engine on its own analysis thread, as the app runs it. The hop
//  callback counts hops; when recording, it is also the one consumer
//  and copies out each hop just published, so a test sees every hop.

import Foundation
import Testing
import TunerCore

final class RunningEngine: @unchecked Sendable
{
    let engine: OpaquePointer
    let recording: Bool

    private let condition = NSCondition()
    private var hopCount = 0
    private var hopRecords: [ActualHop] = []
    private var hopBlocks: [[Double]] = []
    private var hopThreads: Set<UInt64> = []

    // init(rate:recording:)
    init(rate: Double = 44100, recording: Bool = false) throws
    {
        engine = try createEngine(rate: rate)
        self.recording = recording
    }

    deinit
    {
        TunerEngineDestroy(engine)
    }

    // start
    func start() throws
    {
        let callback: TunerHopCallback =
        {
            Unmanaged<RunningEngine>.fromOpaque($0!).takeUnretainedValue().hop()
        }

        let status = TunerEngineStart(engine, callback,
                                      Unmanaged.passUnretained(self).toOpaque())
        try #require(status == kTunerStatusOK)
    }

    // push: one push of the samples in a range
    func push(_ samples: [Float], _ range: Range<Int>)
    {
        samples[range].withUnsafeBufferPointer
        {
            TunerEnginePush(engine, $0.baseAddress, Int32($0.count))
        }
    }

    // hop: on the analysis thread, after each publish
    private func hop()
    {
        var thread: UInt64 = 0
        pthread_threadid_np(nil, &thread)

        var record: ActualHop?
        var block: [Double] = []

        if recording
        {
            var snapshot = TunerSnapshot()
            TunerEngineAcquire(engine, &snapshot)
            record = ActualHop(snapshot: snapshot)

            let scope = UnsafeBufferPointer(start: snapshot.scope,
                                            count: Int(kTunerScopeLength))
            block = Array(scope.suffix(Int(kTunerBlock)))
        }

        condition.lock()
        hopCount += 1
        hopThreads.insert(thread)
        if let record
        {
            hopRecords.append(record)
            hopBlocks.append(block)
        }
        condition.broadcast()
        condition.unlock()
    }

    // wait: until at least count hops have run; false on timeout
    @discardableResult
    func wait(hops count: Int, seconds: Double = 60) -> Bool
    {
        let deadline = Date(timeIntervalSinceNow: seconds)

        condition.lock()
        defer { condition.unlock() }

        while hopCount < count
        {
            if !condition.wait(until: deadline)
            {
                return false
            }
        }

        return true
    }

    var hops: Int { locked { hopCount } }
    var records: [ActualHop] { locked { hopRecords } }
    var blocks: [[Double]] { locked { hopBlocks } }
    var threads: Set<UInt64> { locked { hopThreads } }

    // locked
    private func locked<T>(_ body: () -> T) -> T
    {
        condition.lock()
        defer { condition.unlock() }
        return body()
    }
}

// currentThread: this thread's id, as the hop callback records it
func currentThread() -> UInt64
{
    var thread: UInt64 = 0
    pthread_threadid_np(nil, &thread)
    return thread
}
