import 'package:flutter/material.dart';

class QRScannerScreen extends StatelessWidget {
  const QRScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR scan unavailable')),
      body: const Center(
        child: Text(
          'QR scanning is not supported in the web build. Use the Android/iOS app instead.',
        ),
      ),
    );
  }
}
