//
//  CaptureHAL.m
//  Tuner
//
//  Created by Bill Farmer on 18/02/2018.
//  Copyright © 2018 Bill Farmer. All rights reserved.
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
//  Stage 1 capture: today's AUHAL input unit from swift/Audio.m, with
//  the dispatch, the log calls and the filter taken out of the input
//  callback, which renders into a preallocated buffer and pushes it.

#include <math.h>
#include <stdatomic.h>
#include <stdlib.h>

#include <AudioToolbox/AudioToolbox.h>
#include <CoreAudio/CoreAudio.h>

#include "TunerCapture.h"

// Check what the input callback calls, where this clang can
#if defined(__has_warning)
#if __has_warning("-Wfunction-effects")
#pragma clang diagnostic warning "-Wfunction-effects"
#endif
#endif

// Stream format: mono 32-bit float
enum
{
    kBytesPerPacket = 4,
    kBytesPerFrame = 4,
    kChannelsPerFrame = 1
};

struct Capture
{
    AudioUnit unit;
    CapturePush push;
    void *context;
    double sampleRate;
    UInt32 frames;
    float *buffer;
    AudioBufferList list;
    atomic_int status;
};

// CaptureStatusString
const char *CaptureStatusString(CaptureStatus status)
{
    switch (status)
    {
    case kCaptureStatusOK:
        return "OK";
    case kCaptureStatusNoMemory:
        return "Out of memory";
    case kCaptureStatusBadArgument:
        return "Bad argument";
    case kCaptureStatusNoComponent:
        return "No audio output unit";
    case kCaptureStatusNoInputDevice:
        return "No input device";
    case kCaptureStatusDevice:
        return "Input device setup failed";
    case kCaptureStatusUnit:
        return "Audio unit setup failed";
    case kCaptureStatusStart:
        return "Audio input failed to start";
    case kCaptureStatusRender:
        return "Audio input failed";
    }

    return "Unknown status";
}

// CaptureBufferFrames
int CaptureBufferFrames(double minimum, double maximum)
{
    int frames = kCaptureBlock;

    while (frames > 1 && frames > maximum)
        frames /= 2;

    // Today's loop halved for ever when the minimum was above the block
    if (frames < minimum)
        frames = (int)ceil(minimum);

    return frames;
}

// InputProc
static OSStatus InputProc(void *inRefCon,
                          AudioUnitRenderActionFlags *ioActionFlags,
                          const AudioTimeStamp *inTimeStamp,
                          UInt32 inBusNumber, UInt32 inNumberFrames,
                          AudioBufferList *ioData) CAPTURE_NONBLOCKING
{
    Capture *capture = inRefCon;
    (void)ioData;

    // More frames than the buffer holds
    if (inNumberFrames > capture->frames)
    {
        atomic_store_explicit(&capture->status, kCaptureStatusRender,
                              memory_order_relaxed);
        return kAudioUnitErr_TooManyFramesToProcess;
    }

    // Render into the preallocated buffer
    capture->list.mBuffers[0].mData = capture->buffer;
    capture->list.mBuffers[0].mDataByteSize =
        inNumberFrames * sizeof(float);

    OSStatus status = AudioUnitRender(capture->unit, ioActionFlags,
                                      inTimeStamp, inBusNumber,
                                      inNumberFrames, &capture->list);
    if (status != noErr)
    {
        atomic_store_explicit(&capture->status, kCaptureStatusRender,
                              memory_order_relaxed);
        return status;
    }

    // Channel 0, as rendered
    capture->push(capture->context, capture->list.mBuffers[0].mData,
                  (int)inNumberFrames);

    return noErr;
}

