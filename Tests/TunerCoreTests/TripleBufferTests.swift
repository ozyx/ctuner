//
//  TripleBufferTests.swift
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
//  The triple buffer under a reader that never stops: every slot it
//  acquires is one whole hop, and sequence numbers never go back.

import Foundation
import Testing
import TunerCore

@Suite("core triple buffer")
struct TripleBufferTests
{
    static let hops = 100_000
    static let block = Int(kTunerBlock)
    static let blocksInScope = Int(kTunerScopeLength) / block

    // The value every sample of input block k carries
    static func level(_ k: Int) -> Float
    {
        return Float(k % 4096 + 1) / 4096
    }

    @Test func readerOnlySeesWholeSlots() throws
    {
        let running = try RunningEngine()
        try running.start()

        // The writer side: a producer thread feeding constant blocks,
        // kept a few hops ahead of the analysis thread
        let producer = Thread
        {
            var block = [Float](repeating: 0, count: TripleBufferTests.block)

            for k in 0 ..< TripleBufferTests.hops
            {
                while k - running.hops > 8
                {
                    running.wait(hops: k - 8)
                }

                for i in block.indices
                {
                    block[i] = TripleBufferTests.level(k)
                }
                running.push(block, block.indices)
            }
        }
        producer.start()

        // The reader side: this thread, acquiring as fast as it can
        var snapshot = TunerSnapshot()
        var last: UInt64 = 0
        var acquired = 0
        var torn = 0
        var backwards = 0

        while last < UInt64(TripleBufferTests.hops)
        {
            let fresh = TunerEngineAcquire(running.engine, &snapshot)

            if snapshot.sequence < last || (fresh && snapshot.sequence == last)
            {
                backwards += 1
            }

            if fresh
            {
                acquired += 1
                if !whole(snapshot)
                {
                    torn += 1
                }
            }

            last = snapshot.sequence
        }

        #expect(torn == 0)
        #expect(backwards == 0)
        #expect(acquired > 0)
    }

    // whole: the scope holds the blocks that end at the slot's own hop
    func whole(_ snapshot: TunerSnapshot) -> Bool
    {
        // Hop s ran input block s - 1
        let newest = Int(snapshot.sequence) - 1
        let scope = UnsafeBufferPointer(start: snapshot.scope,
                                        count: Int(kTunerScopeLength))

        for b in 0 ..< TripleBufferTests.blocksInScope
        {
            let k = newest - (TripleBufferTests.blocksInScope - 1 - b)
            let value = k < 0 ? 0.0 : Double(TripleBufferTests.level(k))

            for i in b * TripleBufferTests.block ..< (b + 1) * TripleBufferTests.block
            {
                if scope[i] != value
                {
                    return false
                }
            }
        }

        return true
    }
}
