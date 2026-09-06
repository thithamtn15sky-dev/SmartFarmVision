import 'package:flutter/material.dart';

import '../colors.dart';
import '../models/weather.dart';

/// Thẻ thời tiết trên Home: nhiệt độ, độ ẩm và kết luận
/// môi trường hiện tại có phù hợp cho chuồng hay không.
class WeatherCard extends StatefulWidget {
  final Weather weather;

  const WeatherCard({super.key, required this.weather});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final weather = widget.weather;
    final gradient = _gradientFor(weather);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.place, size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  weather.city,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                weather.temperatureText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(top: 4, left: 2),
                                child: Text(
                                  '°C',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${weather.condition} • cảm giác ${weather.feelsLike.toStringAsFixed(0)}°C',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _iconFor(weather),
                      size: 60,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _MetricChip(
                      icon: Icons.water_drop_outlined,
                      label: 'Độ ẩm',
                      value: '${weather.humidity}%',
                    ),
                    const SizedBox(width: 8),
                    _MetricChip(
                      icon: Icons.air,
                      label: 'Gió',
                      value: '${weather.windSpeed.toStringAsFixed(0)} km/h',
                    ),
                    const SizedBox(width: 8),
                    _MetricChip(
                      icon: Icons.thermostat,
                      label: 'THI',
                      value: weather.comfort.thi.toStringAsFixed(1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _ComfortBanner(
            comfort: weather.comfort,
            expanded: _expanded,
            onToggle: () => setState(() => _expanded = !_expanded),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(Weather weather) {
    switch (weather.icon) {
      case 'sunny':
        return weather.isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
      case 'partly_cloudy':
        return weather.isDay ? Icons.wb_cloudy_rounded : Icons.nights_stay_rounded;
      case 'cloudy':
        return Icons.cloud_rounded;
      case 'fog':
        return Icons.foggy;
      case 'drizzle':
        return Icons.grain_rounded;
      case 'rain':
        return Icons.umbrella_rounded;
      case 'heavy_rain':
        return Icons.water_drop_rounded;
      case 'thunderstorm':
        return Icons.thunderstorm_rounded;
      case 'snow':
        return Icons.ac_unit_rounded;
      default:
        return Icons.cloud_rounded;
    }
  }

  /// Nền thẻ đổi theo trời nắng/mây/mưa và ngày/đêm.
  List<Color> _gradientFor(Weather weather) {
    if (!weather.isDay) {
      return const [Color(0xFF2C3E63), Color(0xFF1B2440)];
    }
    switch (weather.icon) {
      case 'sunny':
        return const [Color(0xFF4A9DD6), Color(0xFF2B6CA3)];
      case 'partly_cloudy':
        return const [Color(0xFF5B9BC4), Color(0xFF3E7195)];
      case 'cloudy':
      case 'fog':
        return const [Color(0xFF6E8296), Color(0xFF4A5A6B)];
      case 'drizzle':
      case 'rain':
      case 'heavy_rain':
        return const [Color(0xFF4E6E8C), Color(0xFF32485C)];
      case 'thunderstorm':
        return const [Color(0xFF4A4560), Color(0xFF2B2839)];
      case 'snow':
        return const [Color(0xFF8AA6BF), Color(0xFF5F7A93)];
      default:
        return const [Color(0xFF5B9BC4), Color(0xFF3E7195)];
    }
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dải kết luận: môi trường có phù hợp cho chuồng không + khuyến nghị.
class _ComfortBanner extends StatelessWidget {
  final PoultryComfort comfort;
  final bool expanded;
  final VoidCallback onToggle;

  const _ComfortBanner({
    required this.comfort,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(comfort.level);

    return Material(
      color: style.background,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: InkWell(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(style.icon, size: 20, color: style.foreground),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comfort.headline,
                          style: TextStyle(
                            color: style.foreground,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Chỉ số stress nhiệt THI ${comfort.thi} • ${comfort.label}',
                          style: TextStyle(
                            color: style.foreground.withValues(alpha: 0.85),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: style.foreground,
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 10),
                for (final advice in comfort.advices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5, right: 8),
                          child: Icon(Icons.circle, size: 6, color: style.foreground),
                        ),
                        Expanded(
                          child: Text(
                            advice,
                            style: TextStyle(
                              color: style.foreground.withValues(alpha: 0.9),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 30),
                  child: Text(
                    comfort.advices.isEmpty ? '' : comfort.advices.first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: style.foreground.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  _BannerStyle _styleFor(ComfortLevel level) {
    switch (level) {
      case ComfortLevel.comfort:
        return const _BannerStyle(
          background: AgriTechColors.onPrimaryContainer,
          foreground: Color(0xFF102A0C),
          icon: Icons.verified,
        );
      case ComfortLevel.alert:
        return const _BannerStyle(
          background: AgriTechColors.secondaryContainer,
          foreground: Color(0xFF5A3A2E),
          icon: Icons.info_outline,
        );
      case ComfortLevel.danger:
        return const _BannerStyle(
          background: Color(0xFFFFB77C),
          foreground: Color(0xFF5A2D00),
          icon: Icons.warning_amber_rounded,
        );
      case ComfortLevel.emergency:
        return const _BannerStyle(
          background: Color(0xFFFFB4AB),
          foreground: Color(0xFF5C0000),
          icon: Icons.crisis_alert,
        );
    }
  }
}

class _BannerStyle {
  final Color background;
  final Color foreground;
  final IconData icon;

  const _BannerStyle({
    required this.background,
    required this.foreground,
    required this.icon,
  });
}

/// Khung chờ khi đang tải thời tiết.
class WeatherCardLoading extends StatelessWidget {
  const WeatherCardLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 176,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

/// Khung báo lỗi gọn, không chặn phần còn lại của Home.
class WeatherCardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const WeatherCardError({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, color: colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Chưa lấy được thời tiết.\n$message',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          IconButton(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            color: AgriTechColors.primary,
          ),
        ],
      ),
    );
  }
}
