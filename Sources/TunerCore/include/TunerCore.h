//
//  TunerCore.h
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
//  The tuner's analysis engine: a plain C library on Accelerate. An
//  engine is an opaque handle with no globals, so several can exist in
//  one process. It turns 1024-sample blocks into snapshots: the note
//  found, its deviation, the maxima, the newest input for the scope and
//  the spectrum.

#ifndef TunerCore_h
#define TunerCore_h

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Marks a function the real-time audio thread may call; clang checks
// what such a function calls where it knows the attribute
#if defined(__has_attribute)
#if __has_attribute(nonblocking)
#define TUNER_NONBLOCKING __attribute__((nonblocking))
#endif
#endif
#ifndef TUNER_NONBLOCKING
#define TUNER_NONBLOCKING
#endif

// Sizes
enum
{
    kTunerBlock = 1024,
    kTunerSamples = 16384,
    kTunerScopeLength = 8192,
    kTunerRange = 7168,
    kTunerMaxima = 8,
    kTunerTemperaments = 32,
    kTunerNotes = 12,
    kTunerOctaves = 9
};

// Status codes
typedef enum
{
    kTunerStatusOK = 0,
    kTunerStatusNoMemory,
    kTunerStatusBadArgument,
    kTunerStatusFFTSetup,
    kTunerStatusThread
} TunerStatus;

// One spectrum maximum: measured and reference frequency in Hz and the
// note number, where 57 is A4
typedef struct
{
    double f;
    double fr;
    int n;
} TunerMaximum;

// A view of one snapshot. The sequence counts hops from 1, so 0 means
// no hop has been published yet. The pointers point into the slot that holds
// the snapshot and stay valid only as long as that slot is not reused.
typedef struct
{
    uint64_t sequence;
    double sampleRate;
    double binWidth;
    bool found;
    int note;
    double deviation;
    double frequency;
    double reference;
    double lower;
    double upper;
    double peak;
    int peakBin;
    int count;
    const TunerMaximum *maxima;
    const double *scope;
    const double *spectrum;
} TunerSnapshot;

typedef struct TunerEngine TunerEngine;
typedef struct TunerSlot TunerSlot;

// Called on the analysis thread after each hop is published
typedef void (*TunerHopCallback)(void *context);

// Status string
const char *TunerStatusString(TunerStatus status);

// Create an engine at a sample rate with a temperament table of
// kTunerTemperaments rows of kTunerNotes ratios, copied at create.
// Destroy stops the analysis thread if it is running; stop capture
// first, so nothing pushes into a freed engine.
TunerStatus TunerEngineCreate(double sampleRate, const double *temperaments,
                              TunerEngine **engine);
void TunerEngineDestroy(TunerEngine *engine);

// Configuration, safe to set from any thread; each hop reads it once
// as it starts
void TunerEngineSetReference(TunerEngine *engine, double reference);
void TunerEngineSetTemperament(TunerEngine *engine, int temperament);
void TunerEngineSetKey(TunerEngine *engine, int key);
void TunerEngineSetFilter(TunerEngine *engine, bool filter);
void TunerEngineSetDownsample(TunerEngine *engine, bool downsample);
void TunerEngineSetFundamental(TunerEngine *engine, bool fundamental);
void TunerEngineSetNoteFilter(TunerEngine *engine, bool noteFilter);
void TunerEngineSetNoteMask(TunerEngine *engine, uint32_t notes);
void TunerEngineSetOctaveMask(TunerEngine *engine, uint32_t octaves);

// Start the analysis thread, which runs one pass for each complete
// kTunerBlock samples pushed and publishes it, then calls the callback
// if there is one. Stop returns once the thread has exited.
TunerStatus TunerEngineStart(TunerEngine *engine, TunerHopCallback callback,
                             void *context);
void TunerEngineStop(TunerEngine *engine);

// Copy samples into the ring and wake the analysis thread; from the
// audio thread, which is its one producer. A push that does not fit
// is dropped whole and counted as an overrun.
void TunerEnginePush(TunerEngine *engine, const float *samples,
                     int count) TUNER_NONBLOCKING;
uint64_t TunerEngineOverruns(TunerEngine *engine);

// View the newest published snapshot; from one consumer thread only.
// Returns true when it is newer than the last one acquired. The view's
// pointers stay valid until the next acquire.
bool TunerEngineAcquire(TunerEngine *engine, TunerSnapshot *snapshot);

// Process one block of kTunerBlock samples on the caller's thread into
// a slot, bypassing the ring; not while the analysis thread runs
TunerStatus TunerEngineProcessBlock(TunerEngine *engine, const float *block,
                                    TunerSlot *slot);

// Snapshot slots
TunerSlot *TunerSlotCreate(void);
void TunerSlotDestroy(TunerSlot *slot);
void TunerSlotView(const TunerSlot *slot, TunerSnapshot *snapshot);

#ifdef __cplusplus
}
#endif

#endif /* TunerCore_h */
