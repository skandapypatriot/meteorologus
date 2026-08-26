import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/weather_provider.dart';
import '../../services/claim_service.dart';
import '../../utils/glass_container.dart';
import 'qr_scanner_screen.dart';

class ClaimDialog extends StatefulWidget {
  final String? initialMac;

  const ClaimDialog({super.key, this.initialMac});

  @override
  State<ClaimDialog> createState() => _ClaimDialogState();
}

class _ClaimDialogState extends State<ClaimDialog> {
  late final TextEditingController _macController;
  final ClaimService _claimService = ClaimService();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _macController = TextEditingController(text: widget.initialMac ?? '');
  }

  @override
  void dispose() {
    _macController.dispose();
    super.dispose();
  }

  Future<void> _openScanner() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _macController.text = result;
        _errorMessage = null;
      });
    }
  }

  Future<void> _handleClaim() async {
    final mac = ClaimService.normalizeMac(_macController.text.trim());
    if (!ClaimService.isValidMac(mac)) {
      setState(() {
        _errorMessage = 'Invalid MAC. Please enter 12 hexadecimal characters.';
      });
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      setState(() {
        _errorMessage = 'You must be signed in to claim a device.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isClaimed = await _claimService.isDeviceClaimed(mac);
      if (isClaimed) {
        setState(() {
          _errorMessage = 'This device is already claimed by an account.';
          _isLoading = false;
        });
        return;
      }

      await _claimService.claimDevice(uid: user.uid, mac: mac);

      if (mounted) {
        context.read<WeatherProvider>().refresh();
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Claim failed: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: GlassCard(
        backgroundColor: const Color(0xEE1E1B4B),
        borderColor: Colors.white.withAlpha(40),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isSuccess) ...[
                const Center(
                  child: Text(
                    '✅',
                    style: TextStyle(fontSize: 48),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Device Claimed!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'The node will pick up its key when it connects and start syncing automatically.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withAlpha(180),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: const Color(0xFF3B82F6),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Claim Weather Node',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter the 12-character MAC address shown on your node display or scan its QR code.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withAlpha(180),
                  ),
                ),
                const SizedBox(height: 16),

                // MAC text field
                TextField(
                  controller: _macController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                  ),
                  decoration: InputDecoration(
                    labelText: 'DEVICE MAC ADDRESS',
                    labelStyle: TextStyle(
                      color: Colors.white.withAlpha(150),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                    hintText: 'e.g. 7CDF8B62AC88',
                    hintStyle: TextStyle(
                      color: Colors.white.withAlpha(80),
                      fontFamily: 'monospace',
                    ),
                    filled: true,
                    fillColor: Colors.black.withAlpha(80),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withAlpha(40)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withAlpha(40)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF60A5FA)),
                      onPressed: _openScanner,
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFFB7185),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // Claim Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleClaim,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: const Color(0xFF3B82F6),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Claim Device',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),

                const SizedBox(height: 8),

                // Scan QR Secondary Button
                OutlinedButton.icon(
                  onPressed: _openScanner,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18, color: Colors.white),
                  label: const Text(
                    'Scan with Camera',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.white.withAlpha(50)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
