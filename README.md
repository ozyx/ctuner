# Musical instrument strobe tuner ![.github/workflows/build.yml](https://github.com/billthefarmer/ctuner/workflows/.github/workflows/build.yml/badge.svg)

A musical instrument strobe tuner with cents and frequency
display. With additional features useful for tuning accordions or
melodeons. The strobe display may be replaced with the staff, if
required. This fork is the [Mac](App) app, with a legacy
[Linux](linux) port. An
[Android](https://github.com/billthefarmer/tuner) version is
available, also on
[F-Droid](https://f-droid.org/packages/org.billthefarmer.tuner).

|     |     |
| --- | --- |
| ![Tuner](https://github.com/billthefarmer/billthefarmer.github.io/raw/master/images/ctuner/Tuner-swift.png) | ![Preferences](https://github.com/billthefarmer/billthefarmer.github.io/raw/master/images/ctuner/Tuner-preferences.png) |
|     | ![Note Filters](https://github.com/billthefarmer/billthefarmer.github.io/raw/master/images/ctuner/Note-filter.png) |


## Using

See [App/README.md](App/README.md) for the Mac app's features,
keyboard shortcuts and click actions. Build it with `make app` at the
top of the repository, which needs only the Command Line Tools and
leaves `.build/Tuner.app`; `make dmg` also makes the disk image.

## How it works

I have included a How It Works section because none of the other
open source tuners that I have looked at give any explanation of
the algorithms used. This tuner uses an overlapped Fast Fourier
Transform together with the phase difference between sequential
runs of the FFT to measure the actual frequency accurately. It
appears to be about as accurate as the clock in the sound
card. The filter is a single pole Butterworth filter with a
corner frequency of 120Hz. The output of the FFT is scanned by a
peak detector which detects up to eight peaks in the
spectrum. The highest peak is taken as the measured note, other
peaks are shown on the zoomed in spectrum if within range, all of
them are displayed if the multiple option is on.
