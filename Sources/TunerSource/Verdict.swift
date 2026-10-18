//
//  Verdict.swift
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
//  The pass or fail rule CI depends on. A run skips the warm-up hops,
//  then requires every remaining hop to be found, on the target note
//  and within the tolerance of the target's cents.

import Foundation
import TunerState

// What a run is expected to read
public struct Target: Equatable, Sendable
{
    // Cents the tuner reads, relative to the note, within this
    public static let defaultTolerance = 0.5

    // Note number, where 57 is A4
    public var note: Int
    public var cents: Double
    public var tolerance: Double

    // init
    public init(note: Int, cents: Double = 0,
                tolerance: Double = defaultTolerance)
    {
        self.note = note
        self.cents = cents
        self.tolerance = tolerance
    }
}

public enum Verdict: Equatable, Sendable
{
    // The hops the golden tests skip while the tuner locks on
    public static let warmUpHops = 20

    case pass(judged: Int, meanCents: Double)
    case notFound(hop: Int)
    case wrongNote(hop: Int, note: Int)
    case outOfTolerance(hop: Int, cents: Double)

    // Too few hops to judge
    case nothingToJudge(hops: Int)

    // judge: hops are numbered from 1 in the order given
    public static func judge(_ hops: [Hop], against target: Target) -> Verdict
    {
        guard hops.count > warmUpHops else
        {
            return .nothingToJudge(hops: hops.count)
        }

        let judged = hops.enumerated().dropFirst(warmUpHops)

        if let miss = judged.first(where: { !$0.element.found })
        {
            return .notFound(hop: miss.offset + 1)
        }

        if let wrong = judged.first(where: { $0.element.note != target.note })
        {
            return .wrongNote(hop: wrong.offset + 1, note: wrong.element.note)
        }

        let worst = judged.max
        {
            abs($0.element.cents - target.cents)
              < abs($1.element.cents - target.cents)
        }!

        if abs(worst.element.cents - target.cents) > target.tolerance
        {
            return .outOfTolerance(hop: worst.offset + 1,
                                   cents: worst.element.cents)
        }

        let mean = judged.map { $0.element.cents }.reduce(0, +)
          / Double(judged.count)
        return .pass(judged: judged.count, meanCents: mean)
    }

    // exitCode: 0 for a pass, 1 for a fail, 2 when there was nothing to
    // judge
    public var exitCode: Int32
    {
        switch self
        {
        case .pass: return 0
        case .nothingToJudge: return 2
        default: return 1
        }
    }

    // summary: the one line printed for the verdict
    public var summary: String
    {
        switch self
        {
        case .pass(let judged, let mean):
            return String(format: "pass: %d hops judged, mean %+.3f cents",
                          judged, mean)

        case .notFound(let hop):
            return "fail: hop \(hop) was not found"

        case .wrongNote(let hop, let note):
            let shown = DisplayNote(note: note, transpose: Notes.noTranspose)
            return "fail: hop \(hop) read \(shown.text), not the target note"

        case .outOfTolerance(let hop, let cents):
            return String(format: "fail: hop %d read %+.3f cents, "
                            + "outside the tolerance", hop, cents)

        case .nothingToJudge(let hops):
            return "error: \(hops) hops, and the first "
              + "\(Verdict.warmUpHops) are warm-up, so nothing to judge"
        }
    }
}
