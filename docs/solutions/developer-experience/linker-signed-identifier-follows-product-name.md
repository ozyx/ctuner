---
title: The app's signing identifier comes from the SwiftPM product name
date: 2026-10-17
category: developer-experience
module: swift
problem_type: configuration_error
component: build
symptoms:
  - "`codesign -dv Tuner.app` shows the identifier TunerAppKit, where the old build had Tuner"
root_cause: config_error
resolution_type: config_change
severity: high
framework_version: SwiftPM on the Command Line Tools, macOS 27 SDK, ad-hoc linker signing
tags: [codesign, linker-signed, bundle-identifier, tcc, microphone, swiftpm, product-name]
---

# The app's signing identifier comes from the SwiftPM product name

## Problem

Stage 1 builds the app as a SwiftPM executable, with no entitlements and no separate signing step: the linker signs the binary ad hoc. The linker uses the product's name as the signing identifier. The first build named the product `TunerAppKit`, after its target, so the bundled app was signed as `TunerAppKit`, where today's app is signed as `Tuner`.

The microphone permission is tied to the app's code signature. A changed identifier risks a new microphone prompt or a lost grant, and the plan stops on any signing change that could cause that.

## Solution

Commit `78ef466` names the product `Tuner` and leaves the target as `TunerAppKit` (`Package.swift`; `swift/Makefile` builds `PRODUCT = Tuner`). Check the result with:

```sh
codesign -dv swift/Tuner.app 2>&1 | grep Identifier
```

## Prevention

- Don't rename the app's executable product. The target name is free to change; the product name sets the identifier.
- Check `codesign -dv` after any change to `Package.swift` products or to `swift/Makefile`.
- `CFBundleIdentifier` in `swift/Info.plist` is a separate setting, which the saved settings (`UserDefaults`) depend on. Keep both unchanged.
