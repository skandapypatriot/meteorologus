import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/device_reading.dart';
import '../../../models/weather_code.dart';
import '../../../utils/glass_container.dart';
import 'sparkline_painter.dart';
import 'weather_icon_widget.dart';

class CurrentSlide extends StatelessWidget {
  final DeviceReading? reading;
  final List<DeviceReading> readings;
  final Color textColor;

  const CurrentSlide({
    super.key,
    required this.reading,
    required this.readings,
    required this.textColor,
  });

  String _formatTime(int? ts) {
    if (ts == null || ts < 1000000) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return 'Updated ${DateFormat.jm().format(dt)}';
  }

  @override
  Widget build(BuildContext context) {
    final info = WeatherCodeHelper.getInfo(reading?.weatherCode);
    final tempStr = reading?.t != null ? reading!.t!.toStringAsFixed(1) : '—';
    final humStr = reading?.h != null ? '${reading!.h!.round()}%' : '—';
    final pressStr = reading?.p != null ? reading!.p!.toStringAsFixed(1) : '—';
    final timeStr = _formatTime(reading?.ts);

    final temps = readings
        .map((r) => r.t)
        .where((t) => t != null && !t.isNaN)
        .cast<double>()
        .toList();

    return GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Weather Visual
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: WeatherVisualWidget(
              category: info.category,
              size: 74,
            ),
          ),

          // Weather state label
          Text(
            info.label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),

          // Updated time
          if (timeStr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor.withAlpha(120),
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 12),

          // Big Temperature
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tempStr,
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -2,
                  height: 1.0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 2),
                child: Text(
                  '°C',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: textColor.withAlpha(200),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Humidity & Pressure cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(38),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withAlpha(15)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        humStr,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'HUMIDITY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: textColor.withAlpha(120),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(38),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withAlpha(15)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        pressStr,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'HPA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: textColor.withAlpha(120),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Sparkline
          if (temps.length >= 2)
            SparklineWidget(
              temperatures: temps,
              color: textColor,
              height: 44,
            ),
        ],
      ),
    );
  }
}
