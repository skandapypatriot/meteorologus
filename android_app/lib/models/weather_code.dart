enum WeatherCategory {
  sunny,
  clear,
  slightlyCloudy,
  cloud,
  lightRain,
  rain,
}

class WeatherInfo {
  final String emoji;
  final String label;
  final WeatherCategory category;

  const WeatherInfo({
    required this.emoji,
    required this.label,
    required this.category,
  });
}

class WeatherCodeHelper {
  static WeatherInfo getInfo(dynamic code) {
    if (code == null) {
      return const WeatherInfo(
        emoji: '—',
        label: 'Unknown',
        category: WeatherCategory.clear,
      );
    }

    final num? c = num.tryParse(code.toString());
    if (c == null || !c.isFinite) {
      return const WeatherInfo(
        emoji: '—',
        label: 'Unknown',
        category: WeatherCategory.clear,
      );
    }

    if (c <= 10) {
      return const WeatherInfo(
        emoji: '☀️',
        label: 'Sunny',
        category: WeatherCategory.sunny,
      );
    }
    if (c <= 20) {
      return const WeatherInfo(
        emoji: '🌙',
        label: 'Clear',
        category: WeatherCategory.clear,
      );
    }
    if (c <= 40) {
      return const WeatherInfo(
        emoji: '⛅',
        label: 'Slightly Cloudy',
        category: WeatherCategory.slightlyCloudy,
      );
    }
    if (c <= 60) {
      return const WeatherInfo(
        emoji: '☁️',
        label: 'Cloud',
        category: WeatherCategory.cloud,
      );
    }
    if (c <= 80) {
      return const WeatherInfo(
        emoji: '🌦️',
        label: 'Light Rain',
        category: WeatherCategory.lightRain,
      );
    }
    return const WeatherInfo(
      emoji: '🌧️',
      label: 'Rain',
      category: WeatherCategory.rain,
    );
  }
}
