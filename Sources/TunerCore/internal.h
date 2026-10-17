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
//  Every field was a function-scope static in swift/Audio.m.

#ifndef TunerCoreInternal_h
#define TunerCoreInternal_h

#include <Accelerate/Accelerate.h>

#include "TunerCore.h"

// Analysis constants, as in swift/Audio.h
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
    // Configuration
    double sampleRate;
    double reference;
    int temperament;
    int key;
    bool filter;
    bool downsample;
    bool fundamental;
    bool noteFilter;
    uint32_t notes;
    uint32_t octaves;
    double temperaments[kTunerTemperaments][kTunerNotes];

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

// Filter
void FilterInit(Filter *filter, double sampleRate);
void FilterBlock(Filter *filter, bool enabled, const float *data, int count,
                 double *out);

// Analysis
void AnalysisInit(TunerEngine *engine);
void AnalysisRun(TunerEngine *engine, TunerSlot *slot);

#endif /* TunerCoreInternal_h */
