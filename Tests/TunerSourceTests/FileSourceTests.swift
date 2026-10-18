//
//  FileSourceTests.swift
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
//  File sources, read from WAVs the tests write to a temporary folder.
//  No test opens an audio device.

import AVFAudio
import Foundation
import Testing
@testable import TunerSource
import TunerState

// A temporary folder that goes away with the test
private final class Scratch
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
private func sine(_ frequency: Double, rate: Double, count: Int,
                  amplitude: Double = 0.5) -> [Float]
{
    return (0 ..< count).map
    {
        Float(amplitude * sin(2 * Double.pi * frequency * Double($0) / rate))
    }
}

// write: a file of the channels at the rate with the file settings
private func write(_ path: String, channels: [[Float]], rate: Double,
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

@Suite("file source")
struct FileSourceTests
{
    @Test func sixteenBitAtItsOwnRate() throws
    {
        let scratch = Scratch()
        let wave = sine(440, rate: 48000, count: 48000)
        try write(scratch.path("a.wav"), channels: [wave], rate: 48000,
                  bits: 16)

        let source = try FileSource(path: scratch.path("a.wav"))
        #expect(source.rate == 48000)
        #expect(source.samples.count == wave.count)

        let worst = zip(source.samples, wave).map { abs($0 - $1) }.max()!
        #expect(worst < 1.0 / 32768)
    }

    @Test func floatStereoReadsTheLeftChannel() throws
    {
        let scratch = Scratch()
        let left = sine(440, rate: 44100, count: 4410)
        let right = [Float](repeating: 0, count: 4410)
        try write(scratch.path("b.wav"), channels: [left, right],
                  rate: 44100, bits: 32, float: true)

        let source = try FileSource(path: scratch.path("b.wav"))
        #expect(source.samples == left)
    }

    @Test func twentyFourBit() throws
    {
        let scratch = Scratch()
        let wave = sine(1000, rate: 96000, count: 9600)
        try write(scratch.path("c.wav"), channels: [wave], rate: 96000,
                  bits: 24)

        let source = try FileSource(path: scratch.path("c.wav"))
        #expect(source.rate == 96000)

        let worst = zip(source.samples, wave).map { abs($0 - $1) }.max()!
        #expect(worst < 1.0 / 8_388_608 * 2)
    }

    @Test func partialLastBlockIsDropped() throws
    {
        let scratch = Scratch()
        try write(scratch.path("d.wav"),
                  channels: [sine(440, rate: 44100, count: 5000)],
                  rate: 44100, bits: 16)

        let source = try FileSource(path: scratch.path("d.wav"))
        #expect(source.samples.count == 5000)
        #expect(source.blockCount == 4)
        #expect(source.block(3).count == Engine.blockSize)
        #expect(source.block(3).first == source.samples[3 * 1024])
    }

    @Test func loopWrapsWithoutPadding() throws
    {
        let scratch = Scratch()
        let wave = sine(440, rate: 44100, count: 3000)
        try write(scratch.path("e.wav"), channels: [wave], rate: 44100,
                  bits: 32, float: true)

        var reader = LoopingReader(try FileSource(path: scratch.path("e.wav")))
        var block = [Float](repeating: 0, count: 1024)

        // Three blocks leave the playhead 72 samples past the end
        var heard: [Float] = []
        for _ in 0 ..< 4
        {
            block.withUnsafeMutableBufferPointer { reader.read(into: $0) }
            heard += block
        }

        #expect(Array(heard[0 ..< 3000]) == wave)
        #expect(Array(heard[3000 ..< 3100]) == Array(wave[0 ..< 100]))
        #expect(reader.position == 4096 - 3000)
    }

    @Test func loopReturnsToZeroExactly() throws
    {
        let scratch = Scratch()
        try write(scratch.path("f.wav"),
                  channels: [sine(440, rate: 44100, count: 2048)],
                  rate: 44100, bits: 32, float: true)

        var reader = LoopingReader(try FileSource(path: scratch.path("f.wav")))
        var block = [Float](repeating: 0, count: 1024)
        for _ in 0 ..< 2
        {
            block.withUnsafeMutableBufferPointer { reader.read(into: $0) }
        }
        #expect(reader.position == 0)
    }

    // Covers AE5
    @Test func missingPathNamesThePath() throws
    {
        let path = Scratch().path("missing.wav")
        do
        {
            _ = try FileSource(path: path)
            Issue.record("a missing file opened")
        }
        catch
        {
            #expect(error.message.contains(path))
        }
    }

    // Covers AE5
    @Test func textFileNamedWavNamesThePathAndReason() throws
    {
        let scratch = Scratch()
        let path = scratch.path("not.wav")
        try "this is not audio".write(toFile: path, atomically: true,
                                     encoding: .utf8)
        do
        {
            _ = try FileSource(path: path)
            Issue.record("a text file opened")
        }
        catch
        {
            #expect(error.message.contains(path))
            #expect(error.message.count > path.count + 4)
        }
    }

    @Test func compressedFormatIsRejectedByName() throws
    {
        let scratch = Scratch()
        let path = scratch.path("g.m4a")
        let wave = sine(440, rate: 44100, count: 8192)

        // The writer flushes when it goes away, so it lives in its own scope
        do
        {
            let file = try AVAudioFile(forWriting: URL(fileURLWithPath: path),
                                       settings:
                                         [AVFormatIDKey: kAudioFormatMPEG4AAC,
                                          AVSampleRateKey: 44100.0,
                                          AVNumberOfChannelsKey: 1])
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                          frameCapacity: 8192)!
            buffer.frameLength = 8192
            for (i, sample) in wave.enumerated()
            {
                buffer.floatChannelData![0][i] = sample
            }
            try file.write(from: buffer)
        }

        do
        {
            _ = try FileSource(path: path)
            Issue.record("an AAC file opened")
        }
        catch
        {
            #expect(error.message.contains(path))
            #expect(error.message.contains("PCM"))
        }
    }
}
