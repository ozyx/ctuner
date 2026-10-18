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

// Called on the audio thread with each block of samples
typedef void (*CapturePush)(void *context, const float *samples,
                            int count) CAPTURE_NONBLOCKING;

// Status string
const char *CaptureStatusString(CaptureStatus status);

// AVAudioEngine and a sink node on the default input at the device's
// own rate, which is never changed. The engine lives as long as the
// handle; each start attaches a new sink and each stop detaches it. The
// blocks are formed here, never in Swift.

typedef struct CaptureEngine CaptureEngine;

// Called when the engine's configuration changes, on the thread that
// posts the notification; it must not destroy the handle
typedef void (*CaptureChange)(void *context);

// Create the engine and observe its configuration changes
CaptureStatus CaptureEngineCreate(CaptureChange change, void *context,
                                  CaptureEngine **engine);
void CaptureEngineDestroy(CaptureEngine *engine);

// The default input's sample rate, or 0 when there is no input device
double CaptureEngineInputRate(CaptureEngine *engine);

// Attach a sink at the input's format that pushes channel 0 of each
// block, and start the engine; stop stops it and detaches the sink
CaptureStatus CaptureEngineStart(CaptureEngine *engine, CapturePush push,
                                 void *context);
void CaptureEngineStop(CaptureEngine *engine);

#ifdef __cplusplus
}
#endif

#endif /* TunerCapture_h */
