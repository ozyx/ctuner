//
//  SpectrumView.swift
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
//  The spectrum (R12, R16): the bins on a dark graticule, either the
//  zoomed window around the reference or the whole log axis with
//  expand, with the markers and their cents in yellow. SpectrumAxis
//  maps bins to x for the trace and the markers alike, so a marker
//  sits on its peak in both modes. Like the scope it redraws on a new
//  snapshot, a new reading or a changed setting. The header holds the
//  zoom control and, only while zoom is off, the expand control,
//  because expand applies to the unzoomed axis alone.

import SwiftUI
import TunerState

struct SpectrumView: View
{
    @Environment(AppModel.self) private var model

    var body: some View
    {
        // Read everything the canvas draws here, so the observation
        // tracks it and the drawing closure holds plain values
        let spectrum = model.traces.spectrum
        let binWidth = model.traces.binWidth
        let markers = model.display.markers
        let zoom = model.settings.zoom
        let expand = model.settings.expand
        let downsample = model.settings.downsample
        let noteFilter = model.settings.noteFilter

        Canvas
        {
            context, size in
            var context = context
            SpectrumView.draw(&context, size, spectrum: spectrum,
                              binWidth: binWidth, markers: markers,
                              zoom: zoom, expand: expand,
                              downsample: downsample, noteFilter: noteFilter)
        }
        .overlay(alignment: .topTrailing)
        {
            header(zoom: zoom, expand: expand)
        }
    }

    // header: the zoom and expand controls. The click on the pane
    // zooms too, so the control is the labelled form of it.
    private func header(zoom: Bool, expand: Int) -> some View
    {
        HStack(spacing: 6)
        {
            if !zoom
            {
                Button
                {
                    model.settings.expandSpectrum()
                }
                label:
                {
                    Text("x \(expand)")
                        .monospacedDigit()
                }
                .help("Expand the spectrum")
            }

            Button
            {
                model.settings.zoom.toggle()
            }
            label:
            {
                Image(systemName: zoom ? "minus.magnifyingglass"
                                       : "plus.magnifyingglass")
            }
            .help(zoom ? "Show the whole spectrum" : "Zoom to the note")
        }
        .buttonStyle(.plain)
        .font(.system(size: ScopeView.textSize, weight: .bold))
        .foregroundStyle(.yellow)
        .padding(4)
    }

    nonisolated private static func draw(_ context: inout GraphicsContext,
                                         _ size: CGSize, spectrum: [Double],
                                         binWidth: Double, markers: Markers?,
                                         zoom: Bool, expand: Int,
                                         downsample: Bool, noteFilter: Bool)
    {
        ScopeView.drawGraticule(&context, size)

        if downsample
        {
            context.draw(ScopeView.badge("D"), at: CGPoint(x: 2, y: 2),
                         anchor: .topLeading)
        }

        if noteFilter
        {
            context.draw(ScopeView.badge("NF"),
                         at: CGPoint(x: 2, y: size.height - 2),
                         anchor: .bottomLeading)
        }

        guard !spectrum.isEmpty, binWidth > 0 else
        {
            return
        }

        // The markers in bins, none after a reading goes stale
        let reeds = markers?.reeds ?? []
        let axis: SpectrumAxis?
        if zoom
        {
            axis = markers.flatMap
            {
                SpectrumAxis(zoomedFrom: $0.lower / binWidth,
                             reference: $0.reference / binWidth,
                             upper: $0.upper / binWidth, width: size.width,
                             count: spectrum.count)
            }
        }

        else
        {
            axis = SpectrumAxis(width: size.width, count: spectrum.count,
                                expand: expand)
        }

        guard let axis else
        {
            return
        }

        let columns = spectrum.withUnsafeBufferPointer
        {
            axis.decimate($0)
        }

        guard let first = columns.first, let last = columns.last else
        {
            return
        }

        // The scale follows the trace's own peak, at least 1
        let peak = max(1, columns.reduce(0) { max($0, $1.maximum) })
        let yscale = size.height / peak

        var trace = Path()
        trace.move(to: CGPoint(x: Double(first.x), y: size.height))
        for column in columns
        {
            trace.addLine(to: CGPoint(x: Double(column.x),
                                      y: size.height - column.minimum * yscale))
            trace.addLine(to: CGPoint(x: Double(column.x),
                                      y: size.height - column.maximum * yscale))
        }

        trace.addLine(to: CGPoint(x: Double(last.x), y: size.height))
        trace.closeSubpath()

        context.fill(trace, with: .color(.green.opacity(0.25)))
        context.stroke(trace, with: .color(.green), lineWidth: 1)

        if zoom
        {
            var centre = Path()
            centre.move(to: CGPoint(x: size.width / 2, y: 0))
            centre.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            context.stroke(centre, with: .color(.green), lineWidth: 1)
        }

        // The markers, on the trace column of their bin
        var lines = Path()
        for reed in reeds
        {
            let bin = reed.frequency / binWidth
            if !axis.contains(bin: bin)
            {
                continue
            }

            let x = axis.x(bin: bin)
            lines.move(to: CGPoint(x: x, y: 0))
            lines.addLine(to: CGPoint(x: x, y: size.height))
            context.draw(ScopeView.badge(String(format: "%+0.0f", reed.cents),
                                         font: .system(size: ScopeView.textSize,
                                                       weight: .bold)),
                         at: CGPoint(x: x, y: size.height),
                         anchor: .bottomLeading)
        }

        context.stroke(lines, with: .color(.yellow), lineWidth: 1)

        if !zoom && expand > 1
        {
            context.draw(ScopeView.badge("x \(expand)",
                                         font: .system(size: ScopeView.textSize,
                                                       weight: .bold)),
                         at: CGPoint(x: size.width - 2, y: size.height),
                         anchor: .bottomTrailing)
        }
    }
}
