//
//  MainArea.swift
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
//  What the main area shows (U19): the tuner, or the status view for
//  a capture that cannot supply a reading. A pure mapping, so the
//  window only draws what it is told.

// The main area's content
public enum MainArea: Equatable, Sendable
{
    // Stopped, requesting (blank, the system prompt is up) and running
    case tuner

    // Microphone access denied or restricted (R30)
    case denied

    // No input device (R31)
    case noDevice

    // The core or capture failed, or the backend could not be made
    case failed(String)

    // init: the capture state, or nil with the backend-creation failure
    public init(state: CaptureState?, failure: String?)
    {
        guard let state else
        {
            self = .failed(failure ?? "Capture is unavailable")
            return
        }

        switch state
        {
        case .stopped, .requesting, .running:
            self = .tuner

        case .denied:
            self = .denied

        case .noDevice:
            self = .noDevice

        case .failed(let message):
            self = .failed(message)
        }
    }

    // isStatus: a status view replaces the tuner
    public var isStatus: Bool
    {
        return self != .tuner
    }
}
