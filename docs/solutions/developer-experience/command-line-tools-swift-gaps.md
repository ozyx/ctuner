---
title: What the Command Line Tools alone cannot do for the Swift package
date: 2026-10-17
category: developer-experience
module: package
problem_type: build_error
component: tooling
symptoms:
  - "`swift test` fails about half the time on the Command Line Tools because the Testing macro plugin isn't found"
  - "`@State` and `@Entry` do not compile in a SwiftUI target"
  - "The Swift Testing bundle can't run under `leaks`"
root_cause: missing_tooling
resolution_type: workaround
severity: medium
framework_version: Command Line Tools with Swift 6.4, Apple clang 21, macOS 27 SDK
tags: [command-line-tools, swift-testing, macro-plugin, swiftui, state, leaks, makefile]
---

# What the Command Line Tools alone cannot do for the Swift package

## Problem

The plan builds and tests the Mac app with the Command Line Tools only, without Xcode. They build SwiftUI apps and run Swift Testing (checked on the owner's Mac on 2026-10-16), but three things fail in ways the code doesn't explain. XCTest, `xcodebuild`, `actool`, `xcrun metal` and the iOS SDK aren't there at all.

## 1. `swift test` finds the Testing macro plugin only some of the time

Bare `swift test` fails about half the time on the Command Line Tools because it can't find the Swift Testing macro plugin. Passing the plugin directory explicitly makes it reliable:

```sh
swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```

The root `Makefile` adds the flag (`TESTINGPLUGIN`) only when `xcode-select -p` resolves to `/Library/Developer/CommandLineTools`. On an Xcode toolchain, such as CI's, the flake doesn't happen, and the path would point at a different toolchain from the one compiling, so the flag is left out there. Run tests through `make test`, `make test-release` and `make sanitize`, not bare `swift test`.

The flag can't go in `Package.swift`: no target may use `unsafeFlags`, so the library products stay usable as dependencies.

## 2. SwiftUI's `@State` and `@Entry` macros don't compile

The Command Line Tools ship SwiftUI but not its macro plugin, so the macro forms of `@State` and `@Entry` don't compile. A plain property wrapper reached through a type alias does, because it doesn't need the plugin:

```swift
typealias LocalState<V> = SwiftUI.State<V>

@LocalState private var count = 0
```

This doesn't matter in stage 1, which has no SwiftUI. It applies to the later SwiftUI stages.

## 3. `leaks` can't run the test bundle

`leaks --atExit` drops the framework search path that the Swift Testing framework loads from, so the test bundle can't load under it on the Command Line Tools. `make core-leaks` builds `Scripts/core-leaks.c`, a small C driver that runs the engine's create, start, push, stop and destroy cycle 100 times against the core's objects, and runs that under `leaks --atExit` with `MallocStackLogging=1`. `leaks` exits non-zero when anything leaks.

## Prevention

- Add new test entry points to the root `Makefile` with `$(TESTINGPLUGIN)`, not as bare `swift test`.
- In SwiftUI code built here, use `LocalState` (or another alias) in place of `@State`, and avoid `@Entry`.
- Put new lifecycle leak checks in a plain executable like `Scripts/core-leaks.c`, not in a Swift Testing test.
