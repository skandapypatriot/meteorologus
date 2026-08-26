import 'package:flutter_test/flutter_test.dart';
import 'package:meteorologus_app/models/weather_code.dart';

void main() {
  group('WeatherCodeHelper Tests', () {
    test('Code <= 10 maps to Sunny', () {
      final info0 = WeatherCodeHelper.getInfo(0);
      expect(info0.category, WeatherCategory.sunny);
      expect(info0.emoji, '☀️');
      expect(info0.label, 'Sunny');

      final info10 = WeatherCodeHelper.getInfo(10);
      expect(info10.category, WeatherCategory.sunny);
    });

    test('Code <= 20 maps to Clear', () {
      final info15 = WeatherCodeHelper.getInfo(15);
      expect(info15.category, WeatherCategory.clear);
      expect(info15.emoji, '🌙');
      expect(info15.label, 'Clear');
    });

    test('Code <= 40 maps to Slightly Cloudy', () {
      final info30 = WeatherCodeHelper.getInfo(30);
      expect(info30.category, WeatherCategory.slightlyCloudy);
      expect(info30.emoji, '⛅');
      expect(info30.label, 'Slightly Cloudy');
    });

    test('Code <= 60 maps to Cloud', () {
      final info55 = WeatherCodeHelper.getInfo(55);
      expect(info55.category, WeatherCategory.cloud);
      expect(info55.emoji, '☁️');
      expect(info55.label, 'Cloud');
    });

    test('Code <= 80 maps to Light Rain', () {
      final info70 = WeatherCodeHelper.getInfo(70);
      expect(info70.category, WeatherCategory.lightRain);
      expect(info70.emoji, '🌦️');
      expect(info70.label, 'Light Rain');
    });

    test('Code > 80 maps to Rain', () {
      final info95 = WeatherCodeHelper.getInfo(95);
      expect(info95.category, WeatherCategory.rain);
      expect(info95.emoji, '🌧️');
      expect(info95.label, 'Rain');
    });

    test('Null or invalid codes fallback safely', () {
      final nullInfo = WeatherCodeHelper.getInfo(null);
      expect(nullInfo.label, 'Unknown');
      expect(nullInfo.emoji, '—');

      final invalidInfo = WeatherCodeHelper.getInfo('invalid_string');
      expect(invalidInfo.label, 'Unknown');
    });
  });
}
