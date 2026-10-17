//
//  CaptureController.swift
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
//  The stage 2 capture lifecycle (KTD8): microphone permission, the
//  default input and its rate, a core at that rate, restarts on a
//  configuration change, and a pause a few seconds after the window
//  stops being visible (R5, R30, R31, R34). The backend is a protocol
//  so the tests drive the controller without an audio device.

import AVFAudio
import Foundation
import Synchronization
import TunerCapture
import TunerCore

// The C callbacks are declared out here, away from the main actor, so
// no isolation check reaches the threads that call them

// enginePush: the shim's push on the audio thread; the context is the
// core handle
private let enginePush: CapturePush =
{
    context, samples, count in
    TunerEnginePush(OpaquePointer(context), samples, count)
}

// engineChange: reported on the notification's thread; the context is
// the backend, which acts on the main actor
private let engineChange: CaptureChange =
{
    context in

    let backend =
      Unmanaged<EngineBackend>.fromOpaque(context!).takeUnretainedValue()
    Task
    {
        @MainActor in
        backend.onConfigurationChange?()
    }
}

// At most one hop post waits on the main actor
private final class HopPost: Sendable
{
    let pending = Atomic<Bool>(false)
}

// The microphone permission as the backend reports it; restricted
// counts as denied
public enum RecordPermission: Sendable
{
    case undetermined
    case denied
    case granted
}

// What the window shows about capture
public enum CaptureState: Equatable, Sendable
{
    // Not started, or paused while the window is hidden
    case stopped

    // The permission prompt is up
    case requesting

    // Denied or restricted (R30)
    case denied

    // No input device (R31)
    case noDevice

    // Capturing at this sample rate
    case running(Double)

    // The core or the capture failed to start
    case failed(String)
}

// A capture call that failed
public struct CaptureError: Error, Sendable
{
    public let message: String

    // init
    public init(_ status: CaptureStatus)
    {
        message = String(cString: CaptureStatusString(status))
    }
}

// The audio side of the controller
@MainActor
public protocol CaptureBackend: AnyObject
{
    var permission: RecordPermission { get }

    // The default input's sample rate, or 0 when there is none
    var inputSampleRate: Double { get }

    // Called on the main actor when the configuration changes
    var onConfigurationChange: (@MainActor () -> Void)? { get set }

    // Show the permission prompt; done gets the answer on the main actor
    func requestPermission(_ done: @escaping @MainActor (Bool) -> Void)

    // Push the default input into the engine's core
    func start(_ engine: Engine) throws(CaptureError)
    func stop()
}

// A scheduled action that can be cancelled
public protocol CaptureTimer
{
    func cancel()
}

extension Task: CaptureTimer {}

// Runs an action after a delay in seconds
public typealias CaptureScheduler =
  @MainActor (Double, @escaping @MainActor () -> Void) -> CaptureTimer

@MainActor
@Observable
public final class CaptureController
{
    // Capture stops this long after the window stops being visible
    public nonisolated static let pauseAfter = 3.0

    public private(set) var state = CaptureState.stopped

    // The running core, if any
    @ObservationIgnored public private(set) var engine: Engine?

    // Called after each hop reaches the display model, with the
    // snapshot, which is valid for this turn only
    @ObservationIgnored public var onSnapshot: ((Snapshot) -> Void)?

    @ObservationIgnored private let backend: CaptureBackend
    @ObservationIgnored private let model: DisplayModel
    @ObservationIgnored private let settings: Settings
    @ObservationIgnored private let schedule: CaptureScheduler
    @ObservationIgnored private var visible = true
    @ObservationIgnored private var pause: CaptureTimer?

    // init
    public init(backend: CaptureBackend, model: DisplayModel,
                settings: Settings,
                schedule: @escaping CaptureScheduler =
                  CaptureController.after)
    {
        self.backend = backend
        self.model = model
        self.settings = settings
        self.schedule = schedule

        backend.onConfigurationChange =
        {
            [weak self] in
            self?.configurationChanged()
        }
    }

    // after: the default scheduler, a task on the main actor
    public static func after(_ delay: Double,
                             _ action: @escaping @MainActor () -> Void)
      -> CaptureTimer
    {
        return Task
        {
            @MainActor in
            try await Task.sleep(for: .seconds(delay))
            action()
        }
    }

    // activate: the app became active; checks the permission and the
    // input again, so a grant or an input chosen in System Settings
    // starts capture (R30, R31)
    public func activate()
    {
        switch state
        {
        case .stopped, .denied, .noDevice, .failed:
            if visible
            {
                begin()
            }

        case .requesting, .running:
            break
        }
    }

