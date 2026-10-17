//
//  generate.c
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
//  Writes a golden fixture input: float32 samples computed in double
//  from the parameters on the command line, and prints the header
//  lines that describe them, ending with the FNV-1a hash of the bytes
//  written. The arithmetic is unoptimised and contraction-free so that
//  every compiler produces the same bytes; a changed hash means the
//  input changed, not the engine.
//
//  usage: GoldenGenerator --out FILE [--rate HZ] [--hops N]
//             [--tone HZ:AMP:PHASE]... [--harmonic HZ:AMP:K]...
//             [--noise AMP:SEED]
//
//  --tone      a sine, AMP * sin(2 pi HZ n / rate + PHASE)
//  --harmonic  harmonics 1 to K of HZ, harmonic k at amplitude AMP / k
//  --noise     white noise in [-AMP, AMP) from an xorshift64* seed
//
//  No component gives silence.

#pragma clang fp contract(off)

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum
{
    kBlock = 1024,
    kMaxParts = 16,
    kDefaultRate = 44100,
    kDefaultHops = 64
};

typedef enum
{
    kPartTone,
    kPartHarmonic,
    kPartNoise
} PartKind;

typedef struct
{
    PartKind kind;
    double hz;
    double amp;
    double phase;
    int harmonics;
    uint64_t seed;
} Part;

// usage
static int usage(void)
{
    fprintf(stderr, "usage: GoldenGenerator --out FILE [--rate HZ] [--hops N]\n"
            "           [--tone HZ:AMP:PHASE]... [--harmonic HZ:AMP:K]...\n"
            "           [--noise AMP:SEED]\n");
    return 2;
}

// nextRandom (xorshift64*)
__attribute__((optnone))
static uint64_t nextRandom(uint64_t *state)
{
    uint64_t x = *state;

    x ^= x >> 12;
    x ^= x << 25;
    x ^= x >> 27;
    *state = x;

    return x * 0x2545F4914F6CDD1DULL;
}

// sampleAt
__attribute__((optnone))
static double sampleAt(Part *parts, int count, long n, double rate)
{
    double sum = 0.0;

    for (int p = 0; p < count; p++)
    {
        Part *part = &parts[p];

        switch (part->kind)
        {
        case kPartTone:
            sum += part->amp *
                sin(2.0 * M_PI * part->hz * (double)n / rate + part->phase);
            break;

        case kPartHarmonic:
            for (int k = 1; k <= part->harmonics; k++)
                sum += (part->amp / (double)k) *
                    sin(2.0 * M_PI * part->hz * (double)k * (double)n / rate);
            break;

        case kPartNoise:
        {
            // Top 53 bits to [0, 1), then to [-1, 1)
            double unit = (double)(nextRandom(&part->seed) >> 11) *
                (1.0 / 9007199254740992.0);
            sum += part->amp * (2.0 * unit - 1.0);
            break;
        }
        }
    }

    return sum;
}

// fnv1a
static uint64_t fnv1a(uint64_t hash, const unsigned char *bytes, size_t length)
{
    for (size_t i = 0; i < length; i++)
    {
        hash ^= bytes[i];
        hash *= 0x100000001B3ULL;
    }

    return hash;
}

// main
int main(int argc, char *argv[])
{
    Part parts[kMaxParts];
    int count = 0;
    double rate = kDefaultRate;
    long hops = kDefaultHops;
    const char *out = NULL;

    for (int i = 1; i < argc; i++)
    {
        const char *arg = argv[i];
        const char *value = (i + 1 < argc)? argv[i + 1]: NULL;

        if (value == NULL)
            return usage();

        if (strcmp(arg, "--out") == 0)
            out = value;

        else if (strcmp(arg, "--rate") == 0)
            rate = atof(value);

        else if (strcmp(arg, "--hops") == 0)
            hops = atol(value);

        else if (count < kMaxParts && strcmp(arg, "--tone") == 0)
        {
            Part part = {kPartTone};
            if (sscanf(value, "%lf:%lf:%lf", &part.hz, &part.amp,
                       &part.phase) != 3)
                return usage();
            parts[count++] = part;
        }

        else if (count < kMaxParts && strcmp(arg, "--harmonic") == 0)
        {
            Part part = {kPartHarmonic};
            if (sscanf(value, "%lf:%lf:%d", &part.hz, &part.amp,
                       &part.harmonics) != 3)
                return usage();
            parts[count++] = part;
        }

        else if (count < kMaxParts && strcmp(arg, "--noise") == 0)
        {
            Part part = {kPartNoise};
            unsigned long long seed;
            if (sscanf(value, "%lf:%llu", &part.amp, &seed) != 2 || seed == 0)
                return usage();
            part.seed = seed;
            parts[count++] = part;
        }

        else
            return usage();

        i++;
    }

    if (out == NULL || rate <= 0.0 || hops <= 0)
        return usage();

    FILE *file = fopen(out, "wb");
    if (file == NULL)
    {
        perror(out);
        return 1;
    }

    uint64_t hash = 0xCBF29CE484222325ULL;
    float block[kBlock];

    for (long h = 0; h < hops; h++)
    {
        for (int i = 0; i < kBlock; i++)
            block[i] = (float)sampleAt(parts, count, h * kBlock + i, rate);

        hash = fnv1a(hash, (const unsigned char *)block, sizeof(block));

        if (fwrite(block, sizeof(block), 1, file) != 1)
        {
            perror(out);
            fclose(file);
            return 1;
        }
    }

    fclose(file);

    // The signal description, so the header records how to remake it
    printf("signal");
    for (int i = 1; i < argc; i++)
        if (strcmp(argv[i], "--out") == 0)
            i++;
        else
            printf(" %s", argv[i]);
    printf("\n");

    printf("hops %ld\n", hops);
    printf("block %d\n", kBlock);
    printf("input_bytes %ld\n", hops * kBlock * (long)sizeof(float));
    printf("input_hash %016llx\n", (unsigned long long)hash);

    return 0;
}
