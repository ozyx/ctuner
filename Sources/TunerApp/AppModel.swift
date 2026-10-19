//
//  AppModel.swift
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
//  The app-level model, injected through the environment. It owns the
//  settings and the display model and holds the actions the toolbar,
//  the menus, the bare keys and the pane clicks share, so each mirror
//  of a toggle reads the same state. It also owns the capture
//  controller and folds the main window's occlusion and the app being
//  hidden into the one visibility flag that controller follows (KTD9).

import AppKit
import Observation
import TunerSource
import TunerState

@Observable
final class AppModel
{
    let settings = Settings()
    let display = DisplayModel()

    // The scope and spectrum arrays, copied on the trace refresh
    let traces = TraceStore()

    // Nil when the backend could not be made; captureFailure then says
    // why, for the failed view
    private(set) var capture: CaptureController?
    private(set) var captureFailure: String?

    // The main window and the one visibility flag derived from it
    private weak var window: NSWindow?
    private(set) var isVisible = true

    init()
    {
        if let backend = makeBackend()
        {
            let controller = CaptureController(backend: backend,
                                               model: display,
                                               settings: settings)

            // The traces take a snapshot only on the refresh hop, and
            // keep nothing of its buffers beyond this turn
            let display = display
            let traces = traces
            var signalled = 0
            controller.onSnapshot =
            {
                if display.traceRefresh
                {
                    traces.refresh($0)
                }

                if display.readoutTick != signalled
                {
                    signalled = display.readoutTick
                    Signposts.hop(signalled)
                }
            }

            capture = controller
        }

        // The first activation is the first start and the permission
        // request (R30); later ones retry a denied, absent or failed input
        observe(NSApplication.didBecomeActiveNotification)
        {
            $0.capture?.activate()
        }

        observe(NSApplication.didHideNotification)
        {
            $0.updateVisibility()
        }

        observe(NSApplication.didUnhideNotification)
        {
            $0.updateVisibility()
        }

        observe(NSWindow.didChangeOcclusionStateNotification)
        {
            $0.updateVisibility()
        }
    }

    // makeBackend: a file or tone when the launch asks for one with
    // -InputSource (R10), the default input otherwise. The flag is
    // read from the argument domain and never saved (R11). A bad value
    // or an unreadable file is the capture failure, shown in the window.
    private func makeBackend() -> (any CaptureBackend)?
    {
        do
        {
            let arguments = UserDefaults.standard.volatileDomain(
              forName: UserDefaults.argumentDomain)
            if let spec = try InputSource.source(arguments: arguments)
            {
                return try SourceBackend(spec, settings: RunSettings(settings))
            }

            return try EngineBackend()
        }

        catch let error as SourceError
        {
            captureFailure = error.message
        }

        catch let error as CaptureError
        {
            captureFailure = error.message
        }

        catch
        {
            captureFailure = "\(error)"
        }

        return nil
    }

    // observe: run an action on the main actor for each notification
    private func observe(_ name: Notification.Name,
                         _ action: @escaping (AppModel) -> Void)
    {
        Task
        {
            [weak self] in
            for await _ in NotificationCenter.default.notifications(named: name)
            {
                guard let self else
                {
                    return
                }

                action(self)
            }
        }
    }

    // attach: the main window, reported by the root view
    func attach(window: NSWindow)
    {
        self.window = window
        updateVisibility()
    }

    // updateVisibility: visible means the window shows on screen and
    // the app is not hidden; a minimised or covered window is occluded
    private func updateVisibility()
    {
        guard let window else
        {
            return
        }

        let visible = window.occlusionState.contains(.visible) &&
                      !NSApplication.shared.isHidden
        if visible != isVisible
        {
            isVisible = visible
        }

        capture?.setVisible(visible)
    }

    // mainArea: the tuner, or the status view that replaces it
    var mainArea: MainArea
    {
        return MainArea(state: capture?.state, failure: captureFailure)
    }

    // canCopy: the display holds a reading (R18)
    var canCopy: Bool
    {
        return display.copyLine(transpose: settings.transpose) != nil
    }

    // toggleLock
    func toggleLock()
    {
        display.isLocked.toggle()
    }

    // toggleStrobe: the strobe and the staff replace each other
    func toggleStrobe()
    {
        settings.strobe.toggle()
    }

    // copyReadout: the readout line to the pasteboard; nothing in blank
    func copyReadout()
    {
        guard let line = display.copyLine(transpose: settings.transpose)
        else
        {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(line, forType: .string)
    }
}
