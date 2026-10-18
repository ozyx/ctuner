//
//  ScopeTrace.swift
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
//  Which samples the scope pane draws (R10): the trigger is the
//  steepest rising slope among the first width samples, and the trace
//  takes every fourth sample from there, one to a point, stopping at
//  the end of the window so no pane width reads past it.

import Foundation

public enum ScopeTrace
{
    // Samples to a point
    public nonisolated static let step = 4

    // trigger: the index after the steepest rise among the first width
    // samples, 0 when nothing rises
    public nonisolated static func trigger(_ samples: UnsafeBufferPointer<Double>,
                                           width: Int) -> Int
    {
        var steepest = 0.0
        var index = 0

        for i in 1 ..< max(1, min(width, samples.count))
        {
            let slope = samples[i] - samples[i - 1]
            if slope > steepest
            {
                steepest = slope
                index = i
            }
        }

        return index
    }

    // points: how many points the trace has from a trigger, at most one
    // to a column, every sample read inside the window
    public nonisolated static func points(count: Int, trigger: Int,
                                          width: Int) -> Int
    {
        guard count > trigger, width > 0 else
        {
            return 0
        }

        return min(width, (count - 1 - trigger) / step + 1)
    }
}
