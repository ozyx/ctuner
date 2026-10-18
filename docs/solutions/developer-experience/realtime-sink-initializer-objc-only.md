---
title: The realtime-safe sink initializer is Objective-C only, and SwiftPM's two build systems disagree on ARC
date: 2026-10-17
category: developer-experience
module: TunerCapture
problem_type: build_error
component: capture
symptoms:
  - "`initWithRealtimeSafeReceiverBlock:` and `AVAudioSinkNodeReceiverBlockRealtimeSafe` can't be used from Swift"
  - "CI's SDK 26 doesn't declare the realtime-safe initializer at all"
  - "`swift build -v` shows no `-fobjc-arc` on the Objective-C files, but `--build-system native` shows it"
root_cause: platform_constraint
resolution_type: workaround
severity: high
framework_version: Swift 6.4 on the Command Line Tools with the macOS 27 SDK; CI on Xcode 26.6 with SDK 26
tags: [avaudioengine, avaudiosinknode, realtime, nonblocking, swift-unavailable, sdk-guard, objc-arc, swiftbuild, swiftpm]
---

# The realtime-safe sink initializer is Objective-C only, and SwiftPM's two build systems disagree on ARC

## Problem

Stage 2 captures through `AVAudioEngine` and an `AVAudioSinkNode` on the input node. Two things about the sink can't be read off the final code.

1. The macOS 27 SDK adds `initWithRealtimeSafeReceiverBlock:` and its block type `AVAudioSinkNodeReceiverBlockRealtimeSafe`. Both are marked `__SWIFT_UNAVAILABLE_MSG("Swift is not supported for use with audio realtime threads")`, and the block type carries `CA_REALTIME_API`, which is clang's `nonblocking` attribute. Swift can't call the initializer or form the block. The macOS 26 SDK, which CI compiles against, doesn't declare either one.
2. The shim that forms the blocks is Objective-C in the `TunerCapture` target. SwiftPM's default build system (swiftbuild, on Swift 6.4) compiles Objective-C targets **without** `-fobjc-arc`. The deprecated native build system, `swift build --build-system native`, compiles them **with** it. CI's toolchain may use either, so the same file must be correct under both memory models.

## Solution

`Sources/TunerCapture/CaptureEngine.m`:

- The SDK check is `#if defined(__MAC_27_0) || defined(__IPHONE_27_0)`, and inside it `if (@available(macOS 27.0, iOS 27.0, *))` picks the realtime-safe initializer. Otherwise the shim uses `initWithReceiverBlock:`, and so does CI's SDK 26 build. Both block literals are written in Objective-C. The realtime one is annotated `CAPTURE_NONBLOCKING`, so `-Wfunction-effects` checks what it calls.
- The C push callback and the configuration-change callback that Swift hands in are file-scope `let` constants in `CaptureController.swift`, not closures written inside a `@MainActor` method, so no main-actor isolation check can reach the audio thread.
- Every Objective-C object the shim keeps is a `CFTypeRef` in a plain C struct. An `Adopt` macro takes ownership of an `alloc`/`new` result: `CFBridgingRetain` under ARC, a bare `__bridge` cast without it. Any other object is kept with `CFBridgingRetain`, and `CFRelease` lets go. These calls mean the same under both build systems. An Objective-C class with ivars and `__bridge_retained`/`__bridge_transfer` would leak, or over-release an observer it never retained, under the build system without ARC.

Check both build systems after editing the shim:

```sh
swift build --target TunerCapture
swift build --build-system native --target TunerCapture --scratch-path /tmp/native
swift build --target TunerCapture -v 2>&1 | grep 'CaptureEngine.m' | grep -c fobjc-arc   # 0 on swiftbuild
```

## Prevention

- Form any block that runs on the audio thread in Objective-C, never in Swift.
- Guard every macOS 27 audio API twice: by SDK at compile time and by `@available` at run time. CI's DMG uses the SDK 26 path, so U12 checks that DMG on the owner's Mac.
- In `TunerCapture`, don't write code that depends on ARC being on or off. Hold objects through Core Foundation, or check both build systems.
- The package can't simply turn ARC on: `-fobjc-arc` would need `unsafeFlags`, which would stop the library products from being used as dependencies (KTD2).
