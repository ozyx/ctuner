//
//  TunerCapture.h
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

#ifndef TunerCapture_h
#define TunerCapture_h

#ifdef __cplusplus
extern "C" {
#endif

// Capture status codes
typedef enum
{
    kCaptureStatusOK = 0
} CaptureStatus;

// Status string
const char *CaptureStatusString(CaptureStatus status);

#ifdef __cplusplus
}
#endif

#endif /* TunerCapture_h */
