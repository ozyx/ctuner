# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A musical instrument strobe tuner (by Bill Farmer, GPLv3) with three independent native ports in sibling directories. There is no shared code between ports; each is a self-contained GUI app with its own copy of the FFT/peak-detection pipeline and its own temperament table. The Mac app's engine now lives in the Swift package at the repo root (`Sources/`).

| Dir | Platform | Language / toolkit | Status |
| --- | --- | --- | --- |
| `swift/` | macOS 26+ (arm64) | Swift AppKit window on the package's C core and AUHAL capture | Current Mac app (stage 1); most active |
| `linux/` | Linux | C++, GTK3 + ALSA (`tuner.cpp`); `tuner.c` is an older GTK2 version | Current |
| `mac/` | macOS 10.4 (i386, Carbon) | C | Legacy, superseded by `swift/` |

`docs/` is a generated Hugo site (GitHub Pages), not source. CI is `.github/workflows/build.yml`. `docs/solutions/` holds documented solutions to past problems (bugs, best practices, workflow patterns), organized by category with YAML frontmatter (module, tags, problem_type).

## Build commands

Everything is plain `make`. The Swift package at the repo root holds the new analysis core, its capture layer, the platform-free state layer and their tests; the root `Makefile` wraps it.

```sh
# Swift package (repo root) — Command Line Tools are enough
make test                   # swift test, debug
make test-release           # swift test, release (the shipped optimisation level)
make sanitize               # address+undefined, then thread
make core-check             # the core warning-free under -Wall -Wextra, no Cocoa/ObjC/logging symbols
make core-leaks             # the engine's start/stop/destroy lifecycle 100 times under leaks
make build                  # release build of every product, the app's Tuner product included
make app                    # bundle the release TunerApp (SwiftUI) product as .build/Tuner.app, ad hoc signed as Tuner
make fixtures               # rewrite the golden fixtures from the frozen engine
make fixture-screen         # check every fixture holds across builds and sanitizers
make tone-checks            # tuner-run over known tones, each row asserting its exit code (CI runs it)
.build/release/tuner-run tone:A4+7 --target A4+7   # headless reading of a tone or file:PATH; exit 0 pass, 1 fail, 2 usage

# macOS (Swift app) — swift build -c release --product Tuner at the
# repo root, then bundles that binary as Tuner.app
cd swift && make            # Tuner.app
cd swift && make dmg        # Tuner-<version>.dmg (version read from Info.plist)
cd swift && make clean

# Linux
cd linux && make            # needs libgtk-3-dev libasound2-dev
```