    // setVisible: the window's visibility; capture pauses after a few
    // seconds hidden and resumes at once when visible (R34)
    public func setVisible(_ visible: Bool)
    {
        guard visible != self.visible else
        {
            return
        }

        self.visible = visible
        pause?.cancel()
        pause = nil

        if visible
        {
            if state == .stopped
            {
                begin()
            }
        }

        else
        {
            pause = schedule(CaptureController.pauseAfter)
            {
                [weak self] in
                self?.paused()
            }
        }
    }

    // begin: the permission, then the device
    private func begin()
    {
        switch backend.permission
        {
        case .undetermined:
            state = .requesting
            backend.requestPermission
            {
                [weak self] granted in
                guard let self, self.state == .requesting else
                {
                    return
                }

                if granted
                {
                    self.begin()
                }

                else
                {
                    self.state = .denied
                }
            }

        case .denied:
            state = .denied

        case .granted:
            startCapture()
        }
    }

    // startCapture: a core at the input's rate, then the input into it
    private func startCapture()
    {
        // Nothing starts while the window is hidden, whichever event
        // asked; showing it starts capture again (R34)
        guard visible else
        {
            state = .stopped
            return
        }

        let rate = backend.inputSampleRate
        guard rate > 0 else
        {
            state = .noDevice
            return
        }

        let engine: Engine
        do
        {
            engine = try Engine(sampleRate: rate)
        }

        catch
        {
            fail(error.message)
            return
        }

        // Settings apply to the engine as it attaches, and after
        settings.engine = engine
        self.engine = engine

        // Coalesce: post only when no post is waiting
        let post = HopPost()
        do
        {
            try engine.start
            {
                [weak self] in
                if !post.pending.exchange(true,
                                          ordering: .acquiringAndReleasing)
                {
                    Task
                    {
                        @MainActor in
                        post.pending.store(false, ordering: .releasing)
                        self?.hop(engine)
                    }
                }
            }
        }

        catch
        {
            fail(error.message)
            return
        }

        do
        {
            try backend.start(engine)
        }

        catch
        {
            fail(error.message)
            return
        }

        state = .running(rate)
    }

    // fail: stop whatever started and show why
    private func fail(_ message: String)
    {
        stopCapture()
        state = .failed(message)
    }

    // stopCapture: the input, then the core; the display goes blank
    // and lock turns off for the next core (R31)
    private func stopCapture()
    {
        guard let engine else
        {
            return
        }

        backend.stop()
        engine.stop()
        settings.engine = nil
        self.engine = nil
        model.reset()
    }

    // configurationChanged: the device or its rate changed; start again
    // with fresh history, unless capture is paused or not allowed
    private func configurationChanged()
    {
        switch state
        {
        case .running, .noDevice, .failed:
            stopCapture()
            startCapture()

        case .stopped, .requesting, .denied:
            break
        }
    }

    // paused: the window has been hidden for the debounce
    private func paused()
    {
        pause = nil
        if !visible, case .running = state
        {
            stopCapture()
            state = .stopped
        }
    }

    // hop: the newest snapshot into the display model; a post from a
    // core that has since stopped is dropped
    private func hop(_ from: Engine)
    {
        guard from === engine, let snapshot = from.acquire() else
        {
            return
        }

        model.update(snapshot.hop, now: ProcessInfo.processInfo.systemUptime)
        onSnapshot?(snapshot)
    }
}

// The default input through AVAudioEngine and the TunerCapture shim
@MainActor
public final class EngineBackend: CaptureBackend
{
    public var onConfigurationChange: (@MainActor () -> Void)?

    // The shim, which lives as long as this backend
    private var capture: OpaquePointer?

    // init
    public init() throws(CaptureError)
    {
        let status = CaptureEngineCreate(engineChange,
                                         Unmanaged.passUnretained(self)
                                           .toOpaque(),
                                         &capture)
        if status != kCaptureStatusOK
        {
            throw CaptureError(status)
        }
    }

    isolated deinit
    {
        CaptureEngineDestroy(capture)
    }

    public var permission: RecordPermission
    {
        switch AVAudioApplication.shared.recordPermission
        {
        case .granted:
            return .granted

        case .undetermined:
            return .undetermined

        default:
            return .denied
        }
    }

    public var inputSampleRate: Double
    {
        return CaptureEngineInputRate(capture)
    }

    // requestPermission
    public func requestPermission(_ done: @escaping @MainActor (Bool)
                                    -> Void)
    {
        Task
        {
            done(await AVAudioApplication.requestRecordPermission())
        }
    }

    // start: the shim pushes straight into the core's ring
    public func start(_ engine: Engine) throws(CaptureError)
    {
        let status = CaptureEngineStart(capture, enginePush,
                                        UnsafeMutableRawPointer(engine.handle))
        if status != kCaptureStatusOK
        {
            throw CaptureError(status)
        }
    }

    // stop
    public func stop()
    {
        CaptureEngineStop(capture)
    }
}
