// Model thời tiết + đánh giá mức độ phù hợp cho chuồng gia cầm
// (GET /api/weather/current).

/// Mức độ stress nhiệt theo chỉ số THI.
enum ComfortLevel { comfort, alert, danger, emergency }

ComfortLevel _parseLevel(String? raw) {
  switch (raw) {
    case 'COMFORT':
      return ComfortLevel.comfort;
    case 'DANGER':
      return ComfortLevel.danger;
    case 'EMERGENCY':
      return ComfortLevel.emergency;
    default:
      return ComfortLevel.alert;
  }
}

double _parseDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

int _parseInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

class PoultryComfort {
  final double thi;
  final ComfortLevel level;
  final String label;
  final String headline;
  final bool suitableForCoop;
  final List<String> advices;

  const PoultryComfort({
    required this.thi,
    required this.level,
    required this.label,
    required this.headline,
    required this.suitableForCoop,
    required this.advices,
  });

  factory PoultryComfort.fromJson(Map<String, dynamic> json) {
    return PoultryComfort(
      thi: _parseDouble(json['thi']),
      level: _parseLevel(json['level']?.toString()),
      label: json['label']?.toString() ?? '',
      headline: json['headline']?.toString() ?? '',
      suitableForCoop: json['suitable_for_coop'] == true,
      advices: ((json['advices'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class Weather {
  final String city;
  final String? country;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double precipitation;
  final double windSpeed;
  final String condition;
  final String icon;
  final bool isDay;
  final PoultryComfort comfort;

  const Weather({
    required this.city,
    required this.country,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.precipitation,
    required this.windSpeed,
    required this.condition,
    required this.icon,
    required this.isDay,
    required this.comfort,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    final location = (json['location'] as Map<String, dynamic>?) ?? const {};
    return Weather(
      city: location['city']?.toString() ?? 'Không rõ',
      country: location['country']?.toString(),
      temperature: _parseDouble(json['temperature']),
      feelsLike: _parseDouble(json['feels_like']),
      humidity: _parseInt(json['humidity']),
      precipitation: _parseDouble(json['precipitation']),
      windSpeed: _parseDouble(json['wind_speed']),
      condition: json['condition']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'cloudy',
      isDay: json['is_day'] == true,
      comfort: PoultryComfort.fromJson(
        (json['comfort'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }

  /// Nhiệt độ hiển thị gọn: 26.5 -> "26.5", 26.0 -> "26"
  String get temperatureText =>
      temperature == temperature.roundToDouble()
          ? temperature.toStringAsFixed(0)
          : temperature.toStringAsFixed(1);
}