// Setup
static CaptureStatus Setup(Capture *capture)
{
    // Specify an output unit
    AudioComponentDescription dc =
        {kAudioUnitType_Output,
         kAudioUnitSubType_HALOutput,
         kAudioUnitManufacturer_Apple,
         0, 0};

    // Find an output unit
    AudioComponent cp = AudioComponentFindNext(NULL, &dc);
    if (cp == NULL)
        return kCaptureStatusNoComponent;

    // Open it
    OSStatus status = AudioComponentInstanceNew(cp, &capture->unit);
    if (status != noErr)
    {
        capture->unit = NULL;
        return kCaptureStatusNoComponent;
    }

    UInt32 enable;
    UInt32 size;

    // Enable input
    enable = true;
    status = AudioUnitSetProperty(capture->unit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  1, &enable, sizeof(enable));
    if (status != noErr)
        return kCaptureStatusUnit;

    // Disable output
    enable = false;
    status = AudioUnitSetProperty(capture->unit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  0, &enable, sizeof(enable));
    if (status != noErr)
        return kCaptureStatusUnit;

    AudioDeviceID id;
    size = sizeof(id);

    // Get the default input device
    AudioObjectPropertyAddress inputDeviceAOPA =
        {kAudioHardwarePropertyDefaultInputDevice,
         kAudioObjectPropertyScopeGlobal,
         kAudioObjectPropertyElementMain};

    status = AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                        &inputDeviceAOPA,
                                        0, NULL, &size, &id);
    if (status != noErr || id == kAudioObjectUnknown)
        return kCaptureStatusNoInputDevice;

    // Set the audio unit device
    status = AudioUnitSetProperty(capture->unit,
                                  kAudioOutputUnitProperty_CurrentDevice,
                                  kAudioUnitScope_Global,
                                  0, &id, size);
    if (status != noErr)
        return kCaptureStatusUnit;

    Float64 nominal = kCaptureSampleRate;
    size = sizeof(nominal);

    AudioObjectPropertyAddress audioDeviceAOPA =
        {kAudioDevicePropertyNominalSampleRate,
         kAudioObjectPropertyScopeGlobal,
         kAudioObjectPropertyElementMain};

    // Set the sample rate, if in range, ignore errors; the rate the
    // device then has is the rate captured at
    AudioObjectSetPropertyData(id, &audioDeviceAOPA, 0, NULL,
                               size, &nominal);

    // Get the sample rate
    status = AudioObjectGetPropertyData(id, &audioDeviceAOPA, 0, NULL,
                                        &size, &nominal);
    if (status != noErr)
        return kCaptureStatusDevice;

    capture->sampleRate = nominal;

    // Get the buffer size range
    AudioValueRange sizes;
    size = sizeof(sizes);
    audioDeviceAOPA.mSelector = kAudioDevicePropertyBufferFrameSizeRange;

    status = AudioObjectGetPropertyData(id, &audioDeviceAOPA, 0, NULL,
                                        &size, &sizes);
    if (status != noErr)
        return kCaptureStatusDevice;

    UInt32 frames = CaptureBufferFrames(sizes.mMinimum, sizes.mMaximum);
    size = sizeof(frames);

    // Set the max frames
    status = AudioUnitSetProperty(capture->unit,
                                  kAudioUnitProperty_MaximumFramesPerSlice,
                                  kAudioUnitScope_Global, 0,
                                  &frames, sizeof(frames));
    if (status != noErr)
        return kCaptureStatusUnit;

    // Set the buffer frame size
    audioDeviceAOPA.mSelector = kAudioDevicePropertyBufferFrameSize;

    status = AudioObjectSetPropertyData(id, &audioDeviceAOPA, 0, NULL,
                                        size, &frames);
    if (status != noErr)
        return kCaptureStatusDevice;

    // Get the frames
    status = AudioUnitGetProperty(capture->unit,
                                  kAudioUnitProperty_MaximumFramesPerSlice,
                                  kAudioUnitScope_Global, 0, &frames, &size);
    if (status != noErr)
        return kCaptureStatusUnit;

    // The buffer the callback renders into
    capture->frames = frames;
    capture->buffer = calloc(frames, sizeof(float));
    if (capture->buffer == NULL)
        return kCaptureStatusNoMemory;

    capture->list.mNumberBuffers = 1;
    capture->list.mBuffers[0].mNumberChannels = kChannelsPerFrame;
    capture->list.mBuffers[0].mDataByteSize = frames * sizeof(float);
    capture->list.mBuffers[0].mData = capture->buffer;

    AudioStreamBasicDescription format;
    size = sizeof(format);

    // Get stream format
    status = AudioUnitGetProperty(capture->unit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input, 1,
                                  &format, &size);
    if (status != noErr)
        return kCaptureStatusUnit;

    // Set format
    format.mSampleRate = nominal;
    format.mBytesPerPacket = kBytesPerPacket;
    format.mBytesPerFrame = kBytesPerFrame;
    format.mChannelsPerFrame = kChannelsPerFrame;

    // Set stream format
    status = AudioUnitSetProperty(capture->unit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output, 1,
                                  &format, sizeof(format));
    if (status != noErr)
        return kCaptureStatusUnit;

    AURenderCallbackStruct input =
        {InputProc, capture};

    // Set callback
    status = AudioUnitSetProperty(capture->unit,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Global, 0,
                                  &input, sizeof(input));
    if (status != noErr)
        return kCaptureStatusUnit;

    // Init the audio unit
    status = AudioUnitInitialize(capture->unit);
    if (status != noErr)
        return kCaptureStatusUnit;

    return kCaptureStatusOK;
}

// Dispose
static void Dispose(Capture *capture)
{
    if (capture->unit != NULL)
    {
        AudioOutputUnitStop(capture->unit);
        AudioUnitUninitialize(capture->unit);
        AudioComponentInstanceDispose(capture->unit);
    }

    free(capture->buffer);
    free(capture);
}

// CaptureCreate
CaptureStatus CaptureCreate(CapturePush push, void *context,
                            Capture **capture)
{
    if (!push || capture == NULL)
        return kCaptureStatusBadArgument;

    Capture *c = calloc(1, sizeof(Capture));
    if (c == NULL)
        return kCaptureStatusNoMemory;

    c->push = push;
    c->context = context;
    atomic_init(&c->status, kCaptureStatusOK);

    // Dispose the unit on any failure
    CaptureStatus status = Setup(c);
    if (status != kCaptureStatusOK)
    {
        Dispose(c);
        return status;
    }

    *capture = c;
    return kCaptureStatusOK;
}

// CaptureDestroy
void CaptureDestroy(Capture *capture)
{
    if (capture == NULL)
        return;

    Dispose(capture);
}

// CaptureStart
CaptureStatus CaptureStart(Capture *capture)
{
    if (capture == NULL)
        return kCaptureStatusBadArgument;

    atomic_store_explicit(&capture->status, kCaptureStatusOK,
                          memory_order_relaxed);

    // Start the audio unit
    if (AudioOutputUnitStart(capture->unit) != noErr)
    {
        atomic_store_explicit(&capture->status, kCaptureStatusStart,
                              memory_order_relaxed);
        return kCaptureStatusStart;
    }

    return kCaptureStatusOK;
}

// CaptureStop
void CaptureStop(Capture *capture)
{
    if (capture == NULL)
        return;

    AudioOutputUnitStop(capture->unit);
}

// CaptureGetStatus
CaptureStatus CaptureGetStatus(Capture *capture)
{
    return atomic_load_explicit(&capture->status, memory_order_relaxed);
}

// CaptureSampleRate
double CaptureSampleRate(Capture *capture)
{
    return capture->sampleRate;
}
