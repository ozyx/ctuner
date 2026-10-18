//
//  SourceBackendTests.swift
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
//  The capture controller running on a file or tone backend. The blocks
//  go to a recorder in place of the engine, and no test opens an audio
//  device.

import Foundation
import Testing
@testable import TunerSource
import TunerState

// The blocks the feeder pushed, whole and in order
private final class Recorder: @unchecked Sendable
{
    private let lock = NSLock()
    private var samples: [Float] = []

    // push
    func push(_ engine: Engine, _ block: UnsafeBufferPointer<Float>)
    {
        lock.lock()
        samples.append(contentsOf: block)
        lock.unlock()
    }

    // blocks: the number of whole blocks pushed
    var blocks: Int
    {
        lock.lock()
        defer { lock.unlock() }
        return samples.count / Engine.blockSize
    }

    // all
    var all: [Float]
    {
        lock.lock()
        defer { lock.unlock() }
        return samples
    }
}

// A clock the test advances by hand
@MainActor
private final class Clock
{
    private final class Timer: CaptureTimer
    {
        let action: @MainActor () -> Void
        var cancelled = false

        // init
        init(action: @escaping @MainActor () -> Void)
        {
            self.action = action
        }

        // cancel
        func cancel()
        {
            cancelled = true
        }
    }

    private var timers: [Timer] = []

    // schedule
    func schedule(_ delay: Double,
                  _ action: @escaping @MainActor () -> Void) -> CaptureTimer
    {
        let timer = Timer(action: action)
        timers.append(timer)
        return timer
    }

    // fire: every timer that was not cancelled
    func fire()
    {
        let due = timers.filter { !$0.cancelled }
        timers.removeAll()
        for timer in due
        {
            timer.action()
        }
    }
}

// A controller on a source backend, with throwaway settings
@MainActor
private struct Rig
{
    let backend: SourceBackend
    let recorder = Recorder()
    let clock = Clock()
    let controller: CaptureController

    // init
    init(_ description: String, settings: RunSettings = RunSettings()) throws
    {
        let recorder = self.recorder
        backend = try SourceBackend(SourceSpec.parse(description),
                                    settings: settings)
        {
            recorder.push($0, $1)
        }

        let suite = "TunerSourceTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let clock = self.clock
        controller = CaptureController(backend: backend,
                                       model: DisplayModel(),
                                       settings: Settings(defaults: defaults))
        {
            clock.schedule($0, $1)
        }
    }

    // pushed: wait until the recorder holds this many blocks
    func pushed(_ count: Int) async throws
    {
        while recorder.blocks < count
        {
            try await Task.sleep(for: .milliseconds(1))
        }
    }
}

// A ramp that tells its position: sample i is i / 10000
private let kLength = 10_000

private func ramp() -> [Float]
{
    return (0 ..< kLength).map { Float($0) / Float(kLength) }
}

@MainActor
@Suite("source backend")
struct SourceBackendTests
{
    // Covers AE6
    @Test func aToneRunsTheControllerWithoutAskingForAnything() throws
    {
        let rig = try Rig("tone:A4")

        #expect(rig.backend.permission == .granted)
        rig.controller.activate()

        #expect(rig.controller.state == .running(44100))
        #expect(rig.controller.engine != nil)
        rig.controller.setVisible(false)
        rig.clock.fire()
        #expect(rig.controller.state == .stopped)
    }

    @Test func aFileSetsTheEnginesRate() throws
    {
        let scratch = Scratch()
        let path = scratch.path("ramp.wav")
        try write(path, channels: [ramp()], rate: 48000, bits: 32,
                  float: true)

        let rig = try Rig("file:" + path)
        #expect(rig.backend.inputSampleRate == 48000)

        rig.controller.activate()
        #expect(rig.controller.state == .running(48000))
        #expect(rig.controller.engine?.sampleRate == 48000)
        rig.controller.setVisible(false)
        rig.clock.fire()
    }

