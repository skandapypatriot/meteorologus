import 'package:flutter_test/flutter_test.dart';
import 'package:meteorologus_app/config/theme_engine.dart';
import 'package:meteorologus_app/models/weather_code.dart';

void main() {
  group('ThemeEngine Tests', () {
    test('Time period determination by hour', () {
      expect(ThemeEngine.getCurrentPeriod(DateTime(2026, 8, 26, 7, 0)), TimePeriod.morning);
      expect(ThemeEngine.getCurrentPeriod(DateTime(2026, 8, 26, 13, 0)), TimePeriod.afternoon);
      expect(ThemeEngine.getCurrentPeriod(DateTime(2026, 8, 26, 18, 0)), TimePeriod.evening);
      expect(ThemeEngine.getCurrentPeriod(DateTime(2026, 8, 26, 22, 0)), TimePeriod.night);
      expect(ThemeEngine.getCurrentPeriod(DateTime(2026, 8, 26, 3, 0)), TimePeriod.night);
    });

    test('Greeting strings for each time period', () {
      expect(ThemeEngine.getGreeting(DateTime(2026, 8, 26, 8, 0)), 'Good morning');
      expect(ThemeEngine.getGreeting(DateTime(2026, 8, 26, 14, 0)), 'Good afternoon');
      expect(ThemeEngine.getGreeting(DateTime(2026, 8, 26, 19, 0)), 'Good evening');
      expect(ThemeEngine.getGreeting(DateTime(2026, 8, 26, 23, 0)), 'Good night');
    });

    test('Theme returns 3 gradient colors for all combinations', () {
      for (final cat in WeatherCategory.values) {
        final theme = ThemeEngine.getTheme(cat, DateTime(2026, 8, 26, 9, 0));
        expect(theme.gradientColors.length, 3);
        expect(theme.textColor, isNotNull);
      }
    });
  });
}
