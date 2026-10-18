//
//  HeadlessRun.swift
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
//  A source and settings run through the engine with no window and no
//  audio device. Fast mode analyses every block on the calling thread
//  as quickly as it can; paced mode runs the analysis thread and feeds
//  it in real time, as the app does.

import Foundation
import TunerState

// The engine settings a run applies; the defaults are the app's. A run
// never builds a Settings, which would read and write a defaults domain.
public struct RunSettings: Equatable, Sendable
{
    // Every note and every octave, the widths Settings uses
    static let allNotes = UInt32((1 << Settings.noteCount) - 1)
    static let allOctaves = UInt32((1 << Settings.octaveCount) - 1)

    public var reference = Notes.reference
    public var temperament = Temperaments.equal
    public var key = 0
    public var filter = false
    public var downsample = false
    public var fundamental = false
    public var noteFilter = false
    public var notes: UInt32 = RunSettings.allNotes
    public var octaves: UInt32 = RunSettings.allOctaves

    // init
    public init() {}

    // apply: through the engine's setters, as Settings does; an empty
    // mask shows everything, as it does there
    func apply(to engine: Engine)
    {
        engine.setReference(reference)
        engine.setTemperament(temperament)
        engine.setKey(key)
        engine.setFilter(filter)
        engine.setDownsample(downsample)
        engine.setFundamental(fundamental)
        engine.setNoteFilter(noteFilter)
        engine.setNoteMask(notes == 0 ? RunSettings.allNotes : notes)
        engine.setOctaveMask(octaves == 0 ? RunSettings.allOctaves : octaves)
    }
}

// The blocks of a source, one at a time. One thread uses it at a time.
public final class SampleStream: @unchecked Sendable
{
    public let rate: Double

    // nil is endless
    public let blockCount: Int?

    private enum Kind
    {
        case tone(Tone)
        case file(FileSource)
        case loop(LoopingReader)
    }

    private var kind: Kind
    private var block = 0

    // open: a description and the settings a note name needs.
    // defaultSeconds applies to a tone that gives no secs; a file plays
    // once unless loop is set.
    public init(_ spec: SourceSpec, settings: RunSettings = RunSettings(),
                defaultSeconds: Double? = nil, loop: Bool = false)
      throws(SourceError)
    {
        switch spec
        {
        case .tone(var tone):
            if tone.seconds == nil
            {
                tone.seconds = defaultSeconds
            }

            let resolved = try Tone(tone, reference: settings.reference,
                                    temperament: settings.temperament,
                                    key: settings.key)
            rate = resolved.rate
            blockCount = resolved.count.map { $0 / Engine.blockSize }
            kind = .tone(resolved)

        case .file(let path):
            let file = try FileSource(path: path)
            rate = file.rate

            if loop
            {
                blockCount = nil
                kind = .loop(LoopingReader(file))
            }
            else
            {
                blockCount = file.blockCount
                kind = .file(file)
            }
        }
    }

    // next: fill the block; false once the source has ended
    public func next(into out: UnsafeMutableBufferPointer<Float>) -> Bool
    {
        if let blockCount, block >= blockCount
        {
            return false
        }

        switch kind
        {
        case .tone(let tone):
            tone.fill(out, from: block * Engine.blockSize)

        case .file(let file):
            for (i, sample) in file.block(block).enumerated()
            {
                out[i] = sample
            }

        case .loop(var reader):
            reader.read(into: out)
            kind = .loop(reader)
        }

        block += 1
        return true
    }
}

// What a run produced
public struct RunResult: Sendable
{
    public var hops: [Hop]
    public var overruns: UInt64
}

public enum HeadlessRun
{
    // run: every hop goes to onHop as it is read, with the overrun count
    // in paced mode; onHop may be called on another thread, one call at
    // a time
    public static func run(_ stream: SampleStream,
                           settings: RunSettings = RunSettings(),
                           paced: Bool = false,
                           onHop: @escaping @Sendable (Hop, UInt64?) -> Void
                             = { _, _ in }) throws -> RunResult
    {
        guard let total = stream.blockCount else
        {
            throw SourceError("a run needs a source with an end")
        }

        let engine = try Engine(sampleRate: stream.rate)
        settings.apply(to: engine)

        return paced
          ? try runPaced(stream, engine, total: total, onHop: onHop)
          : try runFast(stream, engine, total: total, onHop: onHop)
    }

    // runFast: the same hops the threaded path gives, as fast as the
    // analysis goes
    private static func runFast(_ stream: SampleStream, _ engine: Engine,
                                total: Int,
                                onHop: (Hop, UInt64?) -> Void) throws
      -> RunResult
    {
        var block = [Float](repeating: 0, count: Engine.blockSize)
        var hops: [Hop] = []
        hops.reserveCapacity(total)

        while block.withUnsafeMutableBufferPointer({ stream.next(into: $0) })
        {
            let hop = try block.withUnsafeBufferPointer
            {
                try engine.processBlock($0)
            }
            hops.append(hop)
            onHop(hop, nil)
        }

        return RunResult(hops: hops, overruns: 0)
    }

    // The hops the analysis thread read, in order
    private final class Collector: @unchecked Sendable
    {
        private let lock = NSLock()
        private(set) var hops: [Hop] = []

        // add
        func add(_ hop: Hop)
        {
            lock.lock()
            defer { lock.unlock() }
            hops.append(hop)
        }

        // last: the sequence of the newest hop read
        var last: UInt64
        {
            lock.lock()
            defer { lock.unlock() }
            return hops.last?.sequence ?? 0
        }
    }

    // runPaced: hops are read inside the callback, as the app reads
    // them, so a hop the analysis skipped shows as a gap in the numbers
    private static func runPaced(_ stream: SampleStream, _ engine: Engine,
                                 total: Int,
                                 onHop: @escaping @Sendable (Hop, UInt64?)
                                   -> Void) throws -> RunResult
    {
        let collector = Collector()
        try engine.start
        {
            if let hop = engine.acquire()?.hop
            {
                collector.add(hop)
                onHop(hop, engine.overruns)
            }
        }
        defer { engine.stop() }

        let feeder = Feeder(rate: stream.rate,
                            fill: { stream.next(into: $0) },
                            push: { engine.push($0) })
        feeder.start()
        feeder.wait()
        feeder.stop()

        // The last block's hop lands a moment after its push
        let patience = ProcessInfo.processInfo.systemUptime + 2
        while collector.last < UInt64(total),
              ProcessInfo.processInfo.systemUptime < patience
        {
            Thread.sleep(forTimeInterval: 0.005)
        }

        return RunResult(hops: collector.hops, overruns: engine.overruns)
    }
}
