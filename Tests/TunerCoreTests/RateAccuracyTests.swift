//
//  RateAccuracyTests.swift
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
//  The core at rates today's engine never ran at. No reference output
//  exists there, so this is an accuracy invariant against the analytic
//  frequency, not a golden.

import Foundation
import Testing
import TunerCore

@Suite("core rate accuracy")
struct RateAccuracyTests
{
    struct Case: CustomTestStringConvertible, Sendable
    {
        let rate: Double
        let frequency: Double

        var testDescription: String { "\(frequency) Hz at \(rate)" }
    }

    static let frequencies = [55.0, 110.0, 220.0, 440.0, 880.0, 1760.0]
    static let cases = [48000.0, 96000.0].flatMap
    {
        rate in frequencies.map { Case(rate: rate, frequency: $0) }
    }

    // Bound in cents, after warm-up. Tones under about 20 bins above
    // zero read off, as 27.5 and 55 Hz do at 44100 (Fixtures/README.md),
    // so these get the error measured on the first run plus a margin:
    // 55 Hz at 48000 and 110 Hz at 96000 sit 18.8 bins up and swing to
    // 0.35 cents, and 55 Hz at 96000 sits 9.4 bins up and swings to
    // 1.29 cents.
    static let bound = 0.2
    static let wider: [String: Double] = [
        "55.0 Hz at 48000.0": 0.5,
        "110.0 Hz at 96000.0": 0.5,
        "55.0 Hz at 96000.0": 1.5,
    ]

    @Test(arguments: RateAccuracyTests.cases)
    func pureToneWithinBound(c: Case) throws
    {
        // The same 0.5 amplitude sine as the tone fixtures, 64 hops
        let samples = (0 ..< 64 * Fixture.block).map
        {
            Float(0.5 * sin(2.0 * Double.pi * c.frequency * Double($0) / c.rate))
        }

        let bound = RateAccuracyTests.wider[c.testDescription] ?? RateAccuracyTests.bound
        var config = CoreConfig()
        config.rate = c.rate
        let hops = try runCore(samples: samples, config: config)

        for (hop, actual) in hops.enumerated().dropFirst(Fixture.warmUpHops)
        {
            #expect(actual.found, "hop \(hop): not found")

            let cents = 1200 * log2(actual.f / c.frequency)
            #expect(abs(cents) < bound, "hop \(hop): \(cents) cents")
        }
    }
}
