# Tuner

A musical instrument tuner with extra facilities for tuning free reed
instruments

|     |     |
| --- | --- |
| ![Tuner](https://github.com/billthefarmer/billthefarmer.github.io/blob/master/images/ctuner/Tuner-swift.png) | ![Preferences](https://github.com/billthefarmer/billthefarmer.github.io/blob/master/images/ctuner/Tuner-preferences.png) |
|     | ![Note Filters](https://github.com/billthefarmer/billthefarmer.github.io/blob/master/images/ctuner/Note-filter.png) |

 * Oscilloscope
 * Spectrum with zoom, shows individual reeds
 * Display frequency, cents, frequency deviation for single reed or up to eight
 * Strobe with choice of colours
 * Staff displays current note
 * Meter shows cents deviation
 * Display lock
 * Audio lowpass filter for bass reeds
 * Experimental downsampling for bass reeds
 * Fundamental filter
 * Note filter - allows display of selected notes and octaves only

A SwiftUI window with a toolbar, an inspector for the scope, spectrum
and note filter, and a Settings window (Command-,). Every toggle is in
the toolbar and the menus, and the bare keys below work while the window
has focus. The microphone is asked for once, the first time the app
opens. If it is denied, or there is no input device, the window says so.

Needs macOS 26.

### Keys
 * **c** - Copy the readout to the clipboard (also Command-C)
 * **d** - Toggle downsampling
 * **f** - Toggle audio filter
 * **k** - Change strobe colours
 * **l** - Toggle display lock
 * **m** - Toggle multiple reeds
 * **s** - Toggle strobe/staff display
 * **z** - Toggle Spectrum zoom
 * **+** - Expand the spectrum, x 1 to x 16, then back to x 1
 * **-** - Contract the spectrum, x 16 to x 1, then back to x 16
 * **Option-Command-I** - Show or hide the inspector

### Toolbar
Filter, downsample, fundamental filter, note filter, lock, multiple
reeds, strobe and inspector. The fundamental filter and the note filter
are also in the View menu.

### Actions
 * Click on scope to toggle audio filter
 * Click on spectrum to toggle zoom; its header has the zoom control and,
   while zoom is off, the expand control
 * Click on display to lock
 * Click on meter to lock
 * Click on strobe to switch to the staff
 * Click on staff to switch to the strobe

### Playing a file or a tone instead of the microphone
Launch with `-InputSource` to hear nothing and still watch the tuner move:

```sh
open -n .build/Tuner.app --args -InputSource tone:E4+5
open -n .build/Tuner.app --args -InputSource file:/Users/me/take.wav
```

 * `tone:` takes a note such as `A4` or `Eb4+7` (cents) or a frequency in
   Hz, with optional `,rate=`, `,amp=` and `,secs=` parts. A tone never
   ends in the window.
 * `file:` takes a WAV file, uses its first channel at its own sample rate, and loops it. Use an absolute path,
   because an app started by `open` runs with `/` as its working
   directory.
 * Quit the running app first, or use `open -n`: `open --args` passes
   nothing to an instance that is already running.
 * The flag is read once and never saved, so the next launch from Finder
   uses the microphone. A bad value or an unreadable file shows in the
   window as a capture failure.
