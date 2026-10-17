# Golden fixtures

Each fixture is three files with one name:

- `NAME.bin`: the input, 64 hops of 1024 float32 samples (native byte order, little-endian on every Apple platform).
- `NAME.header`: how the input was made and how the engine is configured for it.
- `NAME.expected.txt`: one line per hop from the frozen copy of today's engine.

`make fixtures` writes them all with `Scripts/fixtures.sh`, which holds the fixture table. Running it again must change nothing. `make fixture-screen` runs the stability screen and the sanitizer pass described below.

## Where the expected output comes from

`Sources/GoldenReference/Reference/` holds `Audio.m`, `Audio.h` and `Temperaments.h` copied from `swift/` after PR #2. The only edit is one line before the final `timer++` in `ProcessAudio`, which calls the harness hook with the per-hop locals. `Tuner-Swift.h` there is a stub that replaces the six AppKit views with plain objects carrying the properties the engine touches.

`Sources/GoldenReference/main.m` includes the frozen `Audio.m` textually, so one translation unit sees its file statics. It defines `AudioUnitRender` to hand over the next 1024-frame block, so the real `InputProc` runs the input filter and the sliding window. It drains the main queue after each block, so `ProcessAudio` runs once per hop. The display is never locked.

The inputs come from `Sources/GoldenGenerator/generate.c`, which computes each sample in double, rounds it to float32, and hashes the bytes. Its arithmetic is unoptimised and contraction-free, so any compiler writes the same bytes.

## Header

One `key value` pair per line. A key that is absent takes the default shown.

| Key | Default | Meaning |
| --- | --- | --- |
| `name` | | the fixture's name |
| `rate` | 44100 | sample rate in Hz |
| `reference` | 440 | reference A in Hz |
| `temper` | 8 | temperament row, 8 is equal temperament |
| `key` | 0 | temperament key, 0 is C |
| `filt` | 0 | input filter on |
| `down` | 0 | downsampling (the harmonic product) on |
| `fund` | 0 | fundamental filter on |
| `note` | 0 | note filter on |
| `notes` | fff | note filter mask in hex, bit 0 is C, bit 9 is A |
| `octaves` | 1ff | octave filter mask in hex, bit 0 is octave 0 |
| `filt_toggle_hop` | -1 | hop before which the input filter is switched over, -1 for never |
| `expect_hz` | none | the analytic frequency of the tone, for the accuracy check |
| `expect_cents` | 0.2 | bound on the measured error against `expect_hz`, in cents |
| `same_binary_only` | 0 | 1 if found, note or count may differ between builds, so only the same-binary check applies |
| `signal` | | the generator arguments that made the input |
| `hops` | | number of 1024-sample hops in the input |
| `block` | 1024 | samples per hop |
| `input_bytes` | | size of `NAME.bin` |
| `input_hash` | | FNV-1a 64-bit hash of `NAME.bin`, in hex |

The two lowest pure tones have wider accuracy bounds. Today's engine reads 27.5 Hz about 1 cent off and 55 Hz about 0.6 cents off, because those tones sit only 10 and 20 bins above zero. The downsampled harmonic-rich fixtures allow 3 cents, because the harmonic product shifts low notes by up to about 2.6 cents.

## Expected line

Fields are separated by single spaces. Doubles are printed to 17 significant digits, so they read back exactly.

```text
hop found note count f fr c max imax sumsq b-3 b-2 b-1 b0 b+1 b+2 b+3 [mf mfr mn]...
```

| Field | Meaning |
| --- | --- |
| `hop` | hop number from 0 |
| `found` | 1 if a note was found |
| `note` | note number, 57 is A4; meaningless when `found` is 0 |
| `count` | number of maxima, 0 to 8 |
| `f` | measured frequency in Hz |
| `fr` | reference frequency of the note in Hz |
| `c` | deviation from `fr` in semitones, so 0.05 is 5 cents |
| `max` | peak spectrum magnitude |
| `imax` | bin of the peak |
| `sumsq` | sum of squares of all 7168 spectrum bins, in bin order |
| `b-3` to `b+3` | the spectrum bins from `imax - 3` to `imax + 3`, 0 outside the spectrum |
| `mf mfr mn` | for each of the `count` maxima: frequency, reference frequency and note number |

When `found` is 0, `note`, `f`, `fr` and `c` come from arithmetic on infinities or a float-to-int conversion that is undefined in C, so the comparison skips them.

## Comparison

The golden tests skip the first 20 hops, while the window fills and the phase history settles. Then, per hop:

- `found`, `count` and each maximum's `mn` must match exactly, and `note` must match when `found` is 1.
- `f`, `fr`, `mf`, `mfr`, `max`, `sumsq` and the seven bins must match within a relative 1e-12. `f` and `fr` are compared only when `found` is 1.
- `c` must match within an absolute 1e-9 semitones, when `found` is 1.

## Stability screen

`make fixture-screen` builds the frozen reference at `-O0`, at `-O3` and with `-ffp-contract=off`, runs every fixture, and fails if `found`, `note` or `count` differs anywhere from the committed file. It skips that check for a fixture marked `same_binary_only 1`, which sits on a threshold on purpose. Every committed fixture passes. A many-peak fixture that fills the maxima list was tried and dropped: it changed count at `-O3` and under the address sanitizer, because of the out-of-bounds write listed below.

## Known sanitizer reports in the frozen engine

The screen also runs the reference under the address and undefined-behaviour sanitizers with recovery on. The sanitized output equals the committed output for every fixture. Line numbers are in the frozen `Audio.m`.

1. **`xa[-1]` read.** With downsampling on, the loop that recomputes the differences starts at 0, so `dxa[0] = xa[0] - xa[-1]` reads one element before the spectrum (line 555). Every `down-*` fixture raises it, as a global-buffer-overflow from the address sanitizer and an index -1 from the undefined-behaviour sanitizer.
2. **Float-to-int conversion of NaN or infinity.** `int note = round(cf) + kC5Offset` runs for bins whose frequency is zero or negative, where `cf` is NaN or infinite (line 583). In the found branch the same conversion runs on `f = 0` when no maximum was kept (line 681). Almost every fixture raises one or both.
3. **Negative temperament index.** When that conversion yields a large negative note, `(note - key + 12) % 12` is negative and indexes before a temperament row (lines 692 and 695). `note-c5-filtered`, `note-octave-4` and `down-harmonic-027.5` raise it. It follows from report 2.
4. **Write past the maxima list.** The clear of `maxima[count]` and `values[count]` at the top of the search loop runs before the `count < 8` test (lines 575 to 579), so once eight maxima are kept it writes one element past both arrays. No committed fixture reaches a count of 8, for the reason in the stability screen above.

The undefined-behaviour sanitizer reports each source location once per process, so a fixture may raise a report more often than the screen lists.
