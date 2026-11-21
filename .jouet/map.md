# Map

Swift package at the root (`Package.swift` registers every target and product); targets depend one way, app to state to core and capture.

- `Sources/TunerCore/`: C analysis engine on Accelerate, opaque handle; public header `include/TunerCore.h`. Tests: `Tests/TunerCoreTests/` (`mise run test:filter TunerCoreTests`)
- `Sources/TunerCapture/`: Objective-C AVAudioEngine capture shim, `CaptureEngine.m`, header `include/TunerCapture.h`. Compiles with and without ARC
- `Sources/TunerSource/`: `file:`/`tone:` sources, tone synthesis, WAV reader, feeder, headless run and verdict. Tests: `Tests/TunerSourceTests/`
- `Sources/TunerState/`: platform-free state (`Engine`, `DisplayModel`, `Settings`, `CaptureController`, `StrobeMotion`, `MeterScale`, `ReadoutLayout`, ...). One test file per type in `Tests/TunerStateTests/` (`mise run test:filter StrobeMotionTests`)
- `Sources/TunerApp/`: SwiftUI app; panes in `Panes/`, menu shortcuts in `Commands.swift`, toolbar in `Toolbar.swift`, inspector in `InspectorView.swift`
- `Sources/TunerRun/main.swift`: the `tuner-run` CLI over `TunerSource`; `Scripts/tone-checks.sh` holds its table of known tones and exit codes (`mise run test:tones`)
- `Sources/GoldenReference/Reference/`: frozen copy of the old engine; never edit it to match the new core
- `Sources/GoldenGenerator/`: writes fixture inputs
- `App/`: `Info.plist` (version), `README.md` (shortcuts, shipped in the DMG), `Tuner.png` (icon source)
- `Scripts/`: `package-app.sh` (bundles `.build/Tuner.app`), `fixtures.sh`, `fixture-screen.sh`, `measure.sh`, `core-leaks.c`
- `linux/`: separate GTK3 + ALSA port (`tuner.cpp`), own `Makefile`; CI builds it on Ubuntu
- `docs/plans/`, `docs/solutions/`, `docs/ideation/`: plans, learnings by category, ideation; the rest of `docs/` is generated Hugo output

## Entry points

- App: `Sources/TunerApp/TunerApp.swift` (`@main`), model in `AppModel.swift`
- Headless: `.build/release/tuner-run tone:A4+7 --target A4+7` (exit 0 pass, 1 fail, 2 usage)
- New target or product: `Package.swift`; new bundled resource: `APPBUNDLES` in `Makefile`

## Generated files

- `Tests/TunerCoreTests/Fixtures/`: written by `make fixtures` from the frozen reference; format in its `README.md`. Do not edit by hand
- `.build/Tuner.app`, `.build/Tuner-<version>.dmg`: `mise run build` (`make dmg`)

## Change together

- Shortcuts or click actions: `Commands.swift`, `Toolbar.swift`, pane click handlers, and `App/README.md`
- Version: `CFBundleShortVersionString` in `App/Info.plist` (names the DMG)
- A new setting: `Settings.swift` (UserDefaults key, engine forwarding) and `SettingsTests.swift`, then the view that edits it (`SettingsView.swift`, `InspectorView.swift` or `Commands.swift`)
- New dot-directory: add a `!` entry to `.gitignore`, which ignores all dotfiles

## Tests

- Run through `make`/`mise`, never bare `swift test`: the Makefile adds the Testing plugin path on the Command Line Tools
- Extra `swift test` options: `make test TESTFLAGS="--filter NAME"`
