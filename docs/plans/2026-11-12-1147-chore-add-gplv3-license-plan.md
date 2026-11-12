---
title: Add GPLv3 License - Plan
type: chore
date: 2026-11-12
topic: gplv3-license
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Add GPLv3 License - Plan

## Goal Capsule

- **Objective:** Anyone who finds ctuner or downloads its DMG can see the project's license (GPLv3 or later, with Bill Farmer as the original author), and the app's About box shows a copyright line that no longer contradicts it.
- **Means:** Add the missing license text and notices and correct the About string; relicense nothing (the stay-on-GPLv3 Key Decision).
- **Authority:** The Product Contract wins on behavior, Key Technical Decisions win on mechanism within it, and no unit overrides either.
- **Stop conditions:** Stop and ask the owner if GitHub's license detection does not report GPL-3.0 for the branch once `LICENSE` is pushed, or if the work seems to need changes to source headers or the legacy `COPYING` files.
- **Execution profile:** One PR from the `chore/gplv3-license` branch against `master`. The work is docs and packaging only, so verification is smoke-first (`make dmg`) with no new tests.
- **Finishes and ships:** `ce-work` implements and opens the PR; this plan file is committed in it.

## Product Contract

### Summary

Add a root GPLv3 `LICENSE`, a License section in the README, a corrected copyright string in the app's `Info.plist`, and the `LICENSE` file inside the DMG. Source headers, the legacy ports' license files and Bill Farmer's reference code stay untouched.

### Problem Frame

The source headers (96 files, "version 3 of the License, or (at your option) any later version") and the rewrite plan say GPLv3, but `master` has no top-level license file. The only license files are `linux/COPYING` and `mac/COPYING`, identical GPLv2 texts for the legacy ports. The app's About string reads "Copyright © 2020 Bill Farmer. All rights reserved.", which contradicts a GPL grant, and the DMG that CI builds ships no license text. A reader, or GitHub's license detector, cannot tell what terms apply.

The owner first wanted MIT. ctuner is a fork of Bill Farmer's GPL `billthefarmer/ctuner`, and the new C engine is a behaviour-matched port checked against a frozen copy of his code, not a clean-room rewrite. MIT therefore needs his written permission, and the owner chose to stay on GPLv3 instead.

### Key Decisions

