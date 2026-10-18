//
//  LocalState.swift
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
//  The Command Line Tools lack the macro plugin behind SwiftUI's
//  @State, so view-local state goes through this alias of the
//  property wrapper (docs/solutions/developer-experience/
//  command-line-tools-swift-gaps.md).

import SwiftUI

typealias LocalState<V> = SwiftUI.State<V>
