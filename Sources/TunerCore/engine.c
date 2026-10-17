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
//  The engine handle: lifecycle, configuration and the block entry.

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

    e->sampleRate = sampleRate;
    e->reference = 440.0;
    e->temperament = kEqual;
    e->notes = (1u << kTunerNotes) - 1;
    e->octaves = (1u << kTunerOctaves) - 1;
    memcpy(e->temperaments, temperaments, sizeof(e->temperaments));

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

    vDSP_destroy_fftsetupD(engine->setup);
    free(engine);
}

// TunerEngineSetReference
void TunerEngineSetReference(TunerEngine *engine, double reference)
{
    engine->reference = reference;
}

// TunerEngineSetTemperament
void TunerEngineSetTemperament(TunerEngine *engine, int temperament)
{
    engine->temperament = temperament;
}

// TunerEngineSetKey
void TunerEngineSetKey(TunerEngine *engine, int key)
{
    engine->key = key;
}

// TunerEngineSetFilter
void TunerEngineSetFilter(TunerEngine *engine, bool filter)
{
    engine->filter = filter;
}

// TunerEngineSetDownsample
void TunerEngineSetDownsample(TunerEngine *engine, bool downsample)
{
    engine->downsample = downsample;
}

// TunerEngineSetFundamental
void TunerEngineSetFundamental(TunerEngine *engine, bool fundamental)
{
    engine->fundamental = fundamental;
}

// TunerEngineSetNoteFilter
void TunerEngineSetNoteFilter(TunerEngine *engine, bool noteFilter)
{
    engine->noteFilter = noteFilter;
}

// TunerEngineSetNoteMask
void TunerEngineSetNoteMask(TunerEngine *engine, uint32_t notes)
{
    engine->notes = notes;
}

// TunerEngineSetOctaveMask
void TunerEngineSetOctaveMask(TunerEngine *engine, uint32_t octaves)
{
    engine->octaves = octaves;
}

// TunerEngineProcessBlock
TunerStatus TunerEngineProcessBlock(TunerEngine *engine, const float *block,
                                    TunerSlot *slot)
{
    if (engine == NULL || block == NULL || slot == NULL)
        return kTunerStatusBadArgument;

    // Slide the window by one block, then filter the block in
    // sample order onto its end
    memmove(engine->buffer, engine->buffer + kTunerBlock,
            (kTunerSamples - kTunerBlock) * sizeof(double));
    FilterBlock(&engine->inputFilter, engine->filter, block, kTunerBlock,
                engine->buffer + kTunerSamples - kTunerBlock);

    AnalysisRun(engine, slot);
    engine->sequence++;

    return kTunerStatusOK;
}

// TunerSlotCreate
TunerSlot *TunerSlotCreate(void)
{
    return calloc(1, sizeof(TunerSlot));
}

// TunerSlotDestroy
void TunerSlotDestroy(TunerSlot *slot)
{
    free(slot);
}

// TunerSlotView
void TunerSlotView(const TunerSlot *slot, TunerSnapshot *snapshot)
{
    *snapshot = slot->values;
    snapshot->maxima = slot->maxima;
    snapshot->scope = slot->scope;
    snapshot->spectrum = slot->spectrum;
}
