//
//  VerdictTests.swift
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
//  The pass and fail rules CI depends on, on hops made by hand.

import Testing
import TunerSource
import TunerState

// hops: a run of found hops on one note with the cents given for each
private func hops(note: Int = 57, count: Int = 60,
                  cents: (Int) -> Double = { _ in 0 }) -> [Hop]
{
    return (1 ... count).map
    {
        Hop(sequence: UInt64($0), found: true, note: note, cents: cents($0),
            frequency: 440, reference: 440)
    }
}

@Suite("verdict")
struct VerdictTests
{
    @Test func steadyHopsOnTargetPass()
    {
        let verdict = Verdict.judge(hops { _ in 7.1 },
                                    against: Target(note: 57, cents: 7))
        guard case .pass(let judged, let mean) = verdict else
        {
            Issue.record("\(verdict)")
            return
        }

        #expect(judged == 40)
        #expect(abs(mean - 7.1) < 1e-9)
        #expect(verdict.exitCode == 0)
    }

    @Test func tolerancePassesAtTheEdge()
    {
        // The edge is inclusive
        let verdict = Verdict.judge(hops { _ in 0.5 },
                                    against: Target(note: 57))
        #expect(verdict.exitCode == 0)
    }

    @Test func warmUpHopsAreNotJudged()
    {
        // Wild hops during the first 20 are not judged
        let verdict = Verdict.judge(hops { $0 <= 20 ? 30 : 0 },
                                    against: Target(note: 57))
        #expect(verdict.exitCode == 0)
    }

    @Test func oneHopOutsideToleranceFailsWithTheWorstOne()
    {
        let verdict = Verdict.judge(hops { $0 == 33 ? 0.9 : ($0 == 40 ? 0.6 : 0) },
                                    against: Target(note: 57))
        #expect(verdict == .outOfTolerance(hop: 33, cents: 0.9))
        #expect(verdict.exitCode == 1)
    }

    // Covers AE2
    @Test func sevenCentsAgainstZeroFails()
    {
        let verdict = Verdict.judge(hops { _ in 7 },
                                    against: Target(note: 57, cents: 0))
        guard case .outOfTolerance(_, let cents) = verdict else
        {
            Issue.record("\(verdict)")
            return
        }

        #expect(abs(cents - 7) < 1e-9)
        #expect(verdict.exitCode == 1)
        #expect(verdict.summary.contains("+7.000"))
    }

    @Test func customToleranceWidensThePass()
    {
        let verdict = Verdict.judge(hops { _ in 2 },
                                    against: Target(note: 57, cents: 0,
                                                    tolerance: 3))
        #expect(verdict.exitCode == 0)
    }

    @Test func wrongNoteFails()
    {
        let verdict = Verdict.judge(hops(note: 69), against: Target(note: 57))
        #expect(verdict == .wrongNote(hop: 21, note: 69))
        #expect(verdict.exitCode == 1)
        #expect(verdict.summary.contains("A5"))
    }

    @Test func silenceAfterHopThirtyFailsOnTheFirstMiss()
    {
        var run = hops()
        for i in 30 ..< run.count
        {
            run[i].found = false
        }

        let verdict = Verdict.judge(run, against: Target(note: 57))
        #expect(verdict == .notFound(hop: 31))
        #expect(verdict.exitCode == 1)
    }

    @Test func aToneThatNeverLocksFails()
    {
        // A found hop at the very end must not rescue a run that was
        // lost throughout
        var run = hops()
        for i in 0 ..< run.count - 1
        {
            run[i].found = false
        }

        let verdict = Verdict.judge(run, against: Target(note: 57))
        #expect(verdict == .notFound(hop: 21))
    }

    // Covers AE8
    @Test func fifteenHopsHaveNothingToJudge()
    {
        let verdict = Verdict.judge(hops(count: 15), against: Target(note: 57))
        #expect(verdict == .nothingToJudge(hops: 15))
        #expect(verdict.exitCode == 2)
    }

    @Test func exactlyTheWarmUpHasNothingToJudge()
    {
        let verdict = Verdict.judge(hops(count: 20), against: Target(note: 57))
        #expect(verdict == .nothingToJudge(hops: 20))
    }

    @Test func oneJudgedHopIsEnough()
    {
        let verdict = Verdict.judge(hops(count: 21), against: Target(note: 57))
        #expect(verdict == .pass(judged: 1, meanCents: 0))
    }
}
