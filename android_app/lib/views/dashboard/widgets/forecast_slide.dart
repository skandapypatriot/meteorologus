import 'package:flutter/material.dart';
import '../../../models/device_reading.dart';
import '../../../models/weather_code.dart';
import '../../../utils/glass_container.dart';
import 'weather_icon_widget.dart';

class ForecastSlide extends StatelessWidget {
  final DeviceReading? forecastReading;
  final Color textColor;

  const ForecastSlide({
    super.key,
    required this.forecastReading,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final forecast = forecastReading?.forecast;
    final dayNames = ['Day 1', 'Day 2', 'Day 3'];

    return GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '3-Day Forecast',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(3, (index) {
              final dayCode = (forecast != null &&
                      forecast.length > index &&
                      forecast[index] != null)
                  ? forecast[index]
                  : null;

              final info = WeatherCodeHelper.getInfo(dayCode);
              final hasData = dayCode != null;

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    left: index == 0 ? 0 : 4,
                    right: index == 2 ? 0 : 4,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(38),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withAlpha(15)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        dayNames[index],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: textColor.withAlpha(120),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 38,
                        child: Center(
                          child: hasData
                              ? WeatherVisualWidget(
                                  category: info.category,
                                  size: 36,
                                  animate: false, // keep forecast compact and static
                                )
                              : Text(
                                  '—',
                                  style: TextStyle(
                                    fontSize: 22,
                                    color: textColor.withAlpha(100),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasData ? info.label : 'No data',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
