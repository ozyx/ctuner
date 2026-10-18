# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A musical instrument strobe tuner (by Bill Farmer, GPLv3) with three independent native ports. There is no shared code between ports; each is a self-contained GUI app with its own copy of the FFT/peak-detection pipeline and its own temperament table. The Mac app is the Swift package at the repo root (`Sources/`, `App/`).

| Dir | Platform | Language / toolkit | Status |
| --- | --- | --- | --- |
| `Sources/`, `App/` | macOS 26+ (arm64) | SwiftUI window on a C core, with AVAudioEngine capture | Current Mac app; most active |
| `linux/` | Linux | C++, GTK3 + ALSA (`tuner.cpp`); `tuner.c` is an older GTK2 version | Current |
| `mac/` | macOS 10.4 (i386, Carbon) | C | Legacy, superseded by the package at the root |

`docs/` is a generated Hugo site (GitHub Pages), not source. CI is `.github/workflows/build.yml`. `docs/solutions/` holds documented solutions to past problems (bugs, best practices, workflow patterns), organized by category with YAML frontmatter (module, tags, problem_type).

## Build commands

Everything is plain `make`. The Swift package at the repo root holds the app, the analysis core, its capture layer, the platform-free state layer and their tests; the root `Makefile` wraps it.

```sh
# Swift package (repo root) — Command Line Tools are enough
make test                   # swift test, debug
make test-release           # swift test, release (the shipped optimisation level)
make sanitize               # address+undefined, then thread
make core-check             # the core warning-free under -Wall -Wextra, no Cocoa/ObjC/logging symbols
make core-leaks             # the engine's start/stop/destroy lifecycle 100 times under leaks
make build                  # release build of every product, the app's TunerApp product included
make app                    # bundle the release TunerApp (SwiftUI) product as .build/Tuner.app, ad hoc signed as Tuner
make dmg                    # .build/Tuner-<version>.dmg: the app, an Applications link and App/README.md (version read from App/Info.plist)
make fixtures               # rewrite the golden fixtures from the frozen engine
make fixture-screen         # check every fixture holds across builds and sanitizers
make tone-checks            # tuner-run over known tones, each row asserting its exit code (CI runs it)
.build/release/tuner-run tone:A4+7 --target A4+7   # headless reading of a tone or file:PATH; exit 0 pass, 1 fail, 2 usage

# Linux
cd linux && make            # needs libgtk-3-dev libasound2-dev
```

Bundling from the package: `make app` builds the release `TunerApp` product (the SwiftUI window) and runs `Scripts/package-app.sh`, which copies the executable and the named resource bundles, copies `App/Info.plist`, writes `PkgInfo`, builds the icon from `App/Tuner.png` with `sips` and `iconutil`, and signs ad hoc with no entitlements and no hardened runtime. The script names the executable and signs with `--identifier Tuner` from `App/Info.plist`, not the bundle identifier, because the microphone grant is tied to the signature, so `TunerApp` bundles as `Tuner`.

Golden fixtures: `Tests/TunerCoreTests/Fixtures/` holds committed inputs and the per-hop output of a frozen copy of today's engine (`Sources/GoldenReference/Reference/`, unmodified except one hook line). Never edit the frozen copy to match a change in the new core; the fixtures are what the new core is judged against. Their format and the known sanitizer reports are in that directory's `README.md`.

Package notes: on the Command Line Tools, `swift test` finds the Swift Testing macro plugin only about half the time, so the root `Makefile` adds `-plugin-path` for it when `xcode-select -p` is the Command Line Tools and leaves it out on an Xcode toolchain such as CI's. Run tests through `make`, not bare `swift test`. No target may use `unsafeFlags`; compiler policy goes in pragmas and attributes in source, so the library products stay usable as dependencies.

Linux notes: use the plain `Makefile`, not autoconf. Running `./configure` overwrites `Makefile` with one that doesn't work; `Makefile.de` is the backup.

## Swift app architecture

The rewrite plan is `docs/plans/2026-10-16-1644-feat-mac-native-rewrite-plan.md`; the old AppKit app and its AUHAL capture are gone.

Package targets, dependencies pointing one way (app to state to core and capture):

