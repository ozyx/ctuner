//
//  RootView.swift
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
//  The window's content: the main area, the inspector on the trailing
//  side and the toolbar.

import SwiftUI
import TunerState

struct RootView: View
{
    @Environment(AppModel.self) private var model

    var body: some View
    {
        @Bindable var settings = model.settings

        MainArea()
            // Room for the toolbar items in one row and, in the main
            // area, eight reed rows, the meter and a strobe tall
            // enough to read; U11 confirms it against the real rows
            .frame(minWidth: 560, minHeight: 360)
            .inspector(isPresented: $settings.inspector)
            {
                InspectorView()
                    .inspectorColumnWidth(min: 220, ideal: 280, max: 480)
            }
            .toolbar(id: "main")
            {
                TunerToolbar(settings: model.settings,
                             display: model.display)
            }
    }
}
