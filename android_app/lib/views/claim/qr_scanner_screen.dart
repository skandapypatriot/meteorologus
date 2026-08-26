import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/claim_service.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _hasScanned = false;

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawVal = barcode.rawValue;
      if (rawVal != null && rawVal.isNotEmpty) {
        String candidate = rawVal.trim();
        // If it is a URL, get the last segment
        if (candidate.contains('/')) {
          final uri = Uri.tryParse(candidate);
          if (uri != null && uri.pathSegments.isNotEmpty) {
            candidate = uri.pathSegments.last;
          } else {
            candidate = candidate.split('/').last;
          }
        }

        final clean = ClaimService.normalizeMac(candidate);
        if (ClaimService.isValidMac(clean)) {
          _hasScanned = true;
          Navigator.of(context).pop(clean);
          return;
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Scan Node QR Code',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                  color: Colors.white,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                return Icon(
                  state.cameraDirection == CameraFacing.front
                      ? Icons.camera_front
                      : Icons.camera_rear,
                  color: Colors.white,
                );
              },
            ),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Target Box Overlay
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blueAccent, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const Positioned(
            bottom: 40,
            child: Text(
              'Align the QR code shown on node OLED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                backgroundColor: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
