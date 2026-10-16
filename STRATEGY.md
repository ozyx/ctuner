---
name: Tuner
last_updated: 2026-10-16
---

# Tuner Strategy

## Purpose

I play and tune a variety of instruments on a current Mac and want a strobe tuner whose build I own. Upstream's Mac app is pinned to macOS 10.12 and an old Xcode library layout, so each new macOS or Xcode release risks it no longer building or running.

## Positioning

Mac-only, tracking current macOS, keeping Bill Farmer's Objective-C audio engine as-is and modernising the Swift shell around it. Not a rewrite, not a multi-platform project, so that the app keeps building with the least ongoing work.

## Users

**Primary:** Me, tuning a variety of instruments to both Western and non-Western temperaments. I'm hiring Tuner to tune to notes with specific cent modifications on the Mac I own today.

## Boundaries

- No Xcode project or Swift Package; the build stays plain `make`, with the paths fixed.
- No work on the Linux port. It stays in the tree and CI as untouched legacy.
- No code signing or notarization for now; ad-hoc local builds are enough.
- No pure-Swift rewrite of the audio engine; `Audio.swift` stays parked.

_Resist a change when:_ it adds a toolchain, platform, or distribution step that the Mac app running on my own machine does not need.

## Key metrics

- **Builds clean on current macOS and Xcode** - `make` from a fresh checkout on the latest macOS and Xcode with no deprecated-API warnings; measured in CI on `macos-latest`.
- **Runs on latest macOS with mic permission** - app launches, gets microphone access, and shows a live spectrum on the current macOS release; manual check after each macOS update.
- **Tunes to a cent-offset target accurately** - against a generated reference tone, displayed cents are within tolerance for the chosen temperament and offset; manual test with a reference tone.

## Tracks

### Drop Windows cross-compilation

Remove the Windows port and its mingw CI job; CI builds the Mac app (Linux stays as legacy).

_Why it serves the approach:_ every platform not built is one less thing that can break the Mac build.

### Modern macOS build and runtime

Raise the deployment target, fix the hard-coded Xcode dylib path, add mic privacy entitlements, retire deprecated AppKit and CoreAudio APIs, and make temperaments and per-note cent offsets editable in Preferences.

_Why it serves the approach:_ this is the rot being fixed, plus the one feature the primary user needs.

### Engine correctness checks

A reference-tone harness or light tests so changes around the engine can be verified without ear-checking.

_Why it serves the approach:_ keeping the engine untouched only holds if regressions around it are caught.
