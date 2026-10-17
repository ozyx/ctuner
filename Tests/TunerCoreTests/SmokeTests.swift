//
//  SmokeTests.swift
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

import Foundation
import Testing
import TunerCapture
import TunerCore

@Suite("core smoke")
struct CoreSmokeTests
{
    @Test func coreStatusString()
    {
        #expect(String(cString: TunerStatusString(kTunerStatusOK)) == "OK")
    }

    @Test func captureStatusString()
    {
        #expect(String(cString: CaptureStatusString(kCaptureStatusOK)) == "OK")
    }

    @Test func fixturesBundled() throws
    {
        let url = try #require(Bundle.module.url(forResource: "README",
                                                 withExtension: "md",
                                                 subdirectory: "Fixtures"))
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}
