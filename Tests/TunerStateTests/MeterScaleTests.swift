//
//  MeterScaleTests.swift
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

struct MeterScaleTests
{
    // The inner stretch is linear: 5 cents is half the half track, so the
    // bar a tenth of the way out at 1 cent
    @Test(arguments: [(0.0, 0.0), (1.0, 0.1), (2.0, 0.2), (5.0, 0.5)])
    func innerStretchIsLinear(cents: Double, position: Double)
    {
        #expect(abs(MeterScale.position(cents: cents) - position) < 1e-9)
        #expect(abs(MeterScale.position(cents: -cents) + position) < 1e-9)
    }

    // The outer stretch follows the curve the owner chose from, which the
    // requirements table rounds to 65%, 80% and the end
    @Test(arguments: [(10.0, 0.651), (20.0, 0.801), (50.0, 1.0)])
    func outerStretchFollowsTheCurve(cents: Double, position: Double)
    {
        #expect(abs(MeterScale.position(cents: cents) - position) < 0.001)
    }

    // A reading past the end pins the bar there on either side
    @Test(arguments: [50.1, 60.0, 63.0, 1000.0])
    func readingPastTheEndPinsTheBar(cents: Double)
    {
        #expect(MeterScale.position(cents: cents) == 1.0)
        #expect(MeterScale.position(cents: -cents) == -1.0)
    }

    @Test func mappingIsContinuousAtTheJoin()
    {
        let below = MeterScale.position(cents: 4.999)
        let above = MeterScale.position(cents: 5.001)

        #expect(abs(below - 0.5) < 0.001)
        #expect(abs(above - 0.5) < 0.001)
    }

    @Test func mappingRisesAcrossASweep()
    {
        var last = -Double.infinity

        for step in stride(from: -60.0, through: 60.0, by: 0.25)
        {
            let position = MeterScale.position(cents: step)

            // Strictly inside the scale, and level only where it is
            // pinned at an end
            if abs(step) < 50
            {
                #expect(position > last)
            }

            else
            {
                #expect(position >= last)
            }

            last = position
        }
    }

    @Test(arguments: [0.3, 1.0, 4.9, 5.0, 7.5, 12.0, 33.0, 50.0, 80.0])
    func mappingIsOdd(cents: Double)
    {
        #expect(MeterScale.position(cents: -cents)
                == -MeterScale.position(cents: cents))
    }

    @Test func ticksRunFromMinusFiftyToPlusFiftyInOrder()
    {
        let ticks = MeterScale.ticks

        #expect(ticks.map(\.cents) == [-50, -20, -10, -5, -2, -1, 0,
                                       1, 2, 5, 10, 20, 50])
        #expect(ticks.count == 13)
    }

    @Test func eachTickSitsWhereTheMappingPutsIt()
    {
        for tick in MeterScale.ticks
        {
            #expect(tick.position == MeterScale.position(cents: tick.cents))
        }
    }

    @Test func labelsCarryASignExceptZero()
    {
        #expect(MeterScale.ticks.map(\.label)
                == ["-50", "-20", "-10", "-5", "-2", "-1", "0",
                    "+1", "+2", "+5", "+10", "+20", "+50"])
    }
}
