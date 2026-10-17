//
//  core-leaks.c
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
//  The engine's lifecycle a hundred times over, for leaks --atExit:
//  create, start, push, stop and destroy, then destroy with the thread
//  waiting on its semaphore. The test bundle cannot run under leaks on
//  the Command Line Tools, because leaks drops the framework path the
//  Testing framework loads from, so make core-leaks runs this instead.

#include <stdio.h>
#include <unistd.h>

#include "TunerCore.h"

// Number of cycles
#define kCycles 100

// main
int main(void)
{
    static double temperaments[kTunerTemperaments * kTunerNotes];
    static float block[4 * kTunerBlock];

    for (int i = 0; i < kTunerTemperaments * kTunerNotes; i++)
        temperaments[i] = 1.0;

    for (int i = 0; i < 4 * kTunerBlock; i++)
        block[i] = 0.25f;

    for (int n = 0; n < kCycles; n++)
    {
        TunerEngine *engine;
        TunerSnapshot snapshot;

        if (TunerEngineCreate(44100, temperaments, &engine) != kTunerStatusOK)
            return 1;

        TunerEngineStart(engine, NULL, NULL);
        TunerEnginePush(engine, block, 4 * kTunerBlock);

        do
        {
            usleep(100);
            TunerEngineAcquire(engine, &snapshot);
        } while (snapshot.sequence < 4);

        TunerEngineStop(engine);
        TunerEngineDestroy(engine);

        if (TunerEngineCreate(44100, temperaments, &engine) != kTunerStatusOK)
            return 1;

        TunerEngineStart(engine, NULL, NULL);
        TunerEngineDestroy(engine);
    }

    printf("core-leaks: %d cycles\n", kCycles);
    return 0;
}
