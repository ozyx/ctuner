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
