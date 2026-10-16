---
title: Remove Windows Port - Plan
type: chore
date: 2026-10-16
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Remove Windows Port - Plan

## Goal Capsule

- **Objective:** The fork contains and builds only what the Mac app and the legacy Linux port need, so no Windows toolchain can break CI or mislead a reader.
- **Means:** Delete the Windows port and every build path and doc that points at it, and keep the Linux build in CI as its own job (KTD1).
- **Authority:** `STRATEGY.md` track "Drop Windows cross-compilation" sets the scope. This plan's R-IDs own behavior, its KTDs own mechanism.
- **Stop conditions:** Stop and ask if any file outside `windows/` turns out to compile or include something from `windows/`. Stop if the Linux job cannot be separated without changing how `linux/` builds.
- **Execution profile:** Deletions plus small edits to one workflow and three docs. No app code changes.
- **Finishes and ships:** The implementer commits to `master` and pushes, per the fork's no-PR workflow.

## Product Contract

### Summary

Delete `windows/` and the Travis leftover that only builds it. Replace the combined Windows-and-Linux CI job with a Linux-only job. Update the README, agent instructions, and `.gitignore` so nothing describes Windows as a supported target.

### Problem Frame

The fork is Mac-only by strategy, with Linux kept as untouched legacy. The Windows port still sits in the tree and in CI. Its mingw cross-compile is one more thing that can fail on a Mac-focused push. The Linux build currently runs inside the job named `build-windows`, so the two are coupled. The root `README.md` is the Windows user manual, so a reader landing on the fork sees instructions for an app the fork no longer ships.

### Requirements

**Source tree**

- R1. The `windows/` directory is gone from the repository.
- R2. `scripts/build.sh`, which only cross-compiles Windows for Travis, is gone.

**CI**

- R3. `.github/workflows/build.yml` has no Windows job, no mingw install, and no `Tuner.exe` artifact.
- R4. CI still builds the Linux port and uploads `linux/tuner`, in a job that installs only Linux dependencies.
- R5. The macOS job keeps building the Mac app as it does today.

**Docs and config**

- R6. The root `README.md` describes the fork as a Mac app, with the Linux port noted as legacy, and points Mac usage to `swift/README.md`.
- R7. `AGENTS.md` lists no Windows port, no Windows build command, and no Windows README convention.
- R8. `.gitignore` drops the `*.exe` pattern.

### Scope Boundaries

- The generated Hugo site in `docs/` still links to `windows/`. It is generated output with no source in this repo, so it is left alone.
- `linux/` and `mac/` sources are untouched.
- `STRATEGY.md` is not edited. The track stays as written until the user retires it.

#### Deferred to Follow-Up Work

- The macOS job uploads `Tuner-1.08.dmg` while `swift/Info.plist` is at 1.09. That mismatch belongs to the "Modern macOS build and runtime" track.
- The macOS build depends on the hard-coded `XCODELIB` path in `swift/Makefile`. CI may fail on `macos-latest` for that reason, which is also the modern-build track.

## Planning Contract

### Key Technical Decisions

- KTD1. **Split the Linux build into its own `build-linux` job.** The current job builds both ports. Renaming it would leave mingw installs behind. A separate job with only `build-essential`, `libgtk-3-dev`, and `libasound2-dev` keeps Linux as legacy with no Windows residue.
- KTD2. **Rewrite the root README rather than delete it.** The repo root needs a landing page. The Windows-only sections (Using, Options, Keyboard shortcuts) are replaced by a pointer to `swift/README.md`. The "How it works" section is platform-neutral and stays.

### Assumptions

These were inferred without confirmation. Correct any that are wrong before execution.

- Bump `actions/checkout` and `actions/upload-artifact` from v2 to v4 in the workflow. GitHub rejects upload-artifact v2, so the split Linux job would fail without it. The macOS job gets the same bump so the file stays consistent.
- Keep the upstream build badge URL in the README as is. Pointing it at the fork's own workflow is a separate choice.
- No commit history rewrite. `windows/` stays reachable in git history.