Bundling from the package: `make app` builds the release `TunerApp` product (the SwiftUI window) and runs `Scripts/package-app.sh`, which copies the executable and the named resource bundles, copies `App/Info.plist` (today's `swift/Info.plist` without `NSMainNibFile`), writes `PkgInfo`, builds the icon from `App/Tuner.png` with `sips` and `iconutil`, and signs ad hoc with no entitlements and no hardened runtime. The script names the executable and signs with `--identifier Tuner` from `App/Info.plist`, not the bundle identifier, because the microphone grant is tied to the signature, so `TunerApp` bundles as `Tuner`. `cd swift && make` and `make dmg` still bundle and ship the stage 1 `Tuner` product (the `TunerAppKit` target, linker-signed as `Tuner`; do not rename it) until U12 deletes `swift/` and moves the name.

Golden fixtures: `Tests/TunerCoreTests/Fixtures/` holds committed inputs and the per-hop output of a frozen copy of today's engine (`Sources/GoldenReference/Reference/`, unmodified except one hook line). Never edit the frozen copy to match a change in the new core; the fixtures are what the new core is judged against. Their format and the known sanitizer reports are in that directory's `README.md`.

Package notes: on the Command Line Tools, `swift test` finds the Swift Testing macro plugin only about half the time, so the root `Makefile` adds `-plugin-path` for it when `xcode-select -p` is the Command Line Tools and leaves it out on an Xcode toolchain such as CI's. Run tests through `make`, not bare `swift test`. No target may use `unsafeFlags`; compiler policy goes in pragmas and attributes in source, so the library products stay usable as dependencies.

Linux notes: use the plain `Makefile`, not autoconf. Running `./configure` overwrites `Makefile` with one that doesn't work; `Makefile.de` is the backup.

## Swift app architecture (`swift/`)

Stage 1 of the rewrite plan (`docs/plans/2026-10-16-1644-feat-mac-native-rewrite-plan.md`): today's AppKit window runs on the package's engine. `swift/` holds only the window's Swift sources and the bundle and DMG rules; the sources compile as the package's `TunerAppKit` executable target (`path: "swift"`, an explicit `sources:` list, Swift 5 language mode). There is no Objective-C in `swift/`, no bridging header and no generated header.

Package targets, dependencies pointing one way (app to state to core and capture):

- `TunerCore` (C on Accelerate, no Cocoa, no globals): the analysis engine behind an opaque handle. It owns its analysis thread; capture pushes samples into a wait-free ring (`TunerEnginePush`), and each hop is published to a triple buffer that one consumer reads with `TunerEngineAcquire`. Settings are atomics set through `TunerEngineSet...`.
- `TunerCapture` (Objective-C): the AUHAL input unit behind `CaptureCreate`/`CaptureStart`/`CaptureStop`/`CaptureDestroy` (`CaptureHAL.m`, what the stage 1 app runs on). Create does all the setup, so `CaptureSampleRate` is known before the engine is made; the input callback only renders and calls the push function it was given. The stage 2 shim (`CaptureEngine.m`, unused until U18) is `CaptureEngineCreate`/`CaptureEngineStart`/`CaptureEngineStop`/`CaptureEngineDestroy` and `CaptureEngineInputRate`: an `AVAudioEngine` with a sink node on the input node at the device's own rate, which it never changes, and a C callback for the configuration-change notification. Both audio-thread blocks are formed in Objective-C, never in Swift, and the file compiles with and without ARC (see `docs/solutions/developer-experience/realtime-sink-initializer-objc-only.md`).
- `TunerSource` (Swift, links AVFAudio, not a product): `file:`/`tone:` source descriptions, tone synthesis, the WAV reader, the real-time feeder, the headless run and its pass/fail verdict. The `tuner-run` executable (`TunerRun`) is its command line.
- `TunerState` (Swift, no AppKit): `Engine` (wraps the handle; `start(onHop:)` runs its callback on the analysis thread; `acquire()` returns a `Snapshot` whose scope and spectrum buffers are valid only until the next acquire), `DisplayModel` (the blank/live/stale/locked state machine: readout cadence, 1.5 s stale, lock, meter smoothing, the every-16th-hop trace refresh, the copy line, the staff note), `Settings` (every setting, written to `UserDefaults` as it changes and forwarded to an attached engine; reads today's nine legacy keys on first launch), `Notes`, `Temperaments`, and the stage 2 `CaptureController` (the capture lifecycle behind the `CaptureBackend` protocol, which `EngineBackend` implements on the shim: microphone permission with restricted counted as denied, the no-input-device state, a fresh `Engine` at each new rate, a restart with a blank unlocked display on a configuration change, a retry of a failed start on activation or configuration change, and a pause 3 s after the window stops being visible; nothing starts while the window is hidden). Nothing uses the controller until U18; its tests drive it on a fake backend and clock.
- `TunerApp` (SwiftUI executable, Swift 6, main-actor default isolation; `Sources/TunerApp/`): the stage 2 window, shell only until U18 adds capture. A `Window` scene with a unified toolbar and an inspector, a `Settings` scene, and menu `Commands` carrying the bare-letter shortcuts. `AppModel` is the `@Observable` model in the environment, owning `Settings` and `DisplayModel`; the readout, meter, staff and note filter are real panes (U11), the strobe is a Core Animation layer view (U16: `StrobeLayerView` draws four band layers once and one repeating additive animation moves them, `StrobeMotion` in `TunerState` decides when it is replaced and where it restarts), and the scope and spectrum are placeholder panes that carry their clicks until U17 replaces them. The Command Line Tools lack the `@State` macro, so view-local state uses the `LocalState` alias. Files importing both SwiftUI and `TunerState` write `TunerState.Settings`, because SwiftUI has its own `Settings` scene.

The window (`swift/`):

- `AppDelegate.swift` builds the whole UI in code (no nibs; the menu is nibless, see `main.swift`) and owns the Preferences window and the note-filter panel. It holds the control tags (four-char codes), the `settings` and `model` globals and the view globals. `startAudio()` creates capture first for its rate, then the `Engine`, attaches it to `settings`, writes the engine handle into the push context and starts capture. The engine's `onHop` posts to the main queue at most once at a time (an atomic flag); `hop()` acquires one snapshot, feeds `model.update`, marks the display and staff dirty when `readoutTick` changes, and on `traceRefresh` copies the scope and spectrum arrays into those views and marks them dirty. A 20 ms `Timer` marks the strobe and meter dirty. Shutdown stops capture, then the engine.
- `TunerView.swift` is the base `NSView` (edge drawing, key handling); `ScopeView`, `SpectrumView`, `DisplayView`, `StrobeView`, `StaffView`, `MeterView` subclass it and draw from `model`, `settings` and the arrays copied into them. Handlers change `settings` or `model.isLocked` and update the matching Preferences control.

The app links against the Swift runtime that ships with macOS and nothing is bundled, so the Command Line Tools are enough to build it; no Xcode install is needed. The package floor is macOS 26, so the app needs macOS 26.

## Conventions

- Every change ships as a pull request against `master`. Do the work in a git worktree on a feature branch (the `ce-worktree` skill sets one up), and never commit to or push `master` directly. CI builds the macOS and Linux apps on each pull request. Worktree directories (`.claude/worktrees/`, `.worktrees/`) are dot-directories, so `.gitignore` already ignores them. Older plans in `docs/plans/` that say the implementer "commits to `master` and pushes" record how that work shipped, not the current workflow.
- Version lives in `swift/Info.plist` and `App/Info.plist` (`CFBundleShortVersionString`, the same value in both); bump both together until U12 deletes `swift/`. `cd swift && make dmg` names the DMG from `swift/Info.plist` and CI uploads whichever DMG that produces; `make app` bundles `App/Info.plist`.
- Keyboard shortcuts and click actions per view are documented in `swift/README.md`; keep them in sync with `keyDown`/`mouseDown` handlers when changing behaviour.
- Build artifacts (`*.app`, `*.dmg`, `*.o`) are gitignored; `.gitignore` also ignores all dotfiles, so new dot-directories need an explicit `!` entry.
- After a solved, verified problem, automatically invoke the `ce-compound` skill with `mode:non-interactive` at the completion checkpoint only when the work produced durable project reasoning that is not readily recoverable from the final code, tests, types, comments, or existing documentation, and losing it would plausibly cause recurrence, material risk, or substantial rediscovery. Apply this counterfactual: if the learning document disappeared, would a future engineer reading the final implementation still be likely to repeat the mistake or redo substantial investigation? If not, do not invoke it. Completion, effort, and diff size alone are not enough. Capture at the checkpoint so a qualifying learning can ship in the PR that produced it, and only where the repository treats captured learnings as tracked, committed knowledge.
- Write every report, summary, or handoff to the user through the `ce-noslop` skill. This applies when you are the top-level agent writing to the user, not when you are a subagent reporting to its caller. Do not apply it to code, config, verbatim quotes, or text the user asked to post as written.
