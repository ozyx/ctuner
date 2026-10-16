---
title: Build the Mac App on the Current Toolchain - Plan
type: fix
date: 2026-10-16
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Build the Mac App on the Current Toolchain - Plan

## Goal Capsule

- **Objective:** Running `make` in `swift/` on a fresh checkout produces a working `Tuner.app` on current macOS with only the Command Line Tools installed, and CI publishes the DMG it actually built.
- **Means:** Raise the deployment target to macOS 14, build arm64 only, and use the Swift runtime that ships with macOS instead of a bundled copy (KTD1, KTD2, KTD3).
- **Authority:** `STRATEGY.md` track "Modern macOS build and runtime" and its metric "Builds clean on current macOS and Xcode" set the scope. This plan's R-IDs own behavior; its KTDs own mechanism.
- **Stop conditions:**
  - Stop and ask if the Swift 6.4 compiler rejects existing source in a way that needs more than a few mechanical edits.
  - Stop and ask if any change to `Audio.m` beyond a recompile turns out to be needed.
  - Stop and ask if GitHub Actions is disabled on the fork, because enabling it is the owner's call.
- **Execution profile:** Build-config and CI edits, deletion of the bundled runtime, and a few doc lines. No app behavior changes.
- **Finishes and ships:** The implementer commits to `master` and pushes, per the fork's no-PR workflow.

---

## Product Contract

### Summary

Rewrite the Swift app's `Makefile` to build a single arm64 binary that targets macOS 14 and links against the system Swift runtime. Delete the committed `swift/Frameworks/` dylibs and the step that copies them from an Xcode path. Make the CI DMG upload follow the version in `Info.plist`, and update the docs that describe the old setup.

### Problem Frame

`swift/Makefile` copies 18 Swift runtime dylibs from `/Applications/Xcode.app/.../swift-5.0/macosx/` into `Frameworks/` on every build, because `Frameworks` is a phony target that depends on that directory. That path exists only with an old full Xcode install. The owner's Mac runs macOS 27 with the Command Line Tools and Swift 6.4, and has no Xcode, so a fresh `make` fails at the copy step. The bundled runtime is a Swift 5.0-era copy (11 MB, committed to git) that the app only needed to run on macOS releases older than 10.14.4.

The CI workflow uploads `swift/Tuner-1.08.dmg`, but `Info.plist` is at 1.09, so the DMG artifact step finds no file. The fork has no CI runs yet, so nothing has caught this.

Until the app builds, none of the other items in the strategy track can start. The microphone entitlement, the deprecated-API cleanup and editable temperaments all depend on it.

### Requirements

**Local build**

- R1. `make` in `swift/` succeeds from a fresh checkout on current macOS with only the Command Line Tools installed, and needs no Xcode path.
- R2. The built `Tuner.app` launches on the owner's Mac and loads its Swift runtime from the OS, with no bundled runtime dylibs.
- R3. `make dmg` produces `Tuner-<version>.dmg` with the version taken from `Info.plist`.
- R4. `make clean` removes every build product the `Makefile` creates.

**CI**

- R5. The `build-macos` job on `macos-latest` builds the app and uploads the DMG that `make dmg` produced, whatever the version in `Info.plist`.

**Docs**

- R6. `AGENTS.md` describes the new platform floor and build setup, with no remaining instructions about `XCODELIB` or bumping the CI DMG name.

### Success Criteria

- The owner can open the built app, grant microphone access and see a live spectrum, which is the strategy metric "Runs on latest macOS with mic permission".

### Scope Boundaries

