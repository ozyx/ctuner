//
//  DisplayModelTests.swift
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

import Foundation
import Testing
import TunerState

// One hop's length at 44100 Hz
private let kHop = 1024.0 / 44100.0

// A4 at +3 cents, with its one reed
private let kA4 = Hop(sequence: 0, found: true, note: 57, cents: 3,
                      frequency: 440.76, reference: 440, lower: 425,
                      upper: 455,
                      reeds: [Reed(note: 57, cents: 3, frequency: 440.76,
                                   reference: 440)])

// C5 at -10 cents, with its one reed
private let kC5 = Hop(sequence: 0, found: true, note: 60, cents: -10,
                      frequency: 520.24, reference: 523.25, lower: 505,
                      upper: 541,
                      reeds: [Reed(note: 60, cents: -10, frequency: 520.24,
                                   reference: 523.25)])

// A hop with no note
private let kSilence = Hop(sequence: 0, found: false)

// Feeds hops to a model with a running sequence and clock
@MainActor
private final class Feeder
{
    let model: DisplayModel
    var sequence: UInt64 = 0
    var now = 0.0

    // init
    init(_ model: DisplayModel = DisplayModel())
    {
        self.model = model
    }

    // feed: one hop at the current time, then advance the clock
    func feed(_ hop: Hop)
    {
        var hop = hop
        sequence += 1
        hop.sequence = sequence
        model.update(hop, now: now)
        now += kHop
    }

    // feed: hops for a span of seconds
    func feed(_ hop: Hop, for seconds: Double)
    {
        let end = now + seconds
        while now < end
        {
            feed(hop)
        }
    }

    // feed: one hop at a given time
    func feed(_ hop: Hop, at time: Double)
    {
        now = time
        feed(hop)
    }
}

@MainActor
@Suite("display model")
struct DisplayModelTests
{
    // Covers AE12
    @Test func staleAfterOneAndAHalfSeconds()
    {
        let feeder = Feeder()
        let model = feeder.model

        feeder.feed(kA4, at: 0)
        #expect(model.phase == .live)

        feeder.feed(kSilence, at: 1.49)
        #expect(model.phase == .live)
        #expect(!model.isStale)
        #expect(model.strobeCents == 3)

        feeder.feed(kSilence, at: 1.5)
        #expect(model.phase == .stale)
        #expect(model.isStale)
        #expect(model.reading?.note == 57)
        #expect(model.strobeCents == 0)

        // A note after the silence shows at once, though the text
        // interval has not passed since the stale transition
        let tick = model.readoutTick
        feeder.feed(kC5, at: 1.51)
        #expect(model.phase == .live)
        #expect(!model.isStale)
        #expect(model.reading?.note == 60)
        #expect(model.readoutTick > tick)
    }

    @Test func blankUntilFirstNoteThenTextAtMostEveryTenthOfASecond()
    {
        let feeder = Feeder()
        let model = feeder.model

        #expect(model.phase == .blank)
        #expect(model.reading == nil)
        #expect(model.meterCents == 0)
        #expect(model.copyLine(transpose: 6) == nil)

        feeder.feed(kSilence, for: 0.5)
        #expect(model.phase == .blank)
        #expect(model.reading == nil)

        // The first note shows at once
        let first = feeder.now
        feeder.feed(kA4)
        #expect(model.phase == .live)
        #expect(model.reading?.note == 57)

        // A note whose cents drift every hop
        var updates = [first]
        var last = model.reading
        var cents = 3.0
        while feeder.now < first + 1
        {
            cents += 0.1
            var hop = kA4
            hop.cents = cents
            let time = feeder.now
            feeder.feed(hop)
            if model.reading != last
            {
                updates.append(time)
                last = model.reading
            }
        }

        // The text moved on, but never twice within 100 ms
        #expect(updates.count >= 8)
        for (earlier, later) in zip(updates, updates.dropFirst())
        {
            #expect(later - earlier >= 0.1 - 1e-9)
        }
    }

    // Covers AE4
    @Test func lockHoldsTheWholeReading()
    {
        let feeder = Feeder()
        let model = feeder.model

        feeder.feed(kA4, for: 1)
        let meter = model.meterCents
        #expect(abs(meter - 3) < 0.01)

        model.isLocked = true
        feeder.feed(kC5, for: 1)

        #expect(model.isLocked)
        #expect(model.phase == .live)
        #expect(model.reading?.note == 57)
        #expect(model.reading?.cents == 3)
        #expect(model.reading?.frequency == 440.76)
        #expect(model.reading?.reeds == kA4.reeds)
        #expect(model.markers?.frequency == 440.76)
        #expect(model.markers?.maxima == [440.76])
        #expect(model.meterCents == meter)
        #expect(model.strobeCents == 3)
        #expect(model.staffNote(transpose: 6)?.text == "A4")

        model.isLocked = false
        #expect(!model.isLocked)
        #expect(model.reading?.note == 60)
        #expect(model.strobeCents == -10)
        #expect(model.markers?.frequency == 520.24)
        #expect(model.staffNote(transpose: 6)?.text == "C5")
    }

