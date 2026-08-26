import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme_engine.dart';
import '../models/weather_code.dart';

class ThemeProvider extends ChangeNotifier {
  WeatherCategory _category = WeatherCategory.clear;
  TimePeriod _period = ThemeEngine.getCurrentPeriod();
  Timer? _timer;
  dynamic _lastWeatherCode;

  ThemeProvider() {
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final newPeriod = ThemeEngine.getCurrentPeriod();
      if (newPeriod != _period) {
        _period = newPeriod;
        notifyListeners();
      }
    });
  }

  WeatherThemeData get theme => ThemeEngine.getTheme(_category);
  WeatherCategory get category => _category;
  TimePeriod get period => _period;
  String get greeting => ThemeEngine.getGreeting();
  dynamic get lastWeatherCode => _lastWeatherCode;

  void updateFromWeatherCode(dynamic weatherCode) {
    _lastWeatherCode = weatherCode;
    final info = WeatherCodeHelper.getInfo(weatherCode);
    if (info.category != _category) {
      _category = info.category;
      _period = ThemeEngine.getCurrentPeriod();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
