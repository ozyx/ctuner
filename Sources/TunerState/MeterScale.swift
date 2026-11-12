//
//  MeterScale.swift
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
//  The meter's scale: where a reading in cents falls between the centre
//  and an end of the track. The middle half of the track covers the 5
//  cents either side of zero, linearly, so the last few cents of a tuning
//  get room. The outer quarters cover 5 to 50 cents on a log curve, which
//  puts 10 cents at 65% of the way out and 20 cents at 80%. The scale does
//  not depend on the in-tune tolerance setting; only the drawn zone does.

import Foundation

public enum MeterScale
{
    // One labelled mark on the scale
    public struct Tick: Equatable, Sendable
    {
        public let cents: Double

        // The signed share of the half track, as position(cents:) gives
        public let position: Double

        // "0", or the value with a sign: "+5", "-50"
        public let label: String
    }

    // The cents at which the linear stretch gives way to the log one, and
    // the cents at the end of the track
    public static let innerCents = 5.0
    public static let outerCents = 50.0

    // position(cents:): the signed share of the distance from the centre to
    // the end of the track, from -1 to +1. A reading past an end sits at
    // the end. The view multiplies it by its own half width.
    public static func position(cents: Double) -> Double
    {
        let magnitude = abs(cents)

        let share: Double
        if magnitude <= innerCents
        {
            share = magnitude / (2 * innerCents)
        }

        else
        {
            share = 0.5 + 0.5 * log10(magnitude / innerCents)
        }

        return copysign(min(share, 1), cents)
    }

    // The labelled ticks from -50 to +50 cents in order
    public static let ticks: [Tick] =
    {
        let magnitudes: [Double] = [1, 2, 5, 10, 20, 50]
        let values = magnitudes.reversed().map { -$0 } + [0] + magnitudes

        return values.map
        {
            Tick(cents: $0, position: position(cents: $0), label: label($0))
        }
    }()

    private static func label(_ cents: Double) -> String
    {
        let whole = Int(cents)
        return whole > 0 ? "+\(whole)" : "\(whole)"
    }
}
