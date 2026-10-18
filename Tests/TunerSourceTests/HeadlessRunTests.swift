//
//  HeadlessRunTests.swift
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
//  Whole runs: a source through the engine in fast and paced mode, the
//  verdicts on what it reads, and the lines it prints. No test opens an
//  audio device.

import Foundation
import Testing
import TunerSource
import TunerState

// stream: a source from a description
private func stream(_ description: String,
                    settings: RunSettings = RunSettings(),
                    seconds: Double? = 3) throws -> SampleStream
{
    return try SampleStream(SourceSpec.parse(description), settings: settings,
                            defaultSeconds: seconds)
}

// fast: a fast run's hops
private func fast(_ description: String,
                  settings: RunSettings = RunSettings()) throws -> [Hop]
{
    return try HeadlessRun.run(stream(description, settings: settings),
                               settings: settings).hops
}

// E4 in Kirnberger III with key C, worked out from the published ratios
// and not from the app's table: the major third from C is pure, 5/4, and
// A is three fifths up from C, each narrowed by a quarter of the
// syntonic comma. That puts E about 3.4 cents under equal temperament.
private let kirnbergerE4 = 440 * (5.0 / 4)
  / ((27.0 / 16) * pow(80.0 / 81, 0.75))

@Suite("headless run")
struct HeadlessRunTests
{
    // Covers AE1
    @Test func sharpToneOnTargetPasses() throws
    {
        let hops = try fast("tone:A4+7")
        let verdict = Verdict.judge(hops, against: Target(note: 57, cents: 7))

        guard case .pass(_, let mean) = verdict else
        {
            Issue.record("\(verdict.summary)")
            return
        }
        #expect(abs(mean - 7) < 0.5)
    }

    // Covers AE2
    @Test func sharpToneAgainstZeroFails() throws
    {
        let hops = try fast("tone:A4+7")
        let verdict = Verdict.judge(hops, against: Target(note: 57, cents: 0))

        guard case .outOfTolerance(_, let cents) = verdict else
        {
            Issue.record("\(verdict.summary)")
            return
        }
        #expect(abs(cents - 7) < 0.5)
        #expect(verdict.exitCode == 1)
    }

    // Covers AE7
    @Test func kirnbergerThirdPassesInKirnbergerOnly() throws
    {
        var kirnberger = RunSettings()
        kirnberger.temperament = 1

        let tone = "tone:\(kirnbergerE4)"
        let target = Target(note: 52)

        let inKirnberger = Verdict.judge(try fast(tone, settings: kirnberger),
                                         against: target)
        #expect(inKirnberger.exitCode == 0, "\(inKirnberger.summary)")

        let inEqual = Verdict.judge(try fast(tone), against: target)
        #expect(inEqual.exitCode == 1, "\(inEqual.summary)")
    }

    // Covers AE8
    @Test func fifteenHopsHaveNothingToJudge() throws
    {
        let hops = try fast("tone:A4,secs=0.35")
        #expect(hops.count == 15)

        let verdict = Verdict.judge(hops, against: Target(note: 57))
        #expect(verdict == .nothingToJudge(hops: 15))
        #expect(verdict.exitCode == 2)
    }

    @Test func wrongNoteFails() throws
    {
        let verdict = Verdict.judge(try fast("tone:A5"),
                                    against: Target(note: 57))
        guard case .wrongNote(_, let note) = verdict else
        {
            Issue.record("\(verdict.summary)")
            return
        }
        #expect(note == 69)
    }

    @Test func toneThatDropsToSilenceFailsOnTheFirstMiss() throws
    {
        let scratch = Scratch()
        let path = scratch.path("drop.wav")

        // 30 hops of A4, then 30 of silence
        let block = 1024
        var wave = sine(440, rate: 44100, count: 30 * block)
        wave += [Float](repeating: 0, count: 30 * block)
        try write(path, channels: [wave], rate: 44100, bits: 32, float: true)

        let hops = try fast("file:" + path)
        #expect(hops.count == 60)

        let verdict = Verdict.judge(hops, against: Target(note: 57))
        guard case .notFound(let hop) = verdict else
        {
            Issue.record("\(verdict.summary)")
            return
        }

        // The first hop the tuner no longer finds is shortly after 30
        #expect(hop > 30)
        #expect(hops[hop - 1].found == false)
        #expect(hops[hop - 2].found == true)
    }

