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

// A view of one snapshot. The pointers point into the slot that holds
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

// Status string
const char *TunerStatusString(TunerStatus status);

// Create an engine at a sample rate with a temperament table of
// kTunerTemperaments rows of kTunerNotes ratios, copied at create
TunerStatus TunerEngineCreate(double sampleRate, const double *temperaments,
                              TunerEngine **engine);
void TunerEngineDestroy(TunerEngine *engine);

// Configuration
void TunerEngineSetReference(TunerEngine *engine, double reference);
void TunerEngineSetTemperament(TunerEngine *engine, int temperament);
void TunerEngineSetKey(TunerEngine *engine, int key);
void TunerEngineSetFilter(TunerEngine *engine, bool filter);
void TunerEngineSetDownsample(TunerEngine *engine, bool downsample);
void TunerEngineSetFundamental(TunerEngine *engine, bool fundamental);
void TunerEngineSetNoteFilter(TunerEngine *engine, bool noteFilter);
void TunerEngineSetNoteMask(TunerEngine *engine, uint32_t notes);
void TunerEngineSetOctaveMask(TunerEngine *engine, uint32_t octaves);

// Process one block of kTunerBlock samples on the caller's thread into
// a slot
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
