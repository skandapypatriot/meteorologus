import SwiftUI

/// Mirrors `dashboard_screen.dart`.
struct DashboardView: View {

    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var weather: WeatherViewModel
    @EnvironmentObject private var theme: ThemeViewModel

    @State private var currentPage = 0
    @State private var showClaimSheet = false

    // Accent color loaded once from the asset catalog (matches app tint).
    private let brandBlue = Color(red: 0.23, green: 0.51, blue: 0.96)

    var body: some View {
        contentContainer
            .background(
                LinearGradient(
                    colors: theme.theme.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .onAppear { setup() }
            .onDisappear { weather.stop() }
            .sheet(isPresented: $showClaimSheet) {
                ClaimView(
                    weather: weather,
                    auth: auth
                )
            }
    }

    private var contentContainer: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            greeting
            errorBanner
            mainContent
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Setup

    private func setup() {
        guard let uid = auth.userID else { return }
        weather.tokenProvider = { auth.session?.idToken }
        weather.onUnauthorized = { auth.signOut() }
        weather.onWeatherCodeChange = { code in theme.updateFromWeatherCode(code) }
        weather.start(for: uid)
        theme.refreshPeriod()
        updateTheme()
    }

    private func updateTheme() {
        if let code = weather.latestReading?.weatherCode {
            theme.updateFromWeatherCode(code)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 0) {
                Image("Logo")
                    .resizable()
                    .frame(width: 22, height: 22)
                Text("Meteorologus")
                    .font(.system(size: 19, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundColor(theme.theme.textColor)
                if !weather.devices.isEmpty {
                    DeviceSelectorView(
                        devices: weather.devices,
                        selectedDevice: weather.selectedDevice,
                        onSelected: { weather.selectDevice($0) },
                        onClaimNew: { showClaimSheet = true },
                        textColor: theme.theme.textColor
                    )
                }
            }
            Spacer()
            HStack(spacing: 5) {
                HeaderIconButton(systemImage: "plus", tooltip: "Claim node", textColor: theme.theme.textColor) {
                    showClaimSheet = true
                }
                HeaderIconButton(systemImage: "arrow.clockwise", tooltip: "Refresh", textColor: theme.theme.textColor) {
                    Task { await weather.refresh() }
                }
                HeaderIconButton(systemImage: "rectangle.portrait.and.arrow.right", tooltip: "Sign out", textColor: theme.theme.textColor) {
                    auth.signOut()
                }
            }
        }
    }

    private var greeting: some View {
        Text("\(theme.greeting).")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(theme.theme.textColor.opacity(0.55))
            .padding(.top, 4)
            .padding(.bottom, 12)
    }

    private var errorBanner: some View {
        Group {
            if let message = weather.errorMessage {
                Text(message)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.98, green: 0.44, blue: 0.52))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.98, green: 0.44, blue: 0.52).opacity(0.24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.98, green: 0.44, blue: 0.52).opacity(0.5), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        if weather.isLoading && weather.devices.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tint(theme.theme.textColor)
        } else if weather.devices.isEmpty {
            emptyState
        } else {
            slidesWithIndicator
        }
    }

    private var emptyState: some View {
        GlassCard(padding: EdgeInsets(top: 32, leading: 24, bottom: 32, trailing: 24)) {
            VStack(spacing: 0) {
                Text("\u{1F4E1}")
                    .font(.system(size: 48))
                Text("No devices yet")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.theme.textColor)
                    .padding(.top, 12)
                Text("Scan your node\u{2019}s QR code or enter its MAC to claim it and start monitoring.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.theme.textColor.opacity(0.59))
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                Button {
                    showClaimSheet = true
                } label: {
                    Label("Claim a Weather Node", systemImage: "qrcode.viewfinder")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.glassProminent)
                .tint(brandBlue)
                .padding(.top, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var slidesWithIndicator: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                CurrentSlideView(reading: weather.latestReading, readings: weather.readings, textColor: theme.theme.textColor)
                    .tag(0)
                ForecastSlideView(forecastReading: weather.forecastReading, textColor: theme.theme.textColor)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .padding(.bottom, 10)

            PageIndicatorView(count: 2, currentIndex: currentPage, color: theme.theme.textColor)
                .padding(.bottom, 6)
        }
    }
}