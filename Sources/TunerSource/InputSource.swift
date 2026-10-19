//
//  InputSource.swift
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
//  The -InputSource launch flag (R10): the app's sound from a file or a
//  tone instead of the microphone. It is read once from the argument
//  domain, which holds the launch arguments and is never saved, and
//  nothing here writes it, so the next launch uses the microphone
//  (R11, KTD11).

import Foundation
import TunerState

public enum InputSource
{
    // The launch argument's name
    public nonisolated static let key = "InputSource"

    // source: the source a launch asks for, nil when it asks for none.
    // arguments is UserDefaults' argument domain.
    public nonisolated static func source(arguments: [String: Any])
      throws(SourceError) -> SourceSpec?
    {
        guard let value = arguments[key] else
        {
            return nil
        }

        guard let text = value as? String, !text.isEmpty else
        {
            throw SourceError("-\(key) needs file:<path> or tone:<spec>, "
                              + "not \"\(value)\"")
        }

        return try SourceSpec.parse(text)
    }
}

extension RunSettings
{
    // init: the app settings a source's notes resolve against (R2)
    @MainActor
    public init(_ settings: Settings)
    {
        self.init()
        reference = settings.reference
        temperament = settings.temperament
        key = settings.key
    }
}
