import 'package:flutter/material.dart';
import '../../../models/owned_device.dart';

class DeviceSelector extends StatelessWidget {
  final List<OwnedDevice> devices;
  final OwnedDevice? selectedDevice;
  final ValueChanged<OwnedDevice> onSelected;
  final VoidCallback onClaimNew;
  final Color textColor;

  const DeviceSelector({
    super.key,
    required this.devices,
    required this.selectedDevice,
    required this.onSelected,
    required this.onClaimNew,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return const SizedBox.shrink();
    }

    if (devices.length == 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(50),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withAlpha(20)),
        ),
        child: Text(
          selectedDevice?.mac ?? '',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: textColor,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(50),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedDevice?.mac,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, color: textColor, size: 16),
          dropdownColor: const Color(0xFF1E1B4B),
          borderRadius: BorderRadius.circular(12),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: textColor,
          ),
          items: devices.map((d) {
            return DropdownMenuItem<String>(
              value: d.mac,
              child: Text(
                d.mac,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  letterSpacing: 0.8,
                  fontSize: 11,
                ),
              ),
            );
          }).toList(),
          onChanged: (mac) {
            if (mac == null) return;
            final match = devices.firstWhere((d) => d.mac == mac);
            onSelected(match);
          },
        ),
      ),
    );
  }
}
