//
//  StrobeLayerView.swift
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
//  The strobe (R13, R22): four bands of bars, each twice the period of
//  the one below, on layers that Core Animation moves. The bands are
//  drawn once, and again only when the look, the colours or the size
//  change; between those one repeating animation on the layer that
//  carries them runs the motion, so no app code runs per frame. Each
//  hop's cents go to StrobeMotion, which says when the animation must
//  be replaced and where in the pattern the new one starts. The
//  colours are fixed pairs in both appearances (KTD9), and the old
//  strobe's three looks are kept: bars, a gradient in the two lower
//  bands' place above 20 cents and a flat fill above 40.

import AppKit
import QuartzCore
import SwiftUI
import TunerState

struct StrobeLayerView: View
{
    @Environment(AppModel.self) private var model

    var body: some View
    {
        // Read everything the layer needs here, so the observation
        // tracks it and the representable gets plain values
        StrobeRepresentable(cents: model.display.strobeCents,
                            stale: model.display.isStale,
                            paused: !model.isVisible,
                            colour: model.settings.colour)
    }
}

private struct StrobeRepresentable: NSViewRepresentable
{
    let cents: Double
    let stale: Bool
    let paused: Bool
    let colour: Int

    func makeNSView(context: Context) -> StrobeHostView
    {
        return StrobeHostView()
    }

    func updateNSView(_ view: StrobeHostView, context: Context)
    {
        view.apply(cents: cents, stale: stale, paused: paused, colour: colour)
    }
}

// One band: bars of half the band's period, the foreground on the
// right of each multiple of the period. Plain old Core Animation
// drawing, once per look, colour or size.
nonisolated final class BandLayer: CALayer
{
    // The band's bar width is unit * 2^band; the look decides whether
    // it draws bars, a gradient or a fill
    enum Style
    {
        case bars
        case gradient
        case fill
    }

    var fillStyle = Style.bars
    var foreground = CGColor(gray: 0, alpha: 1)
    var background = CGColor(gray: 1, alpha: 1)
    var unit = 1.0
    var band = 0

    override func draw(in context: CGContext)
    {
        let half = unit * Double(1 << band)
        let period = half * 2

        context.setFillColor(background)
        context.fill(bounds)

        switch fillStyle
        {
        case .fill:
            return

        case .bars:
            context.setFillColor(foreground)
            for x in stride(from: 0.0, to: bounds.width, by: period)
            {
                context.fill(CGRect(x: x, y: 0, width: half,
                                    height: bounds.height))
            }

        case .gradient:
            guard let gradient = CGGradient(colorsSpace: nil,
                                            colors: [foreground, background,
                                                     foreground] as CFArray,
                                            locations: [0, 0.5, 1]) else
            {
                return
            }

            // The lowest band's gradient is centred on the bar edge,
            // as the old strobe drew it; the next starts at it
            let shift = (band == 0) ? -half : 0.0
            for x in stride(from: 0.0, to: bounds.width + period, by: period)
            {
                let left = x + shift
                context.saveGState()
                context.clip(to: CGRect(x: left, y: 0, width: period,
                                        height: bounds.height))
                context.drawLinearGradient(gradient,
                                           start: CGPoint(x: left, y: 0),
                                           end: CGPoint(x: left + period,
                                                        y: 0),
                                           options: [])
                context.restoreGState()
            }
        }
    }
}

final class StrobeHostView: NSView
{
    // Today's three foreground and background pairs
    private static let colours: [(foreground: [CGFloat],
                                  background: [CGFloat])] =
        [([0.25, 0.25, 1], [0.25, 1, 1]),
         ([0.5, 0.5, 0], [0.5, 1, 0.85]),
         ([1, 0.25, 1], [1, 1, 0.25])]

    private static let animationKey = "strobe"

    // The layer that moves, and the four bands on it, lowest first
    private let mover = CALayer()
    private let bands = (0 ..< 4).map { _ in BandLayer() }

    private var motion = StrobeMotion()
    private var look = StrobeMotion.Look.plain
    private var colour = -1
    private var unit = 0.0

    private var cents = 0.0
    private var stale = false
    private var paused = false
    private var ticking: Task<Void, Never>?

    // The whole pattern's length: the top band's period, four units
    // of sixteen, so every band repeats within it
    private var period: Double
    {
        return unit * 16
    }

    override init(frame: NSRect)
    {
        super.init(frame: frame)

        wantsLayer = true
        layer?.masksToBounds = true

        mover.anchorPoint = .zero
        layer?.addSublayer(mover)

        for (index, band) in bands.enumerated()
        {
            band.band = index
            band.anchorPoint = .zero
            band.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
            mover.addSublayer(band)
        }
    }

    required init?(coder: NSCoder)
    {
        return nil
    }

