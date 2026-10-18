//
//  TraceStore.swift
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
//  What the scope and spectrum draw: the arrays of the newest snapshot
//  on the trace refresh hop (today's every sixteenth). The snapshot's
//  buffers are valid only for the turn that acquired them (R10), so
//  they are copied here, once per refresh, and the panes redraw from
//  the copies, which only the next refresh replaces.

import Observation
import TunerState

@Observable
final class TraceStore
{
    private(set) var scope: [Double] = []
    private(set) var spectrum: [Double] = []
    private(set) var binWidth = 1.0

    // refresh: copy the snapshot's arrays
    func refresh(_ snapshot: Snapshot)
    {
        scope = Array(snapshot.scope)
        spectrum = Array(snapshot.spectrum)
        binWidth = snapshot.binWidth
    }
}
