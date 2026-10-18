// swift-tools-version:6.2
//
//  Package.swift
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

import PackageDescription

// No target carries unsafe flags: a package that does cannot be used
// as a dependency, and the later iOS project depends on the three
// library products. Compiler policy lives in pragmas and attributes
// in source instead.
let package = Package(
    name: "Tuner",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "TunerCore", targets: ["TunerCore"]),
        .library(name: "TunerCapture", targets: ["TunerCapture"]),
        .library(name: "TunerState", targets: ["TunerState"]),
        .executable(name: "tuner-run", targets: ["TunerRun"]),
        .executable(name: "GoldenGenerator", targets: ["GoldenGenerator"]),
        .executable(name: "GoldenReference", targets: ["GoldenReference"]),
        // The SwiftUI window, bundled and signed as Tuner by
        // Scripts/package-app.sh
        .executable(name: "TunerApp", targets: ["TunerApp"]),
    ],
    targets: [
        // The analysis engine: plain C on Accelerate, no Cocoa
        .target(
            name: "TunerCore",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("Accelerate")]),

        // Audio capture: a leaf that depends on nothing in the package
        .target(
            name: "TunerCapture",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("AVFAudio"),
            ]),

        // Platform-free Swift: engine wrapper, display model, settings
        .target(
            name: "TunerState",
            dependencies: ["TunerCore", "TunerCapture"]),

        // Sound sources for the tuner: tones and files, the headless
        // run and its verdict. Not a product; the executables and, later,
        // the app link it.
        .target(
            name: "TunerSource",
            dependencies: ["TunerState"],
            linkerSettings: [.linkedFramework("AVFAudio")]),

        // The SwiftUI window on the same state layer
        .executableTarget(
            name: "TunerApp",
            dependencies: ["TunerState"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .defaultIsolation(MainActor.self),
            ]),

        // Prints the tuner's readings for a tone or a file and can pass
        // or fail them against a target note
        .executableTarget(
            name: "TunerRun",
            dependencies: ["TunerSource"]),

        // Writes deterministic float32 fixture inputs
        .executableTarget(name: "GoldenGenerator"),

        // Runs the frozen copy of today's engine over a fixture input
        .executableTarget(
            name: "GoldenReference",
            exclude: ["Reference"],
            linkerSettings: [
                .linkedFramework("Cocoa", .when(platforms: [.macOS])),
                .linkedFramework("AudioToolbox", .when(platforms: [.macOS])),
                .linkedFramework("CoreAudio", .when(platforms: [.macOS])),
                .linkedFramework("Accelerate", .when(platforms: [.macOS])),
            ]),

        .testTarget(
            name: "TunerCoreTests",
            dependencies: ["TunerCore", "TunerCapture", "TunerState"],
            resources: [.copy("Fixtures")]),

        .testTarget(
            name: "TunerStateTests",
            dependencies: ["TunerState"]),

        .testTarget(
            name: "TunerSourceTests",
            dependencies: ["TunerSource", "TunerState"]),
    ]
)
