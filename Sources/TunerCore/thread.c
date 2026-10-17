//
//  thread.c
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
//  The analysis thread (KTD4): it waits on the semaphore the push
//  signals, then runs one pass for each complete hop in the ring, so a
//  callback size other than 1024 never splits a hop.

#include <pthread/qos.h>

#include "internal.h"

// AnalysisThread
static void *AnalysisThread(void *argument)
{
    TunerEngine *e = argument;

    pthread_setname_np("TunerCore analysis");

    for (;;)
    {
        dispatch_semaphore_wait(e->wake, DISPATCH_TIME_FOREVER);

        if (atomic_load_explicit(&e->stop, memory_order_acquire))
            break;

        // Catch up on every complete hop
        while (RingRead(&e->ring, e->hop, kTunerBlock))
        {
            // A dropped block leaves a gap in the input; take no phase
            // difference across it
            uint64_t overruns = TunerEngineOverruns(e);
            if (overruns != e->seenOverruns)
            {
                AnalysisReset(e);
                e->seenOverruns = overruns;
            }

            EngineProcessHop(e, e->hop, SnapshotBack(e));
            SnapshotPublish(e);

            if (e->callback != NULL)
                e->callback(e->context);
        }
    }

    return NULL;
}

// TunerEngineStart
TunerStatus TunerEngineStart(TunerEngine *engine, TunerHopCallback callback,
                             void *context)
{
    if (engine == NULL || engine->running)
        return kTunerStatusBadArgument;

    engine->callback = callback;
    engine->context = context;
    atomic_store_explicit(&engine->stop, false, memory_order_relaxed);

    pthread_attr_t attributes;
    pthread_attr_init(&attributes);
    pthread_attr_set_qos_class_np(&attributes, QOS_CLASS_USER_INITIATED, 0);

    int result = pthread_create(&engine->thread, &attributes, AnalysisThread,
                                engine);
    pthread_attr_destroy(&attributes);

    if (result != 0)
        return kTunerStatusThread;

    engine->running = true;
    return kTunerStatusOK;
}

// TunerEngineStop
void TunerEngineStop(TunerEngine *engine)
{
    if (engine == NULL || !engine->running)
        return;

    atomic_store_explicit(&engine->stop, true, memory_order_release);
    dispatch_semaphore_signal(engine->wake);
    pthread_join(engine->thread, NULL);

    engine->running = false;
}
