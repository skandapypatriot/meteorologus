import SwiftUI

/// Mirrors `forecast_slide.dart`: a compact 3-day forecast from the node's ML model.
struct ForecastSlideView: View {
    let forecastReading: DeviceReading?
    let textColor: Color

    private let dayNames = ["Day 1", "Day 2", "Day 3"]

    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                Text("3-Day Forecast")
                    .font(.system(size: 18, weight: .bold))
                    .kerning(-0.2)
                    .foregroundColor(textColor)

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        forecastTile(index: index)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func forecastTile(index: Int) -> some View {
        let dayCodes = forecastReading?.forecast ?? []
        let dayCode: Any? = dayCodes.count > index ? dayCodes[index] : nil
        let hasData = dayCode != nil
        let info = WeatherCodeHelper.getInfo(for: dayCode)

        return VStack(spacing: 6) {
            Text(dayNames[index])
                .font(.system(size: 10, weight: .bold))
                .kerning(0.5)
                .foregroundColor(textColor.opacity(0.47))

            Group {
                if hasData {
                    WeatherVisualView(category: info.category, size: 36, animate: false)
                } else {
                    Text("\u{2014}")
                        .font(.system(size: 22))
                        .foregroundColor(textColor.opacity(0.39))
                }
            }
            .frame(height: 38)

            Text(hasData ? info.label : "No data")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(Color.black.opacity(0.15))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}