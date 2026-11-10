import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/weather_provider.dart';
import '../../services/claim_service.dart';
import '../../utils/glass_container.dart';
import '../claim/claim_dialog.dart';
import 'widgets/current_slide.dart';
import 'widgets/device_selector.dart';
import 'widgets/forecast_slide.dart';
import 'widgets/page_indicator.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<WeatherProvider>().initForUser(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openClaimDialog([String? initialMac]) {
    showDialog(
      context: context,
      builder: (_) => ClaimDialog(initialMac: initialMac),
    );
  }

  /// Mirrors the dashboard's "Unpair this device": deletes the node's history,
  /// revokes the claim and drops it from the owner's list. The node erases its
  /// own credentials on the next wake and returns to QR pairing mode.
  Future<void> _unpairSelectedDevice(WeatherProvider weather) async {
    final device = weather.selectedDevice;
    if (device == null) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final theme = context.read<ThemeProvider>().theme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        title: Text(
          'Unpair ${device.mac}',
          style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'The device\'s stored history is erased, the pairing token is revoked, '
          'and the node returns to pairing mode (QR) on its next connection.',
          style: TextStyle(color: theme.textColor.withAlpha(180), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: theme.textColor)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Unpair',
              style: TextStyle(
                color: Color(0xFFFB7185),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ClaimService().unclaimDevice(uid: user.uid, mac: device.mac);
      if (!mounted) return;
      await weather.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E1B4B),
          content: Text(
            'Unpaired ${device.mac}. The node resets to pairing mode on its next connection.',
            style: TextStyle(color: theme.textColor, fontSize: 13),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E1B4B),
          content: Text(
            'Unpair failed: $e',
            style: const TextStyle(color: Color(0xFFFB7185), fontSize: 13),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final weather = context.watch<WeatherProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    // Update ambient theme if weather code is present
    if (weather.latestReading?.weatherCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        themeProvider.updateFromWeatherCode(weather.latestReading!.weatherCode);
      });
    }

    final theme = themeProvider.theme;
    final devices = weather.devices;
    final selectedDevice = weather.selectedDevice;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: theme.gradient,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Image.asset('assets/logo.png', width: 22, height: 22),
                              const SizedBox(width: 8),
                              Text(
                                'Meteorologus',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: theme.textColor,
                                ),
                              ),
                              if (devices.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: DeviceSelector(
                                    devices: devices,
                                    selectedDevice: selectedDevice,
                                    onSelected: (d) => weather.selectDevice(d),
                                    onClaimNew: () => _openClaimDialog(),
                                    textColor: theme.textColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Claim device button
                            _HeaderIconButton(
                              icon: Icons.add,
                              tooltip: 'Claim node',
                              textColor: theme.textColor,
                              onPressed: () => _openClaimDialog(),
                            ),
                            const SizedBox(width: 5),
                            // Unpair button for the selected device
                            _HeaderIconButton(
                              icon: Icons.link_off,
                              tooltip: 'Unpair node',
                              textColor: theme.textColor,
                              onPressed: () => _unpairSelectedDevice(weather),
                            ),
                            const SizedBox(width: 5),
                            // Refresh button
                            _HeaderIconButton(
                              icon: Icons.refresh,
                              tooltip: 'Refresh',
                              textColor: theme.textColor,
                              onPressed: weather.refresh,
                            ),
                            const SizedBox(width: 5),
                            // Sign out button
                            _HeaderIconButton(
                              icon: Icons.logout,
                              tooltip: 'Sign out',
                              textColor: theme.textColor,
                              onPressed: auth.signOut,
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Greeting
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                      child: Text(
                        '${themeProvider.greeting}.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.textColor.withAlpha(140),
                        ),
                      ),
                    ),

                    if (weather.errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0x3DFB7185),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x80FB7185)),
                        ),
                        child: Text(
                          weather.errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFFB7185),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    // Main Content Area
                    Expanded(
                      child: weather.isLoading && devices.isEmpty
                          ? Center(
                              child: CircularProgressIndicator(
                                color: theme.textColor,
                              ),
                            )
                          : devices.isEmpty
                              ? _buildEmptyState(theme.textColor)
                              : _buildDashboardContent(theme.textColor, weather),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📡', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'No devices yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Scan your node\'s QR code or enter its MAC to claim it and start monitoring.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor.withAlpha(150),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _openClaimDialog(),
              icon: const Icon(Icons.qr_code_scanner, size: 18, color: Colors.white),
              label: const Text(
                'Claim a Weather Node',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(Color textColor, WeatherProvider weather) {
    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              CurrentSlide(
                reading: weather.latestReading,
                readings: weather.readings,
                textColor: textColor,
              ),
              ForecastSlide(
                forecastReading: weather.forecastReading,
                textColor: textColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        PageIndicator(
          count: 2,
          currentIndex: _currentPage,
          color: textColor,
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color textColor;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.textColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(35),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withAlpha(50)),
            ),
            child: Icon(
              icon,
              size: 15,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
