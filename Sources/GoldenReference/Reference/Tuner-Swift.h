//
//  Tuner-Swift.h
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
//  Stub for the golden reference. The frozen Audio.m reaches the six
//  views only through these properties, so plain objects carrying them
//  stand in for the AppKit views. Audio.h includes this file by a
//  quoted name, which finds this copy because it sits beside Audio.h.

#import <Foundation/Foundation.h>

// One line added to the frozen ProcessAudio calls this per hop; the
// maxima are the frozen engine's own maximum structs
void ReferenceHook(bool found, double f, double fr, double c, int note,
                   int count, double max, int imax, const void *maxima,
                   const double *xa);

#define HarnessHook(found, f, fr, c, note, count, max, imax, maxima, xa) \
    ReferenceHook((found), (f), (fr), (c), (note), (count), (max), \
                  (int)(imax), (maxima), (xa))

@interface ScopeView : NSObject
@property (nonatomic) BOOL needsDisplay;
@end

@interface SpectrumView : NSObject
@property (nonatomic) BOOL needsDisplay;
@property (nonatomic) double f;
@property (nonatomic) double l;
@property (nonatomic) double h;
@property (nonatomic) double r;
@end

@interface DisplayView : NSObject
@property (nonatomic) BOOL needsDisplay;
@property (nonatomic) BOOL lock;
@property (nonatomic) BOOL stale;
@property (nonatomic) NSInteger n;
@property (nonatomic) double c;
@property (nonatomic) double f;
@property (nonatomic) double fr;
@end

@interface StrobeView : NSObject
@property (nonatomic) BOOL needsDisplay;
@property (nonatomic) double c;
@end

@interface StaffView : NSObject
@property (nonatomic) BOOL needsDisplay;
@property (nonatomic) NSInteger note;
@end

@interface MeterView : NSObject
@property (nonatomic) BOOL needsDisplay;
@property (nonatomic) double c;
@end
