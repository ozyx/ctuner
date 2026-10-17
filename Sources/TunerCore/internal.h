//
//  internal.h
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
//  The engine handle and snapshot slot, shared by the core's files.
//  Every field was a function-scope static in Reference/Audio.m.

#ifndef TunerCoreInternal_h
#define TunerCoreInternal_h

#include <Accelerate/Accelerate.h>
#include <dispatch/dispatch.h>
#include <pthread.h>
#include <stdalign.h>
#include <stdatomic.h>

#include "TunerCore.h"

// Analysis constants, as in Reference/Audio.h
#define kMin   0.5
#define kScale 2048.0

enum
{
    kOversample = 16,
    kLog2Samples = 14,
    kSamples2 = kTunerSamples / 2,
    kC5Offset = 57,
    kAOffset = 9,
    kOctave = 12,
    kEqual = 8
};

// Threading constants: the ring holds 32 hops, and atomics written by
// different threads sit 128 bytes apart, the cache line on this Mac
enum
{
    kRingLength = 32768,
    kCacheLine = 128,
    kSlots = 3,
    kDirty = 4
};

// Configuration as one hop sees it
typedef struct
{
    double reference;
    int temperament;
    int key;
    bool filter;
    bool downsample;
    bool fundamental;
    bool noteFilter;
    uint32_t notes;
    uint32_t octaves;
} Config;

// Configuration as the UI writes it: relaxed atomics, read once at the
// start of each hop (KTD6)
typedef struct
{
    _Atomic(double) reference;
    _Atomic(int) temperament;
    _Atomic(int) key;
    _Atomic(bool) filter;
    _Atomic(bool) downsample;
    _Atomic(bool) fundamental;
    _Atomic(bool) noteFilter;
    _Atomic(uint32_t) notes;
    _Atomic(uint32_t) octaves;
} SharedConfig;

// Single-producer, single-consumer sample ring with free-running
// indices (KTD4). The producer counts each dropped block and records
// the write index it was dropped at, the latest gap in the input
typedef struct
{
    alignas(kCacheLine) _Atomic(uint64_t) write;
    alignas(kCacheLine) _Atomic(uint64_t) read;
    alignas(kCacheLine) _Atomic(uint64_t) overruns;
    _Atomic(uint64_t) gap;
    alignas(kCacheLine) float data[kRingLength];
} Ring;

// Input filter state: the one-pole Butterworth low-pass from InputProc
typedef struct
{
    double g;
    double k;
    double xv[2];
    double yv[2];
} Filter;

// A snapshot slot
struct TunerSlot
{
    TunerSnapshot values;
    TunerMaximum maxima[kTunerMaxima];
    double scope[kTunerScopeLength];
    double spectrum[kTunerRange];
};

// The engine
struct TunerEngine
{
    // Configuration; the table is fixed at create
    double sampleRate;
    SharedConfig config;
    double temperaments[kTunerTemperaments][kTunerNotes];

    // Thread: the ring it reads, the semaphore that wakes it and the
    // hop it reads into
    Ring ring;
    dispatch_semaphore_t wake;
    pthread_t thread;
    bool running;
    alignas(kCacheLine) _Atomic(bool) stop;
    float hop[kTunerBlock];
    TunerHopCallback callback;
    void *context;

    // Triple buffer (KTD5): the analysis thread owns the back slot,
    // the consumer the front, and the middle index carries the dirty
    // bit between them
    TunerSlot slots[kSlots];
    int back;
    int front;
    alignas(kCacheLine) _Atomic(int) middle;

    // Rate-derived constants
    double fps;
    double expect;

    // Input
    Filter inputFilter;
    double buffer[kTunerSamples];
    uint64_t sequence;

    // Analysis state
    double dmax;
    double xa[kTunerRange];
    double xp[kTunerRange];
    double xq[kTunerRange];
    double xf[kTunerRange];
    double x2[kTunerRange / 2];
    double x3[kTunerRange / 3];
    double x4[kTunerRange / 4];
    double x5[kTunerRange / 5];
    double dxa[kTunerRange];
    double dxp[kTunerRange];
    TunerMaximum maxima[kTunerMaxima];
    double window[kTunerSamples];
    double input[kTunerSamples];
    double re[kSamples2];
    double im[kSamples2];
    FFTSetupD setup;
};

// Configuration
void ConfigInit(SharedConfig *config);
void ConfigLoad(SharedConfig *shared, Config *config);

// Ring
void RingWrite(Ring *ring, const float *data, int count) TUNER_NONBLOCKING;
bool RingRead(Ring *ring, float *data, int count);

// Snapshots
void SnapshotInit(TunerEngine *engine);
TunerSlot *SnapshotBack(TunerEngine *engine);
void SnapshotPublish(TunerEngine *engine);

// One hop through the filter, the window and the analysis into a slot
void EngineProcessHop(TunerEngine *engine, const float *block,
                      TunerSlot *slot);

// Filter
void FilterInit(Filter *filter, double sampleRate);
void FilterBlock(Filter *filter, bool enabled, const float *data, int count,
                 double *out);

// Analysis
void AnalysisInit(TunerEngine *engine);
void AnalysisReset(TunerEngine *engine);
void AnalysisRun(TunerEngine *engine, const Config *config, TunerSlot *slot);

#endif /* TunerCoreInternal_h */