### Sources

- `.github/workflows/build.yml`: the `build-windows` job builds both `windows/` and `linux/`.
- `scripts/build.sh`: Travis-only, Windows-only.
- Grep across `linux/`, `swift/`, and `mac/` found no reference to `windows/`. Each port keeps its own `Temperaments.h`, so nothing shared is lost.
- The fork has no upstream remote, so deleting `windows/` creates no merge-conflict burden.

## Implementation Units

### U1. Delete the Windows port and Travis script

- **Goal:** Remove all Windows-only source and build scripts.
- **Requirements:** R1, R2
- **Dependencies:** none
- **Files:** `windows/` (all 13 tracked files), `scripts/build.sh`. Remove the empty `scripts/` directory too.
- **Approach:** Delete through git so the removal is tracked.
- **Test expectation:** none -- pure deletion with no code consumers, confirmed by the grep in Sources.
- **Verification:** `git ls-files windows scripts` returns nothing.

### U2. Split CI into Linux and macOS jobs

- **Goal:** CI builds Linux and macOS with no Windows step.
- **Requirements:** R3, R4, R5
- **Dependencies:** U1
- **Files:** `.github/workflows/build.yml`
- **Approach:**
  1. Replace `build-windows` with `build-linux` per KTD1. It runs `make` in `linux/` and uploads `linux/tuner` as artifact `Tuner`.
  2. Leave `build-macos` steps unchanged apart from the action version bump in Assumptions.
- **Test expectation:** none -- CI config. Proof is the workflow run in Verification.
- **Verification:** The workflow file has no `mingw`, `windows`, or `.exe` strings. After push, the Actions run shows a `build-linux` job. The fork has no workflow runs yet. If none appears, Actions are likely disabled on the fork, so report that instead of claiming CI passed. Report each job's result as observed. A Linux build failure from `linux/` itself is a finding to report, not something to fix here.

### U3. Update README, AGENTS.md, and .gitignore

- **Goal:** No doc or config describes Windows as a target.
- **Requirements:** R6, R7, R8
- **Dependencies:** U1
- **Files:** `README.md`, `AGENTS.md`, `.gitignore`
- **Approach:**
  1. `README.md`: apply KTD2. Replace the Using, Options, and Keyboard shortcuts sections with a pointer to `swift/README.md`. Change the intro line about available versions to say the fork is the Mac app with a legacy Linux port. Keep "How it works" and the Android link.
  2. `AGENTS.md`: drop the `windows/` table row and the Windows build block. Change "four independent native ports" to "three". Remove the sentence calling `scripts/build.sh` a leftover Travis script. Change the shortcuts convention to name only `swift/README.md`. Remove `*.exe` from the build-artifacts list.
  3. `.gitignore`: remove the `*.exe` line.
- **Test expectation:** none -- docs and ignore rules only.
- **Verification:** No file outside `docs/` mentions `scripts/build.sh`. Grep for `windows` and `mingw` outside `docs/` and `STRATEGY.md` finds only incidental API names such as `NSApp.windowsMenu` and `kWindow*` constants.

## Verification Contract

| Check | Applies to | Done signal |
| --- | --- | --- |
| `git ls-files windows scripts` | U1 | Empty output |
| Grep for `windows`, `mingw`, `.exe` outside `docs/`, `STRATEGY.md`, `linux/configure`, and `mac/` | U2, U3 | Only incidental AppKit or Carbon window API names remain |
| `cd swift && make` locally | All | Builds as before. The repo has no tests. |
| GitHub Actions run after push | U2 | `build-linux` and `build-macos` jobs exist. Results reported as observed. |

## Definition of Done

- R1 through R8 hold.
- Every unit's Verification passes.
- The local Mac build still succeeds.
- No leftover edits beyond the files listed in the units.
