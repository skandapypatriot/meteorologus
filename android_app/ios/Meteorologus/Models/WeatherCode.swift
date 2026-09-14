import Foundation

/// Mirrors the Flutter `WeatherCategory` enum and `WeatherCodeHelper`.
enum WeatherCategory: Int, CaseIterable {
    case sunny = 0
    case clear
    case slightlyCloudy
    case cloud
    case lightRain
    case rain
}

struct WeatherInfo {
    let emoji: String
    let label: String
    let category: WeatherCategory
}

enum WeatherCodeHelper {

    static func getInfo(for code: Any?) -> WeatherInfo {
        guard let code = code else {
            return WeatherInfo(emoji: "\u{2014}", label: "Unknown", category: .clear)
        }

        let numVal: NSNumber?
        if let n = code as? NSNumber {
            numVal = n
        } else if let s = code as? String, let n = NumberFormatter().number(from: s) {
            numVal = n
        } else {
            numVal = nil
        }

        guard let c = numVal else {
            return WeatherInfo(emoji: "\u{2014}", label: "Unknown", category: .clear)
        }

        let value = c.doubleValue
        guard value.isFinite else {
            return WeatherInfo(emoji: "\u{2014}", label: "Unknown", category: .clear)
        }

        if value <= 10 {
            return WeatherInfo(emoji: "\u{2600}\u{FE0F}", label: "Sunny", category: .sunny)
        }
        if value <= 20 {
            return WeatherInfo(emoji: "\u{1F319}", label: "Clear", category: .clear)
        }
        if value <= 40 {
            return WeatherInfo(emoji: "\u{26C5}", label: "Slightly Cloudy", category: .slightlyCloudy)
        }
        if value <= 60 {
            return WeatherInfo(emoji: "\u{2601}\u{FE0F}", label: "Cloud", category: .cloud)
        }
        if value <= 80 {
            return WeatherInfo(emoji: "\u{1F326}\u{FE0F}", label: "Light Rain", category: .lightRain)
        }
        return WeatherInfo(emoji: "\u{1F327}\u{FE0F}", label: "Rain", category: .rain)
    }
}