//
//  ScopeTraceTests.swift
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

struct ScopeTraceTests
{
    let window = 8192

    @Test func triggersOnTheSteepestRisingSlope()
    {
        var samples = [Double](repeating: 0, count: window)
        samples[10] = 0.1
        samples[50] = 0.5
        samples[51] = 0.9
        samples[52] = 0.2

        let n = samples.withUnsafeBufferPointer
        {
            ScopeTrace.trigger($0, width: 200)
        }

        // 0 to 0.5 rises more than 0.5 to 0.9
        #expect(n == 50)
    }

    @Test func triggerSearchStaysInsideTheWidth()
    {
        var samples = [Double](repeating: 0, count: window)
        samples[300] = 1

        let n = samples.withUnsafeBufferPointer
        {
            ScopeTrace.trigger($0, width: 200)
        }

        #expect(n == 0)
    }

    @Test func sampleIndexNeverPassesTheWindow()
    {
        // The worst trigger: the steepest rise at the last place the
        // search looks
        for width in stride(from: 200, through: 3000, by: 7)
        {
            var samples = [Double](repeating: 0, count: window)
            samples[width - 1] = 1

            let n = samples.withUnsafeBufferPointer
            {
                ScopeTrace.trigger($0, width: width)
            }

            let points = ScopeTrace.points(count: window, trigger: n,
                                           width: width)
            #expect(points > 0)
            #expect(n + (points - 1) * ScopeTrace.step <= window - 1)
        }
    }

    @Test func aShortWindowGivesFewerPoints()
    {
        #expect(ScopeTrace.points(count: 100, trigger: 0, width: 400) == 25)
        #expect(ScopeTrace.points(count: 0, trigger: 0, width: 400) == 0)
        #expect(ScopeTrace.points(count: 100, trigger: 100, width: 400) == 0)
    }
}
