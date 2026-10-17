//
//  TunerCapture.h
//  Tuner
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//  Audio capture from the default input device (KTD8). The input
//  callback hands each rendered block of mono float samples to a push
//  callback on the audio thread and does nothing else. This target
//  depends on nothing else in the package.

#ifndef TunerCapture_h
#define TunerCapture_h

#ifdef __cplusplus
extern "C" {
#endif

// Marks a function the real-time audio thread may call; clang checks
// what such a function calls where it knows the attribute
#if defined(__has_attribute)
#if __has_attribute(nonblocking)
#define CAPTURE_NONBLOCKING __attribute__((nonblocking))
#endif
#endif
#ifndef CAPTURE_NONBLOCKING
#define CAPTURE_NONBLOCKING
#endif

// Sizes
enum
{
    kCaptureBlock = 1024,
    kCaptureSampleRate = 44100
};

// Capture status codes
typedef enum
{
    kCaptureStatusOK = 0,
    kCaptureStatusNoMemory,
    kCaptureStatusBadArgument,
    kCaptureStatusNoComponent,
    kCaptureStatusNoInputDevice,
    kCaptureStatusDevice,
    kCaptureStatusUnit,
    kCaptureStatusStart,
    kCaptureStatusRender
} CaptureStatus;

typedef struct Capture Capture;

// Called on the audio thread with each block of samples
typedef void (*CapturePush)(void *context, const float *samples,
                            int count) CAPTURE_NONBLOCKING;

// Status string
const char *CaptureStatusString(CaptureStatus status);

// The buffer size to ask a device for, given its buffer size range:
// the block, halved until the device takes it, and never below the
// device's minimum
int CaptureBufferFrames(double minimum, double maximum);

// Create capture on the default input device, asking the device for
// kCaptureSampleRate and taking the rate it gives. Destroy stops
// capture if it is running and disposes the unit.
CaptureStatus CaptureCreate(CapturePush push, void *context,
                            Capture **capture);
void CaptureDestroy(Capture *capture);

// Start and stop the input callback
CaptureStatus CaptureStart(Capture *capture);
void CaptureStop(Capture *capture);

// The latest status, which the input callback sets when a render
// fails; safe to read from any thread
CaptureStatus CaptureGetStatus(Capture *capture);

// The device's sample rate, read at create
double CaptureSampleRate(Capture *capture);

#ifdef __cplusplus
}
#endif

#endif /* TunerCapture_h */
