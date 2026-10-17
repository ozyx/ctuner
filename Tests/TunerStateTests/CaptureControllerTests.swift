//
//  CaptureControllerTests.swift
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
//  The capture lifecycle against a fake backend and a fake clock: no
//  audio device is opened. The engines are real, so a restart is seen
//  as a new core at the new rate.

import Foundation
import Testing
import TunerState

// A backend whose permission and input the test sets
@MainActor
private final class FakeBackend: CaptureBackend
{
    var permission = RecordPermission.undetermined
    var inputSampleRate = 44100.0
    var onConfigurationChange: (@MainActor () -> Void)?

    // What the controller asked for
    var requests = 0
    var running: Engine?
    var pendingRequest: (@MainActor (Bool) -> Void)?

    // requestPermission: held until the test answers
    func requestPermission(_ done: @escaping @MainActor (Bool) -> Void)
    {
        requests += 1
        pendingRequest = done
    }

    // answer: the user's choice on the prompt
    func answer(_ granted: Bool)
    {
        permission = granted ? .granted : .denied
        let done = pendingRequest
        pendingRequest = nil
        done?(granted)
    }

    // start
    func start(_ engine: Engine) throws(CaptureError)
    {
        running = engine
    }

    // stop
    func stop()
    {
        running = nil
    }

    // change: the system's configuration-change notification
    func change()
    {
        onConfigurationChange?()
    }
}

// A clock the test advances by hand
@MainActor
private final class FakeClock
{
    private final class Timer: CaptureTimer
    {
        let due: Double
        let action: @MainActor () -> Void
        var cancelled = false

        // init
        init(due: Double, action: @escaping @MainActor () -> Void)
        {
            self.due = due
            self.action = action
        }

        // cancel
        func cancel()
        {
            cancelled = true
        }
    }

    private var timers: [Timer] = []
    var now = 0.0

    // schedule: the controller's scheduler
    func schedule(_ delay: Double,
                  _ action: @escaping @MainActor () -> Void) -> CaptureTimer
    {
        let timer = Timer(due: now + delay, action: action)
        timers.append(timer)
        return timer
    }

    // advance: run every timer that falls due
    func advance(_ seconds: Double)
    {
        now += seconds
        let due = timers.filter { $0.due <= now && !$0.cancelled }
        timers.removeAll { $0.due <= now || $0.cancelled }
        for timer in due
        {
            timer.action()
        }
    }
}

// A controller on a fake backend and clock, with throwaway settings
@MainActor
private struct Rig
{
    let backend = FakeBackend()
    let clock = FakeClock()
    let model = DisplayModel()
    let settings: Settings
    let controller: CaptureController

    // init
    init()
    {
        let suite = "TunerStateTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        settings = Settings(defaults: defaults)

        let clock = self.clock
        controller = CaptureController(backend: backend, model: model,
                                       settings: settings)
        {
            clock.schedule($0, $1)
        }
    }
}

// A found hop for the display model
private let kA4 = Hop(sequence: 1, found: true, note: 57, cents: 3,
                      frequency: 440.76, reference: 440, lower: 425,
                      upper: 455, reeds: [])

@MainActor
@Suite("capture controller")
struct CaptureControllerTests
{
    // Covers AE9
    @Test func undeterminedAsksDeniedShowsAndActivationRechecks()
    {
        let rig = Rig()
        let controller = rig.controller

        // Undetermined leads to a request, and nothing captures yet
        controller.activate()
        #expect(rig.backend.requests == 1)
        #expect(controller.state == .requesting)
        #expect(rig.backend.running == nil)

        // Don't Allow shows the denied state
        rig.backend.answer(false)
        #expect(controller.state == .denied)
        #expect(controller.engine == nil)

        // Activation while still denied asks nothing and stays denied
        controller.activate()
        #expect(rig.backend.requests == 1)
        #expect(controller.state == .denied)

        // Granted in Privacy & Security, then the app becomes active
        rig.backend.permission = .granted
        controller.activate()
        #expect(controller.state == .running(44100))
        #expect(controller.engine?.sampleRate == 44100)
        #expect(rig.backend.running === controller.engine)
        #expect(rig.settings.engine === controller.engine)
    }

