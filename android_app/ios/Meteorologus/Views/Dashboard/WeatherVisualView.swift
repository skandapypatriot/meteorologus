import SwiftUI

/// SwiftUI re-implementation of the Flutter `WeatherVisualWidget` /
/// `_WeatherPainter`. Draws stylized volumetric weather illustrations
/// (glowing sun, crescent moon + stars, 3D clouds, animated rain) on a
/// canonical 100x100 grid, then scales to the requested size.
struct WeatherVisualView: View {
    let category: WeatherCategory
    var size: CGFloat = 64
    var animate: Bool = true

    private let cycle: TimeInterval = 4.0

    var body: some View {
        if animate {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                canvas(progress: progressValue(at: timeline.date))
            }
        } else {
            canvas(progress: 0)
        }
    }

    private func canvas(progress: CGFloat) -> some View {
        Canvas { context, canvasSize in
            var ctx = context
            ctx.scaleBy(x: canvasSize.width / 100.0, y: canvasSize.height / 100.0)
            WeatherPainter.draw(&ctx, category: category, progress: progress)
        }
        .frame(width: size, height: size)
    }

    private func progressValue(at date: Date) -> CGFloat {
        let rem = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
        return CGFloat(rem / cycle)
    }
}

// MARK: - Painter

private enum WeatherPainter {

    static func draw(_ ctx: inout GraphicsContext, category: WeatherCategory, progress: CGFloat) {
        switch category {
        case .sunny: drawSunny(&ctx, progress: progress)
        case .clear: drawClearNight(&ctx, progress: progress)
        case .slightlyCloudy: drawSlightlyCloudy(&ctx, progress: progress)
        case .cloud: drawCloudy(&ctx, progress: progress)
        case .lightRain: drawRain(&ctx, progress: progress, isLight: true)
        case .rain: drawRain(&ctx, progress: progress, isLight: false)
        }
    }

    // MARK: 1. Sunny

