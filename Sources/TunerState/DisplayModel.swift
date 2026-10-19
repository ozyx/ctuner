//
//  DisplayModel.swift
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
//  The display state machine (KTD10): blank, live, stale and locked,
//  fed one hop at a time with the time it arrived. It owns the readout
//  cadence, the stale timer, the meter's smoother and the trace refresh
//  cadence that used to be counters in the engine, so lock lives in the
//  app (R7). Under lock the machine keeps running underneath; the views
//  see a held copy, and unlocking shows wherever the live machine is.

import Foundation
import Observation

// One hop of analysis, as the display model takes it
public struct Hop: Equatable, Sendable
{
    // Counts from 1 for each engine
    public var sequence: UInt64
    public var found: Bool

    // Note number, 57 is A4
    public var note: Int
    public var cents: Double
    public var frequency: Double
    public var reference: Double

    // The spectrum's lower and upper marker frequencies in Hz
    public var lower: Double
    public var upper: Double
    public var reeds: [Reed]

    // init
    public init(sequence: UInt64, found: Bool, note: Int = 0,
                cents: Double = 0, frequency: Double = 0,
                reference: Double = 0, lower: Double = 0, upper: Double = 0,
                reeds: [Reed] = [])
    {
        self.sequence = sequence
        self.found = found
        self.note = note
        self.cents = cents
        self.frequency = frequency
        self.reference = reference
        self.lower = lower
        self.upper = upper
        self.reeds = reeds
    }
}

// The spectrum markers, in Hz
public struct Markers: Equatable, Sendable
{
    public var frequency: Double
    public var reference: Double
    public var lower: Double
    public var upper: Double

    // One per multiple-reed row, with the cents the spectrum labels
    public var reeds: [Reed]

    // The reeds' frequencies
    public var maxima: [Double]
    {
        return reeds.map { $0.frequency }
    }
}

// What the readout shows
public enum DisplayPhase: Sendable
{
    // Nothing found yet
    case blank

    // A note is playing
    case live

    // The last reading, greyed, after 1.5 s without a note
    case stale
}

@MainActor
@Observable
public final class DisplayModel
{
    // A reading greys this long after the last found hop
    public nonisolated static let staleAfter = 1.5

    // The readout text updates at most this often while a note holds
    public nonisolated static let textInterval = 0.1

    // The meter smoother's time constant
    public nonisolated static let meterTimeConstant = 0.08

    // The meter shows in tune within this many cents, inclusive
    public nonisolated static let inTuneCents = 5.0

    // The strobe cents move only by at least this many cents, the change
    // that alters the layer animation's speed by StrobeMotion's minimum
    public nonisolated static let strobeDeadBand =
      StrobeMotion.minimumChange / StrobeMotion.pointsPerSecondPerCent

    // The trace refresh fires every this many hops by default
    public nonisolated static let defaultTraceInterval: UInt64 = 16

    // Everything the views show; the live machine has one and lock
    // holds a copy
    private struct Shown: Equatable
    {
        var reading: Reading?
        var stale = false
        var strobe = 0.0
        var meter = 0.0
        var markers: Markers?
    }

    // Outputs: what the views read, held while locked
    public private(set) var reading: Reading?
    public private(set) var isStale = false
    public private(set) var strobeCents = 0.0
    public private(set) var meterCents = 0.0
    public private(set) var markers: Markers?

    // Increments whenever the readout or staff should redraw: new text,
    // a stale, lock or reset change
    public private(set) var readoutTick = 0

    // True for a hop on which the scope and spectrum should redraw
    public private(set) var traceRefresh = false

    // Display lock (R7); starts off on every launch
    public var isLocked = false
    {
        didSet
        {
            if isLocked != oldValue
            {
                held = isLocked ? live : nil
                publish(force: true)
            }
        }
    }

    public var phase: DisplayPhase
    {
        return (reading == nil) ? .blank : isStale ? .stale : .live
    }

    public var inTune: Bool
    {
        return DisplayModel.inTune(meterCents)
    }