    @Test func noTargetReturnsEveryHop() throws
    {
        let hops = try fast("tone:A4")
        #expect(hops.count == 129)
        #expect(hops.first?.sequence == 1)
        #expect(hops.last?.sequence == 129)
    }

    @Test func fastRunIsDeterministic() throws
    {
        let lines: () throws -> [String] =
        {
            try fast("tone:E4+5").map { HopLine.render($0, rate: 44100) }
        }

        #expect(try lines() == lines())
    }

    @Test func foundLineHasEveryField() throws
    {
        let hop = try fast("tone:A4+7")[40]
        let line = HopLine.render(hop, rate: 44100)

        let json = try #require(try JSONSerialization.jsonObject(
                                  with: Data(line.utf8)) as? [String: Any])
        #expect(Set(json.keys) == ["hop", "time", "found", "note", "name",
                                   "cents", "frequency", "reference",
                                   "count"])
        #expect(json["hop"] as? Int == 41)
        #expect(json["found"] as? Bool == true)
        #expect(json["note"] as? Int == 57)
        #expect(json["name"] as? String == "A4")
        #expect(abs((json["cents"] as? Double ?? 0) - 7) < 0.5)
        #expect(abs((json["time"] as? Double ?? 0) - 41 * 1024.0 / 44100)
                < 1e-12)
    }

    @Test func missLineHasNulls() throws
    {
        let line = HopLine.render(Hop(sequence: 3, found: false),
                                  rate: 48000)

        let json = try #require(try JSONSerialization.jsonObject(
                                  with: Data(line.utf8)) as? [String: Any])
        #expect(json["found"] as? Bool == false)
        for key in ["note", "name", "cents", "frequency", "reference"]
        {
            #expect(json[key] is NSNull, "\(key)")
        }
        #expect(json["overruns"] == nil)
    }

    // Covers AE3
    @Test func fortyEightKilohertzFileRunsAtItsOwnRate() throws
    {
        let scratch = Scratch()
        let path = scratch.path("a440.wav")
        try write(path,
                  channels: [sine(440, rate: 48000, count: 48000)],
                  rate: 48000, bits: 16)

        let source = try stream("file:" + path)
        #expect(source.rate == 48000)

        let hops = try HeadlessRun.run(source).hops
        #expect(hops.count == 46)

        for hop in hops.dropFirst(Verdict.warmUpHops)
        {
            #expect(hop.found)
            #expect(hop.note == 57)
            #expect(abs(hop.frequency - 440) < 1)
            #expect(abs(hop.cents) < 0.5)
        }

        let line = HopLine.render(hops[0], rate: source.rate)
        #expect(line.contains("\"time\":\(1024.0 / 48000)"))
    }

    @Test func endlessSourceCannotBeRun() throws
    {
        let source = try stream("tone:A4", seconds: nil)
        #expect(throws: SourceError.self)
        {
            try HeadlessRun.run(source)
        }
    }

    @Test func pacedRunNumbersEveryLineAndCountsOverruns() throws
    {
        let source = try stream("tone:A4,secs=0.25")
        let lines = LineLog()

        let result = try HeadlessRun.run(source, paced: true)
        {
            lines.append(HopLine.render($0, rate: 44100, overruns: $1))
        }

        #expect(result.hops.last?.sequence == 10)
        #expect(result.overruns == 0)
        #expect(lines.lines.count == result.hops.count)

        for line in lines.lines
        {
            #expect(line.contains("\"hop\":"))
            #expect(line.contains("\"overruns\":0"))
        }
    }
}

// The lines a callback printed, in order
private final class LineLog: @unchecked Sendable
{
    private let lock = NSLock()
    private var store: [String] = []

    // append
    func append(_ line: String)
    {
        lock.lock()
        defer { lock.unlock() }
        store.append(line)
    }

    // lines
    var lines: [String]
    {
        lock.lock()
        defer { lock.unlock() }
        return store
    }
}
