import 'package:flutter/material.dart';
import '../models/weather_code.dart';

enum TimePeriod {
  morning,
  afternoon,
  evening,
  night,
}

class WeatherThemeData {
  final List<Color> gradientColors;
  final Color textColor;
  final Color statusBarColor;

  const WeatherThemeData({
    required this.gradientColors,
    required this.textColor,
    required this.statusBarColor,
  });

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors,
      );
}

class ThemeEngine {
  static TimePeriod getCurrentPeriod([DateTime? now]) {
    final dt = now ?? DateTime.now();
    final hour = dt.hour;
    if (hour >= 6 && hour < 12) return TimePeriod.morning;
    if (hour >= 12 && hour < 17) return TimePeriod.afternoon;
    if (hour >= 17 && hour < 20) return TimePeriod.evening;
    return TimePeriod.night;
  }

  static String getGreeting([DateTime? now]) {
    final dt = now ?? DateTime.now();
    final hour = dt.hour;
    if (hour < 6) return 'Good night';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 20) return 'Good evening';
    return 'Good night';
  }

  static final Map<WeatherCategory, Map<TimePeriod, WeatherThemeData>>
      _matrix = {
    WeatherCategory.sunny: {
      TimePeriod.morning: const WeatherThemeData(
        gradientColors: [Color(0xFFFEF3C7), Color(0xFFFBBF24), Color(0xFFF97316)],
        textColor: Color(0xFF1E293B),
        statusBarColor: Color(0xFFF97316),
      ),
      TimePeriod.afternoon: const WeatherThemeData(
        gradientColors: [Color(0xFFFEF9C3), Color(0xFFFACC15), Color(0xFFEA580C)],
        textColor: Color(0xFF1E293B),
        statusBarColor: Color(0xFFEA580C),
      ),
      TimePeriod.evening: const WeatherThemeData(
        gradientColors: [Color(0xFF78350F), Color(0xFFF97316), Color(0xFFFBBF24)],
        textColor: Color(0xFFFFFBEB),
        statusBarColor: Color(0xFF78350F),
      ),
      TimePeriod.night: const WeatherThemeData(
        gradientColors: [Color(0xFF1C1917), Color(0xFF78350F), Color(0xFFB45309)],
        textColor: Color(0xFFFEF3C7),
        statusBarColor: Color(0xFF1C1917),
      ),
    },
    WeatherCategory.clear: {
      TimePeriod.morning: const WeatherThemeData(
        gradientColors: [Color(0xFFFCE7F3), Color(0xFFF472B6), Color(0xFFEC4899)],
        textColor: Color(0xFF1E293B),
        statusBarColor: Color(0xFFEC4899),
      ),
      TimePeriod.afternoon: const WeatherThemeData(
        gradientColors: [Color(0xFFE0F2FE), Color(0xFF38BDF8), Color(0xFF0284C7)],
        textColor: Color(0xFF0C4A6E),
        statusBarColor: Color(0xFF0284C7),
      ),
      TimePeriod.evening: const WeatherThemeData(
        gradientColors: [Color(0xFF312E81), Color(0xFF7C3AED), Color(0xFFF472B6)],
        textColor: Color(0xFFF1F5F9),
        statusBarColor: Color(0xFF312E81),
      ),
      TimePeriod.night: const WeatherThemeData(
        gradientColors: [Color(0xFF020617), Color(0xFF1E1B4B), Color(0xFF312E81)],
        textColor: Color(0xFFE2E8F0),
        statusBarColor: Color(0xFF020617),
      ),
    },
    WeatherCategory.slightlyCloudy: {
      TimePeriod.morning: const WeatherThemeData(
        gradientColors: [Color(0xFFE2E8F0), Color(0xFFFBBF24), Color(0xFFFB923C)],
        textColor: Color(0xFF1E293B),
        statusBarColor: Color(0xFFFB923C),
      ),
      TimePeriod.afternoon: const WeatherThemeData(
        gradientColors: [Color(0xFFCBD5E1), Color(0xFF94A3B8), Color(0xFF60A5FA)],
        textColor: Color(0xFF0F172A),
        statusBarColor: Color(0xFF60A5FA),
      ),
      TimePeriod.evening: const WeatherThemeData(
        gradientColors: [Color(0xFF1E1B4B), Color(0xFF6366F1), Color(0xFF94A3B8)],
        textColor: Color(0xFFF1F5F9),
        statusBarColor: Color(0xFF1E1B4B),
      ),
      TimePeriod.night: const WeatherThemeData(
        gradientColors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
        textColor: Color(0xFFE2E8F0),
        statusBarColor: Color(0xFF0F172A),
      ),
    },
    WeatherCategory.cloud: {
      TimePeriod.morning: const WeatherThemeData(
        gradientColors: [Color(0xFFD1D5DB), Color(0xFF94A3B8), Color(0xFF64748B)],
        textColor: Color(0xFF1E293B),
        statusBarColor: Color(0xFF64748B),
      ),
      TimePeriod.afternoon: const WeatherThemeData(
        gradientColors: [Color(0xFF94A3B8), Color(0xFF64748B), Color(0xFF475569)],
        textColor: Color(0xFFF1F5F9),
        statusBarColor: Color(0xFF475569),
      ),
      TimePeriod.evening: const WeatherThemeData(
        gradientColors: [Color(0xFF334155), Color(0xFF475569), Color(0xFF64748B)],
        textColor: Color(0xFFE2E8F0),
        statusBarColor: Color(0xFF334155),
      ),
      TimePeriod.night: const WeatherThemeData(
        gradientColors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
        textColor: Color(0xFFCBD5E1),
        statusBarColor: Color(0xFF0F172A),
      ),
    },
    WeatherCategory.lightRain: {
      TimePeriod.morning: const WeatherThemeData(
        gradientColors: [Color(0xFF94A3B8), Color(0xFF64748B), Color(0xFF3B82F6)],
        textColor: Color(0xFFF1F5F9),
        statusBarColor: Color(0xFF3B82F6),
      ),
      TimePeriod.afternoon: const WeatherThemeData(
        gradientColors: [Color(0xFF64748B), Color(0xFF475569), Color(0xFF2563EB)],
        textColor: Color(0xFFE2E8F0),
        statusBarColor: Color(0xFF2563EB),
      ),
      TimePeriod.evening: const WeatherThemeData(
        gradientColors: [Color(0xFF1E293B), Color(0xFF334155), Color(0xFF4F46E5)],
        textColor: Color(0xFFCBD5E1),
        statusBarColor: Color(0xFF1E293B),
      ),
      TimePeriod.night: const WeatherThemeData(
        gradientColors: [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF1E1B4B)],
        textColor: Color(0xFF94A3B8),
        statusBarColor: Color(0xFF020617),
      ),
    },
    WeatherCategory.rain: {
      TimePeriod.morning: const WeatherThemeData(
        gradientColors: [Color(0xFF64748B), Color(0xFF475569), Color(0xFF1D4ED8)],
        textColor: Color(0xFFE2E8F0),
        statusBarColor: Color(0xFF1D4ED8),
      ),
      TimePeriod.afternoon: const WeatherThemeData(
        gradientColors: [Color(0xFF475569), Color(0xFF334155), Color(0xFF1E40AF)],
        textColor: Color(0xFFCBD5E1),
        statusBarColor: Color(0xFF1E40AF),
      ),
      TimePeriod.evening: const WeatherThemeData(
        gradientColors: [Color(0xFF1E293B), Color(0xFF1E1B4B), Color(0xFF3730A3)],
        textColor: Color(0xFF94A3B8),
        statusBarColor: Color(0xFF1E293B),
      ),
      TimePeriod.night: const WeatherThemeData(
        gradientColors: [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF1E1B4B)],
        textColor: Color(0xFF64748B),
        statusBarColor: Color(0xFF020617),
      ),
    },
  };

  static WeatherThemeData getTheme(WeatherCategory category, [DateTime? now]) {
    final period = getCurrentPeriod(now);
    return _matrix[category]?[period] ??
        _matrix[WeatherCategory.clear]![TimePeriod.night]!;
  }
}
