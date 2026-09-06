import 'package:flutter/material.dart';
import '../colors.dart';
import '../models/coop.dart';
import '../models/weather.dart';
import '../services/vaccination_service.dart';
import '../services/weather_service.dart';
import '../theme_notifier.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/weather_card.dart';
import 'camera_screen.dart';
import 'coop_detail_screen.dart';
import 'coops_screen.dart';
import 'scan_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VaccinationService _service = VaccinationService();
  final WeatherService _weatherService = WeatherService();
  late Future<List<CoopSummary>> _coopsFuture;
  late Future<Weather> _weatherFuture;

  @override
  void initState() {
    super.initState();
    _coopsFuture = _service.fetchCoops();
    _weatherFuture = _weatherService.fetchCurrent();
  }

  void _reloadCoops() {
    setState(() {
      _coopsFuture = _service.fetchCoops();
    });
  }

  void _reloadWeather() {
    setState(() {
      _weatherFuture = _weatherService.fetchCurrent();
    });
  }

  Future<void> _reloadAll() async {
    setState(() {
      _coopsFuture = _service.fetchCoops();
      _weatherFuture = _weatherService.fetchCurrent();
    });
    await _coopsFuture.catchError((_) => <CoopSummary>[]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        onRefresh: _reloadAll,
        color: AgriTechColors.primary,
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(context),
            const SizedBox(height: 16),
            _buildWeatherSection(),
            const SizedBox(height: 24),
            // ROW chứa 2 ô Action Card có tương tác
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    title: 'Cân đo & Theo dõi',
                    subtitle: 'Ghi chép cân nặng, tăng trưởng',
                    icon: Icons.scale,
                    backgroundColor: const Color(0xFF2D5A27),
                    textColor: Colors.white,
                    onTap: () {
                      print("Đã bấm vào Cân đo & Theo dõi");
                      // Xử lý sự kiện ở đây (ví dụ: Navigator.push)
                    },
                  ),
                ),
                const SizedBox(width: 16), // Khoảng cách giữa 2 ô
               Expanded(
               child: _ActionCard(
                  title: 'Kiểm tra sức khỏe',
                  subtitle: 'Phát hiện sớm dịch bệnh',
                  icon: Icons.monitor_heart,
                  backgroundColor: const Color(0xFF7A5649),
                  textColor: Colors.white,
                  onTap: () {
                    // Chuyển hướng sang màn hình Camera khi bấm
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CameraScreen()),
                    );
                  },
                ),
                ),
               ],
            ),
            const SizedBox(height: 12),
            // Lối vào lịch sử các lần chẩn đoán đã lưu.
            _HistoryButton(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanHistoryScreen()),
              ),
            ),
            const SizedBox(height: 24),
            _buildHealthDashboard(context),
          ],
        ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentTab: AppTab.home),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      title: Row(
        children: [
          Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'SmartFarm • North Pasture',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      actions: [
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (_, mode, _) {
            return IconButton(
              icon: Icon(
                mode == ThemeMode.light ? Icons.dark_mode : Icons.light_mode,
              ),
              onPressed: () => themeNotifier.value = mode == ThemeMode.light
                  ? ThemeMode.dark
                  : ThemeMode.light,
            );
          },
        ),
      ],
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chào buổi sáng, Quản lý',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Hôm nay trang trại của bạn đang hoạt động ổn định.',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  /// Thẻ thời tiết + kết luận môi trường có phù hợp cho chuồng hay không.
  Widget _buildWeatherSection() {
    return FutureBuilder<Weather>(
      future: _weatherFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const WeatherCardLoading();
        }
        if (snapshot.hasError) {
          return WeatherCardError(
            message: snapshot.error.toString(),
            onRetry: _reloadWeather,
          );
        }
        return WeatherCard(weather: snapshot.data!);
      },
    );
  }

  Widget _buildHealthDashboard(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Expanded để tiêu đề co lại thay vì tràn ngang trên màn hẹp.
            Expanded(
              child: Text(
                'Sức khỏe theo chuồng',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const CoopsScreen()),
                (route) => false,
              ),
              child: Text(
                'Xem tất cả',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Lấy dữ liệu chuồng thật từ backend thay vì danh sách cứng,
        // để số liệu trên Home khớp với màn Coops và màn chi tiết.
        FutureBuilder<List<CoopSummary>>(
          future: _coopsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return _HomeCoopsError(
                message: snapshot.error.toString(),
                onRetry: _reloadCoops,
              );
            }

            final coops = snapshot.data ?? const <CoopSummary>[];
            if (coops.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Chưa có chuồng nào trong hệ thống.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              );
            }

            // Ưu tiên hiển thị chuồng đang trễ lịch tiêm lên trước.
            final sorted = [...coops]..sort((a, b) {
                if (a.hasOverdue != b.hasOverdue) return a.hasOverdue ? -1 : 1;
                return a.safetyScore.compareTo(b.safetyScore);
              });
            final preview = sorted.take(3).toList();

            return Column(
              children: [
                for (final coop in preview) ...[
                  _PenCard(
                    coop: coop,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CoopDetailScreen(coopId: coop.id, coopName: coop.name),
                        ),
                      );
                      if (context.mounted) _reloadCoops();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

}

// WIDGET ACTION CARD TƯƠNG TÁC
class _ActionCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color backgroundColor, textColor;
  final VoidCallback onTap; // Thêm callback để bắt sự kiện click

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap, // Gọi hàm khi bấm
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: textColor, size: 30),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8), // Khoảng cách giãn giữa 2 dòng chữ
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PenCard extends StatelessWidget {
  final CoopSummary coop;
  final VoidCallback onTap;

  const _PenCard({required this.coop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final scoreColor = coop.safetyScore >= 80
        ? AgriTechColors.primary
        : (coop.safetyScore >= 50 ? AgriTechColors.secondary : colorScheme.error);

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                coop.species.toLowerCase().contains('vịt') ? Icons.water_drop : Icons.egg,
                size: 40,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      coop.hasOverdue
                          ? 'Trễ ${coop.overdueCount} mũi tiêm'
                          : 'Đã tiêm ${coop.totalCompleted}/${coop.totalRequired} mũi',
                      style: TextStyle(
                        fontSize: 12,
                        color: coop.hasOverdue
                            ? colorScheme.error
                            : colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${coop.safetyScore}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Khối báo lỗi gọn trên Home khi không lấy được danh sách chuồng từ backend.
class _HomeCoopsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _HomeCoopsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off, size: 20, color: colorScheme.error),
              const SizedBox(width: 8),
              Text(
                'Không tải được dữ liệu chuồng',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Thử lại'),
              style: TextButton.styleFrom(foregroundColor: AgriTechColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút mở lịch sử chẩn đoán ảnh đã lưu trên hệ thống.
class _HistoryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HistoryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AgriTechColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.history,
                    size: 20, color: AgriTechColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lịch sử chẩn đoán',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Xem lại các lần quét ảnh đã lưu',
                      style: TextStyle(
                          fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
