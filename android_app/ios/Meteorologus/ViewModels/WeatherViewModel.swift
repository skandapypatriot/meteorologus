import Foundation

/// Observable view model mirroring `weather_provider.dart`.
/// Polls the Realtime Database REST API every few seconds to emulate the
/// Dart app's real-time stream subscriptions.
@MainActor
final class WeatherViewModel: ObservableObject {

    @Published private(set) var devices: [OwnedDevice] = []
    @Published private(set) var selectedDevice: OwnedDevice?
    @Published private(set) var readings: [DeviceReading] = []
    @Published private(set) var latestReading: DeviceReading?
    @Published private(set) var forecastReading: DeviceReading?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    /// Supplies a fresh ID token on every poll.
    var tokenProvider: (() -> String?)?

    /// Invoked when the database rejects the token (session expired).
    var onUnauthorized: (() -> Void)?

    /// Invoked whenever a new latest reading carries a weather code,
    /// mirroring the `themeProvider.updateFromWeatherCode` call in the Flutter UI.
    var onWeatherCodeChange: ((Any?) -> Void)?

    private let db = DatabaseService()
    private var pollTimer: Timer?
    private var currentUID: String?
    private let pollInterval: TimeInterval = 5

    func start(for uid: String) {
        guard uid != currentUID else { return }
        stop()

        currentUID = uid
        isLoading = true
        Task { await poll() }

        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.currentUID != nil else { return }
                await self.poll()
            }
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        currentUID = nil
        devices = []
        selectedDevice = nil
        readings = []
        latestReading = nil
        forecastReading = nil
        errorMessage = nil
        isLoading = false
    }

    func selectDevice(_ device: OwnedDevice) {
        guard selectedDevice?.mac != device.mac else { return }
        selectedDevice = device
        Task { await poll() }
    }

    /// Manual refresh (also called after claiming a new node).
    func refresh() async {
        await poll()
    }

    // MARK: - Polling

    private func poll() async {
        guard let uid = currentUID, let token = tokenProvider?() else {
            isLoading = false
            return
        }

        do {
            let devs = try await db.getOwnedDevices(uid: uid, authToken: token)
            devices = devs
            errorMessage = nil

            if devs.isEmpty {
                selectedDevice = nil
                readings = []
                latestReading = nil
                forecastReading = nil
            } else {
                if selectedDevice == nil || !devs.contains(where: { $0.mac == selectedDevice?.mac }) {
                    selectedDevice = devs.first
                }
                if let mac = selectedDevice?.mac {
                    let list = try await db.getDeviceReadings(mac: mac, authToken: token)
                    readings = list
                    processReadings(list)
                }
                if let code = latestReading?.weatherCode {
                    onWeatherCodeChange?(code)
                }
            }
        } catch DatabaseError.unauthorized {
            errorMessage = nil
            onUnauthorized?()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func processReadings(_ list: [DeviceReading]) {
        if list.isEmpty {
            latestReading = nil
            forecastReading = nil
            return
        }

        latestReading = list.last

        var forecastNode: DeviceReading?
        var maxTS = 0
        for reading in list {
            if let forecast = reading.forecast, !forecast.isEmpty, (reading.ts ?? 0) >= maxTS {
                forecastNode = reading
                maxTS = reading.ts ?? 0
            }
        }
        forecastReading = forecastNode
    }
}