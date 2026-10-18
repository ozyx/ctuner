//
//  SpectrumAxis.swift
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
//  The spectrum pane's horizontal axis (R12, R16, KTD5): where a bin
//  falls, in the zoomed linear window around the reference and on the
//  unzoomed log axis with expand. The trace and the markers both use
//  x(bin:), so a marker lands on the trace column of its bin in both
//  modes. The old unzoomed markers applied a linear formula to the log
//  trace; this is that bug fixed by using the trace's own mapping.

import Foundation

public struct SpectrumAxis: Equatable, Sendable
{
    public enum Mode: Equatable, Sendable
    {
        // A linear window from the lower marker, the reference in the
        // middle
        case zoomed(lower: Double, reference: Double, upper: Double)

        // Bins 1 to count / expand on a log axis
        case log(expand: Int)
    }

    // One column of the decimated trace: the least and greatest value of
    // the bins that fall in it
    public struct Column: Equatable, Sendable
    {
        public var x: Int
        public var minimum: Double
        public var maximum: Double
    }

    public let mode: Mode

    // The width in points and the number of bins the spectrum holds
    public let width: Double
    public let count: Int

    // The points a bin takes: the log axis fits ln of the last visible
    // bin into the width; the zoomed window puts the reference in the
    // middle and fits the farther limit at an edge
    private let scale: Double

    // zoomed: the markers are bins, not Hz. Nil when they do not span a
    // window, as before a first reading.
    public init?(zoomedFrom lower: Double, reference: Double, upper: Double,
                 width: Double, count: Int)
    {
        guard reference > lower, upper > lower, width >= 1, count > 1 else
        {
            return nil
        }

        mode = .zoomed(lower: lower, reference: reference, upper: upper)
        self.width = width
        self.count = count
        scale = (width / 2) / max(reference - lower, upper - reference)
    }

    // log: the unzoomed axis with the expand factor
    public init?(width: Double, count: Int, expand: Int)
    {
        let last = count / max(expand, 1)
        guard width >= 1, expand >= 1, last > 1 else
        {
            return nil
        }

        mode = .log(expand: expand)
        self.width = width
        self.count = count
        scale = width / log(Double(last))
    }

    // x(bin:): the column of a bin, fractional for a marker between bins
    public func x(bin: Double) -> Double
    {
        switch mode
        {
        case .zoomed(_, let reference, _):
            return width / 2 + (bin - reference) * scale

        case .log:
            return log(max(bin, 1)) * scale
        }
    }

    // The bins the trace shows, without the DC bin
    public var bins: ClosedRange<Int>
    {
        switch mode
        {
        case .zoomed(let lower, _, let upper):
            let first = max(1, Int(floor(lower)))
            let last = min(count - 1, Int(ceil(upper)))
            return first ... max(first, last)

        case .log(let expand):
            return 1 ... max(1, count / expand)
        }
    }

    // contains: whether a marker falls inside the pane
    public func contains(bin: Double) -> Bool
    {
        let position = x(bin: bin)
        return position >= 0 && position <= width
    }

    // decimate: two points to a column, keeping the least and greatest
    // value so a narrow peak survives. Columns with no bin are left out.
    public func decimate(_ values: UnsafeBufferPointer<Double>) -> [Column]
    {
        var columns: [Column] = []
        columns.reserveCapacity(Int(width) + 2)

        for bin in bins where bin < values.count
        {
            let position = x(bin: Double(bin))
            if position < 0 || position > width
            {
                continue
            }

            let column = Int(position)
            let value = values[bin]
            if let last = columns.last, last.x == column
            {
                columns[columns.count - 1].minimum = min(last.minimum, value)
                columns[columns.count - 1].maximum = max(last.maximum, value)
            }

            else
            {
                columns.append(Column(x: column, minimum: value,
                                      maximum: value))
            }
        }

        return columns
    }
}
