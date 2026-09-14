import SwiftUI

/// Mirrors the Flutter `TimePeriod` enum.
enum TimePeriod: Int {
    case morning
    case afternoon
    case evening
    case night
}

/// Mirrors the Flutter `WeatherThemeData` class.
/// A concrete set of colors for the current weather category + time period.
struct WeatherThemeData {
    let gradientColors: [Color]
    let textColor: Color
}

/// Mirrors the Flutter `ThemeEngine`.
/// Picks a theme from a category x period matrix and derives greetings/periods.
enum ThemeEngine {

    static func getCurrentPeriod(now: Date = Date()) -> TimePeriod {
        let hour = Calendar.current.component(.hour, from: now)
        if hour >= 6 && hour < 12 { return .morning }
        if hour >= 12 && hour < 17 { return .afternoon }
        if hour >= 17 && hour < 20 { return .evening }
        return .night
    }

    static func getGreeting(now: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        if hour < 6 { return "Good night" }
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        if hour < 20 { return "Good evening" }
        return "Good night"
    }

    static func getTheme(category: WeatherCategory, now: Date = Date()) -> WeatherThemeData {
        let period = getCurrentPeriod(now: now)
        let matrix = themeMatrix[category] ?? [:]
        return matrix[period] ?? themeMatrix[.clear]![.night]!
    }

    /// Color matrix translated 1:1 from `theme_engine.dart`.
    private static let themeMatrix: [WeatherCategory: [TimePeriod: WeatherThemeData]] = [
        .sunny: [
            .morning: WeatherThemeData(
                gradientColors: [Color(hex: 0xFEF3C7), Color(hex: 0xFBBF24), Color(hex: 0xF97316)],
                textColor: Color(hex: 0x1E293B)),
            .afternoon: WeatherThemeData(
                gradientColors: [Color(hex: 0xFEF9C3), Color(hex: 0xFACC15), Color(hex: 0xEA580C)],
                textColor: Color(hex: 0x1E293B)),
            .evening: WeatherThemeData(
                gradientColors: [Color(hex: 0x78350F), Color(hex: 0xF97316), Color(hex: 0xFBBF24)],
                textColor: Color(hex: 0xFFFBEB)),
            .night: WeatherThemeData(
                gradientColors: [Color(hex: 0x1C1917), Color(hex: 0x78350F), Color(hex: 0xB45309)],
                textColor: Color(hex: 0xFEF3C7)),
        ],
        .clear: [
            .morning: WeatherThemeData(
                gradientColors: [Color(hex: 0xFCE7F3), Color(hex: 0xF472B6), Color(hex: 0xEC4899)],
                textColor: Color(hex: 0x1E293B)),
            .afternoon: WeatherThemeData(
                gradientColors: [Color(hex: 0xE0F2FE), Color(hex: 0x38BDF8), Color(hex: 0x0284C7)],
                textColor: Color(hex: 0x0C4A6E)),
            .evening: WeatherThemeData(
                gradientColors: [Color(hex: 0x312E81), Color(hex: 0x7C3AED), Color(hex: 0xF472B6)],
                textColor: Color(hex: 0xF1F5F9)),
            .night: WeatherThemeData(
                gradientColors: [Color(hex: 0x020617), Color(hex: 0x1E1B4B), Color(hex: 0x312E81)],
                textColor: Color(hex: 0xE2E8F0)),
        ],
        .slightlyCloudy: [
            .morning: WeatherThemeData(
                gradientColors: [Color(hex: 0xE2E8F0), Color(hex: 0xFBBF24), Color(hex: 0xFB923C)],
                textColor: Color(hex: 0x1E293B)),
            .afternoon: WeatherThemeData(
                gradientColors: [Color(hex: 0xCBD5E1), Color(hex: 0x94A3B8), Color(hex: 0x60A5FA)],
                textColor: Color(hex: 0x0F172A)),
            .evening: WeatherThemeData(
                gradientColors: [Color(hex: 0x1E1B4B), Color(hex: 0x6366F1), Color(hex: 0x94A3B8)],
                textColor: Color(hex: 0xF1F5F9)),
            .night: WeatherThemeData(
                gradientColors: [Color(hex: 0x0F172A), Color(hex: 0x1E293B), Color(hex: 0x334155)],
                textColor: Color(hex: 0xE2E8F0)),
        ],
        .cloud: [
            .morning: WeatherThemeData(
                gradientColors: [Color(hex: 0xD1D5DB), Color(hex: 0x94A3B8), Color(hex: 0x64748B)],
                textColor: Color(hex: 0x1E293B)),
            .afternoon: WeatherThemeData(
                gradientColors: [Color(hex: 0x94A3B8), Color(hex: 0x64748B), Color(hex: 0x475569)],
                textColor: Color(hex: 0xF1F5F9)),
            .evening: WeatherThemeData(
                gradientColors: [Color(hex: 0x334155), Color(hex: 0x475569), Color(hex: 0x64748B)],
                textColor: Color(hex: 0xE2E8F0)),
            .night: WeatherThemeData(
                gradientColors: [Color(hex: 0x0F172A), Color(hex: 0x1E293B), Color(hex: 0x334155)],
                textColor: Color(hex: 0xCBD5E1)),
        ],
        .lightRain: [
            .morning: WeatherThemeData(
                gradientColors: [Color(hex: 0x94A3B8), Color(hex: 0x64748B), Color(hex: 0x3B82F6)],
                textColor: Color(hex: 0xF1F5F9)),
            .afternoon: WeatherThemeData(
                gradientColors: [Color(hex: 0x64748B), Color(hex: 0x475569), Color(hex: 0x2563EB)],
                textColor: Color(hex: 0xE2E8F0)),
            .evening: WeatherThemeData(
                gradientColors: [Color(hex: 0x1E293B), Color(hex: 0x334155), Color(hex: 0x4F46E5)],
                textColor: Color(hex: 0xCBD5E1)),
            .night: WeatherThemeData(
                gradientColors: [Color(hex: 0x020617), Color(hex: 0x0F172A), Color(hex: 0x1E1B4B)],
                textColor: Color(hex: 0x94A3B8)),
        ],
        .rain: [
            .morning: WeatherThemeData(
                gradientColors: [Color(hex: 0x64748B), Color(hex: 0x475569), Color(hex: 0x1D4ED8)],
                textColor: Color(hex: 0xE2E8F0)),
            .afternoon: WeatherThemeData(
                gradientColors: [Color(hex: 0x475569), Color(hex: 0x334155), Color(hex: 0x1E40AF)],
                textColor: Color(hex: 0xCBD5E1)),
            .evening: WeatherThemeData(
                gradientColors: [Color(hex: 0x1E293B), Color(hex: 0x1E1B4B), Color(hex: 0x3730A3)],
                textColor: Color(hex: 0x94A3B8)),
            .night: WeatherThemeData(
                gradientColors: [Color(hex: 0x020617), Color(hex: 0x0F172A), Color(hex: 0x1E1B4B)],
                textColor: Color(hex: 0x64748B)),
        ],
    ]
}

extension Color {
    /// Creates a color from a 0xRRGGBB hex value (mirrors Flutter `Color(0x...)`).
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}