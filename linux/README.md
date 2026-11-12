# Musical instrument strobe tuner

A musical instrument strobe tuner with cents and frequency
display. With additional features useful for tuning accordions or
melodeons. The strobe display may be replaced with the staff, if
required.

|     |     |
| --- | --- |
| ![Tuner](https://github.com/billthefarmer/billthefarmer.github.io/raw/master/images/ctuner/Tuner-linux.png) | ![Options](https://github.com/billthefarmer/billthefarmer.github.io/raw/master/images/ctuner/Options-linux.png) |
|     | ![Filters](https://github.com/billthefarmer/billthefarmer.github.io/raw/master/images/ctuner/Filters-linux.png) |


## Using
Play your instrument into your microphone and observe the display. The
oscilloscope display at the top shows the input waveform. The display
below shows the spectrum of the input. It may be zoomed in and out by
clicking on the pane. When zoomed in the display shows about ±50 cents
around the current note and includes all concurrent notes within that
range.

## Building
Use the simple makefile provided.

### Raspberry Pi
The app builds ok on a pi, but will not work because of the lack of an
audio input. It should work fine with one - untested.

## Install
Copy the binary `tuner` to `/usr/local/bin`. That's:
```shell
$ git clone https://github.com/billthefarmer/ctuner.git
$ cd ctuner/linux/
$ sudo apt install libasound2-dev libgtk-3-dev
$ make
$ sudo cp tuner /usr/local/bin/
```
On a debian/ubuntu/linux mint/raspberry pi system.