    @ObservationIgnored private let traceInterval: UInt64
    @ObservationIgnored private var live = Shown()
    @ObservationIgnored private var held: Shown?
    @ObservationIgnored private var target = 0.0
    @ObservationIgnored private var lastFound = -Double.infinity
    @ObservationIgnored private var lastText = -Double.infinity
    @ObservationIgnored private var lastTime: Double?
    @ObservationIgnored private var lastSequence: UInt64 = 0

    // init
    public init(traceInterval: UInt64 = DisplayModel.defaultTraceInterval)
    {
        self.traceInterval = traceInterval
    }

    // inTune
    public nonisolated static func inTune(_ cents: Double) -> Bool
    {
        return abs(cents) <= inTuneCents
    }

    // update: one hop, with the time in seconds it arrived
    public func update(_ hop: Hop, now: Double)
    {
        let refresh = hop.sequence / traceInterval !=
          lastSequence / traceInterval
        lastSequence = hop.sequence

        let interval = lastTime.map { max(0, now - $0) } ?? 0
        lastTime = now

        if hop.found
        {
            lastFound = now
            target = hop.cents
            live.strobe = hop.cents
            live.markers = Markers(frequency: hop.frequency,
                                   reference: hop.reference,
                                   lower: hop.lower, upper: hop.upper,
                                   reeds: hop.reeds)

            // The text at once after blank or stale, then every 100 ms
            if live.reading == nil || live.stale ||
                 now - lastText >= DisplayModel.textInterval
            {
                live.reading = Reading(note: hop.note, cents: hop.cents,
                                       frequency: hop.frequency,
                                       reference: hop.reference,
                                       reeds: hop.reeds)
                live.stale = false
                lastText = now
            }
        }

        // Grey the reading and stop the strobe
        else if live.reading != nil && !live.stale &&
                  now - lastFound >= DisplayModel.staleAfter
        {
            live.stale = true
            live.strobe = 0
            live.markers = nil
        }

        // The meter follows the last found cents while live
        if live.reading != nil && !live.stale
        {
            let factor = 1 - exp(-interval / DisplayModel.meterTimeConstant)
            live.meter += (target - live.meter) * factor
        }

        if traceRefresh != refresh
        {
            traceRefresh = refresh
        }

        publish(force: false)
    }

    // reset: a device change or capture restart; lock turns off
    public func reset()
    {
        live = Shown()
        held = nil
        target = 0
        lastFound = -Double.infinity
        lastText = -Double.infinity
        lastTime = nil
        lastSequence = 0

        if traceRefresh
        {
            traceRefresh = false
        }

        if isLocked
        {
            isLocked = false
        }

        publish(force: true)
    }

    // copyLine: the current or held primary line; nothing in blank
    public func copyLine(transpose: Int) -> String?
    {
        return reading?.copyLine(transpose: transpose)
    }

    // staffNote: the note the readout names and the staff draws
    public func staffNote(transpose: Int) -> DisplayNote?
    {
        return reading?.displayNote(transpose: transpose)
    }

    // publish: copy what the views see into the outputs, setting only
    // what changed so an observer redraws only for its own data
    private func publish(force: Bool)
    {
        let shown = held ?? live
        var redraw = force

        if reading != shown.reading
        {
            reading = shown.reading
            redraw = true
        }

        if isStale != shown.stale
        {
            isStale = shown.stale
            redraw = true
        }

        // A change too small to alter the strobe's speed is held, so a
        // steady note does not run the strobe's body on every hop; a
        // forced publish, a stop to zero and a change of look are always
        // exact
        if force || (shown.strobe == 0 && strobeCents != 0) ||
             abs(shown.strobe - strobeCents) >= DisplayModel.strobeDeadBand ||
             StrobeMotion.look(cents: shown.strobe) !=
               StrobeMotion.look(cents: strobeCents)
        {
            if strobeCents != shown.strobe
            {
                strobeCents = shown.strobe
            }
        }

        if meterCents != shown.meter
        {
            meterCents = shown.meter
        }

        if markers != shown.markers
        {
            markers = shown.markers
        }

        if redraw
        {
            readoutTick += 1
        }
    }
}
