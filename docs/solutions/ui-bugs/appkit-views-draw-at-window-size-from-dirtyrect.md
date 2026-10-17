---
title: Tuner views drew at window size because drawing was sized from dirtyRect
date: 2026-10-16
category: ui-bugs
module: swift
problem_type: ui_bug
component: frontend
symptoms:
  - Only the meter shows, stretched over the whole window, and it still moves with the mic
  - Scope, spectrum, note display and strobe/staff are missing even though the build and CI pass
root_cause: wrong_api
resolution_type: code_fix
severity: high
framework_version: AppKit, macOS 27.0 SDK (deployment target macOS 14)
tags: [appkit, nsview, dirtyrect, clipstobounds, draw-rect, macos-14-sdk, swift]
---

# Tuner views drew at window size because drawing was sized from dirtyRect

## Problem

After the Swift app was rebuilt on the current toolchain, it showed only the meter, filling the window. The scope, spectrum, note display and strobe/staff views were gone. The user reported that upstream's Tuner 1.09, released in March 2023 from the same drawing code, shows all of them.

## Symptoms

- The window shows one large meter whose pointer follows the mic, and nothing else.
- `make` builds with no errors or warnings and CI passes. Nothing at build time points at the cause; it only shows on screen.

## What Didn't Work

- Reading the drawing code did not reveal the bug. The code had not changed; the SDK it links against had. (session history)
- Logging with `NSLog` was no use: the unified log shows the values as `<private>`. Writing diagnostics to stderr with `FileHandle.standardError` worked. (session history)
- Comparing against upstream's 1.09 binary was not possible because mounting its DMG failed under the agent sandbox. So the claim that upstream's binary predates the macOS 14 SDK rests on its release date, not on inspecting the binary. (session history)

What found the cause was an instrumented build that logged, for each view, the rect passed to `draw(_:)` next to the view's `bounds`. The trace showed every view being handed a rect the size of the whole window.

## Solution

`TunerView` is the base class of all six tuner views (Scope, Spectrum, Display, Strobe, Staff, Meter). Each subclass's `draw(_:)` calls `super.draw`, which sets `rect`, `width` and `height` for the subclass to draw into. It sized them from `dirtyRect`. The fix sizes them from `bounds` (`swift/TunerView.swift:48`):

```swift
// Before
rect = DrawEdge(dirtyRect)

// After
rect = DrawEdge(bounds)
```

This shipped as commit `c86f560` on `master` ("Draw each tuner view inside its own bounds"), pushed directly before the project moved to PRs. It was checked by rerunning the instrumented trace and by looking at the real app.

## Why This Works

The app links against the macOS 27 SDK with a macOS 14 deployment target (`otool -l swift/Tuner` shows `minos 14.0`, `sdk 27.0`). AppKit changed two things in macOS 14. `NSView.clipsToBounds` defaults to `false` (the SDK's `NSView.h`: "Defaults to NO on macOS 14 and later"), so a view's drawing is no longer clipped to its bounds. And the `dirtyRect` passed to `draw(_:)` can extend outside the view; Apple's `clipsToBounds` documentation says to use `dirtyRect` to decide what to draw and `bounds` to decide where. In the trace it covered the whole window.

Apple documents the change by OS version. This session concluded, without checking an old binary, that AppKit gates it on the SDK an app links against, which is why upstream's older build is unaffected on the same Mac.

`TunerView` treated `dirtyRect` as "the area of this view", which held under older SDKs. Under the new ones, every view laid itself out at window size. The meter is the last view in the `NSStackView` (`swift/AppDelegate.swift:413-414`) and is redrawn every 20 ms by the timer at `swift/AppDelegate.swift:487`, so it painted over all the others. (Line numbers are from the time of the fix; in stage 1 the fix is at `swift/TunerView.swift:36`.)

`bounds` is always the view's own area. These views redraw in full every time, so drawing from `bounds` gives the same picture the old SDK did. `DrawEdge` also sets a clip path inset from that rect, so each view's drawing stays inside it.

## Prevention

- Size layout from `bounds`, never from `dirtyRect`. Treat `dirtyRect` only as a hint for what may be skipped, and only in views that draw part of themselves.
- A new `NSView` subclass that does not go through `TunerView.draw` must size from `bounds` itself.
- If views ever draw over one another again, log `dirtyRect` and `bounds` side by side in `draw(_:)`, writing to stderr, before changing code.

## Related Issues

- None found in `ozyx/ctuner` or upstream `billthefarmer/ctuner`.
