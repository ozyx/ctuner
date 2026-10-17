//
//  ring.c
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
//  The sample ring between the audio thread and the analysis thread
//  (KTD4): one producer, one consumer, free-running indices with
//  acquire and release pairs, and no lock, allocation or log on the
//  push path.

#include <string.h>

#include "internal.h"

// Check what the push path calls, where this clang can
#if defined(__has_warning)
#if __has_warning("-Wfunction-effects")
#pragma clang diagnostic warning "-Wfunction-effects"
#endif
#endif

// Signal: the one call on the push path the checker cannot prove.
// dispatch_semaphore_signal does not allocate or take a lock, and wakes
// a waiter through the kernel, but it carries no nonblocking attribute;
// this is the audited exception.
static void Signal(dispatch_semaphore_t wake) TUNER_NONBLOCKING
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunknown-warning-option"
#pragma clang diagnostic ignored "-Wfunction-effects"
    dispatch_semaphore_signal(wake);
#pragma clang diagnostic pop
}

// RingWrite
void RingWrite(Ring *ring, const float *data, int count) TUNER_NONBLOCKING
{
    uint64_t write = atomic_load_explicit(&ring->write, memory_order_relaxed);
    uint64_t read = atomic_load_explicit(&ring->read, memory_order_acquire);

    // Drop a block that does not fit, whole, count it and mark where
    // it was; the release store of the next write orders the mark
    // before the samples after it
    if (count > kRingLength - (int)(write - read))
    {
        atomic_fetch_add_explicit(&ring->overruns, 1, memory_order_relaxed);
        atomic_store_explicit(&ring->gap, write, memory_order_relaxed);
        return;
    }

    // Copy, across the end of the ring if need be
    int start = (int)(write & (kRingLength - 1));
    int first = (count < kRingLength - start)? count: kRingLength - start;

    memcpy(ring->data + start, data, first * sizeof(float));
    memcpy(ring->data, data + first, (count - first) * sizeof(float));

    atomic_store_explicit(&ring->write, write + count, memory_order_release);
}

// RingRead
bool RingRead(Ring *ring, float *data, int count)
{
    uint64_t write = atomic_load_explicit(&ring->write, memory_order_acquire);
    uint64_t read = atomic_load_explicit(&ring->read, memory_order_relaxed);

    if (write - read < (uint64_t)count)
        return false;

    int start = (int)(read & (kRingLength - 1));
    int first = (count < kRingLength - start)? count: kRingLength - start;

    memcpy(data, ring->data + start, first * sizeof(float));
    memcpy(data + first, ring->data, (count - first) * sizeof(float));

    atomic_store_explicit(&ring->read, read + count, memory_order_release);
    return true;
}

// TunerEnginePush
void TunerEnginePush(TunerEngine *engine, const float *samples, int count)
    TUNER_NONBLOCKING
{
    if (count <= 0)
        return;

    RingWrite(&engine->ring, samples, count);
    Signal(engine->wake);
}

// TunerEngineOverruns
uint64_t TunerEngineOverruns(TunerEngine *engine)
{
    return atomic_load_explicit(&engine->ring.overruns, memory_order_relaxed);
}
