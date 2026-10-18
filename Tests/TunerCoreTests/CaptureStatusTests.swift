//
//  CaptureStatusTests.swift
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
//  The pure parts of capture: the buffer-size search over a device's
//  range and the status strings. Nothing here opens a device.

import Testing
import TunerCapture

@Suite("capture status")
struct CaptureStatusTests
{
    @Test(arguments: [
        (kCaptureStatusOK, "OK"),
        (kCaptureStatusNoMemory, "Out of memory"),
        (kCaptureStatusBadArgument, "Bad argument"),
        (kCaptureStatusNoComponent, "No audio output unit"),
        (kCaptureStatusNoInputDevice, "No input device"),
        (kCaptureStatusDevice, "Input device setup failed"),
        (kCaptureStatusUnit, "Audio unit setup failed"),
        (kCaptureStatusStart, "Audio input failed to start"),
        (kCaptureStatusRender, "Audio input failed"),
    ])
    func statusStrings(status: CaptureStatus, string: String)
    {
        #expect(String(cString: CaptureStatusString(status)) == string)
    }
}
