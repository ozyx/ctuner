//
//  TunerApp.swift
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
//  One window and a Settings scene. This file does not import
//  TunerState, so Settings here is SwiftUI's scene, not the model.

import SwiftUI

@main
struct TunerApp: App
{
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @LocalState private var model = AppModel()

    var body: some Scene
    {
        Window("Tuner", id: "main")
        {
            RootView()
                .environment(model)
        }
        .defaultSize(width: 640, height: 440)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
        .commands
        {
            TunerCommands(model: model)
        }

        Settings
        {
            SettingsView()
                .environment(model)
        }
    }
}
