//
//  StrobeMotionTests.swift
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

struct StrobeMotionTests
{
    let period = 640.0

    // settle: update every 20 ms for a while at fixed cents
    private func settle(_ motion: inout StrobeMotion, from start: Double,
                        cents: Double, seconds: Double = 3) -> Double
    {
        var now = start
        let end = start + seconds
        while now < end
        {
            now += 0.02
            _ = motion.update(now: now, cents: cents, stale: false,
                              paused: false, period: period)
        }

        return now
    }

    @Test func plusOneCentMovesTwentyFivePointsASecond()
    {
        var motion = StrobeMotion()
        _ = settle(&motion, from: 0, cents: 1)
        #expect(motion.speed == 25)
    }

    @Test func minusTwoCentsMoveFiftyPointsTheOtherWay()
    {
        var motion = StrobeMotion()
        _ = settle(&motion, from: 0, cents: -2)
        #expect(motion.speed == -50)
    }

    @Test func smootherReachesSixtyThreePercentIn160ms()
    {
        var motion = StrobeMotion()
        _ = motion.update(now: 0, cents: 10, stale: false, paused: false,
                          period: period)
        _ = motion.update(now: 0.16, cents: 10, stale: false, paused: false,
                          period: period)
        #expect(abs(motion.smoothed - 10 * (1 - exp(-1.0))) < 1e-9)
        #expect(abs(motion.smoothed / 10 - 0.632) < 0.001)
    }

    @Test func settlesOntoTheCentsExactly()
    {
        var motion = StrobeMotion()
        _ = settle(&motion, from: 0, cents: 3)
        #expect(motion.smoothed == 3)
        #expect(!motion.needsTick(cents: 3, stale: false, paused: false))
        #expect(motion.needsTick(cents: 4, stale: false, paused: false))
    }

    @Test func staleStopsAtOnce()
    {
        var motion = StrobeMotion()
        let now = settle(&motion, from: 0, cents: 5)
        #expect(motion.speed == 125)

        let segment = motion.update(now: now + 0.02, cents: 5, stale: true,
                                    paused: false, period: period)
        #expect(segment?.speed == 0)
        #expect(motion.speed == 0)
        #expect(motion.smoothed == 0)
        #expect(!motion.needsTick(cents: 5, stale: true, paused: false))
    }

    @Test func pausedStopsAndHoldsTheSmoother()
    {
        var motion = StrobeMotion()
        let now = settle(&motion, from: 0, cents: 5)
        let segment = motion.update(now: now + 0.02, cents: 5, stale: false,
                                    paused: true, period: period)
        #expect(segment?.speed == 0)
        #expect(motion.smoothed == 5)

        // Back on screen, it runs again from where it stopped
        let held = motion.phase
        let resumed = motion.update(now: now + 5, cents: 5, stale: false,
                                    paused: false, period: period)
        #expect(resumed?.speed == 125)
        #expect(resumed?.phase == held)
    }

    @Test func aHeldValueKeepsTheSpeed()
    {
        // Locked, the display model repeats one value for every update
        var motion = StrobeMotion()
        var now = settle(&motion, from: 0, cents: -4)
        let before = motion.speed
        for _ in 0 ..< 100
        {
            now += 0.02
            #expect(motion.update(now: now, cents: -4, stale: false,
                                  paused: false, period: period) == nil)
        }

        #expect(motion.speed == before)
    }

    @Test func lookSwitchesAtTwentyAndForty()
    {
        #expect(StrobeMotion.look(cents: 0) == .plain)
        #expect(StrobeMotion.look(cents: 19) == .plain)
        #expect(StrobeMotion.look(cents: 21) == .gradient)
        #expect(StrobeMotion.look(cents: -21) == .gradient)
        #expect(StrobeMotion.look(cents: 39) == .gradient)
        #expect(StrobeMotion.look(cents: 41) == .flat)
        #expect(StrobeMotion.look(cents: -41) == .flat)
    }

    @Test func noJumpAcrossSignChanges()
    {
        // The position the layer would show, followed through a swing
        // from +20 to -20 cents and back with a speed change at every
        // update: it never moves farther than the fastest speed allows
        var motion = StrobeMotion()
        var now = 0.0
        var shown = motion.position(at: now, period: period)
        var worst = 0.0

        for step in 0 ..< 600
        {
            now += 0.02
            let cents = 20 * sin(Double(step) / 40)
            _ = motion.update(now: now, cents: cents, stale: false,
                              paused: false, period: period)
            let position = motion.position(at: now, period: period)

            var move = abs(position - shown)
            move = min(move, 1 - move)
            worst = max(worst, move)
            shown = position
        }

        // 20 cents is 500 points a second, 10 points in 20 ms
        #expect(worst * period <= 10.0 + 1e-6)
    }

    @Test func segmentAnimatesFromWhereThePatternIs()
    {
        var motion = StrobeMotion()
        var now = settle(&motion, from: 0, cents: 2)

        // Reverse: the new segment starts at the current position, run
        // backwards
        var last: StrobeMotion.Segment?
        while last == nil || last!.speed >= 0
        {
            now += 0.02
            if let segment = motion.update(now: now, cents: -2, stale: false,
                                           paused: false, period: period)
            {
                last = segment
            }
        }

        let segment = last!
        #expect(segment.speed < 0)
        #expect(segment.phase >= 0 && segment.phase < 1)
        #expect(abs(segment.progress - (1 - segment.phase)) < 1e-12 ||
                segment.phase == 0)
        #expect(segment.duration(period: period) == period / abs(segment.speed))
    }

    @Test func stoppedSegmentHasNoDuration()
    {
        let segment = StrobeMotion.Segment(speed: 0, phase: 0.25)
        #expect(segment.duration(period: period) == nil)
        #expect(segment.progress == 0.25)
    }

    @Test func resizeKeepsThePositionAsAFraction()
    {
        var motion = StrobeMotion()
        let now = settle(&motion, from: 0, cents: 1)
        let before = motion.position(at: now, period: 640)
        let after = motion.position(at: now, period: 320)
        #expect(before == after)
    }
}
