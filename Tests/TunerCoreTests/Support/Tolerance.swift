//
//  Tolerance.swift
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
//  The golden comparison from Fixtures/README.md: one hop of the new
//  core against one expected line.

import Foundation
import TunerCore

// Tolerances
enum Tolerance
{
    static let relative = 1e-12
    static let deviation = 1e-9
}

// close: relative closeness, with equal infinities and NaNs counting
func close(_ a: Double, _ b: Double,
           relative: Double = Tolerance.relative) -> Bool
{
    if a == b || (a.isNaN && b.isNaN)
    {
        return true
    }

    return abs(a - b) <= relative * max(abs(a), abs(b))
}

// One hop of the new core, copied out of its slot
struct ActualHop
{
    let found: Bool
    let note: Int
    let count: Int
    let f: Double
    let fr: Double
    let c: Double
    let max: Double
    let imax: Int
    let sumsq: Double
    let bins: [Double]
    let maxima: [ExpectedMaximum]

    // init(snapshot:)
    init(snapshot s: TunerSnapshot)
    {
        found = s.found
        note = Int(s.note)
        count = Int(s.count)
        f = s.frequency
        fr = s.reference
        c = s.deviation
        max = s.peak
        imax = Int(s.peakBin)

        let spectrum = UnsafeBufferPointer(start: s.spectrum,
                                           count: Int(kTunerRange))
        var sum = 0.0
        for value in spectrum
        {
            sum += value * value
        }
        sumsq = sum

        let half = Fixture.digestHalf
        bins = (imax - half ... imax + half).map
        {
            ($0 >= 0 && $0 < spectrum.count) ? spectrum[$0] : 0.0
        }

        maxima = (0 ..< count).map
        {
            ExpectedMaximum(f: s.maxima[$0].f, fr: s.maxima[$0].fr,
                            n: Int(s.maxima[$0].n))
        }
    }
}

// mismatches: every way one hop differs from its expected line, empty
// when it matches within tolerance
func mismatches(_ actual: ActualHop, _ expected: ExpectedHop) -> [String]
{
    var problems: [String] = []

    func check(_ ok: Bool, _ what: String, _ a: Any, _ e: Any)
    {
        if !ok
        {
            problems.append("\(what): got \(a), expected \(e)")
        }
    }

    check(actual.found == expected.found, "found", actual.found, expected.found)
    check(actual.count == expected.count, "count", actual.count, expected.count)
    check(actual.imax == expected.imax, "imax", actual.imax, expected.imax)
    check(close(actual.max, expected.max), "max", actual.max, expected.max)
    check(close(actual.sumsq, expected.sumsq), "sumsq", actual.sumsq,
          expected.sumsq)

    for (k, (a, e)) in zip(actual.bins, expected.bins).enumerated()
    {
        check(close(a, e), "bin \(k - Fixture.digestHalf)", a, e)
    }

    if actual.found && expected.found
    {
        check(actual.note == expected.note, "note", actual.note, expected.note)
        check(close(actual.f, expected.f), "f", actual.f, expected.f)
        check(close(actual.fr, expected.fr), "fr", actual.fr, expected.fr)
        check(abs(actual.c - expected.c) <= Tolerance.deviation, "c",
              actual.c, expected.c)
    }

    // On a count mismatch report both lists rather than aligning them
    if actual.count != expected.count
    {
        problems.append("maxima: got \(actual.maxima), expected \(expected.maxima)")
        return problems
    }

    for (k, (a, e)) in zip(actual.maxima, expected.maxima).enumerated()
    {
        check(a.n == e.n, "maximum \(k) n", a.n, e.n)
        check(close(a.f, e.f), "maximum \(k) f", a.f, e.f)
        check(close(a.fr, e.fr), "maximum \(k) fr", a.fr, e.fr)
    }

    return problems
}
