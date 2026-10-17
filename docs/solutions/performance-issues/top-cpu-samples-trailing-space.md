---
title: An awk filter on top's CPU samples skipped every sample
date: 2026-10-17
category: performance-issues
module: swift
problem_type: performance_issue
component: tooling
symptoms:
  - A 60-second idle CPU mean from `top` piped into `awk` comes out lower than expected, or from far fewer samples than were taken
root_cause: logic_error
resolution_type: workaround
severity: medium
framework_version: macOS 27 top
tags: [top, awk, cpu, measurement, idle-cpu]
---

# An awk filter on top's CPU samples skipped every sample

## Problem

The idle CPU figures for the stage 1 PR were measured with `top -l <n> -stats cpu` piped into `awk`, which averaged the lines matching `/^[0-9.]+$/`. `top` prints each CPU value with a trailing space (`0.0 `, as `sed -n l` shows), so that pattern skipped those lines, and the mean came from whatever lines did match. The mistake was found after these figures had been reported: the old app's 13.3% baseline (U1) and the first stage 1 reading of 14.7%. Either may be an undercount.

## Solution

Allow spaces on both sides of the number:

```sh
awk '/^ *[0-9.]+ *$/ { sum += $1; n++ } END { print sum / n, n }'
```

Print the sample count `n` with the mean, and check it equals the `-l` count asked for.

## Prevention

- Whenever a measurement is filtered, print the number of samples used next to the result.
- Before comparing a new figure with the U1 baseline, take both again with the corrected pattern. The 7.4% stage 1 figure came from the corrected pattern.
