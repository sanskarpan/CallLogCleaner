import SwiftUI

/// A simple donut chart built with Canvas/Path — works on macOS 13+
struct DonutChartView: View {
    /// Each segment: (color, value)
    let segments: [(Color, Double)]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outerR = size / 2
            let innerR = size / 2 * 0.55
            let total = segments.reduce(0) { $0 + $1.1 }
            guard total > 0 else { return AnyView(EmptyView()) }

            return AnyView(
                ZStack {
                    ForEach(segments.indices, id: \.self) { i in
                        let start = startAngle(for: i, total: total)
                        let end   = endAngle(for: i, total: total)
                        Path { path in
                            // outer arc
                            path.addArc(center: center, radius: outerR - 1,
                                        startAngle: start, endAngle: end, clockwise: false)
                            // inner arc (reverse)
                            path.addArc(center: center, radius: innerR + 1,
                                        startAngle: end, endAngle: start, clockwise: true)
                            path.closeSubpath()
                        }
                        .fill(segments[i].0)
                    }
                    // centre hole
                    Circle()
                        .fill(Color.cardBackground)
                        .frame(width: innerR * 2 - 4, height: innerR * 2 - 4)
                        .position(center)
                }
            )
        }
    }

    // MARK: - Angle Helpers

    private func cumulativeValue(upTo index: Int) -> Double {
        segments.prefix(index).reduce(0) { $0 + $1.1 }
    }

    private func startAngle(for index: Int, total: Double) -> Angle {
        .degrees(cumulativeValue(upTo: index) / total * 360 - 90)
    }

    private func endAngle(for index: Int, total: Double) -> Angle {
        .degrees((cumulativeValue(upTo: index) + segments[index].1) / total * 360 - 90)
    }
}
