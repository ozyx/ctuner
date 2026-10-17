//
//  main.m
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
//  Golden reference harness. Runs the frozen copy of today's engine
//  over one fixture input and writes one line per hop to stdout.
//
//  usage: GoldenReference HEADER INPUT
//
//  The frozen Audio.m is included textually so this one translation
//  unit sees its file statics. AudioUnitRender is defined here, so the
//  real InputProc runs the filter and the sliding window on canned
//  1024-frame blocks, and the main queue is drained after each block so
//  ProcessAudio runs exactly once per hop. The line format is in
//  Tests/TunerCoreTests/Fixtures/README.md.

#include <TargetConditionals.h>

#if TARGET_OS_OSX

#include "Reference/Audio.m"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum
{
    kBlock = 1024,
    kDigestHalf = 3
};

// The stub views carry only their properties
@implementation ScopeView
@end
@implementation SpectrumView
@end
@implementation DisplayView
@end
@implementation StrobeView
@end
@implementation StaffView
@end
@implementation MeterView
@end

// The next block AudioUnitRender hands to InputProc
static Float32 *nextBlock;

// AudioUnitRender, replacing AudioToolbox's for the frozen InputProc
OSStatus AudioUnitRender(AudioUnit unit, AudioUnitRenderActionFlags *flags,
                         const AudioTimeStamp *timeStamp, UInt32 bus,
                         UInt32 frames, AudioBufferList *data)
{
    data->mBuffers[0].mData = nextBlock;
    data->mBuffers[0].mDataByteSize = frames * sizeof(Float32);
    data->mBuffers[0].mNumberChannels = 1;

    return noErr;
}

static long currentHop;

// printDouble
static void printDouble(double value)
{
    printf(" %.17g", value);
}

// ReferenceHook
void ReferenceHook(bool found, double f, double fr, double c, int note,
                   int count, double max, int imax, const void *maxima,
                   const double *xa)
{
    const maximum *list = maxima;

    printf("%ld %d %d %d", currentHop, found? 1: 0, note, count);
    printDouble(f);
    printDouble(fr);
    printDouble(c);
    printDouble(max);
    printf(" %d", imax);

    // Spectrum digest: sum of squares, then the bins around the peak
    double sum = 0.0;
    for (int i = 0; i < kRange; i++)
        sum += xa[i] * xa[i];
    printDouble(sum);

    for (int i = imax - kDigestHalf; i <= imax + kDigestHalf; i++)
        printDouble((i >= 0 && i < kRange)? xa[i]: 0.0);

    for (int i = 0; i < count; i++)
    {
        printDouble(list[i].f);
        printDouble(list[i].fr);
        printf(" %d", list[i].n);
    }

    printf("\n");
}

// Header values
typedef struct
{
    double rate;
    double reference;
    long hops;
    long toggle;
    int temper;
    int key;
    int filt;
    int down;
    int fund;
    int note;
    unsigned notes;
    unsigned octaves;
} Header;

// readHeader
static int readHeader(const char *path, Header *header)
{
    FILE *file = fopen(path, "r");
    if (file == NULL)
    {
        perror(path);
        return -1;
    }

    *header = (Header){44100.0, 440.0, 0, -1, kEqual, 0, 0, 0, 0, 0,
        0xfff, 0x1ff};

    char key[64];
    char value[256];
    char line[512];

    while (fgets(line, sizeof(line), file) != NULL)
    {
        if (sscanf(line, "%63s %255s", key, value) != 2)
            continue;

        if (strcmp(key, "rate") == 0)
            header->rate = atof(value);
        else if (strcmp(key, "reference") == 0)
            header->reference = atof(value);
        else if (strcmp(key, "hops") == 0)
            header->hops = atol(value);
        else if (strcmp(key, "filt_toggle_hop") == 0)
            header->toggle = atol(value);
        else if (strcmp(key, "temper") == 0)
            header->temper = atoi(value);
        else if (strcmp(key, "key") == 0)
            header->key = atoi(value);
        else if (strcmp(key, "filt") == 0)
            header->filt = atoi(value);
        else if (strcmp(key, "down") == 0)
            header->down = atoi(value);
        else if (strcmp(key, "fund") == 0)
            header->fund = atoi(value);
        else if (strcmp(key, "note") == 0)
            header->note = atoi(value);
        else if (strcmp(key, "notes") == 0)
            header->notes = (unsigned)strtoul(value, NULL, 16);
        else if (strcmp(key, "octaves") == 0)
            header->octaves = (unsigned)strtoul(value, NULL, 16);
    }

    fclose(file);
    return 0;
}

// main
int main(int argc, char *argv[])
{
    if (argc != 3)
    {
        fprintf(stderr, "usage: GoldenReference HEADER INPUT\n");
        return 2;
    }

    Header header;
    if (readHeader(argv[1], &header) != 0)
        return 1;

    FILE *file = fopen(argv[2], "rb");
    if (file == NULL)
    {
        perror(argv[2]);
        return 1;
    }

    // The views the frozen engine writes to
    scopeView = [ScopeView new];
    spectrumView = [SpectrumView new];
    displayView = [DisplayView new];
    strobeView = [StrobeView new];
    staffView = [StaffView new];
    meterView = [MeterView new];
    displayView.lock = NO;

    // Configuration, as SetupAudio and the preferences would leave it
    audio.sample = header.rate;
    audio.frames = kBlock;
    audio.reference = header.reference;
    audio.temper = header.temper;
    audio.key = header.key;
    audio.filt = header.filt;
    audio.down = header.down;
    audio.fund = header.fund;
    audio.note = header.note;

    for (int i = 0; i < Length(filters.note); i++)
        filters.note[i] = (header.notes >> i) & 1;
    for (int i = 0; i < Length(filters.octave); i++)
        filters.octave[i] = (header.octaves >> i) & 1;

    static Float32 block[kBlock];
    AudioUnitRenderActionFlags flags = 0;
    AudioTimeStamp timeStamp = {0};

    for (currentHop = 0; currentHop < header.hops; currentHop++)
    {
        if (fread(block, sizeof(block), 1, file) != 1)
        {
            fprintf(stderr, "%s: short input at hop %ld\n", argv[2],
                    currentHop);
            fclose(file);
            return 1;
        }

        if (currentHop == header.toggle)
            audio.filt = !audio.filt;

        nextBlock = block;
        InputProc(&audio.output, &flags, &timeStamp, 1, kBlock, NULL);

        // Run the ProcessAudio block InputProc queued
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, true);
    }

    fclose(file);
    return 0;
}

#else

// main
int main(int argc, char *argv[])
{
    return 1;
}

#endif
