//
//  Support.swift
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
//  Helpers the source tests share: a temporary folder, a sine and a
//  WAV writer. No test opens an audio device.

import AVFAudio
import Foundation

// A temporary folder that goes away with the test
final class Scratch
{
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("TunerSourceTests." + UUID().uuidString)

    // init
    init()
    {
        try! FileManager.default.createDirectory(at: url,
                                                 withIntermediateDirectories:
                                                   true)
    }

    deinit
    {
        try? FileManager.default.removeItem(at: url)
    }

    // path
    func path(_ name: String) -> String
    {
        return url.appendingPathComponent(name).path
    }
}

// sine: samples of a sine at the amplitude
func sine(_ frequency: Double, rate: Double, count: Int,
                  amplitude: Double = 0.5) -> [Float]
{
    return (0 ..< count).map
    {
        Float(amplitude * sin(2 * Double.pi * frequency * Double($0) / rate))
    }
}

// write: a file of the channels at the rate with the file settings
func write(_ path: String, channels: [[Float]], rate: Double,
                   bits: Int, float: Bool = false) throws
{
    let settings: [String: Any] =
    [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: rate,
        AVNumberOfChannelsKey: channels.count,
        AVLinearPCMBitDepthKey: bits,
        AVLinearPCMIsFloatKey: float,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
    ]

    let file = try AVAudioFile(forWriting: URL(fileURLWithPath: path),
                               settings: settings,
                               commonFormat: .pcmFormatFloat32,
                               interleaved: false)

    let count = channels[0].count
    let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                  frameCapacity: AVAudioFrameCount(count))!
    buffer.frameLength = AVAudioFrameCount(count)
    for (index, samples) in channels.enumerated()
    {
        for (i, sample) in samples.enumerated()
        {
            buffer.floatChannelData![index][i] = sample
        }
    }

    try file.write(from: buffer)
}
