//
//  FixtureTests.swift
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
//  Checks the committed fixtures themselves: their inputs are the
//  bytes their headers describe, and the frozen engine's expected
//  output says what today's tuner is known to do.

import Foundation
import Testing

@Suite("fixtures")
struct FixtureTests
{
    @Test func fixturesPresent()
    {
        #expect(Fixture.all.count >= 28)
    }

    @Test(arguments: Fixture.all)
    func inputMatchesHeader(fixture: Fixture) throws
    {
        let header = try fixture.header()
        let data = try fixture.inputData()

        #expect(header["input_bytes"] == String(data.count))
        #expect(header["input_hash"] == String(format: "%016llx", fnv1a64(data)))

        let hops = try #require(header["hops"].flatMap { Int($0) })
        #expect(try fixture.expected().count == hops)
    }

    // The measured frequency is within the header's bound of the
    // analytic frequency on every found hop after warm-up, and every hop
    // after warm-up is found
    @Test(arguments: Fixture.all.filter
          {
              (try? $0.header()["expect_hz"]) != nil
          })
    func accuracy(fixture: Fixture) throws
    {
        let header = try fixture.header()
        let expectHz = try #require(header["expect_hz"].flatMap { Double($0) })
        let bound = header["expect_cents"].flatMap { Double($0) } ?? 0.2

        for hop in try fixture.expected().dropFirst(Fixture.warmUpHops)
        {
            #expect(hop.found, "hop \(hop.hop) not found")
            if hop.found
            {
                let cents = 1200 * log2(hop.f / expectHz)
                #expect(abs(cents) < bound, "hop \(hop.hop): \(cents) cents")
            }
        }
    }

    // Covers AE7: a C5 with the note filter at A in octave 4
    @Test func noteFilterPassesNothing() throws
    {
        let fixture = try #require(Fixture.named("note-c5-filtered"))

        for hop in try fixture.expected().dropFirst(Fixture.warmUpHops)
        {
            #expect(!hop.found, "hop \(hop.hop)")
            #expect(hop.count == 0, "hop \(hop.hop)")
        }
    }

    // Two tones closer than a bin merge and split as the beat moves,
    // which is why the comparison is per hop
    @Test func pairCountAlternates() throws
    {
        let fixture = try #require(Fixture.named("pair-440-442"))
        let counts = Set(try fixture.expected()
                             .dropFirst(Fixture.warmUpHops).map { $0.count })

        #expect(counts == [1, 2])
    }

    // Silence and noise are never found
    @Test(arguments: ["silence", "noise", "down-sine-0440"])
    func neverFound(name: String) throws
    {
        let fixture = try #require(Fixture.named(name))

        for hop in try fixture.expected().dropFirst(Fixture.warmUpHops)
        {
            #expect(!hop.found, "hop \(hop.hop)")
        }
    }
}
