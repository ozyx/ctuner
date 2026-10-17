//
//  snapshot.c
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
//  Snapshot slots and the triple buffer that publishes them (KTD5).
//  The analysis thread writes its back slot and exchanges it into the
//  middle with the dirty bit set; the one consumer exchanges its front
//  slot for the middle when the bit is set. Neither side waits.

#include <stdlib.h>

#include "internal.h"

// SnapshotInit
void SnapshotInit(TunerEngine *engine)
{
    engine->back = 0;
    atomic_init(&engine->middle, 1);
    engine->front = 2;
}

// SnapshotBack
TunerSlot *SnapshotBack(TunerEngine *engine)
{
    return &engine->slots[engine->back];
}

// SnapshotPublish
void SnapshotPublish(TunerEngine *engine)
{
    int old = atomic_exchange_explicit(&engine->middle, engine->back | kDirty,
                                       memory_order_acq_rel);
    engine->back = old & ~kDirty;
}

// TunerEngineAcquire
bool TunerEngineAcquire(TunerEngine *engine, TunerSnapshot *snapshot)
{
    bool fresh = false;

    if (atomic_load_explicit(&engine->middle, memory_order_relaxed) & kDirty)
    {
        int old = atomic_exchange_explicit(&engine->middle, engine->front,
                                           memory_order_acq_rel);
        engine->front = old & ~kDirty;
        fresh = true;
    }

    TunerSlotView(&engine->slots[engine->front], snapshot);
    return fresh;
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
