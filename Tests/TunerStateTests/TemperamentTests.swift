//
//  TemperamentTests.swift
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

import Foundation
import Testing
import TunerState

@Suite("temperaments")
struct TemperamentTests
{
    @Test func thirtyTwoRowsOfTwelve()
    {
        #expect(Temperaments.values.count == 32)
        #expect(Temperaments.names.count == 32)
        for row in Temperaments.values
        {
            #expect(row.count == 12)
        }
        #expect(Temperaments.flattened.count == 32 * 12)
    }

    @Test func rowEightIsEqualTemperament()
    {
        #expect(Temperaments.equal == 8)
        #expect(Temperaments.names[8] == "Equal Temperament")
        for (note, ratio) in Temperaments.values[8].enumerated()
        {
            #expect(abs(ratio - pow(2, Double(note) / 12)) < 1e-8)
        }
    }

    @Test func rowsInHertzNormaliseToRatios()
    {
        // Bach (Klais) and Just (Barbour) are written in Hz from C
        for row in [6, 7]
        {
            let ratios = Temperaments.ratios(row)
            #expect(ratios.count == 12)
            #expect(ratios[0] == 1)
            for ratio in ratios
            {
                #expect(ratio >= 1 && ratio < 2)
            }
        }

        // Just A is a major sixth, 5/3, above C
        #expect(abs(Temperaments.ratios(7)[9] - 5.0 / 3.0) < 1e-12)

        // Bach (Klais): A 440 over C 262.76
        #expect(abs(Temperaments.ratios(6)[9] - 440 / 262.76) < 1e-12)

        // A row already in ratios is unchanged
        #expect(Temperaments.ratios(8) == Temperaments.values[8])
    }
}
