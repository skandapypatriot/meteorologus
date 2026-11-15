import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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

  Future<void> _unpairDevice(String mac, AuthProvider auth, WeatherProvider weather) async {
    final user = auth.user;
    if (user == null) return;
    final theme = context.read<ThemeProvider>().theme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        title: Text(
          'Unpair $mac',
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
      await ClaimService().unclaimDevice(uid: user.uid, mac: mac);
      if (!mounted) return;
      await weather.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E1B4B),
          content: Text(
            'Unpaired $mac. The node resets to pairing mode on its next connection.',
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

  void _navigateToOfflineDevice(String mac) {
    Navigator.pushNamed(context, '/offline-device', arguments: mac);
  }

  void _showOfflineDeviceDialog() {
    final theme = context.read<ThemeProvider>().theme;
    final macController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        title: Text(
          'Connect to Offline Device',
          style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the device MAC address (12 hex characters) to connect to its hotspot.',
              style: TextStyle(color: theme.textColor.withAlpha(180), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: macController,
              style: TextStyle(color: theme.textColor),
              decoration: InputDecoration(
                hintText: 'A1B2C3D4E5F6',
                hintStyle: TextStyle(color: theme.textColor.withAlpha(100)),
                labelText: 'MAC Address',
                labelStyle: TextStyle(color: theme.textColor.withAlpha(150)),
                filled: true,
                fillColor: Colors.black.withAlpha(40),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withAlpha(30)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withAlpha(30)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.textColor.withAlpha(160), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'On the device: Press the wake button 3 times quickly to enable hotspot mode.\n'
              'The device will display the hotspot name and password.',
              style: TextStyle(
                fontSize: 11,
                color: theme.textColor.withAlpha(120),
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: theme.textColor)),
          ),
          ElevatedButton(
            onPressed: () {
              final mac = macController.text.trim().toUpperCase().replaceAll(RegExp(r'[:-]'), '');
              if (RegExp(r'^[A-F0-9]{12}$').hasMatch(mac)) {
                Navigator.of(ctx).pop();
                _navigateToOfflineDevice(mac);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
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
    final user = auth.user;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(theme, user, weather, auth),
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
                        // Menu button + Title
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.menu, color: theme.textColor, size: 26),
                              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                              tooltip: 'Menu',
                            ),
                            const SizedBox(width: 4),
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
                          ],
                        ),
                        // Device selector (if devices exist)
                        if (devices.isNotEmpty)
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

  Widget _buildDrawer(dynamic theme, User? user, WeatherProvider weather, AuthProvider auth) {
    final devices = weather.devices;
    
    return Drawer(
      backgroundColor: const Color(0xFF1E1B4B),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withAlpha(30)),
                ),
              ),
              child: Row(
                children: [
                  Image.asset('assets/logo.png', width: 32, height: 32),
                  const SizedBox(width: 12),
                  Text(
                    'Meteorologus',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: theme.textColor,
                    ),
                  ),
                ],
              ),
            ),

            // User info
            if (user != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withAlpha(20)),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF6366F1),
                      child: Text(
                        user.email?.substring(0, 1).toUpperCase() ?? 'U',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.email ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${devices.length} device${devices.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textColor.withAlpha(120),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Navigation items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.dashboard,
                    label: 'Dashboard',
                    onTap: () => Navigator.pop(context),
                    isSelected: true,
                    textColor: theme.textColor,
                  ),
                  _DrawerItem(
                    icon: Icons.devices,
                    label: 'My Devices (${devices.length})',
                    onTap: () => Navigator.pop(context),
                    textColor: theme.textColor,
                  ),
                  if (devices.isNotEmpty) ...[
                    const Divider(color: Colors.white24, indent: 16, endIndent: 16),
                    ...devices.map((device) => Column(
                      children: [
                        _DrawerItem(
                          icon: Icons.bluetooth_connected,
                          label: device.formattedMac,
                          onTap: () {
                            Navigator.pop(context);
                            weather.selectDevice(device);
                          },
                          textColor: theme.textColor,
                        ),
                        _DrawerItem(
                          icon: Icons.link_off,
                          label: 'Unpair ${device.formattedMac}',
                          onTap: () {
                            Navigator.pop(context);
                            _unpairDevice(device.mac, auth, weather);
                          },
                          textColor: theme.textColor,
                          isDestructive: true,
                        ),
                      ],
                    )),
                  ],
                  const Divider(color: Colors.white24, indent: 16, endIndent: 16),
                  _DrawerItem(
                    icon: Icons.add_circle_outline,
                    label: 'Claim New Device',
                    onTap: () {
                      Navigator.pop(context);
                      _openClaimDialog();
                    },
                    textColor: theme.textColor,
                  ),
                  _DrawerItem(
                    icon: Icons.wifi_find,
                    label: 'Connect Offline Device',
                    onTap: () {
                      Navigator.pop(context);
                      _showOfflineDeviceDialog();
                    },
                    textColor: theme.textColor,
                  ),
                  const Divider(color: Colors.white24, indent: 16, endIndent: 16),
                  _DrawerItem(
                    icon: Icons.history,
                    label: 'View History',
                    onTap: () => Navigator.pop(context),
                    textColor: theme.textColor,
                  ),
                  _DrawerItem(
                    icon: Icons.settings,
                    label: 'Settings',
                    onTap: () => Navigator.pop(context),
                    textColor: theme.textColor,
                  ),
                ],
              ),
            ),

            // Sign out
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withAlpha(20)),
                ),
              ),
              child: _DrawerItem(
                icon: Icons.logout,
                label: 'Sign Out',
                onTap: () {
                  Navigator.pop(context);
                  auth.signOut();
                },
                textColor: theme.textColor,
                isDestructive: true,
              ),
            ),
          ],
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

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color textColor;
  final bool isSelected;
  final bool isDestructive;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.textColor,
    this.isSelected = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? const Color(0xFFFB7185) : textColor;
    final bgColor = isSelected 
        ? const Color(0xFF6366F1).withAlpha(50)
        : Colors.transparent;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: isSelected ? Border.all(color: const Color(0xFF6366F1), width: 1) : null,
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 22),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}