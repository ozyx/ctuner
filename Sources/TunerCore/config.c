//
//  config.c
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
//  Configuration as relaxed atomics (KTD6). The UI sets any field from
//  any thread; each hop loads every field once as it starts.

#include "internal.h"

#define Relaxed memory_order_relaxed

// ConfigInit
void ConfigInit(SharedConfig *config)
{
    atomic_init(&config->reference, 440.0);
    atomic_init(&config->temperament, kEqual);
    atomic_init(&config->key, 0);
    atomic_init(&config->filter, false);
    atomic_init(&config->downsample, false);
    atomic_init(&config->fundamental, false);
    atomic_init(&config->noteFilter, false);
    atomic_init(&config->notes, (1u << kTunerNotes) - 1);
    atomic_init(&config->octaves, (1u << kTunerOctaves) - 1);
}

// ConfigLoad
void ConfigLoad(SharedConfig *shared, Config *config)
{
    config->reference = atomic_load_explicit(&shared->reference, Relaxed);
    config->temperament = atomic_load_explicit(&shared->temperament, Relaxed);
    config->key = atomic_load_explicit(&shared->key, Relaxed);
    config->filter = atomic_load_explicit(&shared->filter, Relaxed);
    config->downsample = atomic_load_explicit(&shared->downsample, Relaxed);
    config->fundamental = atomic_load_explicit(&shared->fundamental, Relaxed);
    config->noteFilter = atomic_load_explicit(&shared->noteFilter, Relaxed);
    config->notes = atomic_load_explicit(&shared->notes, Relaxed);
    config->octaves = atomic_load_explicit(&shared->octaves, Relaxed);
}

// TunerEngineSetReference
void TunerEngineSetReference(TunerEngine *engine, double reference)
{
    atomic_store_explicit(&engine->config.reference, reference, Relaxed);
}

// TunerEngineSetTemperament
void TunerEngineSetTemperament(TunerEngine *engine, int temperament)
{
    // Clamp, so a bad saved index cannot read outside the table
    if (temperament < 0)
        temperament = 0;
    if (temperament >= kTunerTemperaments)
        temperament = kTunerTemperaments - 1;

    atomic_store_explicit(&engine->config.temperament, temperament, Relaxed);
}

// TunerEngineSetKey
void TunerEngineSetKey(TunerEngine *engine, int key)
{
    atomic_store_explicit(&engine->config.key, key, Relaxed);
}

// TunerEngineSetFilter
void TunerEngineSetFilter(TunerEngine *engine, bool filter)
{
    atomic_store_explicit(&engine->config.filter, filter, Relaxed);
}

// TunerEngineSetDownsample
void TunerEngineSetDownsample(TunerEngine *engine, bool downsample)
{
    atomic_store_explicit(&engine->config.downsample, downsample, Relaxed);
}

// TunerEngineSetFundamental
void TunerEngineSetFundamental(TunerEngine *engine, bool fundamental)
{
    atomic_store_explicit(&engine->config.fundamental, fundamental, Relaxed);
}

// TunerEngineSetNoteFilter
void TunerEngineSetNoteFilter(TunerEngine *engine, bool noteFilter)
{
    atomic_store_explicit(&engine->config.noteFilter, noteFilter, Relaxed);
}

// TunerEngineSetNoteMask
void TunerEngineSetNoteMask(TunerEngine *engine, uint32_t notes)
{
    atomic_store_explicit(&engine->config.notes, notes, Relaxed);
}

// TunerEngineSetOctaveMask
void TunerEngineSetOctaveMask(TunerEngine *engine, uint32_t octaves)
{
    atomic_store_explicit(&engine->config.octaves, octaves, Relaxed);
}