- Fixing deprecation warnings. The higher deployment target is expected to surface more of them, and the next strategy item handles them.
- Applying `Tuner.entitlements` or any code signing. Signing stays ad-hoc, as the linker already does it.
- The leftover `NSMainNibFile` key in `Info.plist`. The app is nibless and the key is harmless.
- `Audio.swift`, the Linux port, and the generated `docs/` Hugo site.
- No version bump. The minimum macOS changes, but the app's behavior does not.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Deployment target is macOS 14.0 for both the compiler targets and `LSMinimumSystemVersion`.** (session-settled: user-approved — chosen over macOS 11: a higher floor surfaces the deprecation warnings the next strategy item needs to see, and the app only has to run on the owner's current Mac.)
- KTD2. **Build arm64 only, with no `lipo` step.** (session-settled: user-approved — chosen over keeping the x86_64 + arm64 universal binary: macOS 27 does not run on Intel Macs, and one slice halves the build.) The `Makefile` compiles `Audio.m` once to `Audio.o` and links one `Tuner` binary.
- KTD3. **Use the OS Swift runtime and delete the bundled one.** Every macOS release since 10.14.4 ships the Swift runtime in `/usr/lib/swift`, and KTD1 sets the floor well above that. Remove `XCODELIB`, `LIBRARIES`, the `$(FRAMEWORKS)` rule, its `.PHONY` entry, the copy into the bundle, the `-rpath @loader_path/../Frameworks` linker flag, and the `swift/Frameworks/` directory from git.
- KTD4. **Pin `-swift-version 5` and `-module-name Tuner` on the `swiftc` line.** The code predates Swift 6 strict concurrency, and pinning the language mode keeps a future compiler default from breaking the build. Today the module name comes from the `-o` name (`Tuner_arm`), and that name is baked into the mangled class names in the committed `Tuner-Swift.h`. Pinning it makes the generated header stable.
- KTD5. **CI uploads the DMG by glob (`swift/Tuner-*.dmg`) under a fixed artifact name.** This removes the hard-coded version from `.github/workflows/build.yml`. The "bump both together" convention in `AGENTS.md` goes away.

### Research Notes

- `Audio.h:109-114` declares the Swift view classes only as pointer types, and `Audio.m` only sends messages to them. A stale mangled name in `Tuner-Swift.h` therefore cannot break the link. Regenerating the header after the module-name change keeps it accurate, but nothing depends on getting the order right.
- `Audio.h:32` includes `Tuner-Swift.h`, which `swiftc` regenerates on every link (`-emit-objc-header-path`). This build will rewrite it with Swift 6.4 output and the `Tuner` module name, and the regenerated file gets committed per the `AGENTS.md` convention.
- `.gitignore` ignores `*.o`, `*.app` and `*.dmg` but not the linked `swift/Tuner` binary, so a local build leaves it untracked.

---

## Implementation Units

### U1. Build one arm64 binary against the OS Swift runtime

- **Goal:** `make`, `make dmg` and `make clean` work on the Command Line Tools alone and produce an app that uses the system Swift runtime.
- **Requirements:** R1, R2, R3, R4; KTD1, KTD2, KTD3, KTD4.
- **Dependencies:** none.
- **Files:**
  - `swift/Makefile`
  - `swift/Info.plist`
  - `swift/Tuner-Swift.h` (regenerated by the build)
  - `swift/Frameworks/` (delete)
  - `swift/Tuner.icns` (untrack)
  - `.gitignore`
- **Approach:**
  1. In `swift/Makefile`, collapse the x86/arm variable pairs into one `SFLAGS` and one `CFLAGS` targeting `arm64-apple-macos14`. Drop `APPNAMEX86`, `APPNAMEARM` and the `lipo` rule. Add the flags from KTD4 and remove the rpath flag.
  2. Remove everything KTD3 lists. The app bundle rule stops depending on and copying `Frameworks`.
  3. Make `clean` remove `Tuner.app`, `Tuner.icns`, `Tuner`, `Audio.o`, and any `.dmg` the `Makefile` writes. Use `rm -f` so a partial tree doesn't fail it.
  4. Set `LSMinimumSystemVersion` in `swift/Info.plist` to `14.0`.
  5. Remove `swift/Frameworks/` from git.
  6. Untrack `swift/Tuner.icns`, which the `Tuner.icns: Tuner.png` rule regenerates on every build and `clean` deletes. Add it and `swift/Tuner` to `.gitignore`.
  7. Build once and commit the regenerated `swift/Tuner-Swift.h`. It stays tracked and `clean` leaves it alone, because `Audio.m` compiles against it before `swiftc` runs.
