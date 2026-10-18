//
//  FileSource.swift
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
//  A file source: a PCM file read whole into memory as float, channel
//  0 only, at the file's own sample rate. It hands out whole blocks for
//  a headless run and a sample-exact loop for the app.

import AVFAudio
import Foundation
import TunerState

public struct FileSource: Sendable
{
    public let path: String
    public let rate: Double
    public let samples: [Float]

    // init: every open or read failure names the path and the reason
    public init(path: String) throws(SourceError)
    {
        self.path = path

        func fail(_ reason: String) -> SourceError
        {
            SourceError("\"\(path)\": \(reason)")
        }

        do
        {
            let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))

            let settings = file.fileFormat.settings
            let format = (settings[AVFormatIDKey] as? NSNumber)?.uint32Value
            guard format == kAudioFormatLinearPCM else
            {
                throw fail("the format is not PCM (\(file.fileFormat))")
            }

            let length = AVAudioFrameCount(file.length)
            guard length > 0 else
            {
                throw fail("the file has no samples")
            }

            guard let buffer = AVAudioPCMBuffer(pcmFormat:
                                                  file.processingFormat,
                                                frameCapacity: length)
            else
            {
                throw fail("not enough memory for \(length) samples")
            }

            try file.read(into: buffer)

            guard let channel = buffer.floatChannelData?[0] else
            {
                throw fail("the samples are not readable as float")
            }

            samples = Array(UnsafeBufferPointer(start: channel,
                                                count: Int(buffer.frameLength)))
            rate = file.processingFormat.sampleRate
        }
        catch let error as SourceError
        {
            throw error
        }
        catch
        {
            throw fail(error.localizedDescription)
        }
    }

    // blockCount: whole blocks only; a partial last block is dropped
    public var blockCount: Int
    {
        return samples.count / Engine.blockSize
    }

    // block: the samples of one whole block
    public func block(_ index: Int) -> ArraySlice<Float>
    {
        let start = index * Engine.blockSize
        return samples[start ..< start + Engine.blockSize]
    }
}

// A reader that wraps from the last sample to the first with nothing
// between, and keeps its place until it is told otherwise
public struct LoopingReader: Sendable
{
    private let samples: [Float]

    // The next sample to read
    public private(set) var position = 0

    // init
    public init(_ source: FileSource)
    {
        samples = source.samples
    }

    // read: fill the block, wrapping as often as it takes
    public mutating func read(into block: UnsafeMutableBufferPointer<Float>)
    {
        var filled = 0
        while filled < block.count
        {
            let run = min(block.count - filled, samples.count - position)
            for i in 0 ..< run
            {
                block[filled + i] = samples[position + i]
            }

            filled += run
            position = (position + run) % samples.count
        }
    }
}
