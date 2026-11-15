import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/offline_service.dart';
import '../../models/offline_device_data.dart';
import '../../utils/glass_container.dart';

class _WeatherIcon extends StatelessWidget {
  final int weatherCode;
  final double size;
  const _WeatherIcon({required this.weatherCode, required this.size});

  String _getEmoji(int code) {
    if (code <= 10) return '☀️';
    if (code <= 20) return '🌙';
    if (code <= 40) return '⛅';
    if (code <= 60) return '☁️';
    if (code <= 80) return '🌦️';
    return '🌧️';
  }

  @override
  Widget build(BuildContext context) {
    return Text(_getEmoji(weatherCode), style: TextStyle(fontSize: size));
  }
}

class OfflineDeviceScreen extends StatefulWidget {
  final String deviceMac;
  const OfflineDeviceScreen({super.key, required this.deviceMac});

  @override
  State<OfflineDeviceScreen> createState() => _OfflineDeviceScreenState();
}

class _OfflineDeviceScreenState extends State<OfflineDeviceScreen> {
  final OfflineService _offlineService = OfflineService();
  OfflineDeviceData? _deviceData;
  bool _isLoading = false;
  bool _isConnected = false;
  String? _errorMessage;
  String? _hotspotSsid;
  String? _hotspotPassword;
  String? _hotspotIp;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  @override
  void dispose() {
    _offlineService.stopAutoScan();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    setState(() => _isLoading = true);
    try {
      final hotspot = await _offlineService.findHotspot();
      if (hotspot != null) {
        setState(() {
          _isConnected = true;
          _hotspotSsid = hotspot.ssid;
          _hotspotPassword = hotspot.password;
          _hotspotIp = hotspot.ipAddress;
        });
        await _fetchData();
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error checking connection: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchData() async {
    if (_hotspotIp == null) return;
    
    try {
      final data = await _offlineService.fetchDataFromHotspot(_hotspotIp!);
      if (data != null && mounted) {
        setState(() {
          _deviceData = data;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to fetch data: $e');
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _checkConnection();
    if (_isConnected) await _fetchData();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.theme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: theme.textColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Offline Device',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: theme.textColor,
                            ),
                          ),
                        ),
                        if (_isConnected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withAlpha(50),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withAlpha(100)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.wifi, size: 14, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(
                                  'Connected',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        IconButton(
                          icon: Icon(Icons.refresh, color: theme.textColor),
                          onPressed: _isLoading ? null : _refreshData,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Connection Status Card
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isConnected ? Icons.wifi : Icons.wifi_off,
                                color: _isConnected ? Colors.green : theme.textColor.withAlpha(100),
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isConnected ? 'Connected to Hotspot' : 'Not Connected',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: theme.textColor,
                                      ),
                                    ),
                                    Text(
                                      _isConnected
                                          ? 'Fetching data from ${widget.deviceMac}'
                                          : 'Connect to the device hotspot to view data',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: theme.textColor.withAlpha(150),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          if (_isConnected) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            _buildInfoRow('Hotspot', _hotspotSsid ?? 'Unknown'),
                            _buildInfoRow('Password', _hotspotPassword ?? 'weather123'),
                            _buildInfoRow('Device IP', _hotspotIp ?? 'Unknown'),
                            if (_deviceData != null) ...[
                              const SizedBox(height: 12),
                              _buildInfoRow('Inferences', '${_deviceData!.inferenceCount} records'),
                              _buildInfoRow('Clients', '${_deviceData!.connectedClients} connected'),
                            ],
                          ] else ...[
                            const SizedBox(height: 16),
                            Text(
                              'Instructions:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: theme.textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '1. On the device, press the wake button 3 times quickly\n'
                              '2. The device will show the hotspot name and password\n'
                              '3. Connect your phone to that WiFi network\n'
                              '4. Return to this screen and tap Refresh',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.textColor.withAlpha(180),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _refreshData,
                              icon: const Icon(Icons.wifi_find, size: 18),
                              label: const Text('Scan for Hotspot'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Data Display
                    if (_deviceData != null) ...[
                      Expanded(
                        child: _buildDataView(theme),
                      ),
                    ] else if (!_isConnected) ...[
                      Expanded(
                        child: Center(
                          child: GlassCard(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cloud_off,
                                  size: 48,
                                  color: theme.textColor.withAlpha(100),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Offline Data',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: theme.textColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Connect to the device hotspot to view stored inferences',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.textColor.withAlpha(150),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFFB7185),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.textColor.withAlpha(140),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataView(dynamic theme) {
    if (_deviceData == null) return const SizedBox();
    
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: theme.textColor,
            unselectedLabelColor: theme.textColor.withAlpha(100),
            indicatorColor: theme.textColor,
            tabs: const [
              Tab(text: 'Current'),
              Tab(text: 'Forecast'),
              Tab(text: 'History'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: [
                _buildCurrentTab(theme),
                _buildForecastTab(theme),
                _buildHistoryTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab(dynamic theme) {
    final latest = _deviceData!.latest;
    if (latest == null) {
      return Center(
        child: Text('No current data', style: TextStyle(color: theme.textColor.withAlpha(100))),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _WeatherIcon(weatherCode: latest.currentWeatherCode, size: 80),
                const SizedBox(height: 12),
                Text(
                  latest.temp.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ),
                ),
                Text(
                  '°C',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: theme.textColor.withAlpha(150),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getWeatherDescription(latest.currentWeatherCode),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.textColor.withAlpha(200),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Updated ${_formatTime(latest.dateTime)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textColor.withAlpha(100),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('Humidity', style: TextStyle(fontSize: 12, color: theme.textColor.withAlpha(100))),
                      const SizedBox(height: 4),
                      Text(
                        '${latest.humidity.toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: theme.textColor),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('Pressure', style: TextStyle(fontSize: 12, color: theme.textColor.withAlpha(100))),
                      const SizedBox(height: 4),
                      Text(
                        '${latest.pressure.toStringAsFixed(1)} hPa',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: theme.textColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForecastTab(dynamic theme) {
    final forecast = _deviceData!.forecast;
    if (forecast.isEmpty || forecast.every((c) => c < 0)) {
      return Center(
        child: Text('No forecast data', style: TextStyle(color: theme.textColor.withAlpha(100))),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(3, (i) {
                if (i >= forecast.length) return const SizedBox();
                final code = forecast[i];
                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Day ${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.textColor.withAlpha(150),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _WeatherIcon(weatherCode: code, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        _getWeatherDescription(code),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(dynamic theme) {
    final history = _deviceData!.history;
    if (history.isEmpty) {
      return Center(
        child: Text('No history available', style: TextStyle(color: theme.textColor.withAlpha(100))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final record = history[index];
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _WeatherIcon(weatherCode: record.currentWeatherCode, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(record.dateTime),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: theme.textColor,
                          ),
                        ),
                        Text(
                          _formatTime(record.dateTime),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textColor.withAlpha(100),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${record.temp.toStringAsFixed(1)}°C',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.textColor,
                        ),
                      ),
                      Text(
                        '${record.humidity.toStringAsFixed(0)}% • ${record.pressure.toStringAsFixed(1)} hPa',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textColor.withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (record.forecastCodes.any((c) => c >= 0)) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(3, (i) {
                    if (i >= record.forecastCodes.length) return const SizedBox();
                    final code = record.forecastCodes[i];
                    if (code < 0) return const SizedBox();
                    return Column(
                      children: [
                        Text(
                          'D${i + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: theme.textColor.withAlpha(100),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _WeatherIcon(weatherCode: code, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          _getWeatherDescription(code),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: theme.textColor.withAlpha(180),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _getWeatherDescription(int code) {
    if (code <= 10) return 'Sunny';
    if (code <= 20) return 'Clear';
    if (code <= 40) return 'Partly Cloudy';
    if (code <= 60) return 'Cloudy';
    if (code <= 80) return 'Light Rain';
    return 'Rain';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}