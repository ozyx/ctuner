//
//  main.swift
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
//  tuner-run: runs a tone or a file through the tuner's engine with no
//  window and no audio device. It prints one JSON line per hop to
//  stdout and, given a target, a verdict to stderr. Exits 0 for a pass
//  or a run with no target, 1 for a fail and 2 for a usage error, a
//  source error or nothing to judge.

import Foundation
import TunerSource

// The seconds a tone plays when its description gives none
let kDefaultSeconds = 3.0

// fail: a message and the exit code for a run that could not start
func fail(_ message: String, usage: Bool = false) -> Never
{
    FileHandle.standardError.write(Data("tuner-run: \(message)\n".utf8))
    if usage
    {
        FileHandle.standardError.write(Data((RunOptions.usage + "\n").utf8))
    }
    exit(2)
}

let options: RunOptions
do
{
    options = try RunOptions.parse(Array(CommandLine.arguments.dropFirst()))
}
catch
{
    fail(error.message, usage: true)
}

let stream: SampleStream
do
{
    stream = try SampleStream(SourceSpec.parse(options.source),
                              settings: options.settings,
                              defaultSeconds: kDefaultSeconds)
}
catch
{
    fail(error.message)
}

// Paced hops arrive on the analysis thread, so lines go out one at a time
let output = NSLock()
let rate = stream.rate
let quiet = options.quiet

let result: RunResult
do
{
    result = try HeadlessRun.run(stream, settings: options.settings,
                                 paced: options.paced)
    {
        hop, overruns in
        guard !quiet else
        {
            return
        }

        let line = HopLine.render(hop, rate: rate, overruns: overruns)
        output.lock()
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
        output.unlock()
    }
}
catch
{
    fail("\(error)")
}

guard let target = options.target else
{
    exit(0)
}

let verdict = Verdict.judge(result.hops, against: target)
FileHandle.standardError.write(Data((verdict.summary + "\n").utf8))
exit(verdict.exitCode)
