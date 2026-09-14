import Foundation
import SwiftUI

/// Observable view model mirroring `theme_provider.dart`.
/// Drives the ambient gradient based on the current weather category and time of day.
@MainActor
final class ThemeViewModel: ObservableObject {

    @Published private(set) var category: WeatherCategory = .clear
    @Published private(set) var period: TimePeriod = ThemeEngine.getCurrentPeriod()
    @Published private(set) var lastWeatherCode: Any?

    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let newPeriod = ThemeEngine.getCurrentPeriod()
                if newPeriod != self.period {
                    self.period = newPeriod
                }
            }
        }
    }

    var theme: WeatherThemeData {
        ThemeEngine.getTheme(category: category)
    }

    var greeting: String {
        ThemeEngine.getGreeting()
    }

    func updateFromWeatherCode(_ weatherCode: Any?) {
        lastWeatherCode = weatherCode
        let info = WeatherCodeHelper.getInfo(for: weatherCode)
        if info.category != category {
            category = info.category
            period = ThemeEngine.getCurrentPeriod()
        }
    }

    func refreshPeriod() {
        period = ThemeEngine.getCurrentPeriod()
    }

    deinit {
        timer?.invalidate()
    }
}