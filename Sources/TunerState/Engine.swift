//
//  Engine.swift
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
//  The engine wrapper: owns one core handle, starts and stops its
//  analysis thread, acquires snapshots for the one consumer and
//  forwards settings to the core's configuration atomics (KTD6). The
//  temperament table is fixed at create; transpose never reaches here.

import Foundation
import TunerCore

// statusText
public func statusText(_ status: TunerStatus) -> String
{
    return String(cString: TunerStatusString(status))
}

// A core call that failed
public struct EngineError: Error, Sendable
{
    public let message: String

    // init
    init(_ status: TunerStatus)
    {
        message = statusText(status)
    }
}

// The newest published hop and the arrays the scope and spectrum draw.
// The buffers point into the core's slot and are valid only until the
// next acquire, so a view uses them within the turn and keeps nothing.
public struct Snapshot
{
    public let hop: Hop
    public let sampleRate: Double
    public let binWidth: Double
    public let scope: UnsafeBufferPointer<Double>
    public let spectrum: UnsafeBufferPointer<Double>
}

public final class Engine: @unchecked Sendable
{
    public let sampleRate: Double

    // The core handle, for the capture layer to push into
    public let handle: OpaquePointer

    // Set before the thread starts and cleared after it stops
    private var onHop: (@Sendable () -> Void)?

    // init(sampleRate:temperaments:)
    public init(sampleRate: Double,
                temperaments: [Double] = Temperaments.flattened)
      throws(EngineError)
    {
        var engine: OpaquePointer?
        let status = temperaments.withUnsafeBufferPointer
        {
            TunerEngineCreate(sampleRate, $0.baseAddress, &engine)
        }

        guard status == kTunerStatusOK, let engine else
        {
            throw EngineError(status)
        }

        self.sampleRate = sampleRate
        handle = engine
    }

    deinit
    {
        TunerEngineDestroy(handle)
    }

    // start: run the analysis thread; onHop runs on that thread after
    // each hop is published
    public func start(onHop: @escaping @Sendable () -> Void)
      throws(EngineError)
    {
        self.onHop = onHop

        let callback: TunerHopCallback =
        {
            Unmanaged<Engine>.fromOpaque($0!).takeUnretainedValue().onHop?()
        }

        let status = TunerEngineStart(handle, callback,
                                      Unmanaged.passUnretained(self)
                                        .toOpaque())
        if status != kTunerStatusOK
        {
            self.onHop = nil
            throw EngineError(status)
        }
    }

    // stop: returns once the analysis thread has exited
    public func stop()
    {
        TunerEngineStop(handle)
        onHop = nil
    }

    // push: samples into the ring, from the one producer
    public func push(_ samples: UnsafeBufferPointer<Float>)
    {
        TunerEnginePush(handle, samples.baseAddress, Int32(samples.count))
    }

    // acquire: the newest snapshot if it is newer than the last one
    // acquired; from one consumer only
    public func acquire() -> Snapshot?
    {
        var snapshot = TunerSnapshot()
        guard TunerEngineAcquire(handle, &snapshot) else
        {
            return nil
        }

        return Snapshot(hop: Hop(snapshot),
                        sampleRate: snapshot.sampleRate,
                        binWidth: snapshot.binWidth,
                        scope: UnsafeBufferPointer(start: snapshot.scope,
                                                   count:
                                                     Int(kTunerScopeLength)),
                        spectrum: UnsafeBufferPointer(start:
                                                        snapshot.spectrum,
                                                      count:
                                                        Int(kTunerRange)))
    }

    // setReference
    public func setReference(_ reference: Double)
    {
        TunerEngineSetReference(handle, reference)
    }

    // setTemperament
    public func setTemperament(_ temperament: Int)
    {
        TunerEngineSetTemperament(handle, Int32(temperament))
    }

    // setKey
    public func setKey(_ key: Int)
    {
        TunerEngineSetKey(handle, Int32(key))
    }

    // setFilter
    public func setFilter(_ filter: Bool)
    {
        TunerEngineSetFilter(handle, filter)
    }

    // setDownsample
    public func setDownsample(_ downsample: Bool)
    {
        TunerEngineSetDownsample(handle, downsample)
    }

    // setFundamental
    public func setFundamental(_ fundamental: Bool)
    {
        TunerEngineSetFundamental(handle, fundamental)
    }

    // setNoteFilter
    public func setNoteFilter(_ noteFilter: Bool)
    {
        TunerEngineSetNoteFilter(handle, noteFilter)
    }

    // setNoteMask: 12 bits from C
    public func setNoteMask(_ notes: UInt32)
    {
        TunerEngineSetNoteMask(handle, notes)
    }

    // setOctaveMask: 9 bits from octave 0
    public func setOctaveMask(_ octaves: UInt32)
    {
        TunerEngineSetOctaveMask(handle, octaves)
    }
}

extension Hop
{
    // init: the display model's input from a core snapshot
    init(_ snapshot: TunerSnapshot)
    {
        let count = max(0, min(Int(snapshot.count), Int(kTunerMaxima)))
        let maxima = UnsafeBufferPointer(start: snapshot.maxima, count: count)
        var reeds: [Reed] = []

        // Today's multiple-reed rows: skip a maximum with no note or
        // with cents that are not a number
        for maximum in maxima where maximum.n >= 0
        {
            let cents = -1200 * log2(maximum.fr / maximum.f)
            if cents.isFinite
            {
                reeds.append(Reed(note: Int(maximum.n), cents: cents,
                                  frequency: maximum.f,
                                  reference: maximum.fr))
            }
        }

        self.init(sequence: snapshot.sequence, found: snapshot.found,
                  note: Int(snapshot.note), cents: snapshot.deviation * 100,
                  frequency: snapshot.frequency,
                  reference: snapshot.reference, lower: snapshot.lower,
                  upper: snapshot.upper, reeds: reeds)
    }
}
