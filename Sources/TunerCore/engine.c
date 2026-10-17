//
//  engine.c
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
//  The engine handle: lifecycle and the block entry.

#include <stdlib.h>
#include <string.h>

#include "internal.h"

// TunerStatusString
const char *TunerStatusString(TunerStatus status)
{
    switch (status)
    {
    case kTunerStatusOK:
        return "OK";
    case kTunerStatusNoMemory:
        return "Out of memory";
    case kTunerStatusBadArgument:
        return "Bad argument";
    case kTunerStatusFFTSetup:
        return "FFT setup failed";
    case kTunerStatusThread:
        return "Analysis thread failed";
    }

    return "Unknown status";
}

// TunerEngineCreate
TunerStatus TunerEngineCreate(double sampleRate, const double *temperaments,
                              TunerEngine **engine)
{
    if (engine == NULL || temperaments == NULL || !(sampleRate > 0.0))
        return kTunerStatusBadArgument;

    TunerEngine *e = calloc(1, sizeof(TunerEngine));
    if (e == NULL)
        return kTunerStatusNoMemory;

    e->setup = vDSP_create_fftsetupD(kLog2Samples, kFFTRadix2);
    if (e->setup == NULL)
    {
        free(e);
        return kTunerStatusFFTSetup;
    }

    e->wake = dispatch_semaphore_create(0);
    if (e->wake == NULL)
    {
        vDSP_destroy_fftsetupD(e->setup);
        free(e);
        return kTunerStatusNoMemory;
    }

    e->sampleRate = sampleRate;
    memcpy(e->temperaments, temperaments, sizeof(e->temperaments));

    ConfigInit(&e->config);
    SnapshotInit(e);
    FilterInit(&e->inputFilter, sampleRate);
    AnalysisInit(e);

    *engine = e;
    return kTunerStatusOK;
}

// TunerEngineDestroy
void TunerEngineDestroy(TunerEngine *engine)
{
    if (engine == NULL)
        return;

    TunerEngineStop(engine);

    dispatch_release(engine->wake);
    vDSP_destroy_fftsetupD(engine->setup);
    free(engine);
}

// EngineProcessHop
void EngineProcessHop(TunerEngine *engine, const float *block, TunerSlot *slot)
{
    // One reading of the configuration for the whole hop
    Config config;
    ConfigLoad(&engine->config, &config);

    // Slide the window by one block, then filter the block in
    // sample order onto its end
    memmove(engine->buffer, engine->buffer + kTunerBlock,
            (kTunerSamples - kTunerBlock) * sizeof(double));
    FilterBlock(&engine->inputFilter, config.filter, block, kTunerBlock,
                engine->buffer + kTunerSamples - kTunerBlock);

    engine->sequence++;
    AnalysisRun(engine, &config, slot);
}

// TunerEngineProcessBlock
TunerStatus TunerEngineProcessBlock(TunerEngine *engine, const float *block,
                                    TunerSlot *slot)
{
    if (engine == NULL || block == NULL || slot == NULL || engine->running)
        return kTunerStatusBadArgument;

    EngineProcessHop(engine, block, slot);
    return kTunerStatusOK;
}