    // Covers AE9
    @Test(.timeLimit(.minutes(1)))
    func hiddenPastTheDelayStopsAndShowingResumesAtThePlayhead()
      async throws
    {
        let scratch = Scratch()
        let path = scratch.path("ramp.wav")
        try write(path, channels: [ramp()], rate: 44100, bits: 32,
                  float: true)

        let rig = try Rig("file:" + path)
        rig.controller.activate()
        try await rig.pushed(5)

        rig.controller.setVisible(false)
        rig.clock.fire()
        #expect(rig.controller.state == .stopped)

        // The feeder has exited, so this is every block there will be
        let before = rig.recorder.blocks
        #expect(before >= 5)
        try await Task.sleep(for: .milliseconds(80))
        #expect(rig.recorder.blocks == before)

        rig.controller.setVisible(true)
        #expect(rig.controller.state == .running(44100))
        try await rig.pushed(before + 3)

        // The first block after the pause starts where the last one ended
        let all = rig.recorder.all
        let first = (before * Engine.blockSize) % kLength
        #expect(all[before * Engine.blockSize] == Float(first) / Float(kLength))

        rig.controller.setVisible(false)
        rig.clock.fire()
    }

    // The window has no end-of-sound state, so secs does not end a tone
    @Test(.timeLimit(.minutes(1)))
    func aToneKeepsPlayingPastItsSeconds() async throws
    {
        // 0.01 s is under one block
        let rig = try Rig("tone:A4,secs=0.01")
        rig.controller.activate()
        try await rig.pushed(5)
        #expect(rig.controller.state == .running(44100))
        rig.controller.setVisible(false)
        rig.clock.fire()
    }

    // Covers AE5
    @Test func aMissingPathThrowsAnErrorThatNamesIt() throws
    {
        let path = "/no/such/folder/ramp.wav"
        let spec = try SourceSpec.parse("file:" + path)
        do
        {
            _ = try SourceBackend(spec, settings: RunSettings())
            Issue.record("a missing file opened")
        }

        catch
        {
            #expect(error.message.contains(path))
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func aShortFileWrapsAtTheSampleWithNoGap() async throws
    {
        let scratch = Scratch()
        let path = scratch.path("ramp.wav")
        try write(path, channels: [ramp()], rate: 44100, bits: 32,
                  float: true)

        let rig = try Rig("file:" + path)
        rig.controller.activate()
        try await rig.pushed(30)
        rig.controller.setVisible(false)
        rig.clock.fire()

        let all = rig.recorder.all
        let wanted = ramp()
        for (i, sample) in all.enumerated()
        {
            #expect(sample == wanted[i % kLength])
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func aNoteNameResolvesAgainstTheTemperamentInEffect() async throws
    {
        var settings = RunSettings()
        settings.temperament = 1
        settings.key = 0

        let rig = try Rig("tone:E4", settings: settings)
        rig.controller.activate()
        try await rig.pushed(40)
        rig.controller.setVisible(false)
        rig.clock.fire()

        // Hz from the rising zero crossings across whole blocks
        let all = rig.recorder.all
        var crossings: [Double] = []
        for i in 1 ..< all.count where all[i - 1] < 0 && all[i] >= 0
        {
            let fraction = Double(-all[i - 1]) / Double(all[i] - all[i - 1])
            crossings.append(Double(i - 1) + fraction)
        }
        let cycles = Double(crossings.count - 1)
        let measured = cycles * 44100 / (crossings.last! - crossings.first!)

        let wanted = try Tone.frequency(note: Notes.a4 - 5,
                                        reference: Notes.reference,
                                        temperament: 1, key: 0)
        let equalE4 = try Tone.frequency(note: Notes.a4 - 5,
                                         reference: Notes.reference,
                                         temperament: Temperaments.equal,
                                         key: 0)
        #expect(abs(1200 * log2(measured / wanted)) < 0.5)
        #expect(abs(1200 * log2(wanted / equalE4)) > 1)
    }
}
