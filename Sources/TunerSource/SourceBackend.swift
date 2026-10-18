//
//  SourceBackend.swift
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
//  A file or tone as stage 2's capture backend (KTD8): the controller
//  runs on it exactly as on the microphone, with no permission request
//  and no configuration change, at the source's own rate. The stream
//  keeps its playhead, so a pause while the window is hidden resumes
//  where the sound left off (R13).

import Foundation
import TunerState

@MainActor
public final class SourceBackend: CaptureBackend
{
    public let permission = RecordPermission.granted
    public let inputSampleRate: Double

    // Stored and never called: a source's configuration does not change
    public var onConfigurationChange: (@MainActor () -> Void)?

    private let stream: SampleStream

    // Takes each block; the engine's push unless a test says otherwise
    private let push: @Sendable (Engine, UnsafeBufferPointer<Float>) -> Void

    private var feeder: Feeder?

    // init: a note-name tone resolves once against the settings in effect
    // (R2); a file loops until the controller stops it
    public convenience init(_ spec: SourceSpec, settings: RunSettings)
      throws(CaptureError)
    {
        try self.init(spec, settings: settings)
        {
            $0.push($1)
        }
    }

    // init(_:settings:push:): a tone is endless here whatever secs says,
    // since the window has no end-of-sound state (KTD3)
    init(_ spec: SourceSpec, settings: RunSettings,
         push: @escaping @Sendable (Engine, UnsafeBufferPointer<Float>)
           -> Void) throws(CaptureError)
    {
        var spec = spec
        if case .tone(var tone) = spec
        {
            tone.seconds = nil
            spec = .tone(tone)
        }

        do
        {
            stream = try SampleStream(spec, settings: settings, loop: true)
        }

        catch
        {
            throw CaptureError(message: error.message)
        }

        inputSampleRate = stream.rate
        self.push = push
    }

    isolated deinit
    {
        feeder?.stop()
    }

    // requestPermission: nothing to ask
    public func requestPermission(_ done: @escaping @MainActor (Bool) -> Void)
    {
        done(true)
    }

    // start: a feeder into this engine, from the stream's playhead
    public func start(_ engine: Engine) throws(CaptureError)
    {
        feeder?.stop()

        let stream = self.stream
        let push = self.push
        let feeder = Feeder(rate: stream.rate,
                            fill: { stream.next(into: $0) },
                            push: { push(engine, $0) })
        self.feeder = feeder
        feeder.start()
    }

    // stop: the thread has exited when this returns
    public func stop()
    {
        feeder?.stop()
        feeder = nil
    }
}
