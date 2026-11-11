import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/offline_service.dart';
import '../../models/device_reading.dart';
import '../../models/weather_code.dart';
import '../../utils/glass_container.dart';
import '../dashboard/widgets/current_slide.dart';
import '../dashboard/widgets/forecast_slide.dart';

class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState>();
}

class _OfflineScreenState extends State<OfflineScreen> {
  final _ipController = TextEditingController(text: '192.168.4.1');
  final OfflineService _offlineService = OfflineService();

  bool _isLoading = false;
  String? _errorMessage;
  String? _statusMessage;
  DeviceReading? _latest;
  List<DeviceReading> _readings = [];

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _connect() async {
    final ip = kDefaultDeviceIp;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Connecting to $ip...';
    });

    try {
      final reachable = await _offlineService.isReachable(ip);
      if (!reachable) {
        setState(() {
          _errorMessage = 'Could not reach device at $ip. Make sure the node hotspot (WeatherMonitor-*) is active.';
          _isLoading = false;
          _statusMessage = null;
        });
        return;
      }

      final latest = await _offlineService.fetchLatest(ip);
      final readings = await _offlineService.fetchReadings(ip);

      setState(() {
        _latest = latest;
        _readings = readings;
        _isLoading = false;
        _statusMessage = 'Connected. ${readings.length} reading(s) stored on device.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection failed: $e';
        _isLoading = false;
        _statusMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Mode'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Connect to Node Hotspot',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join the WeatherMonitor-* Wi-Fi hotspot on your phone, then tap Connect.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(38),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withAlpha(15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi, size: 18, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$kDefaultDeviceIp:81',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withAlpha(30),
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade900.withAlpha(30),
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _connect,
                icon: const Icon(Icons.wifi),
                label: const Text('Connect'),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _latest == null
                        ? const Center(
                            child: Text(
                              'Not connected yet. Enter the device IP and tap Connect.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: PageView(
                                  children: [
                                    CurrentSlide(
                                      reading: _latest,
                                      readings: _readings,
                                      textColor: theme.colorScheme.onSurface,
                                    ),
                                    ForecastSlide(
                                      forecastReading: _latest,
                                      textColor: theme.colorScheme.onSurface,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Offline data · clears after 30 days',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