    // The pane carries the click and the tooltip in SwiftUI
    override func hitTest(_ point: NSPoint) -> NSView?
    {
        return nil
    }

    override func viewDidChangeBackingProperties()
    {
        super.viewDidChangeBackingProperties()

        let scale = window?.backingScaleFactor ?? 2
        for band in bands
        {
            band.contentsScale = scale
            band.setNeedsDisplay()
        }
    }

    override func layout()
    {
        super.layout()

        // Each band is a quarter of the height, and the unit is that
        // height, as the old strobe's bar size was
        let size = bounds.height / 4
        if size != unit
        {
            unit = size
            resize()
        }

        // A change of size moves the layer's base and animation length
        step()
    }

    // apply: the latest values from the SwiftUI side
    func apply(cents: Double, stale: Bool, paused: Bool, colour: Int)
    {
        self.cents = cents
        self.stale = stale
        self.paused = paused

        if colour != self.colour
        {
            self.colour = colour
            restyle()
        }

        step()
    }

    // resize: lay the bands out for the unit and redraw them
    private func resize()
    {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Wide enough that the layer, shifted up to a whole pattern to
        // the right, still covers the view
        let width = bounds.width + period
        mover.bounds = CGRect(x: 0, y: 0, width: width, height: bounds.height)
        mover.position = CGPoint(x: -period, y: 0)

        for band in bands
        {
            band.unit = unit
            band.frame = CGRect(x: 0, y: Double(band.band) * unit,
                                width: width, height: unit)
            band.setNeedsDisplay()
        }

        CATransaction.commit()

        // Replace the animation for the new length
        run(StrobeMotion.Segment(speed: motion.speed, phase: motion.phase))
    }

    // restyle: the colours of the chosen pair
    private func restyle()
    {
        let pair = StrobeHostView.colours[
            min(max(colour, 0), StrobeHostView.colours.count - 1)]
        let foreground = CGColor(srgbRed: pair.foreground[0],
                                 green: pair.foreground[1],
                                 blue: pair.foreground[2], alpha: 1)
        let background = CGColor(srgbRed: pair.background[0],
                                 green: pair.background[1],
                                 blue: pair.background[2], alpha: 1)

        for band in bands
        {
            band.foreground = foreground
            band.background = background
            band.setNeedsDisplay()
        }
    }

    // restyleLook: the two lower bands change with the look; the rest
    // are always bars
    private func restyleLook()
    {
        switch look
        {
        case .plain:
            bands[0].fillStyle = .bars
            bands[1].fillStyle = .bars

        case .gradient:
            bands[0].fillStyle = .gradient
            bands[1].fillStyle = .bars

        case .flat:
            bands[0].fillStyle = .fill
            bands[1].fillStyle = .gradient
        }

        bands[0].setNeedsDisplay()
        bands[1].setNeedsDisplay()
    }

    // advance: bring the motion up to now, replacing the animation if
    // its speed changed. True while the smoother is still moving.
    @discardableResult
    private func advance() -> Bool
    {
        guard unit > 0 else
        {
            return false
        }

        let segment = motion.update(now: CACurrentMediaTime(), cents: cents,
                                    stale: stale, paused: paused,
                                    period: period)

        if motion.look != look
        {
            look = motion.look
            restyleLook()
        }

        if let segment
        {
            run(segment)
        }

        return motion.needsTick(cents: cents, stale: stale, paused: paused)
    }

    // step: advance, and keep ticking while the smoother settles. A
    // hop usually moves the cents, but a held or repeated value
    // sends no more, so the settling cannot wait for one.
    private func step()
    {
        if advance() && ticking == nil
        {
            ticking = Task
            {
                @MainActor [weak self] in
                while !Task.isCancelled
                {
                    try? await Task.sleep(for: .milliseconds(20))
                    guard let self, self.advance() else
                    {
                        break
                    }
                }

                self?.ticking = nil
            }
        }
    }

    // run: replace the animation with one that starts at the segment's
    // position and speed, or park the layer there if it is stopped
    private func run(_ segment: StrobeMotion.Segment)
    {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        mover.removeAnimation(forKey: StrobeHostView.animationKey)

        if let duration = segment.duration(period: period)
        {
            mover.position = CGPoint(x: -period, y: 0)

            let forward = segment.speed > 0
            let animation = CABasicAnimation(keyPath: "position.x")
            animation.isAdditive = true
            animation.fromValue = forward ? 0 : period
            animation.toValue = forward ? period : 0
            animation.duration = duration
            animation.repeatCount = .infinity
            animation.timeOffset = segment.progress * duration
            animation.beginTime = mover.convertTime(CACurrentMediaTime(),
                                                    from: nil)
            mover.add(animation, forKey: StrobeHostView.animationKey)
        }

        else
        {
            mover.position = CGPoint(x: -period + segment.phase * period,
                                     y: 0)
        }

        CATransaction.commit()
    }
}
