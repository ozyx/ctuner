//
//  Signposts.swift
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
//  The latency signposts (U13): "hop <n>" when the display model
//  publishes a new readout and "readout <n>" when the readout view
//  has the change, with the model's readout tick as n.
//  Scripts/measure.sh latency pairs them from the log stream.

import os

enum Signposts
{
    nonisolated static let latency = OSSignposter(
        subsystem: "org.billthefarmer.Tuner", category: "latency")

    // hop: the model published a new readout
    static func hop(_ tick: Int)
    {
        latency.emitEvent("hop", "hop \(tick)")
    }

    // readout: the readout view took the change
    static func readout(_ tick: Int)
    {
        latency.emitEvent("readout", "readout \(tick)")
    }
}