- **Stay on GPLv3 or later; do not relicense.** (session-settled: user-directed — chosen over MIT with Bill Farmer's grant, a clean-room replacement of his derived code, and MIT headers on new files only: MIT needs his written permission, because the engine is a port of his code and the shipped app links it.) Governs R1, R2.
- **Name "Bill Farmer and contributors" in the copyright string, with no personal name.** (session-settled: user-approved — chosen over adding the owner's personal name: the owner confirmed the call-out as proposed and can ask for a name later.) Governs R3.
- **Ship `LICENSE` in the DMG.** (session-settled: user-approved — chosen over leaving the DMG as built today: DMG recipients otherwise get no license text, and the owner agreed to this fourth edit beyond the three first confirmed.) Governs R4.

### Requirements

- R1. A root `LICENSE` file holds the unmodified GPLv3 text.
- R2. The README has a License section that states GPLv3 or later, points at `LICENSE`, credits Bill Farmer's original ctuner, and says the engine derives from his code so relicensing needs his permission.
- R3. The app's About string reads "Copyright © 2010–2026 Bill Farmer and contributors", without "All rights reserved".
- R4. The DMG built by `make dmg` contains `LICENSE` beside `README.md`, with the repo's descriptions of the DMG contents kept in step.

### Success Criteria

GitHub's license detection reports GPL-3.0 for the repository once this lands.

### Scope Boundaries

- Source headers, `linux/COPYING`, `mac/COPYING`, the six legacy GPLv2-or-later source files and `Sources/GoldenReference/` are unchanged. The headerless build files (the Makefiles and `Scripts/*.sh`) gain no license header, and the only change to any of them is the DMG recipe and comment edit in the root `Makefile` (U3). The root `LICENSE` covers them, and "or later" lets the tree ship as GPLv3.
- MIT relicensing is not pursued. It stays possible with Bill Farmer's written grant, and nothing here blocks asking for one later.
- Considered and not built: license text inside `Tuner.app` itself. CI also uploads the bare `.app`, but the DMG is the shipped artifact (`AGENTS.md`); revisit if the `.app` is ever distributed alone.

## Planning Contract

### Key Technical Decisions

- KTD1. **`LICENSE` is the canonical GPLv3 text, unedited.** Take it from gnu.org's `gpl-3.0.txt` at implementation time and add no project header. GitHub's detector matches the standard text, and each source file already carries its own notice. Governs R1.
- KTD2. **The README section goes at the end, in neutral third person.** The README body is Bill Farmer's first-person writing, and a separate closing section keeps his text intact. Governs R2.
- KTD3. **The `Info.plist` edit alone changes the About box.** Nothing under `Sources/TunerApp` sets About text, so the default panel reads `NSHumanReadableCopyright` from the bundle. The version stays at 1.09 and no other key changes. Governs R3.
- KTD4. **`make dmg` copies `LICENSE` next to `README.md`, and the `.app` bundle is untouched.** The recipe gains one copy line beside the README's. The DMG's name and path stay the same, so CI's upload glob in `.github/workflows/build.yml` needs no edit. (session-settled: user-approved — see the DMG Key Decision.) Governs R4.

## Implementation Units

### U1. Add the GPLv3 license and README section

- **Goal:** The repo root states its license in a file GitHub detects and in the README.
- **Requirements:** R1, R2; KTD1, KTD2.
- **Dependencies:** none.
- **Files:** `LICENSE` (create), `README.md` (modify).
- **Approach:**
  1. Create `LICENSE` from gnu.org's GPLv3 text, byte for byte.
  2. Append a `## License` section to the end of `README.md` that says the project is GPLv3 or later and links `LICENSE`.
  3. In the same section, say that ctuner is a fork of Bill Farmer's `billthefarmer/ctuner`, that its audio engine derives from his code, and that any relicensing needs his permission.
  4. Add one clause saying the legacy `linux/` and `mac/` ports keep their own GPLv2-or-later notices and `COPYING` files.
- **Test expectation:** none -- documentation only.
- **Verification:** Once the branch is pushed, GitHub's license API for it reports GPL-3.0, and the README's `LICENSE` link resolves.

### U2. Correct the app's copyright string

- **Goal:** The About box shows the right author and no "All rights reserved".
- **Requirements:** R3; KTD3.
- **Dependencies:** none.
- **Files:** `App/Info.plist` (modify).
- **Approach:** Replace the `NSHumanReadableCopyright` value with "Copyright © 2010–2026 Bill Farmer and contributors". Keep the file's existing encoding and indentation, and touch no other key.
- **Test expectation:** none -- configuration only.
- **Verification:** The plist still lints, and the `Info.plist` inside the bundle that `make app` builds carries the new string. No app launch is needed.

### U3. Ship `LICENSE` in the DMG

- **Goal:** Someone who downloads the DMG gets the license text with the app.
- **Requirements:** R4; KTD4.
- **Dependencies:** U1, because the file must exist before it can be copied.
- **Files:** `Makefile` (modify), `AGENTS.md` (modify).
- **Approach:**
  1. Add a copy line for `LICENSE` to the `dmg` recipe, next to the one for `App/README.md`.
  2. Update the comment above the DMG variables, which lists the DMG's contents, to include the license.
  3. Update `AGENTS.md`'s `make dmg` line under Build commands to list `LICENSE` beside `App/README.md`.
- **Execution note:** This is packaging work, so prefer smoke verification of the built DMG over unit coverage.
- **Test expectation:** none -- packaging only.
- **Verification:** `make dmg` succeeds, and the DMG it builds lists `LICENSE` beside `README.md`.

## Verification Contract

| Gate | Applies to | Signal |
|---|---|---|
| `make dmg` (builds the app, then the DMG) | U2, U3 | Exits 0; the built DMG lists `LICENSE` beside `README.md`; the bundled `Info.plist` shows the new copyright string |
| `plutil -lint App/Info.plist` | U2 | Reports OK |
| GitHub license API for the pushed branch | U1 | Reports GPL-3.0, which is the Success Criteria signal |
| CI on the PR (`.github/workflows/build.yml`) | All | Linux and macOS jobs green; the macOS job runs `make dmg` |

## Definition of Done

- R1 to R4 hold, and the Success Criteria signal is met.
- U1: `LICENSE` matches the standard GPLv3 text, and the README section says everything U1's approach lists for it.
- U2: `App/Info.plist` differs from `master` only in the copyright string.
- U3: the Makefile recipe, the Makefile comment and the `AGENTS.md` line all name `LICENSE`.
- No temporary staging files, scratch copies of the license, or abandoned-attempt edits remain in the diff.
- The PR is open against `master` from `chore/gplv3-license`, with this plan committed in it.

## Sources & Research

- `docs/plans/2026-10-16-1644-feat-mac-native-rewrite-plan.md`: "The licence stays GPLv3"; its KTD7 builds the golden fixtures from a frozen copy of Bill Farmer's engine in `Sources/GoldenReference/Reference/`.
- `linux/COPYING` and `mac/COPYING` are identical GPLv2 texts. Six legacy source files say version 2 "or any later version" and 96 files say version 3 "or any later version". The current tree holds no Apache text; the only Apache-licensed file in history is an Android `ColourPicker.java` from Bill Farmer's February 2013 commits, whose Apache header was removed within a week.
- The `Makefile` `dmg` recipe stages the app, an Applications link and `App/README.md`, and `.github/workflows/build.yml` uploads `.build/Tuner-*.dmg`.
- Upstream `billthefarmer/ctuner` shows no detected license on GitHub, and Bill Farmer is its only contributor.
