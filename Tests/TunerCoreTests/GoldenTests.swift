//
//  GoldenTests.swift
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
//  The new core against the frozen engine's per-hop output, within the
//  tolerances in Fixtures/README.md (covers AE1).

import Foundation
import Testing
import TunerCore

@Suite("golden")
struct GoldenTests
{
    // Fixtures whose found, note or count may differ between builds are
    // left to the same-binary check
    static let gated = Fixture.all.filter
    {
        (try? $0.header()["same_binary_only"]) != "1"
    }

    @Test func gatedFixturesPresent()
    {
        #expect(GoldenTests.gated.count >= 27)
    }

    @Test(arguments: GoldenTests.gated)
    func matchesFrozenEngine(fixture: Fixture) throws
    {
        let config = CoreConfig(header: try fixture.header())
        let actual = try runCore(samples: try fixture.samples(), config: config)
        let expected = try fixture.expected()

        try #require(actual.count == expected.count)

        for hop in Fixture.warmUpHops ..< expected.count
        {
            let problems = mismatches(actual[hop], expected[hop])
            #expect(problems.isEmpty, "hop \(hop): \(problems)")

            // One failing hop's detail is enough to start from
            if !problems.isEmpty
            {
                break
            }
        }
    }

    // The comparison can fail: a corrupted expected line is caught
    @Test func corruptedExpectationFails() throws
    {
        let fixture = try #require(Fixture.named("tone-00440.0"))
        let actual = try runCore(samples: try fixture.samples(),
                                 config: CoreConfig(header: try fixture.header()))
        let good = try fixture.expected()[30]

        #expect(mismatches(actual[30], good).isEmpty)

        var fields = good.line.split(separator: " ").map(String.init)
        fields[4] = String(good.f * (1 + 1e-9))
        let bad = try ExpectedHop(line: fields.joined(separator: " "))

        #expect(!mismatches(actual[30], bad).isEmpty)
    }

    // The same binary on the same input is exact, on every fixture
    // including the boundary ones
    @Test(arguments: [Fixture.named("tone-00440.0"),
                      Fixture.named("detune-p50"),
                      Fixture.named("pair-440-442")].compactMap { $0 })
    func sameBinaryTwice(fixture: Fixture) throws
    {
        let config = CoreConfig(header: try fixture.header())
        let samples = try fixture.samples()
        let first = try runCore(samples: samples, config: config)
        let second = try runCore(samples: samples, config: config)

        for (a, b) in zip(first, second)
        {
            #expect(a.found == b.found && a.note == b.note && a.count == b.count)
            #expect(a.f.bitPattern == b.f.bitPattern)
            #expect(a.c.bitPattern == b.c.bitPattern)
            #expect(a.sumsq.bitPattern == b.sumsq.bitPattern)
            #expect(a.maxima == b.maxima)
        }
    }

    // Covers AE7: a C5 with the note filter at A in octave 4
    @Test func noteFilterPassesNothing() throws
    {
        let fixture = try #require(Fixture.named("note-c5-filtered"))
        let actual = try runCore(samples: try fixture.samples(),
                                 config: CoreConfig(header: try fixture.header()))

        for hop in actual.dropFirst(Fixture.warmUpHops)
        {
            #expect(!hop.found)
            #expect(hop.count == 0)
        }
    }

    // Noise is never found, keeps at most eight maxima, and publishes no
    // NaN in a field the UI reads
    @Test func noiseInvariants() throws
    {
        let fixture = try #require(Fixture.named("noise"))
        let actual = try runCore(samples: try fixture.samples(),
                                 config: CoreConfig(header: try fixture.header()))

        for hop in actual.dropFirst(Fixture.warmUpHops)
        {
            #expect(!hop.found)
            #expect(hop.count <= Int(kTunerMaxima))
            #expect(!hop.c.isNaN && !hop.fr.isNaN && !hop.max.isNaN)
            #expect(hop.maxima.allSatisfy { !$0.f.isNaN && !$0.fr.isNaN })
        }
    }
}