- **Patterns to follow:** Keep the existing `Makefile` style, with its tool variables (`RM`, `CP`, `SWIFTC`) and flat rules.
- **Test expectation:** none -- build configuration only; the repo has no test suite, and the build and runtime checks below cover it.
- **Verification:**
  - A clean checkout builds with `make` and with `make dmg`, and prints no error about a missing Xcode path.
  - `lipo -archs` on the app binary reports `arm64` only.
  - `otool -L` shows Swift libraries loading from `/usr/lib/swift/` and no `@rpath` entries.
  - `otool -l` reports a `minos` of 14.0.
  - The app opens, asks for microphone access, and shows a live spectrum.
  - `make clean` leaves `git status` clean.
- **Execution note:** This is packaging work, so prove it with a clean build and a launch rather than unit tests. Expect new deprecation warnings and leave them for the next strategy item.

### U2. Upload the DMG CI actually builds

- **Goal:** The `build-macos` job uploads the built DMG regardless of version.
- **Requirements:** R5; KTD5.
- **Dependencies:** U1, because CI must be able to build the app first.
- **Files:** `.github/workflows/build.yml`
- **Approach:** Change the "Upload Dmg" step to give the artifact a fixed name and a `swift/Tuner-*.dmg` path. Set `if-no-files-found: error` on that step so a missing DMG fails the job instead of just warning. Leave the Linux job untouched.
- **Test expectation:** none -- CI configuration; proven by a CI run.
- **Verification:** After the push, the `build-macos` run on `macos-latest` is green and its artifacts include the app and a DMG named for the current `Info.plist` version.

### U3. Update agent instructions

- **Goal:** `AGENTS.md` no longer tells a reader to fix `XCODELIB` or to bump the DMG name in CI.
- **Requirements:** R6.
- **Dependencies:** U1, U2.
- **Files:** `AGENTS.md`
- **Approach:**
  1. Change the `swift/` row of the ports table from "macOS 10.12+ (x86_64 + arm64)" to "macOS 14+ (arm64)".
  2. Replace the `XCODELIB` paragraph with one line saying the app uses the OS Swift runtime and builds with the Command Line Tools.
  3. In Conventions, drop the clause about the CI workflow hard-coding the DMG filename. Keep "version lives in `swift/Info.plist`".
  4. Also update the "Build commands" comment that says "builds a universal binary".
- **Test expectation:** none -- documentation.
- **Verification:** Searching `AGENTS.md` for `XCODELIB`, `10.12`, `universal` and `1.08` finds no matches.

---

## Verification Contract

| Check | Command or action | Proves |
|---|---|---|
| Fresh build | `cd swift && make clean && make` | R1 |
| DMG name | `cd swift && make dmg`, then confirm `Tuner-1.09.dmg` exists | R3 |
| Architecture and floor | `lipo -archs swift/Tuner.app/Contents/MacOS/Tuner`; `otool -l` on the same binary, reading `minos` | KTD1, KTD2 |
| System runtime | `otool -L swift/Tuner.app/Contents/MacOS/Tuner` shows `/usr/lib/swift/` and no `@rpath`; `swift/Tuner.app/Contents/Frameworks` does not exist | R2, KTD3 |
| Launch | `open swift/Tuner.app`, grant mic access, play a note, see the spectrum move | R2, Success Criteria |
| Clean | `cd swift && make clean && git status --short` prints nothing | R4 |
| CI | After pushing, `gh run list -L 1` shows `build-macos` green, and `gh run view` lists the DMG artifact | R5 |
| Docs | `grep -n -e XCODELIB -e '10\.12' -e universal -e '1\.08' AGENTS.md` finds nothing | R6 |

---

## Definition of Done

- Every row of the Verification Contract passes, and the launch check is confirmed by the owner on their Mac.
- `swift/Frameworks/` is gone from git, and the regenerated `swift/Tuner-Swift.h` is committed.
- Any source edits made to get Swift 6.4 to compile are minimal and listed in the commit message.
- No abandoned experiments are left in the diff, such as leftover x86 variables or commented-out rules.
- The work is pushed to `master`.
