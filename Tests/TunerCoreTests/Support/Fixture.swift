//
//  Fixture.swift
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
//  Reads the golden fixtures in the format Fixtures/README.md defines.

import Foundation
import Testing

// One maximum in an expected line
struct ExpectedMaximum: Equatable
{
    let f: Double
    let fr: Double
    let n: Int
}

// One expected line: the frozen engine's output for one hop
struct ExpectedHop
{
    let hop: Int
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
}

// A fixture: header, input samples and expected hops
struct Fixture: CustomTestStringConvertible, Sendable
{
    static let warmUpHops = 20
    static let block = 1024
    static let digestHalf = 3

    let name: String
    let directory: URL

    var testDescription: String { name }

    // Every committed fixture, listed once
    static let all: [Fixture] =
    {
        guard let directory = Bundle.module.url(forResource: "Fixtures",
                                                withExtension: nil)
        else
        {
            return []
        }

        let names = (try? FileManager.default
                         .contentsOfDirectory(atPath: directory.path)) ?? []

        return names.filter { $0.hasSuffix(".header") }
            .map { Fixture(name: String($0.dropLast(".header".count)),
                           directory: directory) }
            .sorted { $0.name < $1.name }
    }()

    // named
    static func named(_ name: String) -> Fixture?
    {
        return all.first { $0.name == name }
    }

    // header
    func header() throws -> [String: String]
    {
        let url = directory.appendingPathComponent(name + ".header")
        let text = try String(contentsOf: url, encoding: .utf8)
        var values: [String: String] = [:]

        for line in text.split(separator: "\n")
        {
            let parts = line.split(separator: " ", maxSplits: 1)
            if parts.count == 2
            {
                values[String(parts[0])] = String(parts[1])
            }
        }

        return values
    }

    // inputData
    func inputData() throws -> Data
    {
        return try Data(contentsOf: directory
                            .appendingPathComponent(name + ".bin"))
    }

    // samples
    func samples() throws -> [Float]
    {
        let data = try inputData()
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    // expected
    func expected() throws -> [ExpectedHop]
    {
        let url = directory.appendingPathComponent(name + ".expected.txt")
        let text = try String(contentsOf: url, encoding: .utf8)

        return try text.split(separator: "\n").map
        {
            try ExpectedHop(line: String($0))
        }
    }
}

// Parse errors
struct FixtureError: Error, CustomStringConvertible
{
    let description: String
}

extension ExpectedHop
{
    // init(line:)
    init(line: String) throws
    {
        // hop to sumsq, then the digest bins, then three per maximum
        let scalarFields = 10
        let fields = line.split(separator: " ").map(String.init)
        let fixed = scalarFields + 2 * Fixture.digestHalf + 1

        guard fields.count >= fixed
        else
        {
            throw FixtureError(description: "short line: \(line)")
        }

        func int(_ index: Int) throws -> Int
        {
            guard let value = Int(fields[index])
            else
            {
                throw FixtureError(description: "bad int \(fields[index])")
            }
            return value
        }

        func double(_ index: Int) throws -> Double
        {
            guard let value = Double(fields[index])
            else
            {
                throw FixtureError(description: "bad double \(fields[index])")
            }
            return value
        }

        hop = try int(0)
        found = try int(1) != 0
        note = try int(2)
        count = try int(3)
        f = try double(4)
        fr = try double(5)
        c = try double(6)
        max = try double(7)
        imax = try int(8)
        sumsq = try double(9)
        bins = try (scalarFields ..< fixed).map { try double($0) }

        guard fields.count == fixed + 3 * count
        else
        {
            throw FixtureError(description: "count \(count) does not match "
                                   + "\(fields.count - fixed) maxima fields")
        }

        maxima = try (0 ..< count).map
        {
            let base = fixed + 3 * $0
            return ExpectedMaximum(f: try double(base),
                                   fr: try double(base + 1),
                                   n: try int(base + 2))
        }
    }
}

// fnv1a64
func fnv1a64(_ data: Data) -> UInt64
{
    return data.withUnsafeBytes
    {
        var hash: UInt64 = 0xCBF29CE484222325

        for byte in $0
        {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001B3
        }

        return hash
    }
}
