//
//  filter.c
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
//  The input filter from InputProc in Reference/Audio.m: a first-order
//  Butterworth low-pass with its corner at 480 Hz.

#pragma clang fp contract(off)

#include <math.h>

#include "internal.h"

// Corner frequency of the input filter
#define kFilterCorner 480.0

// FilterInit
void FilterInit(Filter *filter, double sampleRate)
{
    // Today's literal coefficients at 44100, so the goldens match
    // exactly; elsewhere the bilinear transform of the same corner
    if (sampleRate == 44100.0)
    {
        filter->g = 3.023332184e+01;
        filter->k = 0.9338478249;
    }

    else
    {
        double wc = tan(M_PI * kFilterCorner / sampleRate);
        filter->g = (1.0 + wc) / wc;
        filter->k = (1.0 - wc) / (1.0 + wc);
    }

    filter->xv[0] = filter->xv[1] = 0.0;
    filter->yv[0] = filter->yv[1] = 0.0;
}

// FilterBlock
void FilterBlock(Filter *filter, bool enabled, const float *data, int count,
                 double *out)
{
    // Butterworth filter, 3dB/octave; it runs whether or not it is
    // chosen, so switching it on starts from settled state
    for (int i = 0; i < count; i++)
    {
        filter->xv[0] = filter->xv[1];
        filter->xv[1] = data[i] / filter->g;

        filter->yv[0] = filter->yv[1];
        filter->yv[1] = (filter->xv[0] + filter->xv[1]) +
            (filter->k * filter->yv[0]);

        // Choose filtered/unfiltered data
        out[i] = enabled? filter->yv[1]: data[i];
    }
}
