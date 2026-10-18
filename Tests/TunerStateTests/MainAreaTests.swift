//
//  MainAreaTests.swift
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

import Testing
import TunerState

struct MainAreaTests
{
    @Test func stoppedRequestingAndRunningShowTheTuner()
    {
        for state: CaptureState in [.stopped, .requesting, .running(48000)]
        {
            let area = MainArea(state: state, failure: nil)
            #expect(area == .tuner)
            #expect(!area.isStatus)
        }
    }

    @Test func deniedAndNoDeviceHaveTheirViews()
    {
        #expect(MainArea(state: .denied, failure: nil) == .denied)
        #expect(MainArea(state: .noDevice, failure: nil) == .noDevice)
        #expect(MainArea(state: .denied, failure: nil).isStatus)
        #expect(MainArea(state: .noDevice, failure: nil).isStatus)
    }

    @Test func aFailedStateCarriesItsMessage()
    {
        let area = MainArea(state: .failed("no good"), failure: nil)
        #expect(area == .failed("no good"))
        #expect(area.isStatus)
    }

    @Test func aBackendFailureShowsTheFailedView()
    {
        #expect(MainArea(state: nil, failure: "no engine") ==
                .failed("no engine"))
        #expect(MainArea(state: nil, failure: nil).isStatus)
    }
}
