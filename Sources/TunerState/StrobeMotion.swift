//
//  StrobeMotion.swift
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
//  The strobe's motion as arithmetic, without a layer (R13, R22). The
//  pattern moves at a speed set by the display model's strobe cents
//  after a smoother, as the old per-draw code did at 50 draws a second:
//  25 points a second for each cent, with a 160 ms time constant. The
//  layer runs a repeating animation at that speed; this type decides
//  when its speed changes and where in the pattern it must restart so
//  the pattern never jumps, including when the sign of the cents flips.
//  The position is kept as a fraction of the pattern's period, so a
//  resize does not move it either.

import Foundation

public struct StrobeMotion: Sendable
{
    // Points a second for each cent, from today's 50 per semitone per
    // 20 ms draw
    public nonisolated static let pointsPerSecondPerCent = 25.0

    // The smoother's time constant, today's (7 * old + new) / 8 per
    // 20 ms draw
    public nonisolated static let timeConstant = 0.16

    // The looks switch when the smoothed cents are above these
    public nonisolated static let gradientAbove = 20.0
    public nonisolated static let flatAbove = 40.0

    // A new speed within this of the running one is not worth a new
    // animation; below it the pattern is taken as stopped
    public nonisolated static let minimumChange = 0.5

    // The smoother is done when it is this close to its input
    public nonisolated static let settledWithin = 0.02

    public enum Look: Equatable, Sendable
    {
        case plain
        case gradient
        case flat
    }

    // A speed to run from a point in the pattern. The layer replaces
    // its animation with one built from this.
    public struct Segment: Equatable, Sendable
    {
        // Points a second, positive to the right, 0 when stopped
        public var speed: Double

        // Where in the pattern the segment starts, as a fraction of
        // its period in 0 ..< 1
        public var phase: Double

        public init(speed: Double, phase: Double)
        {
            self.speed = speed
            self.phase = phase
        }

        // Seconds for one period, nil when stopped
        public func duration(period: Double) -> Double?
        {
            return (speed == 0) ? nil : period / abs(speed)
        }

        // How far through an animation that runs 0 to period when the
        // speed is positive and period to 0 when negative the start is
        public var progress: Double
        {
            return (speed < 0) ? (1 - phase).truncatingRemainder(dividingBy: 1)
                               : phase
        }
    }

    // The smoothed cents, the speed the layer is running and the
    // position at the last update
    public private(set) var smoothed = 0.0
    public private(set) var speed = 0.0
    public private(set) var phase = 0.0

    private var time: Double?

    public init()
    {
    }

    // The look for the smoothed cents
    public var look: Look
    {
        return StrobeMotion.look(cents: smoothed)
    }

    public nonisolated static func look(cents: Double) -> Look
    {
        let size = abs(cents)
        return (size > flatAbove) ? .flat : (size > gradientAbove) ? .gradient
                                                                   : .plain
    }

    // speed(cents:): the speed for settled cents
    public nonisolated static func speed(cents: Double) -> Double
    {
        return cents * pointsPerSecondPerCent
    }

    // position: the pattern's position at a time after the last update
    // if the layer keeps its speed, as a fraction of the period
    public func position(at now: Double, period: Double) -> Double
    {
        let dt = max(0, now - (time ?? now))
        return (period > 0) ? StrobeMotion.wrap(phase + speed * dt / period)
                            : phase
    }

    // needsTick: whether the smoother is still moving toward the cents,
    // so the caller must update again without waiting for a new hop
    public func needsTick(cents: Double, stale: Bool, paused: Bool) -> Bool
    {
        return !(paused || stale || smoothed == cents)
    }

    // update: move the position on to now at the running speed, step the
    // smoother toward the cents and return the new segment if the speed
    // changed. Stale is speed 0 at once; paused stops the pattern and
    // holds the smoother; the cents arrive held under lock from the
    // display model. period is the pattern's length in points.
    public mutating func update(now: Double, cents: Double, stale: Bool,
                                paused: Bool, period: Double) -> Segment?
    {
        let dt = max(0, now - (time ?? now))
        if period > 0
        {
            phase = StrobeMotion.wrap(phase + speed * dt / period)
        }
        time = now

        var wanted = 0.0
        if stale
        {
            smoothed = 0
        }

        else if !paused
        {
            let step = 1 - exp(-dt / StrobeMotion.timeConstant)
            smoothed += (cents - smoothed) * step
            if abs(cents - smoothed) < StrobeMotion.settledWithin
            {
                smoothed = cents
            }

            wanted = StrobeMotion.speed(cents: smoothed)
            if abs(wanted) < StrobeMotion.minimumChange
            {
                wanted = 0
            }
        }

        let changed = ((wanted == 0) != (speed == 0)) ||
                      ((wanted < 0) != (speed < 0)) ||
                      abs(wanted - speed) >= StrobeMotion.minimumChange
        if !changed
        {
            return nil
        }

        speed = wanted
        return Segment(speed: speed, phase: phase)
    }

    nonisolated private static func wrap(_ phase: Double) -> Double
    {
        let wrapped = phase.truncatingRemainder(dividingBy: 1)
        return (wrapped < 0) ? wrapped + 1 : wrapped
    }
}