    private static func drawSunny(_ ctx: inout GraphicsContext, progress: CGFloat) {
        let tau = CGFloat.pi * 2
        let pulse = CGFloat(sin(Double(progress * tau))) * 0.05 + 1.0
        let rotation = progress * tau

        // Ambient warm glow
        ctx.fill(
            Path(ellipseIn: CGRect(x: 50 - 46 * pulse, y: 50 - 46 * pulse, width: 92 * pulse, height: 92 * pulse)),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xF59E0B).opacity(0.31), Color(hex: 0xFBBF24).opacity(0.12), .clear]),
                center: CGPoint(x: 50, y: 50),
                startRadius: 0,
                endRadius: 46 * pulse
            )
        )

        // Sun rays
        ctx.drawLayer { layer in
            layer.translateBy(x: 50, y: 50)
            layer.rotate(by: Angle.radians(rotation))
            for _ in 0..<8 {
                let ray = Path(roundedRect: CGRect(x: -3, y: -38, width: 6, height: 12), cornerRadius: 3)
                layer.fill(ray, with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xFDE047), Color(hex: 0xF59E0B)]),
                    startPoint: CGPoint(x: 0, y: -38),
                    endPoint: CGPoint(x: 0, y: -26)
                ))
                layer.rotate(by: Angle.radians(CGFloat.pi / 4))
            }
        }

        // Core sphere shadow
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 8))
            layer.fill(
                Path(ellipseIn: CGRect(x: 30, y: 33, width: 40, height: 40)),
                with: .color(Color(hex: 0xF59E0B).opacity(0.33))
            )
        }

        // Sun core
        ctx.fill(
            Path(ellipseIn: CGRect(x: 28, y: 28, width: 44, height: 44)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(hex: 0xFFFBEB), location: 0),
                    .init(color: Color(hex: 0xFBBF24), location: 0.5),
                    .init(color: Color(hex: 0xEA580C), location: 1),
                ]),
                center: CGPoint(x: 43.4, y: 43.4),
                startRadius: 0,
                endRadius: 22 * 0.85
            )
        )

        // Highlight sheen
        var arc = Path()
        arc.addArc(
            center: CGPoint(x: 50, y: 50),
            radius: 18,
            startAngle: .radians(-.pi * 0.75),
            endAngle: .radians(-.pi * 0.30),
            clockwise: false
        )
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 1))
            layer.stroke(arc, with: .color(.white.opacity(0.63)), style: StrokeStyle(lineWidth: 2.5))
        }
    }

    // MARK: 2. Clear / Moon

    private static func drawClearNight(_ ctx: inout GraphicsContext, progress: CGFloat) {
        let tau = CGFloat.pi * 2
        let twinkle1 = (CGFloat(sin(Double(progress * tau))) + 1.0) / 2.0
        let twinkle2 = (CGFloat(cos(Double(progress * tau + 1))) + 1.0) / 2.0

        // Ambient night glow
        ctx.fill(
            Path(ellipseIn: CGRect(x: 2, y: 6, width: 88, height: 88)),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0x818CF8).opacity(0.24), Color(hex: 0x6366F1).opacity(0.08), .clear]),
                center: CGPoint(x: 46, y: 50),
                startRadius: 0,
                endRadius: 44
            )
        )

        // Twinkling stars
        drawStar(&ctx, center: CGPoint(x: 74, y: 28), size: 6 + twinkle1 * 3, opacity: (0.4 + twinkle1 * 0.6).clamped01)
        drawStar(&ctx, center: CGPoint(x: 24, y: 34), size: 4.5 + twinkle2 * 2.5, opacity: (0.3 + twinkle2 * 0.7).clamped01)
        drawStar(&ctx, center: CGPoint(x: 78, y: 68), size: 5 + twinkle2 * 3, opacity: (0.35 + twinkle2 * 0.65).clamped01)

        // Crescent moon: outer circle minus offset circle
        var crescent = Path()
        crescent.addEllipse(in: CGRect(x: 22, y: 26, width: 48, height: 48))
        crescent.addEllipse(in: CGRect(x: 37, y: 21, width: 42, height: 42))
        crescent = crescent.normalized(eoFill: true)

        // Moon shadow
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 8))
            let shifted = crescent
            layer.fill(shifted, with: .color(Color(hex: 0x4338CA).opacity(0.38)))
        }

        // Moon gradient
        ctx.fill(crescent, with: .linearGradient(
            Gradient(stops: [
                .init(color: .white, location: 0),
                .init(color: Color(hex: 0xE0E7FF), location: 0.35),
                .init(color: Color(hex: 0xA5B4FC), location: 0.75),
                .init(color: Color(hex: 0x818CF8), location: 1),
            ]),
            startPoint: CGPoint(x: 30, y: 32),
            endPoint: CGPoint(x: 62, y: 70)
        ))

        // Subtle rim
        ctx.stroke(crescent, with: .color(.white.opacity(0.78)), style: StrokeStyle(lineWidth: 1.2))
    }

    private static func drawStar(_ ctx: inout GraphicsContext, center: CGPoint, size: CGFloat, opacity: CGFloat) {
        // Glow
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 3))
            layer.fill(
                Path(ellipseIn: CGRect(x: center.x - size * 0.6, y: center.y - size * 0.6, width: size * 1.2, height: size * 1.2)),
                with: .color(Color(hex: 0xFEF08A).opacity(0.5 * opacity))
            )
        }

        // 4-point sparkle
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - size))
        path.addQuadCurve(to: CGPoint(x: center.x + size, y: center.y), control: center)
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + size), control: center)
        path.addQuadCurve(to: CGPoint(x: center.x - size, y: center.y), control: center)
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - size), control: center)
        path.closeSubpath()

        ctx.fill(path, with: .color(Color(hex: 0xFDE68A).opacity(opacity)))
    }

    // MARK: 3. Slightly cloudy

    private static func drawSlightlyCloudy(_ ctx: inout GraphicsContext, progress: CGFloat) {
        let tau = CGFloat.pi * 2
        let sunHover = CGFloat(sin(Double(progress * tau))) * 1.5

        ctx.drawLayer { layer in
            layer.translateBy(x: 64, y: 34 + sunHover)

            // Sun glow
            layer.fill(
                Path(ellipseIn: CGRect(x: -26, y: -26, width: 52, height: 52)),
                with: .radialGradient(
                    Gradient(colors: [Color(hex: 0xF59E0B).opacity(0.39), .clear]),
                    center: .zero,
                    startRadius: 0,
                    endRadius: 26
                )
            )

            // Mini sun rays
            for i in 0..<6 {
                let angle = CGFloat(i) * (CGFloat.pi / 3) + progress * (CGFloat.pi * 0.5)
                let p1 = CGPoint(x: cos(angle) * 16, y: sin(angle) * 16)
                let p2 = CGPoint(x: cos(angle) * 21, y: sin(angle) * 21)
                var line = Path()
                line.move(to: p1)
                line.addLine(to: p2)
                layer.stroke(line, with: .color(Color(hex: 0xFBBF24)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }

            // Mini sun core
            layer.fill(
                Path(ellipseIn: CGRect(x: -13, y: -13, width: 26, height: 26)),
                with: .radialGradient(
                    Gradient(colors: [Color(hex: 0xFFFBEB), Color(hex: 0xFBBF24), Color(hex: 0xF97316)]),
                    center: CGPoint(x: -3.9, y: -3.9),
                    startRadius: 0,
                    endRadius: 13 * 0.85
                )
            )
        }

        drawVolumetricCloud(&ctx, offset: CGPoint(x: 42, y: 58), scale: 0.88, isDark: false)
    }

    // MARK: 4. Cloudy

    private static func drawCloudy(_ ctx: inout GraphicsContext, progress: CGFloat) {
        let tau = CGFloat.pi * 2
        let floatOffset = CGFloat(sin(Double(progress * tau))) * 1.5

        drawVolumetricCloud(&ctx, offset: CGPoint(x: 36, y: 44 + floatOffset * 0.5), scale: 0.82, isDark: true)
        drawVolumetricCloud(&ctx, offset: CGPoint(x: 48, y: 56 - floatOffset * 0.5), scale: 0.92, isDark: false)
    }

    // MARK: 5 & 6. Rain

    private static func drawRain(_ ctx: inout GraphicsContext, progress: CGFloat, isLight: Bool) {
        if isLight {
            // Small sun peeking behind
            ctx.drawLayer { layer in
                layer.translateBy(x: 66, y: 32)
                layer.fill(
                    Path(ellipseIn: CGRect(x: -12, y: -12, width: 24, height: 24)),
                    with: .radialGradient(
                        Gradient(colors: [Color(hex: 0xFFFBEB), Color(hex: 0xFBBF24), Color(hex: 0xEA580C)]),
                        center: CGPoint(x: -2.4, y: -2.4),
                        startRadius: 0,
                        endRadius: 12 * 0.85
                    )
                )
            }
        }

        drawVolumetricCloud(&ctx, offset: CGPoint(x: 48, y: 48), scale: 0.90, isDark: !isLight, isStorm: !isLight)

        let dropCount = isLight ? 3 : 5
        let dropX: [CGFloat] = isLight ? [36, 48, 60] : [28, 38, 48, 58, 68]
        let dropSpeed: [CGFloat] = isLight ? [1.0, 1.3, 0.9] : [1.2, 1.5, 1.1, 1.4, 1.0]
        let top = isLight ? Color(hex: 0x38BDF8) : Color(hex: 0x60A5FA)
        let bottom = isLight ? Color(hex: 0x0284C7) : Color(hex: 0x2563EB)

        for i in 0..<dropCount {
            let cycle = (progress * dropSpeed[i] + CGFloat(i) * 0.25)
                .truncatingRemainder(dividingBy: 1.0)
            let y = 66 + cycle * 22
            let x = dropX[i] - cycle * 5
            let opacity = CGFloat(sin(Double(cycle * CGFloat.pi))).clamped01
            let topColor = top.opacity((opacity * 0.2).clamped01)
            let bottomColor = bottom.opacity((opacity * 0.9).clamped01)

            ctx.drawLayer { layer in
                layer.translateBy(x: x, y: y)
                layer.rotate(by: Angle.radians(-0.25))
                let drop = Path(roundedRect: CGRect(x: -1.5, y: 0, width: 3, height: 9), cornerRadius: 1.5)
                layer.fill(drop, with: .linearGradient(
                    Gradient(colors: [topColor, bottomColor]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: 9)
                ))
            }
        }
    }

    // MARK: - Shared volumetric cloud builder

    private static func drawVolumetricCloud(
        _ ctx: inout GraphicsContext,
        offset: CGPoint,
        scale: CGFloat,
        isDark: Bool,
        isStorm: Bool = false
    ) {
        ctx.drawLayer { cloud in
            cloud.translateBy(x: offset.x, y: offset.y)
            cloud.scaleBy(x: scale, y: scale)

            // Cloud composed of a base pill + overlapping puffs
            var path = Path()
            path.addRoundedRect(
                in: CGRect(x: -28, y: 2, width: 56, height: 18),
                cornerRadii: RectangleCornerRadii(topLeading: 9, bottomLeading: 9, bottomTrailing: 9, topTrailing: 9)
            )
            path.addEllipse(in: CGRect(x: -26, y: -12, width: 24, height: 24))
            path.addEllipse(in: CGRect(x: -13, y: -25, width: 34, height: 34))
            path.addEllipse(in: CGRect(x: 7, y: -12, width: 22, height: 22))

            // Drop shadow
            cloud.drawLayer { layer in
                layer.addFilter(.blur(radius: 6))
                var shiftedPath = path
                let t = CGAffineTransform(translationX: 0, y: 4)
                shiftedPath = shiftedPath.applying(t)
                layer.fill(shiftedPath, with: .color(.black.opacity(isDark ? 0.22 : 0.16)))
            }

            // Cloud gradient
            let colors: [Color]
            if isStorm {
                colors = [Color(hex: 0x94A3B8), Color(hex: 0x64748B), Color(hex: 0x334155)]
            } else if isDark {
                colors = [Color(hex: 0xCBD5E1), Color(hex: 0x94A3B8), Color(hex: 0x64748B)]
            } else {
                colors = [Color(hex: 0xFFFFFF), Color(hex: 0xF1F5F9), Color(hex: 0xCBD5E1)]
            }

            cloud.fill(path, with: .linearGradient(
                Gradient(stops: [
                    .init(color: colors[0], location: 0),
                    .init(color: colors[1], location: 0.45),
                    .init(color: colors[2], location: 1),
                ]),
                startPoint: CGPoint(x: 0, y: -26),
                endPoint: CGPoint(x: 0, y: 22)
            ))

            // Top rim highlight
            if !isStorm {
                var highlight = Path()
                highlight.addArc(
                    center: CGPoint(x: 4, y: -8), radius: 16.5,
                    startAngle: .radians(-.pi * 0.9), endAngle: .radians(-.pi * 0.1), clockwise: false
                )
                cloud.stroke(highlight, with: .linearGradient(
                    Gradient(colors: [.white.opacity(0.86), .white.opacity(0)]),
                    startPoint: CGPoint(x: 4, y: -25),
                    endPoint: CGPoint(x: 4, y: -5)
                ), style: StrokeStyle(lineWidth: 1.5))
            }
        }
    }
}

// MARK: - Helpers

private extension CGFloat {
    /// Clamped to [0, 1], matching Dart's `double.clamp(0.0, 1.0)`.
    var clamped01: CGFloat {
        Swift.max(0, Swift.min(1, self))
    }
}

private extension Angle {
    static func radians(_ value: CGFloat) -> Angle {
        .init(radians: Double(value))
    }
}