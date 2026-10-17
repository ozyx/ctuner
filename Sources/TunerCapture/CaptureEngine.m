//
//  CaptureEngine.m
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
//  Stage 2 capture: AVAudioEngine with a sink node on the input node
//  (KTD8). Only the input node is touched, never the output or the
//  mixer. The realtime-safe sink initializer and its block type are in
//  the macOS 27 SDK only and Swift cannot form either, so this file
//  picks the initializer by SDK and by the running system, and CI's
//  SDK 26 build uses the plain one.

#include <stdlib.h>

#import <AVFAudio/AVFAudio.h>

#include "TunerCapture.h"

// Check what the sink block calls, where this clang can
#if defined(__has_warning)
#if __has_warning("-Wfunction-effects")
#pragma clang diagnostic warning "-Wfunction-effects"
#endif
#endif

// The SDK declares the realtime-safe sink initializer
#if defined(__MAC_27_0) || defined(__IPHONE_27_0)
#define CAPTURE_REALTIME_SINK 1
#endif

// SwiftPM's native build system compiles this file with ARC and its
// swiftbuild system without, so the objects are held as Core
// Foundation references, which mean the same either way. Adopt takes
// ownership of an object from alloc or new, CFBridgingRetain of any
// other, and CFRelease lets go.
#if __has_feature(objc_arc)
#define Adopt(object) CFBridgingRetain(object)
#else
#define Adopt(object) ((__bridge CFTypeRef)(object))
#endif

struct CaptureEngine
{
    CFTypeRef engine;
    CFTypeRef sink;
    CFTypeRef observer;
};

// Engine
static AVAudioEngine *Engine(CaptureEngine *engine)
{
    return (__bridge AVAudioEngine *)engine->engine;
}

// Sink: a node whose block pushes channel 0 of each block. The input
// format is deinterleaved, so the first buffer is channel 0.
static CFTypeRef Sink(CapturePush push, void *context)
{
#ifdef CAPTURE_REALTIME_SINK
    if (@available(macOS 27.0, iOS 27.0, *))
    {
        AVAudioSinkNodeReceiverBlockRealtimeSafe block =
            ^OSStatus(const AudioTimeStamp *timestamp,
                      AVAudioFrameCount frameCount,
                      const AudioBufferList *inputData) CAPTURE_NONBLOCKING
        {
            (void)timestamp;
            push(context, inputData->mBuffers[0].mData, (int)frameCount);
            return noErr;
        };

        return Adopt([[AVAudioSinkNode alloc]
                         initWithRealtimeSafeReceiverBlock:block]);
    }
#endif

    AVAudioSinkNodeReceiverBlock block =
        ^OSStatus(const AudioTimeStamp *timestamp,
                  AVAudioFrameCount frameCount,
                  const AudioBufferList *inputData)
    {
        (void)timestamp;
        push(context, inputData->mBuffers[0].mData, (int)frameCount);
        return noErr;
    };

    return Adopt([[AVAudioSinkNode alloc] initWithReceiverBlock:block]);
}

// CaptureEngineCreate
CaptureStatus CaptureEngineCreate(CaptureChange change, void *context,
                                  CaptureEngine **engine)
{
    if (!change || engine == NULL)
        return kCaptureStatusBadArgument;

    CaptureEngine *e = calloc(1, sizeof(CaptureEngine));
    if (e == NULL)
        return kCaptureStatusNoMemory;

    e->engine = Adopt([AVAudioEngine new]);

    // The handler only reports the change; the owner stops and
    // restarts later, never inside it
    id observer =
        [NSNotificationCenter.defaultCenter
            addObserverForName:AVAudioEngineConfigurationChangeNotification
                        object:Engine(e)
                         queue:nil
                    usingBlock:^(NSNotification *notification)
         {
             (void)notification;
             change(context);
         }];
    e->observer = CFBridgingRetain(observer);

    *engine = e;
    return kCaptureStatusOK;
}

// CaptureEngineDestroy
void CaptureEngineDestroy(CaptureEngine *engine)
{
    if (engine == NULL)
        return;

    [NSNotificationCenter.defaultCenter
        removeObserver:(__bridge id)engine->observer];
    CFRelease(engine->observer);

    CaptureEngineStop(engine);
    CFRelease(engine->engine);
    free(engine);
}

// CaptureEngineInputRate
double CaptureEngineInputRate(CaptureEngine *engine)
{
    return [Engine(engine).inputNode inputFormatForBus:0].sampleRate;
}

// CaptureEngineStart
CaptureStatus CaptureEngineStart(CaptureEngine *engine, CapturePush push,
                                 void *context)
{
    if (engine == NULL || !push || engine->sink != NULL)
        return kCaptureStatusBadArgument;

    // The sink does no conversion, so it takes the input's own format
    AVAudioEngine *e = Engine(engine);
    AVAudioInputNode *input = e.inputNode;
    AVAudioFormat *format = [input outputFormatForBus:0];
    if (format.sampleRate <= 0)
        return kCaptureStatusNoInputDevice;

    engine->sink = Sink(push, context);
    AVAudioSinkNode *sink = (__bridge AVAudioSinkNode *)engine->sink;

    [e attachNode:sink];
    [e connect:input to:sink format:format];
    [e prepare];

    if (![e startAndReturnError:nil])
    {
        CaptureEngineStop(engine);
        return kCaptureStatusStart;
    }

    return kCaptureStatusOK;
}

// CaptureEngineStop
void CaptureEngineStop(CaptureEngine *engine)
{
    if (engine == NULL)
        return;

    AVAudioEngine *e = Engine(engine);
    [e stop];

    if (engine->sink != NULL)
    {
        [e detachNode:(__bridge AVAudioSinkNode *)engine->sink];
        CFRelease(engine->sink);
        engine->sink = NULL;
    }
}
