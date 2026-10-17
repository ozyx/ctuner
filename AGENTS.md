# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A musical instrument strobe tuner (by Bill Farmer, GPLv3) with three independent native ports in sibling directories. There is no shared code between ports; each is a self-contained GUI app with its own copy of the FFT/peak-detection pipeline and its own `Temperaments.h`.

| Dir | Platform | Language / toolkit | Status |
| --- | --- | --- | --- |
| `swift/` | macOS 14+ (arm64) | Swift + Objective-C, AppKit, CoreAudio, Accelerate | Current Mac app; most active |
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
make build                  # release build of every product
make fixtures               # rewrite the golden fixtures from the frozen engine
make fixture-screen         # check every fixture holds across builds and sanitizers

# macOS (Swift app) — builds an arm64 binary and Tuner.app
cd swift && make            # Tuner.app
cd swift && make dmg        # Tuner-<version>.dmg (version read from Info.plist)
cd swift && make clean

# Linux
cd linux && make            # needs libgtk-3-dev libasound2-dev
```

Golden fixtures: `Tests/TunerCoreTests/Fixtures/` holds committed inputs and the per-hop output of a frozen copy of today's engine (`Sources/GoldenReference/Reference/`, unmodified except one hook line). Never edit the frozen copy to match a change in the new core; the fixtures are what the new core is judged against. Their format and the known sanitizer reports are in that directory's `README.md`.

Package notes: on the Command Line Tools, `swift test` finds the Swift Testing macro plugin only about half the time, so the root `Makefile` adds `-plugin-path` for it when `xcode-select -p` is the Command Line Tools and leaves it out on an Xcode toolchain such as CI's. Run tests through `make`, not bare `swift test`. No target may use `unsafeFlags`; compiler policy goes in pragmas and attributes in source, so the library products stay usable as dependencies.

Linux notes: use the plain `Makefile`, not autoconf. Running `./configure` overwrites `Makefile` with one that doesn't work; `Makefile.de` is the backup.

## Swift app architecture (`swift/`)

The audio engine is Objective-C; the UI is Swift. They talk through globals, not objects.

- `Audio.m` / `Audio.h`: CoreAudio HAL input unit, `InputProc` callback, and the `ProcessAudio` block that runs the overlapped FFT (vDSP), phase-difference frequency measurement, Butterworth filter, optional downsampling, and peak detection (up to `kMaxima` = 8). Results are written into global structs declared in `Audio.h`: `scope`, `spectrum`, `disp` (maxima), `audio` (settings such as `reference`, `temper`, `key`, `filt`, `down`, `fund`, `note`), and `filters` (per-note/per-octave enable flags).
- Swift views read those globals directly. `TunerView.swift` is the base `NSView` (shared note names, edge drawing); `ScopeView`, `SpectrumView`, `DisplayView`, `StrobeView`, `StaffView`, `MeterView` subclass it. `Audio.h` also declares global pointers (`scopeView`, `spectrumView`, ...) that the C side uses to request redraws.
- `AppDelegate.swift` builds the whole UI in code (no nibs/xibs; the menu is also nibless, see `main.swift`), starts audio via `SetupAudio()`, runs a 20 ms `Timer` that marks meter/strobe views dirty, and owns the Preferences window and note-filter panel. Settings changes write straight to the `audio` global and call `needsDisplay` on affected views.
- Constants (sample rate, FFT size `kSamples`, four-char-code tags for controls) live in `Audio.h` and are visible to Swift through `Tuner-Bridging-Header.h`.

Two-way bridging gotcha: `Audio.h` includes `Tuner-Swift.h`, which `swiftc` generates (`-emit-objc-header-path`) from the Swift sources. The generated header is committed so `Audio.m` can compile first. If you add or rename Swift classes/members that ObjC relies on, rebuild and commit the regenerated `Tuner-Swift.h`.

`Audio.swift` is an unfinished Swift port of `Audio.m`. It is not in the Makefile's `SOURCES` and does not compile; ignore it unless you are deliberately continuing that port.

The app links against the Swift runtime that ships with macOS and nothing is bundled, so the Command Line Tools are enough to build it; no Xcode install is needed.

## Conventions

- Every change ships as a pull request against `master`. Do the work in a git worktree on a feature branch (the `ce-worktree` skill sets one up), and never commit to or push `master` directly. CI builds the macOS and Linux apps on each pull request. Worktree directories (`.claude/worktrees/`, `.worktrees/`) are dot-directories, so `.gitignore` already ignores them. Older plans in `docs/plans/` that say the implementer "commits to `master` and pushes" record how that work shipped, not the current workflow.
- Version lives in `swift/Info.plist` (`CFBundleShortVersionString`); `make dmg` names the DMG from it and CI uploads whichever DMG that produces.
- Keyboard shortcuts and click actions per view are documented in `swift/README.md`; keep them in sync with `keyDown`/`mouseDown` handlers when changing behaviour.
- Build artifacts (`*.app`, `*.dmg`, `*.o`) are gitignored; `.gitignore` also ignores all dotfiles, so new dot-directories need an explicit `!` entry.
- After a solved, verified problem, automatically invoke the `ce-compound` skill with `mode:non-interactive` at the completion checkpoint only when the work produced durable project reasoning that is not readily recoverable from the final code, tests, types, comments, or existing documentation, and losing it would plausibly cause recurrence, material risk, or substantial rediscovery. Apply this counterfactual: if the learning document disappeared, would a future engineer reading the final implementation still be likely to repeat the mistake or redo substantial investigation? If not, do not invoke it. Completion, effort, and diff size alone are not enough. Capture at the checkpoint so a qualifying learning can ship in the PR that produced it, and only where the repository treats captured learnings as tracked, committed knowledge.
- Write every report, summary, or handoff to the user through the `ce-noslop` skill. This applies when you are the top-level agent writing to the user, not when you are a subagent reporting to its caller. Do not apply it to code, config, verbatim quotes, or text the user asked to post as written.