    @Test func unlockInSilenceIsStale()
    {
        let feeder = Feeder()
        let model = feeder.model

        feeder.feed(kA4, for: 1)
        model.isLocked = true
        feeder.feed(kSilence, for: 2)
        #expect(model.phase == .live)

        model.isLocked = false
        #expect(model.phase == .stale)
        #expect(model.isStale)
        #expect(model.strobeCents == 0)
    }

    @Test func staleStopsTheStrobeAndHoldsTheMeter()
    {
        let feeder = Feeder()
        let model = feeder.model

        feeder.feed(kA4, for: 1)
        while !model.isStale
        {
            feeder.feed(kSilence)
        }

        let meter = model.meterCents
        #expect(abs(meter - 3) < 0.01)
        #expect(model.strobeCents == 0)

        feeder.feed(kSilence, for: 1)
        #expect(model.isStale)
        #expect(model.meterCents == meter)
        #expect(model.strobeCents == 0)
        #expect(model.reading?.note == 57)
    }

    @Test func lockHoldsTheStrobeAndTheMeter()
    {
        let feeder = Feeder()
        let model = feeder.model

        // Lock part way through a step, so the meter is still moving
        feeder.feed(kA4, for: 1)
        var hop = kA4
        hop.cents = 20
        feeder.feed(hop, for: 0.04)
        let meter = model.meterCents
        #expect(meter > 3 && meter < 20)

        model.isLocked = true
        feeder.feed(kC5, for: 1)
        #expect(model.meterCents == meter)
        #expect(model.strobeCents == 20)

        feeder.feed(kSilence, for: 2)
        #expect(model.meterCents == meter)
        #expect(model.strobeCents == 20)
        #expect(!model.isStale)
    }

    @Test func lockInBlankAndRestart()
    {
        let feeder = Feeder()
        let model = feeder.model

        // Lock in blank stays blank with the badge
        let tick = model.readoutTick
        model.isLocked = true
        #expect(model.isLocked)
        #expect(model.phase == .blank)
        #expect(model.readoutTick > tick)
        feeder.feed(kSilence, for: 1)
        #expect(model.phase == .blank)

        // Unlock with nothing held is blank
        model.isLocked = false
        #expect(model.phase == .blank)
        #expect(model.reading == nil)

        // A restart while locked clears everything and unlocks
        feeder.feed(kA4, for: 1)
        model.isLocked = true
        model.reset()
        #expect(!model.isLocked)
        #expect(model.phase == .blank)
        #expect(model.reading == nil)
        #expect(model.markers == nil)
        #expect(model.meterCents == 0)
        #expect(model.strobeCents == 0)
        #expect(model.copyLine(transpose: 6) == nil)

        // The new engine counts hops from 1 again
        feeder.sequence = 0
        feeder.feed(kC5)
        #expect(model.phase == .live)
        #expect(model.reading?.note == 60)
    }

    @Test func inTuneWithinFiveCentsInclusive()
    {
        #expect(DisplayModel.inTune(4.9))
        #expect(DisplayModel.inTune(5.0))
        #expect(!DisplayModel.inTune(5.1))
        #expect(DisplayModel.inTune(-5.0))
        #expect(!DisplayModel.inTune(-5.1))

        // The model's flag follows the meter
        let feeder = Feeder()
        var hop = kA4
        hop.cents = 4.9
        feeder.feed(hop, for: 2)
        #expect(feeder.model.inTune)

        hop.cents = 5.1
        feeder.feed(hop, for: 2)
        #expect(!feeder.model.inTune)
    }

    @Test func meterReachesSixtyThreePercentInEightyMilliseconds()
    {
        var hop = kA4
        hop.cents = 10

        // Two hops 80 ms apart
        let sparse = Feeder()
        sparse.feed(hop, at: 0)
        sparse.feed(hop, at: 0.08)
        #expect(abs(sparse.model.meterCents - 10 * (1 - exp(-1.0))) < 1e-9)

        // Eight hops 10 ms apart; the smoother is in time, not hops
        let dense = Feeder()
        for i in 0 ... 8
        {
            dense.feed(hop, at: Double(i) * 0.01)
        }
        #expect(abs(dense.model.meterCents - 10 * (1 - exp(-1.0))) < 1e-9)
    }

    @Test func traceRefreshEverySixteenthHop()
    {
        let feeder = Feeder()
        var fired: [UInt64] = []

        for i in 0 ..< 64
        {
            // Lock half way: the traces keep moving under lock
            if i == 32
            {
                feeder.model.isLocked = true
            }

            feeder.feed((i % 2 == 0) ? kA4 : kSilence)
            if feeder.model.traceRefresh
            {
                fired.append(feeder.sequence)
            }
        }

        #expect(fired == [16, 32, 48, 64])
    }
}