    @Test func allowOnThePromptStartsCapture()
    {
        let rig = Rig()

        rig.controller.activate()
        rig.backend.answer(true)
        #expect(rig.controller.state == .running(44100))
        #expect(rig.backend.running != nil)
    }

    @Test func restrictedIsDenied()
    {
        let rig = Rig()
        rig.backend.permission = .denied

        rig.controller.activate()
        #expect(rig.backend.requests == 0)
        #expect(rig.controller.state == .denied)
    }

    // Covers AE10
    @Test func deviceGoneThenBackAtANewRate()
    {
        let rig = Rig()
        rig.backend.permission = .granted
        rig.controller.activate()
        let first = rig.controller.engine
        #expect(rig.controller.state == .running(44100))

        // The interface is unplugged: no input
        rig.backend.inputSampleRate = 0
        rig.backend.change()
        #expect(rig.controller.state == .noDevice)
        #expect(rig.controller.engine == nil)
        #expect(rig.backend.running == nil)
        #expect(rig.settings.engine == nil)

        // The built-in microphone becomes the default at 48000
        rig.backend.inputSampleRate = 48000
        rig.backend.change()
        #expect(rig.controller.state == .running(48000))
        #expect(rig.controller.engine?.sampleRate == 48000)
        #expect(rig.controller.engine !== first)
        #expect(rig.backend.running === rig.controller.engine)
    }

    @Test func noInputAtLaunch()
    {
        let rig = Rig()
        rig.backend.permission = .granted
        rig.backend.inputSampleRate = 0

        rig.controller.activate()
        #expect(rig.controller.state == .noDevice)
        #expect(rig.controller.engine == nil)
    }

    @Test func restartAfterADeviceChangeIsBlankAndUnlocked()
    {
        let rig = Rig()
        rig.backend.permission = .granted
        rig.controller.activate()

        // A reading, held under lock
        rig.model.update(kA4, now: 0)
        rig.model.isLocked = true
        #expect(rig.model.phase == .live)

        // Same device, new rate
        rig.backend.inputSampleRate = 96000
        rig.backend.change()
        #expect(rig.controller.state == .running(96000))
        #expect(rig.model.phase == .blank)
        #expect(rig.model.reading == nil)
        #expect(!rig.model.isLocked)
    }

    @Test func hiddenBrieflyKeepsCaptureLongerPausesVisibleRestarts()
    {
        let rig = Rig()
        rig.backend.permission = .granted
        rig.controller.activate()
        let first = rig.controller.engine

        // Hidden for less than the debounce
        rig.controller.setVisible(false)
        rig.clock.advance(CaptureController.pauseAfter / 2)
        rig.controller.setVisible(true)
        rig.clock.advance(CaptureController.pauseAfter)
        #expect(rig.controller.state == .running(44100))
        #expect(rig.controller.engine === first)

        // Hidden for longer stops capture
        rig.controller.setVisible(false)
        rig.clock.advance(CaptureController.pauseAfter)
        #expect(rig.controller.state == .stopped)
        #expect(rig.backend.running == nil)
        #expect(rig.controller.engine == nil)

        // Visible again restarts at once
        rig.controller.setVisible(true)
        #expect(rig.controller.state == .running(44100))
        #expect(rig.backend.running === rig.controller.engine)
    }

    @Test func noRestartWhileHidden()
    {
        let rig = Rig()
        rig.backend.permission = .granted
        rig.controller.activate()
        rig.controller.setVisible(false)
        rig.clock.advance(CaptureController.pauseAfter)

        // A device change or activation while paused starts nothing
        rig.backend.change()
        rig.controller.activate()
        #expect(rig.controller.state == .stopped)
        #expect(rig.backend.running == nil)
    }
}
