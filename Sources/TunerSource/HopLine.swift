//
//  HopLine.swift
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
//  One hop as one JSON line. The names are spelled out, and cents are
//  cents, not the golden fixtures' semitones. time is sample time, so a
//  fast run's output is the same every time.

import Foundation
import TunerState

public enum HopLine
{
    // render: overruns is present only in a paced run
    public static func render(_ hop: Hop, rate: Double,
                              overruns: UInt64? = nil) -> String
    {
        let time = Double(hop.sequence) * Double(Engine.blockSize) / rate

        var fields = ["\"hop\":\(hop.sequence)", "\"time\":\(time)",
                      "\"found\":\(hop.found)"]

        if hop.found
        {
            let name = DisplayNote(note: hop.note,
                                   transpose: Notes.noTranspose).text
            fields += ["\"note\":\(hop.note)", "\"name\":\"\(name)\"",
                       "\"cents\":\(hop.cents)",
                       "\"frequency\":\(hop.frequency)",
                       "\"reference\":\(hop.reference)"]
        }
        else
        {
            fields += ["\"note\":null", "\"name\":null", "\"cents\":null",
                       "\"frequency\":null", "\"reference\":null"]
        }

        fields.append("\"count\":\(hop.reeds.count)")
        if let overruns
        {
            fields.append("\"overruns\":\(overruns)")
        }

        return "{" + fields.joined(separator: ",") + "}"
    }
}