- `TunerCore` (C on Accelerate, no Cocoa, no globals): the analysis engine behind an opaque handle. It owns its analysis thread; capture pushes samples into a wait-free ring (`TunerEnginePush`), and each hop is published to a triple buffer that one consumer reads with `TunerEngineAcquire`. Settings are atomics set through `TunerEngineSet...`.
- `TunerCapture` (Objective-C): `CaptureEngineCreate`/`CaptureEngineStart`/`CaptureEngineStop`/`CaptureEngineDestroy` and `CaptureEngineInputRate`: an `AVAudioEngine` with a sink node on the input node at the device's own rate, which it never changes, and a C callback for the configuration-change notification. Both audio-thread blocks are formed in Objective-C, never in Swift, and the file compiles with and without ARC (see `docs/solutions/developer-experience/realtime-sink-initializer-objc-only.md`).
- `TunerSource` (Swift, links AVFAudio, not a product): `file:`/`tone:` source descriptions, tone synthesis, the WAV reader, the real-time feeder, the headless run and its pass/fail verdict. The `tuner-run` executable (`TunerRun`) is its command line.
- `TunerState` (Swift, no AppKit): `Engine` (wraps the handle; `start(onHop:)` runs its callback on the analysis thread; `acquire()` returns a `Snapshot` whose scope and spectrum buffers are valid only until the next acquire), `DisplayModel` (the blank/live/stale/locked state machine: readout cadence, 1.5 s stale, lock, meter smoothing, the every-16th-hop trace refresh, the copy line, the staff note), `Settings` (every setting, written to `UserDefaults` as it changes and forwarded to an attached engine; reads today's nine legacy keys on first launch), `Notes`, `Temperaments`, and `CaptureController` (the capture lifecycle behind the `CaptureBackend` protocol, which `EngineBackend` implements on the shim: microphone permission with restricted counted as denied, the no-input-device state, a fresh `Engine` at each new rate, a restart with a blank unlocked display on a configuration change, a retry of a failed start on activation or configuration change, and a pause 3 s after the window stops being visible; nothing starts while the window is hidden). Its tests drive it on a fake backend and clock.
- `TunerApp` (SwiftUI executable, Swift 6, main-actor default isolation; `Sources/TunerApp/`): the app. A `Window` scene with a unified toolbar and an inspector, a `Settings` scene, and menu `Commands` carrying the bare-letter shortcuts. `AppModel` is the `@Observable` model in the environment, owning `Settings` and `DisplayModel`; the readout, meter, staff and note filter are real panes (U11), the strobe is a Core Animation layer view (U16: `StrobeLayerView` draws four band layers once and one repeating additive animation moves them, `StrobeMotion` in `TunerState` decides when it is replaced and where it restarts), and the scope and spectrum are canvases (U17) that redraw from `TraceStore`, which `AppModel` fills from `onSnapshot` on the trace refresh hop; `SpectrumAxis` and `ScopeTrace` in `TunerState` hold their axis, decimation, trigger and clamp arithmetic. The Command Line Tools lack the `@State` macro, so view-local state uses the `LocalState` alias. Files importing both SwiftUI and `TunerState` write `TunerState.Settings`, because SwiftUI has its own `Settings` scene.

The app links against the Swift runtime that ships with macOS and nothing is bundled, so the Command Line Tools are enough to build it; no Xcode install is needed. The package floor is macOS 26, so the app needs macOS 26.

## Conventions

- Every change ships as a pull request against `master`. Do the work in a git worktree on a feature branch (the `ce-worktree` skill sets one up), and never commit to or push `master` directly. CI builds the macOS and Linux apps on each pull request. Worktree directories (`.claude/worktrees/`, `.worktrees/`) are dot-directories, so `.gitignore` already ignores them. Older plans in `docs/plans/` that say the implementer "commits to `master` and pushes" record how that work shipped, not the current workflow.
- Version lives in `App/Info.plist` (`CFBundleShortVersionString`). `make dmg` names the DMG from it and CI uploads that DMG; `make app` bundles the same plist.
- Keyboard shortcuts and click actions per view are documented in `App/README.md`; keep them in sync with `Commands.swift`, the toolbar and the pane clicks when changing behaviour.
- Build artifacts (`*.app`, `*.dmg`, `*.o`) are gitignored; `.gitignore` also ignores all dotfiles, so new dot-directories need an explicit `!` entry.
- After a solved, verified problem, automatically invoke the `ce-compound` skill with `mode:non-interactive` at the completion checkpoint only when the work produced durable project reasoning that is not readily recoverable from the final code, tests, types, comments, or existing documentation, and losing it would plausibly cause recurrence, material risk, or substantial rediscovery. Apply this counterfactual: if the learning document disappeared, would a future engineer reading the final implementation still be likely to repeat the mistake or redo substantial investigation? If not, do not invoke it. Completion, effort, and diff size alone are not enough. Capture at the checkpoint so a qualifying learning can ship in the PR that produced it, and only where the repository treats captured learnings as tracked, committed knowledge.
- Write every report, summary, or handoff to the user through the `ce-noslop` skill. This applies when you are the top-level agent writing to the user, not when you are a subagent reporting to its caller. Do not apply it to code, config, verbatim quotes, or text the user asked to post as written.
