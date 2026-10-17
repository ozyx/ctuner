//
//  analysis.c
//  Tuner
//
//  Created by Bill Farmer on 18/02/2018.
//  Copyright © 2018 Bill Farmer. All rights reserved.
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
//  ProcessAudio from swift/Audio.m, line for line, with its statics in
//  the engine handle and its view writes replaced by snapshot fields.
//  The engine always computes: locking the display is the UI's job, as
//  are the decimation counters and the silence timer.

#pragma clang fp contract(off)

#include <math.h>
#include <string.h>

#include "internal.h"

#define Length(a) ((int)(sizeof(a) / sizeof(a[0])))

// AnalysisInit
void AnalysisInit(TunerEngine *e)
{
    e->fps = e->sampleRate / (double)kTunerSamples;
    e->expect = 2.0 * M_PI * (double)kTunerBlock / (double)kTunerSamples;

    // Init Hamming window
    vDSP_hamm_windowD(e->window, kTunerSamples, 0);
}

// AnalysisRun
void AnalysisRun(TunerEngine *e, TunerSlot *slot)
{
    double *xa = e->xa;
    double *xp = e->xp;
    double *xq = e->xq;
    double *xf = e->xf;
    double *dxa = e->dxa;
    double *dxp = e->dxp;
    TunerMaximum *maxima = e->maxima;
    DSPDoubleSplitComplex x = {e->re, e->im};

    if (e->dmax < 0.125)
        e->dmax = 0.125;

    // Calculate normalising value
    double norm = e->dmax;

    // Get max magitude
    vDSP_maxmgvD(e->buffer, 1, &e->dmax, kTunerSamples);

    // Divide by normalisation
    vDSP_vsdivD(e->buffer, 1, &norm, e->input, 1, kTunerSamples);

    // Multiply by window
    vDSP_vmulD(e->input, 1, e->window, 1, e->input, 1, kTunerSamples);

    // Copy input to split complex vector
    vDSP_ctozD((DSPDoubleComplex *)e->input, 2, &x, 1, kSamples2);

    // Do FFT
    vDSP_fft_zripD(e->setup, &x, 1, kLog2Samples, kFFTDirection_Forward);

    // Zero the zeroth part
    x.realp[0] = 0.0;
    x.imagp[0] = 0.0;

    // Scale the output
    double scale = kScale;

    vDSP_vsdivD(x.realp, 1, &scale, x.realp, 1, kSamples2);
    vDSP_vsdivD(x.imagp, 1, &scale, x.imagp, 1, kSamples2);

    // Magnitude
    vDSP_vdistD(x.realp, 1, x.imagp, 1, xa, 1, kTunerRange);

    // Phase
    vDSP_zvphasD(&x, 1, xq, 1, kTunerRange);

    // Phase difference
    vDSP_vsubD(xp, 1, xq, 1, dxp, 1, kTunerRange);

    for (int i = 1; i < kTunerRange; i++)
    {
        // Do frequency calculation
        double dp = dxp[i];

        // Calculate phase difference
        dp -= (double)i * e->expect;

        int qpd = dp / M_PI;

        if (qpd >= 0)
            qpd += qpd & 1;

        else
            qpd -= qpd & 1;

        dp -=  M_PI * (double)qpd;

        // Calculate frequency difference
        double df = kOversample * dp / (2.0 * M_PI);

        // Calculate actual frequency from slot frequency plus
        // frequency difference
        xf[i] = i * e->fps + df * e->fps;

        // Calculate differences for finding maxima
        dxa[i] = xa[i] - xa[i - 1];
    }

    // Copy phase vector
    memmove(xp, xq, kTunerRange * sizeof(double));

    // Downsample
    if (e->downsample)
    {
        // x2 = xa << 2
        for (int i = 0; i < Length(e->x2); i++)
        {
            e->x2[i] = 0.0;

            for (int j = 0; j < 2; j++)
                e->x2[i] += xa[(i * 2) + j];
        }

        // x3 = xa << 3
        for (int i = 0; i < Length(e->x3); i++)
        {
            e->x3[i] = 0.0;

            for (int j = 0; j < 3; j++)
                e->x3[i] += xa[(i * 3) + j];
        }

        // x4 = xa << 4
        for (int i = 0; i < Length(e->x4); i++)
        {
            e->x4[i] = 0.0;

            for (int j = 0; j < 4; j++)
                e->x4[i] += xa[(i * 4) + j];
        }

        // x5 = xa << 5
        for (int i = 0; i < Length(e->x5); i++)
        {
            e->x5[i] = 0.0;

            for (int j = 0; j < 5; j++)
                e->x5[i] += xa[(i * 5) + j];
        }

        // Add downsamples
        for (int i = 0; i < kTunerRange; i++)
        {
            xa[i] *= (i < Length(e->x2))? e->x2[i]: 0.0;
            xa[i] *= (i < Length(e->x3))? e->x3[i]: 0.0;
            xa[i] *= (i < Length(e->x4))? e->x4[i]: 0.0;
            xa[i] *= (i < Length(e->x5))? e->x5[i]: 0.0;

            // Calculate differences for finding maxima; there is none
            // for bin 0, which today's engine read from before the
            // spectrum, and the search never uses it
            if (i > 0)
                dxa[i] = xa[i] - xa[i - 1];
        }
    }

    // Maximum FFT output
    double max;
    vDSP_Length imax;

    vDSP_maxmgviD(xa, 1, &max, &imax, kTunerRange);

    double f = xf[imax];

    int count = 0;
    int limit = kTunerRange - 1;

    // Find maximum value, and list of maxima
    for (int i = 1; i < limit; i++)
    {
        // Clear the next maximum, if there is room for one; today's
        // engine wrote one past the list once it was full
        if (count < kTunerMaxima)
        {
            maxima[count].f  = 0.0;
            maxima[count].fr = 0.0;
            maxima[count].n  = 0;
        }

        // A bin with no positive frequency estimate is not a note; today's
        // engine converted its infinite or NaN cents to int
        if (!(xf[i] > 0.0))
            continue;

        // Cents relative to reference
        double cf = -12.0 * log2(e->reference / xf[i]);
        int note = round(cf) + kC5Offset;

        // Ignore negative
        if (note < 0)
            continue;

        // Fundamental filter
        if ((e->fundamental) && (count > 0) &&
            ((note % kOctave) != (maxima[0].n % kOctave)))
            continue;

        // Note filter
        if (e->noteFilter)
        {
            // Get note and octave
            int n = note % kOctave;
            int o = note / kOctave;

            // Ignore too high
            if (o >= kTunerOctaves)
                continue;

            // Ignore if filtered
            if (!((e->notes >> n) & 1) ||
                !((e->octaves >> o) & 1))
                continue;
        }

        // Find maxima and add to list
        if (count < kTunerMaxima &&
            xa[i] > kMin && xa[i] > (max / 4) &&
            dxa[i] > 0.0 && dxa[i + 1] < 0.0)
        {
            // Frequency
            maxima[count].f = xf[i];

            // Note number
            maxima[count].n = note;

            // Octave note number
            int n = (note - e->key + kOctave) % kOctave;
            // A note number
            int a = (kAOffset - e->key + kOctave) % kOctave;

            // Temperament ratio
            double temperRatio = e->temperaments[e->temperament][n] /
                e->temperaments[e->temperament][a];
            // Equal ratio
            double equalRatio = e->temperaments[kEqual][n] /
                e->temperaments[kEqual][a];

            // Temperament adjustment
            double temperAdjust = temperRatio / equalRatio;

            // Reference note
            maxima[count].fr = e->reference *
                pow(2.0, round(cf) / 12.0) * temperAdjust;

            // Set limit to octave above
            if (!e->downsample && (limit > i * 2))
                limit = i * 2 - 1;

            count++;
        }
    }

    // Reference note frequency and lower and upper limits
    double fr = 0.0;
    double fl = 0.0;
    double fh = 0.0;

    // Note number
    int note = 0;

    // Found flag and cents value
    bool found = false;
    double c = 0.0;

    // Do the note and cents calculations
    // Frequency
    if (max > kMin && !e->downsample)
        f = maxima[0].f;

    // No candidate: today's engine went on to convert infinite or NaN
    // cents to int and index before a temperament row; only a positive
    // frequency on a non-negative note reaches the calculations
    double cf = (max > kMin && f > 0.0)?
        -12.0 * log2(e->reference / f): 0.0;

    if (max > kMin && f > 0.0 && round(cf) + kC5Offset >= 0)
    {
        found = true;

        // Note number
        note = round(cf) + kC5Offset;

        // Octave note number
        int n = (note - e->key + kOctave) % kOctave;
        // A note number
        int a = (kAOffset - e->key + kOctave) % kOctave;

        // Temperament ratio
        double temperRatio = e->temperaments[e->temperament][n] /
            e->temperaments[e->temperament][a];
        // Equal ratio
        double equalRatio = e->temperaments[kEqual][n] /
            e->temperaments[kEqual][a];

        // Temperament adjustment
        double temperAdjust = temperRatio / equalRatio;

        // Reference note
        fr = e->reference * pow(2.0, round(cf) / 12.0) * temperAdjust;

        // Lower and upper freq
        fl = e->reference * pow(2.0, (round(cf) - 0.60) /
                                12.0) * temperAdjust;
        fh = e->reference * pow(2.0, (round(cf) + 0.60) /
                                12.0) * temperAdjust;

        // Find nearest maximum to reference note
        double df = 1000.0;

        for (int i = 0; i < count; i++)
        {
            if (fabs(maxima[i].f - fr) < df)
            {
                df = fabs(maxima[i].f - fr);
                f = maxima[i].f;
            }
        }

        // Cents relative to reference note
        c = -12.0 * log2(fr / f);

        // Ignore silly values
        if (isnan(c))
        {
            c = 0.0;
            found = false;
        }

        // Ignore if not within 50 cents of reference note
        if (fabs(c) > 0.6)
            found = false;
    }

    // Publish
    TunerSnapshot *s = &slot->values;

    s->sequence = e->sequence;
    s->sampleRate = e->sampleRate;
    s->binWidth = e->fps;
    s->found = found;
    s->note = note;
    s->deviation = c;
    s->frequency = f;
    s->reference = fr;
    s->lower = fl;
    s->upper = fh;
    s->peak = max;
    s->peakBin = (int)imax;
    s->count = count;

    memcpy(slot->maxima, maxima, count * sizeof(TunerMaximum));
    memcpy(slot->scope, e->buffer + kSamples2,
           kTunerScopeLength * sizeof(double));
    memcpy(slot->spectrum, xa, kTunerRange * sizeof(double));
}
