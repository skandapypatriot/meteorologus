import SwiftUI

@main
struct MeteorologusApp: App {

    @StateObject private var auth = AuthViewModel()
    @StateObject private var weather = WeatherViewModel()
    @StateObject private var theme = ThemeViewModel()

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .environmentObject(auth)
                .environmentObject(weather)
                .environmentObject(theme)
        }
    }
}