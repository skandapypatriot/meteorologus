import SwiftUI

/// Mirrors `sparkline_painter.dart`: gradient-filled temperature sparkline
/// with a rounded polyline stroke and endpoint dot.
struct SparklineView: View {
    let temperatures: [Double]
    let color: Color
    var height: CGFloat = 48

    var body: some View {
        if temperatures.count >= 2 {
            Canvas { context, size in
                let pad: CGFloat = 6
                let minT = temperatures.min() ?? 0
                var maxT = temperatures.max() ?? 0
                var lo = minT
                var hi = maxT
                if hi - lo < 1.0 {
                    lo -= 0.5
                    hi += 0.5
                }
                let range = max(hi - lo, 0.0001)

                func x(_ index: Int) -> CGFloat {
                    pad + (size.width - 2 * pad) * CGFloat(index) / CGFloat(temperatures.count - 1)
                }
                func y(_ value: Double) -> CGFloat {
                    size.height - pad - (size.height - 2 * pad) * CGFloat((value - lo) / range)
                }

                var line = Path()
                var fill = Path()

                let firstX = x(0)
                let firstY = y(temperatures[0])
                line.move(to: CGPoint(x: firstX, y: firstY))
                fill.move(to: CGPoint(x: firstX, y: size.height))
                fill.addLine(to: CGPoint(x: firstX, y: firstY))

                for i in 1..<temperatures.count {
                    let p = CGPoint(x: x(i), y: y(temperatures[i]))
                    line.addLine(to: p)
                    fill.addLine(to: p)
                }

                fill.addLine(to: CGPoint(x: x(temperatures.count - 1), y: size.height))
                fill.closeSubpath()

                // Gradient fill below the polyline
                context.fill(fill, with: .linearGradient(
                    Gradient(colors: [color.opacity(0.2), color.opacity(0)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                ))

                // Polyline stroke
                context.stroke(
                    line,
                    with: .color(color.opacity(0.45)),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )

                // Latest endpoint dot
                let dot = CGPoint(x: x(temperatures.count - 1), y: y(temperatures.last ?? 0))
                context.fill(
                    Path(ellipseIn: CGRect(x: dot.x - 3.5, y: dot.y - 3.5, width: 7, height: 7)),
                    with: .color(color.opacity(0.86))
                )
            }
            .frame(height: height)
            .padding(.top, 12)
        }
    }
}