import SwiftUI

/// Mirrors `AppRoot` in `main.dart`.
struct AppRoot: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        Group {
            if auth.isAuthenticated {
                DashboardView()
            } else {
                AuthView()
            }
        }
    }
}