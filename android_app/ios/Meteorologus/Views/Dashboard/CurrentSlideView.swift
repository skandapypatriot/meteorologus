import SwiftUI

/// Mirrors `current_slide.dart`: big temperature, humidity/pressure tiles,
/// weather visual, updated time and a temperature sparkline.
struct CurrentSlideView: View {
    let reading: DeviceReading?
    let readings: [DeviceReading]
    let textColor: Color

    private var info: WeatherInfo {
        WeatherCodeHelper.getInfo(for: reading?.weatherCode)
    }

    private var tempStr: String {
        if let t = reading?.t { return String(format: "%.1f", t) }
        return "\u{2014}"
    }

    private var humStr: String {
        if let h = reading?.h { return "\(Int(h.rounded()))%" }
        return "\u{2014}"
    }

    private var pressStr: String {
        if let p = reading?.p { return String(format: "%.1f", p) }
        return "\u{2014}"
    }

    private var timeStr: String {
        guard let ts = reading?.ts, ts >= 1_000_000 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        return "Updated " + Self.timeFormatter.string(from: date)
    }

    private var temperatures: [Double] {
        readings.compactMap { $0.t }.filter { !$0.isNaN && $0.isFinite }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        GlassCard {
            VStack(spacing: 0) {
                WeatherVisualView(category: info.category, size: 74)
                    .padding(.top, 4)
                    .padding(.bottom, 6)

                Text(info.label)
                    .font(.system(size: 18, weight: .bold))
                    .kerning(-0.2)
                    .foregroundColor(textColor)

                if !timeStr.isEmpty {
                    Text(timeStr)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textColor.opacity(0.47))
                        .padding(.top, 4)
                }

                // Big temperature
                HStack(alignment: .top, spacing: 2) {
                    Text(tempStr)
                        .font(.system(size: 56, weight: .heavy))
                        .kerning(-2)
                        .foregroundColor(textColor)
                    Text("\u{00B0}C")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(textColor.opacity(0.78))
                        .padding(.top, 6)
                }
                .padding(.top, 12)
                .padding(.bottom, 16)

                // Humidity & pressure tiles
                HStack(spacing: 8) {
                    metricTile(value: humStr, label: "HUMIDITY")
                    metricTile(value: pressStr, label: "HPA")
                }
            }

            if temperatures.count >= 2 {
                SparklineView(temperatures: temperatures, color: textColor)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func metricTile(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(textColor)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .kerning(0.5)
                .foregroundColor(textColor.opacity(0.47))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color.black.opacity(0.15))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}